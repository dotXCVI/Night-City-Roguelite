// -----------------------------------------------------------------------------
// Night City Roguelite - arena director
// -----------------------------------------------------------------------------
// Teleports V to an arena's start point and keeps V inside it:
//   - ArenaWalls.reds builds a ring of solid walls (real collision) that light
//     up as red NCPD holo-tape when V gets close;
//   - a position check ten times a second is the safety net: if V still ends
//     up past the wall (or far below the arena), V is put back at the last
//     position that was inside.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLArenaDirector extends IScriptable {
  private let m_system: wref<RogueliteSystem>;
  private let m_arena: ref<RLArenaDef>;
  private let m_walls: ref<RLArenaWalls>;
  private let m_wallsActive: Bool;
  private let m_tickID: DelayID;
  private let m_lastInside: Vector4;
  private let m_hasLastInside: Bool;
  private let m_noticeCooldown: Float;
  private let m_contactCooldown: Float;

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLArenaDirector> {
    let director = new RLArenaDirector();
    director.m_system = system;
    director.m_walls = RLArenaWalls.Create();
    return director;
  }

  public func GetArena() -> ref<RLArenaDef> = this.m_arena

  public func GetCenter() -> Vector4 {
    return IsDefined(this.m_arena) ? this.m_arena.position : Vector4(0.0, 0.0, 0.0, 1.0);
  }

  public func OnSessionEnd() {
    this.StopWalls();
    this.m_walls.OnSessionEnd();
  }

  // --- Teleport -------------------------------------------------------------------------

  public func Enter(player: ref<PlayerPuppet>, arena: ref<RLArenaDef>) {
    this.m_arena = arena;
    this.m_hasLastInside = false;
    RLArenaDirector.TeleportToPoint(player, arena.position, arena.yaw);
    RLLog(s"Arena start: \(arena.name) at (\(arena.position.X), \(arena.position.Y), \(arena.position.Z)).");
  }

  public static func TeleportToPoint(player: ref<PlayerPuppet>, position: Vector4, yaw: Float) {
    let rotation: EulerAngles;
    rotation.Yaw = yaw;
    GameInstance.GetTeleportationFacility(player.GetGame()).Teleport(player, position, rotation);
  }

  // --- Walls -----------------------------------------------------------------------------

  public func StartWalls() {
    if !IsDefined(this.m_arena) {
      return;
    }
    this.m_noticeCooldown = 0.0;
    this.m_contactCooldown = 0.0;
    this.m_walls.Build(this.m_arena);
    if !this.m_wallsActive {
      this.m_wallsActive = true;
      this.ScheduleTick();
    }
  }

  public func StopWalls() {
    if this.m_wallsActive {
      this.m_wallsActive = false;
      RLCancel(GetGameInstance(), this.m_tickID);
    }
    this.m_walls.Clear();
  }

  private func ScheduleTick() {
    this.m_tickID = RLDelay(GetGameInstance(), this, n"wall", 0.1);
  }

  public func OnDelayed(action: CName) {
    if !Equals(action, n"wall") || !this.m_wallsActive {
      return;
    }
    let player = GetPlayer(GetGameInstance());
    if IsDefined(player) && IsDefined(this.m_arena) {
      this.m_walls.Update(player);
      this.CheckBounds(player);
    }
    this.ScheduleTick();
  }

  private func CheckBounds(player: ref<PlayerPuppet>) {
    if this.m_noticeCooldown > 0.0 {
      this.m_noticeCooldown -= 0.1;
    }
    if this.m_contactCooldown > 0.0 {
      this.m_contactCooldown -= 0.1;
    }
    let position = player.GetWorldPosition();
    let center = this.m_arena.position;
    let distance = Vector4.Distance2D(position, center);

    // Walking into the wall: a short reminder of why it's there.
    if distance >= this.m_arena.radius - 1.2 && this.m_contactCooldown <= 0.0 {
      this.m_contactCooldown = 8.0;
      RLNotify(player.GetGame(), "Arena sealed. You go home when the fight is over.", 3.0);
    }

    let inside = distance <= this.m_arena.radius + RLConfig.WallBackstopMargin()
      && position.Z > center.Z - RLConfig.ArenaFloorDrop();
    if inside {
      // Only remember spots clearly inside the wall as return points.
      if distance <= this.m_arena.radius - 1.0 {
        this.m_lastInside = position;
        this.m_hasLastInside = true;
      }
      return;
    }
    // Got past the wall anyway (glitch, vehicle, fall): put V back.
    let target = this.m_hasLastInside ? this.m_lastInside : center;
    RLArenaDirector.TeleportToPoint(player, target, player.GetWorldYaw());
    if this.m_noticeCooldown <= 0.0 {
      this.m_noticeCooldown = 4.0;
      RLNotify(player.GetGame(), "Arena boundary.", 2.0);
    }
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - arena director
// -----------------------------------------------------------------------------
// Teleports V to an arena's start point and keeps V inside it with an
// invisible wall: five times a second V's position is checked, and if V has
// crossed the boundary (or dropped far below the arena), V is put back at the
// last position that was inside. Pushing against the edge feels like a wall.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLArenaDirector extends IScriptable {
  private let m_system: wref<RogueliteSystem>;
  private let m_arena: ref<RLArenaDef>;
  private let m_wallsActive: Bool;
  private let m_tickID: DelayID;
  private let m_lastInside: Vector4;
  private let m_hasLastInside: Bool;
  private let m_noticeCooldown: Float;

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLArenaDirector> {
    let director = new RLArenaDirector();
    director.m_system = system;
    return director;
  }

  public func GetArena() -> ref<RLArenaDef> = this.m_arena

  public func GetCenter() -> Vector4 {
    return IsDefined(this.m_arena) ? this.m_arena.position : Vector4(0.0, 0.0, 0.0, 1.0);
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

  // --- Invisible walls ---------------------------------------------------------------------

  public func StartWalls() {
    if !IsDefined(this.m_arena) {
      return;
    }
    this.m_noticeCooldown = 0.0;
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
  }

  private func ScheduleTick() {
    this.m_tickID = RLDelay(GetGameInstance(), this, n"wall", 0.2);
  }

  public func OnDelayed(action: CName) {
    if !Equals(action, n"wall") || !this.m_wallsActive {
      return;
    }
    this.CheckWalls();
    this.ScheduleTick();
  }

  private func CheckWalls() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_arena) {
      return;
    }
    if this.m_noticeCooldown > 0.0 {
      this.m_noticeCooldown -= 0.2;
    }
    let position = player.GetWorldPosition();
    let center = this.m_arena.position;
    let inside = Vector4.Distance2D(position, center) <= this.m_arena.radius
      && position.Z > center.Z - RLConfig.ArenaFloorDrop();
    if inside {
      this.m_lastInside = position;
      this.m_hasLastInside = true;
      return;
    }
    let target = this.m_hasLastInside ? this.m_lastInside : center;
    RLArenaDirector.TeleportToPoint(player, target, player.GetWorldYaw());
    if this.m_noticeCooldown <= 0.0 {
      this.m_noticeCooldown = 4.0;
      RLNotify(player.GetGame(), "Arena boundary.", 2.0);
    }
  }
}

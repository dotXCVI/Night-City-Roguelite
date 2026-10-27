// -----------------------------------------------------------------------------
// Night City Roguelite - V's apartment hub
// -----------------------------------------------------------------------------
// Whenever V isn't in an arena, V is in the Megabuilding H10 apartment:
//   - after the takeover, on every load and after every arena V is put inside;
//   - the front door is sealed (Hub/HomeDevices.reds);
//   - a soft lock keeps V there as a safety net: get out anyway (glitching
//     through a wall, anything) and V is put back after a moment.
//
// Getting in: the apartment's floor streams in a little after the rest of the
// building, so dropping V straight inside from across the city can land V on
// nothing. V is first put in the hallway outside the front door, and steps
// inside as soon as a downward ray finds the apartment floor. If it never
// loads, the hallway is home for that session.
//
// Safety: V is invulnerable while being moved. If V ends up somewhere else
// entirely after a placement, the next fallback is tried (apartment ->
// hallway -> the spot where the takeover happened).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLHomeMode {
  Unknown = 0,
  Apartment = 1,
  Hallway = 2,
}

public class RLApartmentHub extends RLDelayTarget {
  private let m_system: wref<RogueliteSystem>;
  private let m_leashActive: Bool;
  private let m_tickID: DelayID;
  private let m_outsideSeconds: Float;
  private let m_graceSeconds: Float;
  private let m_broken: Bool;
  private let m_mode: RLHomeMode;
  private let m_entering: Bool;
  private let m_enterElapsed: Float;
  private let m_target: Vector4;
  private let m_targetInside: Bool;
  private let m_failures: Int32;
  private let m_settled: Bool;

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLApartmentHub> {
    let hub = new RLApartmentHub();
    hub.m_system = system;
    return hub;
  }

  public func IsEnabled() -> Bool {
    return RLConfig.UseApartmentHub() && !this.m_broken;
  }

  public func IsBroken() -> Bool = this.m_broken

  // --- Session ----------------------------------------------------------------------

  public func OnSessionStart() {
    this.m_broken = false;
    this.m_mode = RLHomeMode.Unknown;
    this.m_entering = false;
    this.m_failures = 0;
    this.m_outsideSeconds = 0.0;
    this.m_settled = false;
  }

  // V has been placed and checked: inside the apartment, or in the hallway
  // when that is home for this session.
  public func IsSettled() -> Bool = (this.m_settled || this.m_broken) && !this.m_entering

  public func OnSessionEnd() {
    this.StopLeash();
    this.m_entering = false;
  }

  // --- Placement ----------------------------------------------------------------------

  public func SendHome(player: ref<PlayerPuppet>) {
    if !this.IsEnabled() || !IsDefined(player) {
      return;
    }
    if !this.IsInside(player) {
      this.TeleportHome(player);
      RLLog("Sent V home.");
    } else if !this.m_entering {
      this.m_settled = true;
    }
  }

  private func TeleportHome(player: ref<PlayerPuppet>) {
    let game = player.GetGame();
    GameInstance.GetGodModeSystem(game)
      .AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NightCityRoguelite.Home");
    this.m_outsideSeconds = 0.0;
    if Equals(this.m_mode, RLHomeMode.Apartment) && RLApartmentHub.InteriorLoaded(game) {
      this.PlaceInside(player);
      return;
    }
    this.PlaceInHallway(player);
    if !Equals(this.m_mode, RLHomeMode.Hallway) && !this.m_entering {
      // Wait for the apartment to stream in, then step inside.
      this.m_entering = true;
      this.m_enterElapsed = 0.0;
      RLDelay(game, this, n"enter", 0.5);
    }
  }

  private func PlaceInside(player: ref<PlayerPuppet>) {
    this.Place(player, RLApartmentHub.SpawnPoint(player.GetGame()), RLConfig.ApartmentYaw(), true);
  }

  private func PlaceInHallway(player: ref<PlayerPuppet>) {
    this.Place(player, RLConfig.HallwayPosition(), RLConfig.HallwayYaw(), false);
  }

  private func Place(player: ref<PlayerPuppet>, target: Vector4, yaw: Float, inside: Bool) {
    this.m_target = target;
    this.m_targetInside = inside;
    this.m_settled = false;
    this.m_graceSeconds = 5.0;
    RLArenaDirector.TeleportToPoint(player, target, yaw);
    RLDelay(player.GetGame(), this, n"verify", 4.0);
  }

  // The configured spot, nudged onto the navmesh when the room is loaded.
  public static func SpawnPoint(game: GameInstance) -> Vector4 {
    let anchor = RLConfig.ApartmentPosition();
    let found = GameInstance.GetNavigationSystem(game).FindPointInSphereOnlyHumanNavmesh(anchor, 1.5, NavGenAgentSize.Human, false);
    if Equals(found.status, worldNavigationRequestStatus.OK) && AbsF(found.point.Z - anchor.Z) < 1.0
      && RLApartmentHub.InBox(found.point, RLConfig.ApartmentMin(), RLConfig.ApartmentMax()) {
      return found.point;
    }
    return anchor;
  }

  // True once there is solid floor under the apartment spawn point.
  public static func InteriorLoaded(game: GameInstance) -> Bool {
    let anchor = RLConfig.ApartmentPosition();
    let start = Vector4(anchor.X, anchor.Y, anchor.Z + 1.0, 1.0);
    let end = Vector4(anchor.X, anchor.Y, anchor.Z - 1.5, 1.0);
    let result: TraceResult;
    let hit = GameInstance.GetSpatialQueriesSystem(game).SyncRaycastByCollisionGroup(start, end, n"Static", result, true, false);
    return hit && TraceResult.IsValid(result) && AbsF(result.position.Z - anchor.Z) < 1.0;
  }

  // Inside the apartment; the hallway also counts until the apartment has
  // been reached (and for good if it never loads).
  public func IsInside(player: ref<PlayerPuppet>) -> Bool {
    let position = player.GetWorldPosition();
    if RLApartmentHub.InBox(position, RLConfig.ApartmentMin(), RLConfig.ApartmentMax()) {
      return true;
    }
    return NotEquals(this.m_mode, RLHomeMode.Apartment)
      && RLApartmentHub.InBox(position, RLConfig.HallwayMin(), RLConfig.HallwayMax());
  }

  public static func InBox(position: Vector4, low: Vector4, high: Vector4) -> Bool {
    return position.X >= low.X && position.X <= high.X
      && position.Y >= low.Y && position.Y <= high.Y
      && position.Z >= low.Z && position.Z <= high.Z;
  }

  // --- Soft lock ------------------------------------------------------------------------

  public func StartLeash() {
    if !this.IsEnabled() {
      return;
    }
    this.m_outsideSeconds = 0.0;
    if !this.m_leashActive {
      this.m_leashActive = true;
      this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
    }
  }

  public func StopLeash() {
    if this.m_leashActive {
      this.m_leashActive = false;
      RLCancel(GetGameInstance(), this.m_tickID);
    }
  }

  public func OnDelayed(action: CName) {
    switch action {
      case n"tick":
        if this.m_leashActive {
          this.Tick();
          this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
        }
        break;
      case n"enter":
        this.TryEnter();
        break;
      case n"verify":
        this.Verify();
        break;
    }
  }

  // Polls for the apartment floor while V waits in the hallway.
  private func TryEnter() {
    if !this.m_entering {
      return;
    }
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !this.IsEnabled() {
      this.m_entering = false;
      return;
    }
    let game = player.GetGame();
    if RogueliteSystem.IsStoryBusy(player) {
      // Don't move V mid-conversation; keep waiting.
      RLDelay(game, this, n"enter", 0.5);
      return;
    }
    if RLApartmentHub.InteriorLoaded(game) {
      // Only once V has actually arrived in the hallway (a teleport can take
      // a moment to apply) - and not if V has been sent to an arena since.
      if this.IsInside(player) || Vector4.Distance(player.GetWorldPosition(), RLConfig.HallwayPosition()) < 4.0 {
        this.m_entering = false;
        this.m_mode = RLHomeMode.Apartment;
        RLLog(s"Apartment loaded after \(this.m_enterElapsed)s - moving V inside.");
        this.PlaceInside(player);
        return;
      }
      if !this.m_leashActive {
        this.m_entering = false;
        return;
      }
    }
    this.m_enterElapsed += 0.5;
    if this.m_enterElapsed >= RLConfig.ApartmentLoadTimeout() {
      this.m_entering = false;
      this.m_mode = RLHomeMode.Hallway;
      this.m_settled = true;
      RLLog("The apartment never loaded - the hallway is home for this session.");
      this.ReleaseGodMode(player);
      return;
    }
    RLDelay(game, this, n"enter", 0.5);
  }

  private func Tick() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !this.IsEnabled() {
      return;
    }
    if this.m_graceSeconds > 0.0 {
      this.m_graceSeconds -= 1.0;
      return;
    }
    // Quests may unlock the front door again; keep it sealed.
    if RLHomeDevices.ShouldSealDoor(player.GetGame()) {
      RLHomeDevices.SealFrontDoor(player.GetGame(), true);
    }
    if this.m_entering || RogueliteSystem.IsInVehicle(player) || RogueliteSystem.IsStoryBusy(player) {
      return;
    }
    if this.IsInside(player) {
      this.m_outsideSeconds = 0.0;
      return;
    }
    this.m_outsideSeconds += 1.0;
    if this.m_outsideSeconds >= RLConfig.ApartmentLeashSeconds() {
      this.TeleportHome(player);
      RLNotify(player.GetGame(), "The door's sealed. Use your computer (or F7) for the terminal.", 5.0);
    }
  }

  // A few seconds after a placement: if V isn't near where V was put (fell
  // through an unloaded floor and was rescued elsewhere by the game), try the
  // next fallback.
  private func Verify() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !this.IsEnabled() {
      return;
    }
    // V has left home since (sent to an arena): nothing to check.
    if !this.m_leashActive && !this.m_entering {
      return;
    }
    let position = player.GetWorldPosition();
    let distance = Vector4.Distance(position, this.m_target);
    RLLog(s"Home check: V at (\(position.X), \(position.Y), \(position.Z)), \(distance) m from the \(this.m_targetInside ? "apartment" : "hallway") spot.");
    if distance <= 15.0 {
      this.m_failures = 0;
      if this.m_targetInside || Equals(this.m_mode, RLHomeMode.Hallway) {
        this.m_settled = true;
      }
      if !this.m_entering {
        this.ReleaseGodMode(player);
      }
      return;
    }
    this.m_failures += 1;
    if this.m_targetInside {
      RLLog("V didn't stay in the apartment - using the hallway for this session.");
      this.m_mode = RLHomeMode.Hallway;
      this.PlaceInHallway(player);
      return;
    }
    if this.m_failures < 4 {
      // The game sometimes drops a teleport (right after loading, mid-scene).
      RLLog("Trying the hallway again.");
      this.PlaceInHallway(player);
      return;
    }
    this.m_entering = false;
    this.m_broken = true;
    this.StopLeash();
    this.ReleaseGodMode(player);
    RLLog("V couldn't be placed at the apartment - home falls back to the takeover spot for this session.");
    if IsDefined(this.m_system) {
      this.m_system.OnApartmentUnavailable();
    }
  }

  private func ReleaseGodMode(player: ref<PlayerPuppet>) {
    GameInstance.GetGodModeSystem(player.GetGame())
      .RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NightCityRoguelite.Home");
  }
}

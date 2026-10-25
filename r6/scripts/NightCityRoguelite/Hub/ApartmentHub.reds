// -----------------------------------------------------------------------------
// Night City Roguelite - V's apartment hub
// -----------------------------------------------------------------------------
// Whenever V isn't in an arena, V is in the Megabuilding H10 apartment:
//   - after the takeover, on every load and after every arena V is put inside;
//   - a soft lock keeps V there: leave the apartment (front door, glitching
//     through a wall, anything) and V is put back inside after a moment;
//
// Inside test: the game's district tracker reports "LittleChina_VApartment"
// while V is in the apartment. Until that district has been seen once this
// session, a distance/height check around the spawn point is used instead.
//
// Safety: if V ends up well below the apartment floor after being put there
// (the apartment didn't stream in), the apartment hub is switched off for the
// session and the run system falls back to the takeover spot.
//
// The world itself streams around V, so while V is in the apartment only the
// area around H10 is loaded, and each arena streams in when V is sent there.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLApartmentHub extends IScriptable {
  private let m_system: wref<RogueliteSystem>;
  private let m_leashActive: Bool;
  private let m_tickID: DelayID;
  private let m_outsideSeconds: Float;
  private let m_graceSeconds: Float;
  private let m_seenDistrict: Bool;
  private let m_broken: Bool;
  private let m_doorCallbackRegistered: Bool;
  private let m_loggedDoors: array<Uint32>;

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
    this.m_seenDistrict = false;
    this.m_broken = false;
    this.m_outsideSeconds = 0.0;
    ArrayClear(this.m_loggedDoors);
    if RLConfig.UseApartmentHub() && RLConfig.LogApartmentDoors() && !this.m_doorCallbackRegistered {
      // Session-scoped: auto-removed by the callback system when the session ends.
      GameInstance.GetCallbackSystem()
        .RegisterCallback(n"Entity/Attach", this, n"OnDoorAttached")
        .AddTarget(EntityTarget.Type(n"Door"));
      this.m_doorCallbackRegistered = true;
    }
  }

  public func OnSessionEnd() {
    this.StopLeash();
    this.m_doorCallbackRegistered = false;
  }

  // --- Placement ----------------------------------------------------------------------

  public func SendHome(player: ref<PlayerPuppet>) {
    if !this.IsEnabled() || !IsDefined(player) {
      return;
    }
    if !this.IsInside(player) {
      this.TeleportHome(player);
      RLLog("Sent V to the apartment.");
    }
  }

  // Teleports V into the apartment. V is invulnerable until the landing has
  // been checked, so a missing floor can't turn into a fatal fall.
  private func TeleportHome(player: ref<PlayerPuppet>) {
    GameInstance.GetGodModeSystem(player.GetGame())
      .AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NightCityRoguelite.Home");
    RLArenaDirector.TeleportToPoint(player, RLConfig.ApartmentPosition(), RLConfig.ApartmentYaw());
    // Give streaming and the district trigger time before judging position.
    this.m_graceSeconds = 4.0;
    this.m_outsideSeconds = 0.0;
    RLDelay(player.GetGame(), this, n"verify", 4.0);
  }

  public func IsInside(player: ref<PlayerPuppet>) -> Bool {
    if Equals(RLApartmentHub.CurrentDistrictName(player.GetGame()), RLConfig.ApartmentDistrict()) {
      this.m_seenDistrict = true;
      return true;
    }
    if this.m_seenDistrict {
      return false;
    }
    let anchor = RLConfig.ApartmentPosition();
    let position = player.GetWorldPosition();
    return Vector4.Distance2D(position, anchor) <= RLConfig.ApartmentRadius()
      && AbsF(position.Z - anchor.Z) <= RLConfig.ApartmentHeightTolerance();
  }

  public static func CurrentDistrictName(game: GameInstance) -> String {
    let prevention = GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(prevention) {
      return "";
    }
    let district = prevention.GetCurrentDistrict();
    if !IsDefined(district) {
      return "";
    }
    let record = district.GetDistrictRecord();
    if !IsDefined(record) {
      return "";
    }
    return record.EnumName();
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
      case n"verify":
        this.Verify();
        break;
    }
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
    if RogueliteSystem.IsInVehicle(player) || !RogueliteSystem.IsPlayerFree(player) {
      return;
    }
    if this.IsInside(player) {
      this.m_outsideSeconds = 0.0;
      return;
    }
    this.m_outsideSeconds += 1.0;
    if this.m_outsideSeconds >= RLConfig.ApartmentLeashSeconds() {
      this.TeleportHome(player);
      RLNotify(player.GetGame(), "The door's locked. Press F7 for the terminal.", 5.0);
    }
  }

  // After a teleport home: if V is far below the apartment floor, the interior
  // didn't stream in. Switch the apartment hub off for this session.
  private func Verify() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !RLConfig.UseApartmentHub() {
      return;
    }
    let anchor = RLConfig.ApartmentPosition();
    let position = player.GetWorldPosition();
    let district = RLApartmentHub.CurrentDistrictName(player.GetGame());
    GameInstance.GetGodModeSystem(player.GetGame())
      .RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NightCityRoguelite.Home");
    RLLog(s"Apartment check: district '\(district)', height offset \(position.Z - anchor.Z).");
    if position.Z < anchor.Z - 5.0 {
      this.m_broken = true;
      this.StopLeash();
      RLLog("V fell below the apartment floor - apartment hub disabled for this session.");
      if IsDefined(this.m_system) {
        this.m_system.OnApartmentUnavailable();
      }
    }
  }

  // --- Door diagnostics -------------------------------------------------------------------

  protected cb func OnDoorAttached(event: ref<EntityLifecycleEvent>) {
    let door = event.GetEntity() as GameObject;
    if !IsDefined(door) {
      return;
    }
    let distance = Vector4.Distance(door.GetWorldPosition(), RLConfig.ApartmentPosition());
    if distance > 25.0 {
      return;
    }
    let hash = EntityID.GetHash(door.GetEntityID());
    if ArrayContains(this.m_loggedDoors, hash) {
      return;
    }
    ArrayPush(this.m_loggedDoors, hash);
    let position = door.GetWorldPosition();
    RLLog(s"Door near apartment: id \(hash), class \(door.GetClassName()), distance \(distance), position (\(position.X), \(position.Y), \(position.Z)).");
  }
}

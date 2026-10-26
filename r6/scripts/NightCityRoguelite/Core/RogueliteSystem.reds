// -----------------------------------------------------------------------------
// Night City Roguelite - run system (orchestrator)
// -----------------------------------------------------------------------------
// One instance per game session. Persistent fields go into the save file and
// tag the playthrough as a roguelite character; everything about the current
// run is in memory only, because saving is locked while a run is active.
//
// Flow (everything is driven from the terminal, F7):
//
//   new game -> AwaitingTakeover -> Hub (locked in V's apartment)
//   Hub --START RUN--> Preparing --> RunHome (still in the apartment)
//   RunHome --pick reward (if any), pick the next fight (door)--> Deploying
//     (countdown) --> InEncounter (waves, arena walls)
//     --> Cleared (loot countdown, F7 skips) --> RunHome
//     --> Flatlined (countdown) --> Ending --> Hub
//   final floor cleared --> Cleared (countdown) --> Ending --> Hub
//
// Doors (Hades-style): the first fight is a random arena; after that each
// floor offers doors by reward type, and the reward type sets the threat of
// the fight (Rewards/RewardSystem.reds).
//
// The hub is V's apartment (Hub/ApartmentHub.reds) unless that is turned off
// in Config or the apartment fails to load, in which case it is the spot where
// the takeover happened.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public enum RLState {
  Inactive = 0,
  AwaitingTakeover = 1,
  Hub = 2,
  Preparing = 3,
  RunHome = 4,
  Deploying = 5,
  InEncounter = 6,
  Cleared = 7,
  Flatlined = 8,
  Ending = 9,
}

public class RogueliteSystem extends ScriptableSystem {
  // --- Saved with the game -----------------------------------------------------------
  private persistent let m_isRoguelite: Bool;
  private persistent let m_takeoverDone: Bool;
  private persistent let m_hubX: Float;
  private persistent let m_hubY: Float;
  private persistent let m_hubZ: Float;
  private persistent let m_hubYaw: Float;

  // --- Session only --------------------------------------------------------------------
  private let m_state: RLState;
  private let m_run: ref<RLRunState>;
  private let m_spawner: ref<RLWaveSpawner>;
  private let m_arenas: ref<RLArenaDirector>;
  private let m_deathGuard: ref<RLDeathGuard>;
  private let m_hud: ref<RLHud>;
  private let m_apartment: ref<RLApartmentHub>;
  private let m_offers: array<ref<RLOffer>>;
  private let m_doors: array<ref<RLDoor>>;
  private let m_lootQueue: array<ItemID>;
  private let m_lootSweepPending: Bool;
  private let m_popupOpen: Bool;
  private let m_popup: wref<CustomPopup>;
  private let m_takeoverElapsed: Float;
  private let m_readyElapsed: Float;
  private let m_timerID: DelayID;
  private let m_hasTimer: Bool;
  private let m_countdown: Int32;
  private let m_countdownAction: CName;
  private let m_countdownLabel: String;
  private let m_wave: Int32;
  private let m_waveCount: Int32;
  private let m_alive: Int32;
  private let m_lastSummary: String;
  private let m_lastArena: CName;
  private let m_settleTries: Int32;
  private let m_busyNotified: Bool;
  private let m_busyWaits: Int32;

  public static func Get(game: GameInstance) -> ref<RogueliteSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"NightCityRoguelite.RogueliteSystem") as RogueliteSystem;
  }

  // --- Lifecycle -----------------------------------------------------------------------

  public func OnAttach() {
    this.m_state = RLState.Inactive;
    this.m_spawner = RLWaveSpawner.Create(this);
    this.m_arenas = RLArenaDirector.Create(this);
    this.m_deathGuard = RLDeathGuard.Create(this);
    this.m_hud = new RLHud();
    this.m_apartment = RLApartmentHub.Create(this);
  }

  public func OnDetach() {
    this.CancelTimer();
    if IsDefined(this.m_arenas) {
      this.m_arenas.StopWalls();
    }
    if IsDefined(this.m_apartment) {
      this.m_apartment.StopLeash();
    }
  }

  // Saving is only allowed while no run is active.
  public func IsSavingLocked() -> Bool {
    switch this.m_state {
      case RLState.Preparing:
      case RLState.RunHome:
      case RLState.Deploying:
      case RLState.InEncounter:
      case RLState.Cleared:
      case RLState.Flatlined:
      case RLState.Ending:
        return true;
    }
    return false;
  }

  // Called by RogueliteService on Session/Ready.
  public func OnSessionReady(isRestored: Bool) {
    let service = RogueliteService.Get();
    if !isRestored {
      if service.ConsumePendingStart() {
        RLLog("New roguelite character.");
        // A run left unfinished in an earlier session still pays out.
        service.SettleAbandonedRun();
        this.m_isRoguelite = true;
        this.m_takeoverDone = false;
        this.m_apartment.OnSessionStart();
        this.ApplyWorldSettings();
        this.BeginAwaitTakeover();
      }
      return;
    }

    service.ClearPendingStart();
    if !this.m_isRoguelite {
      this.m_state = RLState.Inactive;
      return;
    }

    RLLog("Roguelite save loaded.");
    // No run survives a load: drop any boon buffs that came along.
    RLBoons.ClearBuffs(GetPlayer(this.GetGameInstance()));
    this.m_apartment.OnSessionStart();
    this.ApplyWorldSettings();
    let abandonedPayout = 0;
    let wasAbandoned = service.GetActiveRunToken() != 0;
    if wasAbandoned {
      abandonedPayout = service.SettleAbandonedRun();
    }
    if !this.m_takeoverDone {
      this.BeginAwaitTakeover();
      return;
    }
    this.EnterHub(false);
    if wasAbandoned {
      RLNotify(this.GetGameInstance(), s"Your last run was abandoned and counts as a flatline. +\(abandonedPayout) Cred.", 8.0);
    }
  }

  // Called by RogueliteService on Session/BeforeEnd.
  public func OnSessionEnding() {
    this.CancelTimer();
    this.m_spawner.Abort();
    this.m_arenas.OnSessionEnd();
    this.m_apartment.OnSessionEnd();
    this.m_hud.Release();
    // A run in progress keeps its token: the next load scores it as abandoned.
  }

  public func IsRoguelitePlaythrough() -> Bool = this.m_isRoguelite

  // V's desk computer works as the terminal once the character is set up.
  public func IsHomeTerminalActive() -> Bool = this.m_isRoguelite && this.m_takeoverDone

  // Police off and no story quest on screen for roguelite characters.
  private func ApplyWorldSettings() {
    let game = this.GetGameInstance();
    if RLConfig.DisablePolice() {
      let prevention = GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem") as PreventionSystem;
      if IsDefined(prevention) {
        let request = new TogglePreventionSystem();
        request.sourceName = n"NightCityRoguelite";
        request.isActive = false;
        prevention.QueueRequest(request);
      }
    }
    this.UntrackQuest();
  }

  // Hides the story quest from the HUD (see Core/Story.reds).
  private func UntrackQuest() {
    RLStory.Quiet(this.GetGameInstance());
  }

  // A call, a conversation or a scene is in progress: teleports, the terminal
  // and the reward screen wait until it's over.
  public static func IsStoryBusy(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }
    return StrLen(RogueliteSystem.BusyReason(player)) > 0;
  }

  // Why V counts as busy ("" when not): a phone call, a conversation, a
  // cinematic scene tier, a workspot or a vehicle. While the quest patch holds
  // the opening black the mod itself is setting V up, so nothing is busy.
  public static func BusyReason(player: ref<PlayerPuppet>) -> String {
    if !IsDefined(player) {
      return "";
    }
    let game = player.GetGame();
    if RLStory.IsOpeningSkipInProgress(game) {
      return "";
    }
    if RLStory.IsCallActive(game) {
      return "phone call";
    }
    if RLStory.IsInDialogue(player) {
      return "conversation";
    }
    if RogueliteSystem.IsInVehicle(player) {
      return "vehicle";
    }
    let tier = PlayerPuppet.GetSceneTier(player);
    if tier > EnumInt(gamePSMHighLevel.SceneTier2) {
      return s"scene (tier \(tier))";
    }
    if AIActionHelper.IsInWorkspot(player) {
      return "workspot";
    }
    return "";
  }

  // For timed actions that move V: returns true (and retries `action` in a
  // second) while the story is busy.
  private func WaitIfBusy(action: CName) -> Bool {
    let player = GetPlayer(this.GetGameInstance());
    // Never wait forever: after 30 s go ahead anyway.
    if !RogueliteSystem.IsStoryBusy(player) || this.m_busyWaits >= 30 {
      this.m_busyNotified = false;
      this.m_busyWaits = 0;
      return false;
    }
    this.m_busyWaits += 1;
    if !this.m_busyNotified {
      this.m_busyNotified = true;
      RLNotify(this.GetGameInstance(), "Waiting for " + RogueliteSystem.BusyReason(player) + " to end...", 4.0);
    }
    this.After(action, 1.0);
    return true;
  }

  // --- Timers --------------------------------------------------------------------------

  private func StartTimer(action: CName, seconds: Float) {
    this.CancelTimer();
    this.m_timerID = RLDelay(this.GetGameInstance(), this, action, seconds);
    this.m_hasTimer = true;
  }

  private func CancelTimer() {
    if this.m_hasTimer {
      RLCancel(this.GetGameInstance(), this.m_timerID);
      this.m_hasTimer = false;
    }
  }

  // Short follow-up steps that must not cancel the main timer.
  private func After(action: CName, seconds: Float) {
    RLDelay(this.GetGameInstance(), this, action, seconds);
  }

  // A visible countdown on the HUD; runs `action` when it reaches zero.
  private func StartCountdown(seconds: Int32, const label: String, action: CName) {
    this.m_countdown = seconds;
    this.m_countdownLabel = label;
    this.m_countdownAction = action;
    this.ShowCountdown();
    this.StartTimer(n"countdown", 1.0);
  }

  private func ShowCountdown() {
    let title = IsDefined(this.m_run) ? this.m_run.FloorLabel() : "";
    this.m_hud.Update(title, s"\(this.m_countdownLabel) \(this.m_countdown)");
  }

  private func FinishCountdown() {
    this.CancelTimer();
    let action = this.m_countdownAction;
    this.m_countdownAction = n"";
    this.OnDelayed(action);
  }

  public func OnDelayed(action: CName) {
    switch action {
      case n"countdown":
        this.m_hasTimer = false;
        this.m_countdown -= 1;
        if this.m_countdown <= 0 {
          this.FinishCountdown();
        } else {
          this.ShowCountdown();
          this.StartTimer(n"countdown", 1.0);
        }
        break;
      case n"takeover":
        this.m_hasTimer = false;
        this.TakeoverTick();
        break;
      case n"takeoverFinish":
        this.FinishTakeover();
        break;
      case n"openingReady":
        this.OpeningReadyTick();
        break;
      case n"prepareGear":
        this.PrepareRunGear();
        break;
      case n"prepareKit":
        this.PrepareRunKit();
        break;
      case n"spawn":
        this.SpawnEncounter();
        break;
      case n"returnHome":
        if !this.WaitIfBusy(action) {
          this.ReturnHomeAfterArena();
        }
        break;
      case n"victoryHome":
        if !this.WaitIfBusy(action) {
          this.EndRun(true);
        }
        break;
      case n"flatlineHome":
        if !this.WaitIfBusy(action) {
          this.EndRun(false);
        }
        break;
      case n"settleHome":
        this.SettleHome();
        break;
      case n"openTerminal":
        if !this.m_popupOpen && (Equals(this.m_state, RLState.RunHome) || Equals(this.m_state, RLState.Hub)) {
          this.OnTerminalKey();
        }
        break;
      case n"reopenReward":
        if Equals(this.m_state, RLState.RunHome) && !this.m_popupOpen {
          this.OpenRewardPopup();
        }
        break;
      case n"endGear":
        this.FinishEndRun();
        break;
      case n"lootSweep":
        this.SweepLoot();
        break;
    }
  }

  // --- Takeover ------------------------------------------------------------------------

  private func BeginAwaitTakeover() {
    this.m_state = RLState.AwaitingTakeover;
    this.m_takeoverElapsed = 0.0;
    this.StartTimer(n"takeover", 1.0);
  }

  // Takes over the first moment V is free to move (no scene, workspot or vehicle).
  private func TakeoverTick() {
    if !Equals(this.m_state, RLState.AwaitingTakeover) {
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    this.m_takeoverElapsed += 1.0;
    // Let the opening call play out: cutting it off leaves it running unseen.
    if IsDefined(player) && !RogueliteSystem.IsStoryBusy(player) {
      this.DoTakeover();
      return;
    }
    if this.m_takeoverElapsed == 20.0 {
      RLNotify(this.GetGameInstance(), "Night City Roguelite: taking over once the opening call ends.", 6.0);
    }
    if this.m_takeoverElapsed >= 300.0 && IsDefined(player) && !RogueliteSystem.IsInVehicle(player) && !RLStory.IsCallActive(player.GetGame()) {
      this.DoTakeover();
      return;
    }
    this.StartTimer(n"takeover", 1.0);
  }

  private func DoTakeover() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    if RogueliteSystem.IsInVehicle(player) {
      RLNotify(player.GetGame(), "Step out of the vehicle first.", 4.0);
      return;
    }
    this.CancelTimer();
    let quests = GameInstance.GetQuestsSystem(player.GetGame());
    RLLog(s"Takeover after \(this.m_takeoverElapsed)s (start flag \(quests.GetFact(n"nc_roguelite_start")), opening skipped \(quests.GetFact(n"nc_roguelite_opening_skipped"))).");
    this.m_state = RLState.Preparing;
    this.StoreHub(player);
    RLCharacterReset.ResetProgressionAndUnequip(player, RLConfig.StartingAttributePoints(), RLConfig.StartingPerkPoints());
    this.After(n"takeoverFinish", 0.6);
  }

  private func FinishTakeover() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    RLCharacterReset.RemoveGear(player);
    RLCharacterReset.RestoreBody(player);
    RLCharacterReset.HealFull(player);
    this.m_takeoverDone = true;
    RLLog("Takeover complete.");
    this.EnterHub(true);
  }

  public static func IsInVehicle(player: ref<PlayerPuppet>) -> Bool {
    let blackboard = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(blackboard) {
      return false;
    }
    return blackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle) != EnumInt(gamePSMVehicle.Default);
  }

  public static func IsPlayerFree(player: ref<PlayerPuppet>) -> Bool {
    if RogueliteSystem.IsInVehicle(player) {
      return false;
    }
    if PlayerPuppet.GetSceneTier(player) > EnumInt(gamePSMHighLevel.SceneTier1) {
      return false;
    }
    return !AIActionHelper.IsInWorkspot(player);
  }

  // --- Hub -------------------------------------------------------------------------------

  private func StoreHub(player: ref<PlayerPuppet>) {
    let position = player.GetWorldPosition();
    this.m_hubX = position.X;
    this.m_hubY = position.Y;
    this.m_hubZ = position.Z;
    this.m_hubYaw = player.GetWorldYaw();
  }

  private func HubPosition() -> Vector4 {
    return Vector4(this.m_hubX, this.m_hubY, this.m_hubZ, 1.0);
  }

  private func EnterHub(firstTime: Bool) {
    this.m_state = RLState.Hub;
    this.m_hud.Hide();
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      RLCharacterReset.RestoreBody(player);
    }
    if firstTime {
      if IsDefined(player) {
        this.ReturnToHub(player);
      }
      this.m_apartment.StartLeash();
    } else {
      // Right after a load the game ignores teleports; settle in a moment.
      this.m_settleTries = 0;
      this.After(n"settleHome", 3.0);
    }
    this.UntrackQuest();
    if RLHomeDevices.ShouldSealDoor(this.GetGameInstance()) {
      RLHomeDevices.SealFrontDoor(this.GetGameInstance());
    }
    if firstTime && RLStory.IsOpeningSkipInProgress(this.GetGameInstance()) {
      // The screen is still black: fade in once V is settled in the apartment.
      this.m_readyElapsed = 0.0;
      this.After(n"openingReady", 0.5);
      return;
    }
    this.WelcomeHome(firstTime);
  }

  private func WelcomeHome(firstTime: Bool) {
    let message = firstTime
      ? "Welcome home. Use your computer (or press F7) for the terminal. You can save here."
      : "Home. Use your computer (or press F7) for the terminal.";
    RLNotify(this.GetGameInstance(), message, 8.0);
  }

  // New character, opening skipped: lift the black screen once V is standing
  // in the apartment (or after 30 s whatever happens; the quest patch itself
  // gives up after 45 s).
  private func OpeningReadyTick() {
    let game = this.GetGameInstance();
    if !RLStory.IsOpeningSkipInProgress(game) {
      return;
    }
    this.m_readyElapsed += 0.5;
    if this.m_apartment.IsSettled() || !this.m_apartment.IsEnabled() || this.m_readyElapsed >= 30.0 {
      RLLog(s"Opening finished after \(this.m_readyElapsed)s (apartment settled: \(this.m_apartment.IsSettled())).");
      RLStory.FinishOpeningSkip(game);
      this.WelcomeHome(true);
      return;
    }
    this.After(n"openingReady", 0.5);
  }

  // Puts V back at the hub (apartment, or the fallback spot).
  private func ReturnToHub(player: ref<PlayerPuppet>) {
    if this.m_apartment.IsEnabled() {
      RLHomeDevices.SealFrontDoor(player.GetGame());
      this.m_apartment.SendHome(player);
    } else if this.m_hubX != 0.0 || this.m_hubY != 0.0 {
      RLArenaDirector.TeleportToPoint(player, this.HubPosition(), this.m_hubYaw);
    }
  }

  // After a load: once V can move (and no call is going), send V home.
  private func SettleHome() {
    if !Equals(this.m_state, RLState.Hub) {
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    this.m_settleTries += 1;
    if IsDefined(player) && (!RogueliteSystem.IsStoryBusy(player) || this.m_settleTries > 60) {
      this.ReturnToHub(player);
      this.m_apartment.StartLeash();
      return;
    }
    this.After(n"settleHome", 1.0);
  }

  // Called when V fell below the apartment after being sent there.
  public func OnApartmentUnavailable() {
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      switch this.m_state {
        case RLState.Hub:
        case RLState.RunHome:
        case RLState.Preparing:
          RLArenaDirector.TeleportToPoint(player, this.HubPosition(), this.m_hubYaw);
          break;
      }
    }
    RLNotify(this.GetGameInstance(), "V's apartment didn't load, so home is where you started for now. Please share the log.", 8.0);
  }

  // --- Terminal ----------------------------------------------------------------------------

  public func OnTerminalKey() {
    if this.m_popupOpen && !this.IsPopupAlive() {
      // The popup never attached (or was torn down without a callback).
      this.m_popupOpen = false;
    }
    if this.m_popupOpen {
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    let busy = RogueliteSystem.BusyReason(player);
    if StrLen(busy) > 0 && !Equals(this.m_state, RLState.Cleared) {
      RLLog("Terminal refused: busy (" + busy + ").");
      RLNotify(this.GetGameInstance(), "Not now - " + busy + " in progress.", 3.0);
      return;
    }
    switch this.m_state {
      case RLState.AwaitingTakeover:
        this.DoTakeover();
        break;
      case RLState.Hub:
        this.m_popupOpen = true;
        this.m_popup = RLTerminalPopup.OpenHub(this);
        break;
      case RLState.RunHome:
        if ArraySize(this.m_offers) > 0 {
          this.OpenRewardPopup();
        } else {
          if ArraySize(this.m_doors) == 0 {
            this.RollDoors();
          }
          this.m_popupOpen = true;
          this.m_popup = RLTerminalPopup.OpenDoorPicker(this, this.HomeSummary(), this.m_doors);
        }
        break;
      case RLState.Deploying:
      case RLState.InEncounter:
        this.m_popupOpen = true;
        this.m_popup = RLTerminalPopup.OpenInArena(this, this.ArenaSummary());
        break;
      case RLState.Cleared:
        // Skip the loot countdown.
        this.FinishCountdown();
        break;
    }
  }

  public func OnPopupClosed() {
    this.m_popupOpen = false;
  }

  private func IsPopupAlive() -> Bool {
    return IsDefined(this.m_popup) && IsDefined(this.m_popup.GetRootWidget());
  }

  // --- Run start ---------------------------------------------------------------------------

  public func StartRun(kit: CName) {
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !Equals(this.m_state, RLState.Hub) || !IsDefined(player) {
      return;
    }
    let service = RogueliteService.Get();
    let pools = service.GetPools();
    let factions = pools.GetFactions();
    if ArraySize(factions) == 0 {
      RLNotify(game, "No enemy factions found in TweakDB. Check that TweakXL is installed and up to date.", 8.0);
      return;
    }
    if !RLMeta.IsKitAvailable(service, kit) {
      kit = n"Solo";
    }
    RLBoons.ClearBuffs(player);
    let roguelike = service.IsRoguelikeMode();
    let token = service.BeginRunToken(roguelike);
    this.m_run = RLRunState.Create(token, kit, roguelike);
    this.m_run.rerollsPerFloor = RLMeta.PerkActive(service, n"perk.Reroll") ? 1 : 0;
    this.m_run.offerCount = RLMeta.PerkActive(service, n"perk.FourthChoice") ? 4 : 3;
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);
    this.m_lastArena = n"";
    this.m_state = RLState.Preparing;

    let attributePoints = RLConfig.StartingAttributePoints() + RLMeta.BonusAttributePoints(service);
    RLCharacterReset.ResetProgressionAndUnequip(player, attributePoints, RLConfig.StartingPerkPoints());
    this.After(n"prepareGear", 0.6);
    RLLog(s"Run started: kit \(NameToString(kit)), roguelike \(roguelike).");
  }

  private func PrepareRunGear() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    RLCharacterReset.RemoveGear(player);
    RLCharacterReset.RestoreBody(player);
    this.After(n"prepareKit", 0.6);
  }

  private func PrepareRunKit() {
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    let service = RogueliteService.Get();
    RLKits.Apply(player, service.GetPools(), this.m_run.kit);

    if RLMeta.PerkActive(service, n"perk.HeadStart") {
      PlayerDevelopmentSystem.GetData(player).RL_GrantLevels(2);
    }
    if RLMeta.PerkActive(service, n"perk.Vitality1") {
      ArrayPush(this.m_run.boons, n"ReinforcedFrame");
      RLBoons.ApplyStack(player, n"ReinforcedFrame", this.m_run);
    }
    if RLMeta.PerkActive(service, n"perk.Vitality2") {
      ArrayPush(this.m_run.boons, n"ReinforcedFrame");
      RLBoons.ApplyStack(player, n"ReinforcedFrame", this.m_run);
    }

    RLCharacterReset.HealFull(player);
    this.m_deathGuard.Arm(player);
    FastTravelSystem.AddFastTravelLock(n"NightCityRoguelite", game);
    this.RollDoors();
    this.EnterRunHome();
    RLNotify(game, "Run started. Spend your attribute points in the Character menu, then press F7 to deploy.", 8.0);
  }

  // --- Between arenas (at home, run active) -----------------------------------------------

  private func EnterRunHome() {
    this.m_state = RLState.RunHome;
    this.m_apartment.StartLeash();
    let status = ArraySize(this.m_offers) > 0 ? "HOME - F7: CHOOSE YOUR REWARD" : "HOME - F7: CHOOSE YOUR NEXT FIGHT";
    this.m_hud.Update(this.m_run.FloorLabel(), status);
    this.After(n"openTerminal", 1.5);
  }

  private func ReturnHomeAfterArena() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    this.m_arenas.StopWalls();
    this.m_spawner.DeleteAll();
    this.m_run.Advance();
    this.ReturnToHub(player);
    // Home is safe: V patches up between arenas.
    RLCharacterReset.HealFull(player);
    this.m_deathGuard.Rearm();
    this.EnterRunHome();
  }

  // --- Arenas --------------------------------------------------------------------------------

  // Called from the door picker.
  public func DeployToDoor(index: Int32) {
    if !Equals(this.m_state, RLState.RunHome) || !IsDefined(this.m_run) {
      return;
    }
    if RogueliteSystem.IsStoryBusy(GetPlayer(this.GetGameInstance())) {
      RLNotify(this.GetGameInstance(), "Finish the conversation first.", 3.0);
      return;
    }
    if ArraySize(this.m_offers) > 0 {
      this.OpenRewardPopup();
      return;
    }
    if index < 0 || index >= ArraySize(this.m_doors) {
      return;
    }
    let door = this.m_doors[index];
    let arena = RLArenas.Get(door.arena);
    if !IsDefined(arena) {
      return;
    }
    this.m_run.door = door;
    ArrayClear(this.m_doors);
    this.DeployTo(arena);
  }

  private func DeployTo(arena: ref<RLArenaDef>) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    this.m_lastArena = arena.id;
    this.m_state = RLState.Deploying;
    this.m_apartment.StopLeash();
    this.m_spawner.DeleteAll();
    this.m_wave = 0;
    this.m_waveCount = 0;
    this.m_alive = 0;
    this.m_arenas.Enter(player, arena);
    this.m_arenas.StartWalls();
    RLLoot.RefillForArena(player);
    this.UntrackQuest();
    let reward = RLRewards.CategoryName(this.m_run.door.category);
    RLLog(s"Deploying to \(arena.name): \(reward), threat \(this.m_run.Threat()).");
    this.StartCountdown(RLConfig.DeployCountdown(), s"\(arena.name) - \(reward) - FIGHT IN", n"spawn");
  }

  private func RollDoors() {
    if !IsDefined(this.m_run) {
      return;
    }
    this.m_doors = RLRewards.RollDoors(RogueliteService.Get().GetPools(), this.m_run, this.m_lastArena);
  }

  private func SpawnEncounter() {
    let player = GetPlayer(this.GetGameInstance());
    let arena = this.m_arenas.GetArena();
    if !IsDefined(player) || !IsDefined(this.m_run) || !IsDefined(arena) || !Equals(this.m_state, RLState.Deploying) {
      return;
    }
    let plan = this.BuildPlan(this.m_run, arena);
    this.m_state = RLState.InEncounter;
    this.m_spawner.Start(arena, plan);
    RLNotify(player.GetGame(), this.m_run.FloorLabel() + " - " + plan.factionName, 4.0);
  }

  // Waves for a floor. Threat (from the door's reward type) scales the fight:
  // light = smaller waves of weaker enemies, heavy = bigger waves, more
  // elites, an extra wave and enemies a level above V.
  private func BuildPlan(run: ref<RLRunState>, arena: ref<RLArenaDef>) -> ref<RLEncounterPlan> {
    let pools = RogueliteService.Get().GetPools();
    let faction = pools.PickFactionPreferred(arena.factions, run.act >= 3);
    let threat = run.Threat();
    let plan = new RLEncounterPlan();
    plan.factionName = RogueliteSystem.FactionName(faction.faction);

    let weights = RogueliteSystem.TierWeights(run.act, run.IsEliteFloor(), threat);
    let waves = run.IsEliteFloor() ? 3 : (run.act >= 2 ? 3 : 2);
    if threat >= 3 {
      waves += 1;
    }
    if run.IsBossFloor() {
      waves = 2;
    }
    let size = Clamp(3 + run.floor + (run.act - 1) * 2 + (threat - 2) * 2, 2, RLConfig.MaxAlive() - 2);
    let levelBonus = threat - 2;

    let w = 0;
    while w < waves {
      plan.BeginWave();
      let k = 0;
      while k < size + w {
        let tier = RogueliteSystem.RollTier(weights);
        plan.Add(faction.Pick(tier), false, tier + levelBonus);
        k += 1;
      }
      w += 1;
    }

    if run.IsBossFloor() {
      plan.BeginWave();
      let bosses = RogueliteSystem.BossRecords(run.act);
      if ArraySize(bosses) == 0 {
        // Act 1, or no MaxTac records: faction elites lead the boss wave.
        plan.Add(faction.Pick(2), true, 3 + run.act);
        plan.Add(faction.Pick(2), true, 3 + run.act);
      } else {
        for boss in bosses {
          plan.Add(boss, true, 2 + run.act);
        }
      }
      let adds = run.act + 1;
      while adds > 0 {
        plan.Add(faction.Pick(1), false, 1);
        adds -= 1;
      }
    }
    return plan;
  }

  public static func TierWeights(act: Int32, elite: Bool, threat: Int32) -> array<Int32> {
    let weights: array<Int32>;
    if act <= 1 {
      weights = [70, 30, 0];
    } else if act == 2 {
      weights = [30, 55, 15];
    } else {
      weights = [10, 50, 40];
    }
    if elite || threat >= 3 {
      let shift = Min(20, weights[0]);
      weights[0] -= shift;
      weights[2] += shift;
      weights[2] += 20 - shift;
      weights[1] -= 20 - shift;
    }
    if threat <= 1 {
      // Light fights: mostly grunts.
      let down = Min(15, weights[2]);
      weights[2] -= down;
      weights[0] += down + 15;
      weights[1] = Max(0, weights[1] - 15);
    }
    return weights;
  }

  public static func RollTier(weights: array<Int32>) -> Int32 {
    let total = weights[0] + weights[1] + weights[2];
    let roll = RandRange(0, Max(1, total));
    if roll < weights[0] {
      return 0;
    }
    if roll < weights[0] + weights[1] {
      return 1;
    }
    return 2;
  }

  // MaxTac lead the boss waves of acts 2 and 3; act 1's boss wave is led by
  // faction elites (empty result).
  public static func BossRecords(act: Int32) -> array<TweakDBID> {
    let result: array<TweakDBID>;
    if act <= 1 {
      return result;
    }
    let maxtac: array<TweakDBID>;
    for id in RLBosses.MaxTac() {
      if RLBosses.Exists(id) {
        ArrayPush(maxtac, id);
      }
    }
    let count = act >= 3 ? 3 : 2;
    let i = 0;
    while i < count && ArraySize(maxtac) > 0 {
      ArrayPush(result, maxtac[RandRange(0, ArraySize(maxtac))]);
      i += 1;
    }
    return result;
  }

  public static func FactionName(faction: gamedataAffiliation) -> String {
    switch faction {
      case gamedataAffiliation.Animals: return "Animals";
      case gamedataAffiliation.Maelstrom: return "Maelstrom";
      case gamedataAffiliation.Scavengers: return "Scavengers";
      case gamedataAffiliation.SixthStreet: return "6th Street";
      case gamedataAffiliation.TygerClaws: return "Tyger Claws";
      case gamedataAffiliation.Valentinos: return "Valentinos";
      case gamedataAffiliation.VoodooBoys: return "Voodoo Boys";
      case gamedataAffiliation.Wraiths: return "Wraiths";
      case gamedataAffiliation.Barghest: return "Barghest";
      case gamedataAffiliation.Arasaka: return "Arasaka";
      case gamedataAffiliation.Militech: return "Militech";
      case gamedataAffiliation.KangTao: return "Kang Tao";
    }
    return "Hostiles";
  }

  // --- Encounter events (from RLWaveSpawner) -----------------------------------------------

  public func OnWaveStarted(wave: Int32, waves: Int32, count: Int32) {
    this.m_wave = wave;
    this.m_waveCount = waves;
    this.m_alive = this.m_spawner.GetAliveCount();
    let label = wave == waves && IsDefined(this.m_run) && this.m_run.IsBossFloor() ? "BOSS WAVE" : s"WAVE \(wave)/\(waves)";
    RLNotify(this.GetGameInstance(), label, 3.0);
    this.RefreshHud();
  }

  public func OnWaveCleared(wave: Int32, waves: Int32) {
    RLNotify(this.GetGameInstance(), s"Wave \(wave) cleared. Next wave incoming.", 3.0);
    this.m_alive = 0;
    this.RefreshHud();
  }

  public func OnEnemyCountChanged(alive: Int32) {
    this.m_alive = alive;
    this.RefreshHud();
  }

  public func OnEnemyKilled(isBoss: Bool) {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    this.m_run.kills += 1;
    if isBoss {
      this.m_run.bossesKilled += 1;
    }
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let bloodlust = this.m_run.BoonStacks(n"Bloodlust");
    if bloodlust > 0 {
      GameInstance.GetStatPoolsSystem(player.GetGame()).RequestChangingStatPoolValue(
        Cast<StatsObjectID>(player.GetEntityID()),
        gamedataStatPoolType.Health,
        4.0 * Cast<Float>(bloodlust),
        null,
        false,
        true
      );
    }
    let bounty = this.m_run.BoonStacks(n"BountyHunter");
    if bounty > 0 {
      RLGear.GiveEddies(player, 100 * bounty);
    }
  }

  public func OnEncounterCleared() {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    this.m_run.floorsCleared += 1;
    RogueliteService.Get().UpdateActiveRun(this.m_run.floorsCleared, this.m_run.kills, this.m_run.bossesKilled);

    // Every cleared floor is worth a level.
    if IsDefined(player) {
      PlayerDevelopmentSystem.GetData(player).RL_GrantLevels(1);
    }

    this.m_state = RLState.Cleared;
    if this.m_run.IsFinalFloor() {
      RLNotify(game, "Night City is yours. Run complete!", 6.0);
      this.StartCountdown(RLConfig.ClearedCountdown(), "RUN COMPLETE - HOME IN", n"victoryHome");
      return;
    }

    this.m_run.rerollsLeft = this.m_run.rerollsPerFloor;
    this.RollOffers();
    RLNotify(game, "Area clear. Loot the bodies for ammo - you'll be sent home shortly (F7 to go now).", 6.0);
    this.StartCountdown(RLConfig.ClearedCountdown(), "CLEARED - HOME IN", n"returnHome");
  }

  // --- Rewards -----------------------------------------------------------------------------------

  private func RollOffers() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    let category = IsDefined(this.m_run.door) ? this.m_run.door.category : RLRewardCategory.Boons;
    this.m_offers = RLRewards.RollForCategory(player, RogueliteService.Get().GetPools(), this.m_run, category, this.m_run.Threat(), this.m_run.offerCount);
  }

  private func OpenRewardPopup() {
    if !IsDefined(this.m_run) || this.m_popupOpen || ArraySize(this.m_offers) == 0 {
      return;
    }
    this.m_popupOpen = true;
    let category = IsDefined(this.m_run.door) ? this.m_run.door.category : RLRewardCategory.Boons;
    this.m_popup = RLRewardPopup.Open(this, this.m_offers, RLRewards.CategoryName(category) + " - CHOOSE ONE", this.m_run.rerollsLeft);
  }

  public func OnRewardChosen(index: Int32) {
    if !Equals(this.m_state, RLState.RunHome) || !IsDefined(this.m_run) {
      return;
    }
    if index < 0 || index >= ArraySize(this.m_offers) {
      return;
    }
    let offer = this.m_offers[index];
    if offer.disabled {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return;
    }
    RLRewards.Grant(player, RogueliteService.Get().GetPools(), this.m_run, offer);
    ArrayClear(this.m_offers);
    this.RollDoors();
    RLNotify(game, s"\(offer.title) acquired.", 4.0);
    this.m_hud.Update(this.m_run.FloorLabel(), "HOME - F7: CHOOSE YOUR NEXT FIGHT");
    this.After(n"openTerminal", 0.8);
  }

  public func OnRewardReroll() {
    if !Equals(this.m_state, RLState.RunHome) || !IsDefined(this.m_run) || this.m_run.rerollsLeft <= 0 {
      return;
    }
    this.m_run.rerollsLeft -= 1;
    this.RollOffers();
    this.After(n"reopenReward", 0.5);
  }

  // --- Death and run end ------------------------------------------------------------------------

  // Called from the health listener; never does heavy work inline.
  public func OnLethalDamage() {
    if !IsDefined(this.m_run) {
      return;
    }
    if !Equals(this.m_state, RLState.InEncounter) {
      // Only fights can end a run (V is Immortal, so this is just a scratch).
      this.m_deathGuard.Rearm();
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) && this.m_run.ConsumeBoon(n"SecondWind") {
      RLBoons.RemoveBuffStack(player, n"SecondWind");
      GameInstance.GetStatPoolsSystem(player.GetGame()).RequestSettingStatPoolValue(
        Cast<StatsObjectID>(player.GetEntityID()),
        gamedataStatPoolType.Health,
        50.0,
        null,
        true
      );
      this.m_deathGuard.Rearm();
      RLNotify(player.GetGame(), "SECOND WIND!", 3.0);
      return;
    }
    this.Flatline();
  }

  private func Flatline() {
    this.m_state = RLState.Flatlined;
    // Enemies vanish so the countdown is a breather, not a beating.
    this.m_spawner.Abort();
    RLNotify(this.GetGameInstance(), "FLATLINED", 4.0);
    this.StartCountdown(RLConfig.FlatlineCountdown(), "FLATLINED - HOME IN", n"flatlineHome");
  }

  public func AbandonRun() {
    if IsDefined(this.m_run) {
      this.EndRun(false);
    }
  }

  private func EndRun(victory: Bool) {
    if !IsDefined(this.m_run) || Equals(this.m_state, RLState.Ending) {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    let run = this.m_run;
    this.m_state = RLState.Ending;
    this.CancelTimer();
    this.m_spawner.Abort();
    this.m_arenas.StopWalls();
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);

    let service = RogueliteService.Get();
    let payout = RLMeta.Payout(run.floorsCleared, run.kills, run.bossesKilled, victory, run.roguelike);
    service.AddCred(payout);
    service.RecordRunEnd(run.floorsCleared, run.kills, victory);
    service.ClearRunToken();

    this.m_deathGuard.Disarm();
    RLBoons.RemoveAll(player, run);
    FastTravelSystem.RemoveFastTravelLock(n"NightCityRoguelite", game);
    this.m_hud.Hide();

    this.m_lastSummary = (victory ? "RUN COMPLETE" : "RUN OVER")
      + s" - floors cleared \(run.floorsCleared), kills \(run.kills). +\(payout) Cred (total \(service.GetCred())).";
    RLLog(this.m_lastSummary);
    this.m_run = null;

    if IsDefined(player) {
      this.ReturnToHub(player);
      RLCharacterReset.HealFull(player);
      RLCharacterReset.ResetProgressionAndUnequip(player, RLConfig.StartingAttributePoints(), RLConfig.StartingPerkPoints());
    }
    this.After(n"endGear", 0.6);
  }

  private func FinishEndRun() {
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      RLCharacterReset.RemoveGear(player);
      RLCharacterReset.RestoreBody(player);
      RLCharacterReset.HealFull(player);
    }
    this.m_spawner.DeleteAll();
    this.m_state = RLState.Hub;
    this.m_apartment.StartLeash();
    RLNotify(this.GetGameInstance(), this.m_lastSummary, 10.0);
  }

  // --- Arena loot ----------------------------------------------------------------------------------

  // True while V is in an arena: pickups are filtered (Combat/Loot.reds).
  public func FiltersLoot() -> Bool {
    switch this.m_state {
      case RLState.Deploying:
      case RLState.InEncounter:
      case RLState.Cleared:
      case RLState.Flatlined:
        return true;
    }
    return false;
  }

  public func QueueLootRemoval(itemID: ItemID) {
    ArrayPush(this.m_lootQueue, itemID);
    if !this.m_lootSweepPending {
      this.m_lootSweepPending = true;
      this.After(n"lootSweep", 0.2);
    }
  }

  private func SweepLoot() {
    this.m_lootSweepPending = false;
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
      for itemID in this.m_lootQueue {
        let quantity = transactionSystem.GetItemQuantity(player, itemID);
        if quantity > 0 {
          transactionSystem.RemoveItem(player, itemID, quantity);
        }
      }
    }
    ArrayClear(this.m_lootQueue);
  }

  // --- HUD and summaries -----------------------------------------------------------------------

  private func RefreshHud() {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    let status = s"WAVE \(this.m_wave)/\(this.m_waveCount)   HOSTILES \(this.m_alive)   KILLS \(this.m_run.kills)";
    this.m_hud.Update(this.m_run.FloorLabel(), status);
  }

  public func GetRun() -> ref<RLRunState> = this.m_run

  private func HomeSummary() -> String {
    if !IsDefined(this.m_run) {
      return "";
    }
    return s"NEXT: \(this.m_run.FloorLabel()) of \(this.m_run.TotalFloors()) floors.   Kit: \(RLMeta.KitName(this.m_run.kit)).   Kills: \(this.m_run.kills).   Boons: \(ArraySize(this.m_run.boons)).";
  }

  private func ArenaSummary() -> String {
    if !IsDefined(this.m_run) {
      return "No run in progress.";
    }
    let arena = this.m_arenas.GetArena();
    let arenaName = IsDefined(arena) ? arena.name : "";
    return s"\(this.m_run.FloorLabel()) - \(arenaName). Wave \(this.m_wave)/\(this.m_waveCount), \(this.m_alive) hostiles left. Kills: \(this.m_run.kills). "
      + "Abandoning ends the run and counts as a flatline.";
  }
}

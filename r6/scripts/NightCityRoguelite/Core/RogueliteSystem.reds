// -----------------------------------------------------------------------------
// Night City Roguelite - run system (orchestrator)
// -----------------------------------------------------------------------------
// One instance per game session. Persistent fields go into the save file and
// tag the playthrough as a roguelite character; everything about the current
// run is in memory only, because saving is locked while a run is active.
//
// Flow - home is where a run starts and ends; in between V goes from arena to
// arena, and everything between fights happens right where the last one was
// won (F7 reopens whatever is waiting):
//
//   new game -> AwaitingTakeover -> Hub (locked in V's apartment)
//   Hub --START RUN--> Preparing --> RunHome (the first door)
//   RunHome / Cleared --door--> Traveling (fade, teleport, stream in, fade)
//     --> Deploying (countdown, music) --> InEncounter (waves)
//     --> Cleared: reward (+1 level), the Fixer before a boss, the next door
//   InEncounter --health gone--> Flatlined (V dies for real and comes to)
//     --> Ending (home, reset) --> Hub
//   final floor cleared --> Cleared (countdown) --> Ending --> Hub
//
// Collaborators: doors and offers (Rewards/RewardSystem.reds, Director.reds),
// waves (Run/Encounters.reds, Combat/WaveSpawner.reds), pacing and difficulty
// (Run/Pacing.reds, Run/Difficulty.reds), the Fixer (Run/Fixer.reds), music
// (Audio/Music.reds), the death sequence (Player/Death.reds), fades
// (UI/Transition.reds) and the apartment hub (Hub/ApartmentHub.reds; when it
// is off or fails to load, home is the spot where the takeover happened).
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public enum RLState {
  Inactive = 0,
  AwaitingTakeover = 1,
  Hub = 2,
  Preparing = 3,
  RunHome = 4,
  Traveling = 5,
  Deploying = 6,
  InEncounter = 7,
  Cleared = 8,
  Flatlined = 9,
  Ending = 10,
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
  private let m_music: ref<RLMusic>;
  private let m_pacing: ref<RLPacing>;
  private let m_transition: ref<RLTransition>;
  private let m_journalGuard: ref<RLJournalGuard>;

  // Items the mod hands out mid-fight, exempt from the arena pickup filter.
  private let m_expectedGrants: array<TweakDBID>;
  // One MaxDoc drop per arena at most.
  private let m_healthDropTaken: Bool;
  private let m_fixerStock: array<ref<RLFixerItem>>;
  // What waits between fights: the reward offers (and their type), the doors.
  private let m_offers: array<ref<RLOffer>>;
  private let m_offerCategory: RLRewardCategory;
  private let m_offerThreat: Int32;
  private let m_doors: array<ref<RLDoor>>;
  // The enemy faction of the fight being travelled to / fought.
  private let m_faction: ref<RLFactionPool>;
  private let m_lastArena: CName;

  // Trips.
  private let m_travelArena: ref<RLArenaDef>;
  private let m_waits: Int32;
  private let m_endTitle: String;
  private let m_endSubtitle: String;
  private let m_lastSummary: String;

  // Death sequence (Player/Death.reds).
  private let m_dying: Bool;
  private let m_sawDeath: Bool;
  private let m_deathElapsed: Float;
  private let m_deathMenuFact: Int32;

  private let m_lootQueue: array<ItemID>;
  private let m_lootSweepPending: Bool;
  private let m_popupOpen: Bool;
  private let m_popup: wref<CustomPopup>;
  private let m_takeoverElapsed: Float;
  private let m_readyElapsed: Float;
  private let m_openWaits: Int32;
  private let m_timerID: DelayID;
  private let m_hasTimer: Bool;
  private let m_countdown: Int32;
  private let m_countdownAction: CName;
  private let m_countdownLabel: String;
  private let m_wave: Int32;
  private let m_waveCount: Int32;
  private let m_alive: Int32;
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
    this.m_music = new RLMusic();
    this.m_pacing = new RLPacing();
    this.m_transition = new RLTransition();
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

  // V is in (or just finished) an arena fight.
  public func IsInArenaFight() -> Bool {
    switch this.m_state {
      case RLState.Deploying:
      case RLState.InEncounter:
      case RLState.Cleared:
      case RLState.Flatlined:
        return true;
    }
    return false;
  }

  public func GetArenaCleaner() -> ref<RLArenaCleaner> = this.m_arenas.GetCleaner()

  public func IsRoguelitePlaythrough() -> Bool = this.m_isRoguelite

  // V's desk computer works as the terminal once the character is set up.
  public func IsHomeTerminalActive() -> Bool = this.m_isRoguelite && this.m_takeoverDone

  // V's death is being turned into a resurrection (Player/Death.reds).
  public func IsResurrectionPending() -> Bool = this.m_dying

  public func GetRun() -> ref<RLRunState> = this.m_run

  // --- Session ---------------------------------------------------------------------------

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
        this.PrepareSession();
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
    this.PrepareSession();
    let abandonedPayout = 0;
    let wasAbandoned = service.GetActiveRunToken() != 0;
    if wasAbandoned {
      abandonedPayout = service.SettleAbandonedRun();
    }
    if !this.m_takeoverDone {
      this.BeginAwaitTakeover();
      return;
    }
    RLCharacterReset.ClearDevelopmentPoints(GetPlayer(this.GetGameInstance()));
    this.EnterHub(false);
    if wasAbandoned {
      RLNotify(this.GetGameInstance(), s"Your last run was abandoned and counts as a flatline. +\(abandonedPayout) Cred.", 8.0);
    }
  }

  private func PrepareSession() {
    this.m_apartment.OnSessionStart();
    this.ApplyWorldSettings();
    this.ApplyDifficulty();
    this.QuietJournal();
  }

  // Called by RogueliteService on Session/BeforeEnd.
  public func OnSessionEnding() {
    this.CancelTimer();
    if this.m_dying {
      RLDeath.End(this.GetGameInstance(), this.m_deathMenuFact);
      this.m_dying = false;
    }
    this.m_music.Stop();
    this.m_pacing.Stop();
    if IsDefined(this.m_journalGuard) {
      this.m_journalGuard.Stop(this.GetGameInstance());
    }
    this.m_spawner.Abort();
    this.m_arenas.OnSessionEnd();
    this.m_apartment.OnSessionEnd();
    this.m_hud.Release();
    this.m_transition.Release();
    // A run in progress keeps its token: the next load scores it as abandoned.
  }

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
    RLStory.Quiet(game);
  }

  // The game's difficulty is the mod's: the selector is skipped for roguelite
  // characters and this is applied on every session.
  private func ApplyDifficulty() {
    let stats = GameInstance.GetStatsDataSystem(this.GetGameInstance());
    if IsDefined(stats) && NotEquals(stats.GetDifficulty(), RLConfig.GameDifficulty()) {
      stats.SetDifficulty(RLConfig.GameDifficulty());
      RLLog("Difficulty set to the mod's (" + ToString(RLConfig.GameDifficulty()) + ").");
    }
  }

  private func QuietJournal() {
    if !RLConfig.SilenceStory() {
      return;
    }
    if !IsDefined(this.m_journalGuard) {
      this.m_journalGuard = new RLJournalGuard();
    }
    this.m_journalGuard.Start(this.GetGameInstance());
  }

  // --- Story busy checks -----------------------------------------------------------------

  // A call, a conversation or a scene is in progress: trips, the terminal and
  // the reward screen wait until it's over.
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

  public static func IsInVehicle(player: ref<PlayerPuppet>) -> Bool {
    let blackboard = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(blackboard) {
      return false;
    }
    return blackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle) != EnumInt(gamePSMVehicle.Default);
  }

  // For timed actions: returns true (and retries `action` in a second) while
  // the story is busy. Never waits more than 30 s.
  private func WaitIfBusy(action: CName) -> Bool {
    let player = GetPlayer(this.GetGameInstance());
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
      case n"settleHome":
        this.SettleHome();
        break;
      case n"prepareGear":
        this.PrepareRunGear();
        break;
      case n"prepareKit":
        this.PrepareRunKit();
        break;
      case n"nextStep":
        this.OpenNextStepWhenReady();
        break;
      case n"travelBlack":
        this.ArriveInArena();
        break;
      case n"travelSettle":
        this.SettleArrival();
        break;
      case n"spawn":
        this.SpawnEncounter();
        break;
      case n"victoryHome":
        if !this.WaitIfBusy(action) {
          this.EndRun(true, false, false);
        }
        break;
      case n"deathFade":
        this.DeathFade();
        break;
      case n"deathBlack":
        this.m_spawner.Abort();
        this.m_arenas.StopWalls();
        break;
      case n"deathCheck":
        this.DeathTick();
        break;
      case n"homeBlack":
        this.ArriveHome();
        break;
      case n"endGear":
        this.FinishEndRun();
        break;
      case n"homeSettle":
        this.SettleHomeArrival();
        break;
      case n"glitchOff":
        let player = GetPlayer(this.GetGameInstance());
        if IsDefined(player) {
          GameObjectEffectHelper.StopEffectEvent(player, n"transition_glitch_loop");
        }
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
    RLCharacterReset.ResetProgressionAndUnequip(player);
    this.After(n"takeoverFinish", 0.6);
  }

  private func FinishTakeover() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    RLCharacterReset.RemoveGear(player);
    RLCharacterReset.RestoreBody(player);
    RLPerks.GrantBaseline(player);
    RLCharacterReset.HealFull(player);
    this.m_takeoverDone = true;
    RLLog("Takeover complete.");
    this.EnterHub(true);
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
    RLStory.Quiet(this.GetGameInstance());
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
        case RLState.Ending:
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
    if StrLen(busy) > 0 {
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
        this.OpenNextStep();
        break;
      case RLState.Cleared:
        if Equals(this.m_countdownAction, n"victoryHome") {
          // The run is won: skip the countdown home.
          this.FinishCountdown();
        } else {
          this.OpenNextStep();
        }
        break;
      case RLState.Deploying:
      case RLState.InEncounter:
        this.m_popupOpen = true;
        this.m_popup = RLTerminalPopup.OpenInArena(this, this.ArenaSummary());
        break;
    }
  }

  public func OnPopupClosed() {
    this.m_popupOpen = false;
  }

  private func IsPopupAlive() -> Bool {
    return IsDefined(this.m_popup) && IsDefined(this.m_popup.GetRootWidget());
  }

  // Between fights the screens come one after another: the reward, the Fixer
  // (before a boss), then the doors.
  private func OpenNextStep() {
    if !IsDefined(this.m_run) || this.m_popupOpen {
      return;
    }
    if ArraySize(this.m_offers) > 0 {
      this.m_popupOpen = true;
      this.m_popup = RLRewardPopup.Open(this, this.m_offers, RLRewards.CategoryName(this.m_offerCategory));
      return;
    }
    if this.m_run.fixerPending {
      this.OpenFixer();
      return;
    }
    if ArraySize(this.m_doors) == 0 {
      this.RollDoors();
    }
    this.m_popupOpen = true;
    this.m_popup = RLTerminalPopup.OpenDoorPicker(this, this.m_doors);
  }

  private func OpenNextStepWhenReady() {
    if !Equals(this.m_state, RLState.RunHome) && !Equals(this.m_state, RLState.Cleared) {
      return;
    }
    if this.m_popupOpen || this.WaitIfBusy(n"nextStep") {
      return;
    }
    // At home, never open a menu while V is still being placed.
    if Equals(this.m_state, RLState.RunHome) && this.m_apartment.IsEnabled() && !this.m_apartment.IsSettled() && this.m_openWaits < 30 {
      this.m_openWaits += 1;
      this.After(n"nextStep", 1.0);
      return;
    }
    this.m_openWaits = 0;
    this.OpenNextStep();
  }

  // The HUD line while choosing: what F7 opens next.
  private func ShowStepHud() {
    if !IsDefined(this.m_run) {
      return;
    }
    let status: String;
    if ArraySize(this.m_offers) > 0 {
      status = "F7: CHOOSE YOUR REWARD";
    } else if this.m_run.fixerPending {
      status = "F7: THE FIXER IS IN";
    } else {
      status = "F7: CHOOSE YOUR NEXT FIGHT";
    }
    let title = this.m_run.advancePending ? this.m_run.FloorLabel() + " CLEARED" : "NEXT: " + this.m_run.FloorLabel();
    this.m_hud.Update(title, status);
  }

  // --- Run start ---------------------------------------------------------------------------

  public func StartRun(kit: CName) {
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !Equals(this.m_state, RLState.Hub) || !IsDefined(player) {
      return;
    }
    let service = RogueliteService.Get();
    let factions = service.GetPools().GetFactions();
    if ArraySize(factions) == 0 {
      RLNotify(game, "No enemy factions found in TweakDB. Check that TweakXL is installed and up to date.", 8.0);
      return;
    }
    if !RLMeta.IsKitAvailable(service, kit) {
      kit = n"Solo";
    }
    RLBoons.ClearBuffs(player);
    this.ApplyDifficulty();
    this.m_run = RLRunState.Create(service.BeginRunToken(), kit);
    this.m_pacing.ResetRun();
    this.m_run.rerollsPerAct = RLMeta.RerollsPerAct(service);
    this.m_run.rerolls = this.m_run.rerollsPerAct;
    this.m_run.offerCount = RLMeta.PerkActive(service, n"perk.FourthChoice") ? 4 : 3;
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);
    this.m_lastArena = n"";
    this.m_state = RLState.Preparing;
    SaveLocksManager.RequestSaveLockAdd(game, n"NightCityRoguelite.Run");

    RLCharacterReset.ResetProgressionAndUnequip(player);
    this.After(n"prepareGear", 0.6);
    RLLog("Run started: kit " + NameToString(kit) + ".");
  }

  private func PrepareRunGear() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    RLCharacterReset.RemoveGear(player);
    RLCharacterReset.RestoreBody(player);
    RLPerks.GrantBaseline(player);
    this.After(n"prepareKit", 0.6);
  }

  private func PrepareRunKit() {
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    let service = RogueliteService.Get();
    RLKits.Apply(player, service.GetPools(), this.m_run.kit, RLMeta.PerkActive(service, n"perk.MedKit") ? 2 : 0, RLMeta.BonusAttributePoints(service));

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
    // Quartermaster: the run opens with an Armory pick.
    if RLMeta.PerkActive(service, n"perk.StarterPick") {
      this.RollOffers(RLRewardCategory.Armory, 2);
    }
    this.m_state = RLState.RunHome;
    this.m_apartment.StartLeash();
    this.ShowStepHud();
    RLNotify(game, "Run started. Every reward you pick also grants a level.", 6.0);
    this.After(n"nextStep", 1.5);
  }

  // --- Doors and trips ------------------------------------------------------------------------

  private func RollDoors() {
    if !IsDefined(this.m_run) {
      return;
    }
    let doorCount = RLMeta.PerkActive(RogueliteService.Get(), n"perk.FourthDoor") ? 4 : 3;
    this.m_doors = RLRewards.RollDoors(GetPlayer(this.GetGameInstance()), RogueliteService.Get().GetPools(), this.m_run, this.m_lastArena, doorCount);
    this.m_run.paidRerolls = 0;
  }

  // Called from the door picker.
  public func DeployToDoor(index: Int32) {
    if !this.IsBetweenFights() || ArraySize(this.m_offers) > 0 || this.m_run.fixerPending {
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
    // A workshop door passed over on floor 4 or 10 comes back once.
    if this.m_run.workshopShown {
      let depth = this.m_run.Depth();
      this.m_run.workshopCarry = NotEquals(door.category, RLRewardCategory.Workshop) && (depth == 4 || depth == 10);
    }
    this.m_run.door = door;
    this.m_faction = door.faction;
    ArrayClear(this.m_doors);
    this.TravelToArena(arena);
  }

  private func IsBetweenFights() -> Bool {
    return IsDefined(this.m_run) && (Equals(this.m_state, RLState.RunHome) || Equals(this.m_state, RLState.Cleared));
  }

  // Fade out with the destination on screen, then teleport (ArriveInArena).
  private func TravelToArena(arena: ref<RLArenaDef>) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    this.CancelTimer();
    this.m_state = RLState.Traveling;
    this.m_travelArena = arena;
    this.m_music.Stop();
    if !IsDefined(this.m_faction) {
      this.m_faction = RogueliteService.Get().GetPools().PickFactionPreferred(arena.factions, this.m_run.act >= 3);
    }
    let subtitle = this.m_run.FloorLabel() + " - vs " + RLEncounters.FactionName(this.m_faction.faction);
    this.StartGlitch(player);
    this.m_transition.FadeOut(arena.name, subtitle, RLConfig.FadeSeconds());
    this.After(n"travelBlack", RLConfig.FadeSeconds() + 0.1);
  }

  // The screen is black: leave the old place behind and teleport.
  private func ArriveInArena() {
    let player = GetPlayer(this.GetGameInstance());
    let arena = this.m_travelArena;
    if !IsDefined(player) || !IsDefined(this.m_run) || !IsDefined(arena) || !Equals(this.m_state, RLState.Traveling) {
      return;
    }
    this.m_arenas.StopWalls();
    this.m_spawner.DeleteAll();
    this.m_apartment.StopLeash();
    this.m_lastArena = arena.id;
    ArrayClear(this.m_expectedGrants);
    this.m_arenas.Enter(player, arena);
    RLAtmosphere.Apply(this.GetGameInstance(), arena, this.m_run);
    // V patches up on the way, and the MaxDoc never falls behind the run.
    RLCharacterReset.HealFull(player);
    this.m_deathGuard.Rearm();
    let upgraded = RLConsumables.ApplyHealthFloor(player, this.m_run.Depth(), this.m_run.TotalFloors());
    if StrLen(upgraded) > 0 {
      RLLog("Health item upgraded: " + upgraded + ".");
    }
    RLLoot.RemoveStrayWeapons(player, this.m_run.grantedWeapons);
    RLLoot.RefillForArena(player);
    this.m_waits = 0;
    this.After(n"travelSettle", 1.5);
  }

  // Waits (up to ~7 s) for the arena's navmesh, i.e. for the area to stream
  // in, then fades in and starts the countdown.
  private func SettleArrival() {
    let arena = this.m_travelArena;
    if !IsDefined(arena) || !Equals(this.m_state, RLState.Traveling) {
      return;
    }
    let found = GameInstance.GetNavigationSystem(this.GetGameInstance())
      .FindPointInSphereOnlyHumanNavmesh(arena.position, 4.0, NavGenAgentSize.Human, false);
    if !Equals(found.status, worldNavigationRequestStatus.OK) && this.m_waits < 12 {
      this.m_waits += 1;
      this.After(n"travelSettle", 0.5);
      return;
    }
    this.m_arenas.StartWalls();
    this.StopGlitch();
    this.m_transition.FadeIn(RLConfig.FadeSeconds());
    this.BeginDeploy(arena);
  }

  private func BeginDeploy(arena: ref<RLArenaDef>) {
    this.m_state = RLState.Deploying;
    this.m_wave = 0;
    this.m_waveCount = 0;
    this.m_alive = 0;
    RLStory.Quiet(this.GetGameInstance());
    // The door already named the enemy faction, so the music sets the mood
    // over the countdown.
    this.m_music.Prepare(GetPlayer(this.GetGameInstance()), this.m_faction.faction, this.m_run.Threat(), this.m_run);
    let reward = RLRewards.CategoryName(this.m_run.door.category);
    RLLog(s"Deploying to \(arena.name): \(reward), threat \(this.m_run.Threat()).");
    this.StartCountdown(RLConfig.DeployCountdown(), s"\(reward) - FIGHT IN", n"spawn");
  }

  // The game's own glitch effect (the one scene skips use) over a fade.
  private func StartGlitch(player: ref<PlayerPuppet>) {
    GameObjectEffectHelper.StartEffectEvent(player, n"transition_glitch_loop", false);
    this.After(n"glitchOff", 2.5);
  }

  private func StopGlitch() {
    this.OnDelayed(n"glitchOff");
  }

  private func SpawnEncounter() {
    let player = GetPlayer(this.GetGameInstance());
    let arena = this.m_arenas.GetArena();
    if !IsDefined(player) || !IsDefined(this.m_run) || !IsDefined(arena) || !Equals(this.m_state, RLState.Deploying) {
      return;
    }
    let faction = IsDefined(this.m_faction)
      ? this.m_faction
      : RogueliteService.Get().GetPools().PickFactionPreferred(arena.factions, this.m_run.act >= 3);
    let plan = RLEncounters.Build(this.m_run, faction, this.m_pacing.GetPressure());
    this.m_state = RLState.InEncounter;
    this.m_healthDropTaken = false;
    this.m_pacing.BeginArena();
    this.m_spawner.Start(arena, plan);
    RLNotify(player.GetGame(), this.m_run.FloorLabel() + " - " + plan.factionName, 4.0);
  }

  // --- Encounter events (from RLWaveSpawner) -----------------------------------------------

  public func OnWaveStarted(wave: Int32, waves: Int32, count: Int32) {
    this.m_wave = wave;
    this.m_waveCount = waves;
    this.m_alive = this.m_spawner.GetAliveCount();
    let bossWave = wave == waves && IsDefined(this.m_run) && this.m_run.IsBossFloor();
    this.m_music.OnWaveStarted(wave, waves, bossWave);
    RLNotify(this.GetGameInstance(), bossWave ? "BOSS WAVE" : s"WAVE \(wave)/\(waves)", 3.0);
    this.RefreshHud();
  }

  // Returns true when the pacing director calls for a breather: a longer gap
  // and a smaller next wave.
  public func OnWaveCleared(wave: Int32, waves: Int32) -> Bool {
    let relax = this.m_pacing.WantsRelax();
    RLNotify(this.GetGameInstance(), relax ? s"Wave \(wave) cleared. Catch your breath." : s"Wave \(wave) cleared.", 3.0);
    RLLoot.RefillAfterWave(GetPlayer(this.GetGameInstance()));
    this.m_alive = 0;
    this.RefreshHud();
    return relax;
  }

  public func OnHealthChanged(oldValue: Float, newValue: Float) {
    this.m_pacing.OnHealthChanged(oldValue, newValue);
  }

  // Damage V takes: the run's curve, pacing pressure and assist mode.
  public func GetIncomingDamageScale() -> Float {
    if !IsDefined(this.m_run) {
      return 1.0;
    }
    let scale = RLDifficulty.IncomingDamageScale(this.m_run.Depth(), this.m_run.TotalFloors()) * this.m_pacing.DamageScale();
    let service = RogueliteService.Get();
    if service.IsAssistOn() {
      scale *= 1.0 - service.AssistReduction();
    }
    return scale;
  }

  public func ExpectGrant(record: TweakDBID) {
    ArrayPush(this.m_expectedGrants, record);
  }

  // Rewards are picked in the arena, where pickups are filtered: the item an
  // offer grants must be let through.
  private func ExpectOfferGrant(offer: ref<RLOffer>) {
    if TDBID.IsValid(offer.record) && NotEquals(offer.kind, RLOfferKind.WeaponUpgrade) && NotEquals(offer.kind, RLOfferKind.HealthUpgrade) {
      this.ExpectGrant(offer.record);
    }
  }

  public func ConsumeExpectedGrant(record: TweakDBID) -> Bool {
    return ArrayRemove(this.m_expectedGrants, record);
  }

  public func OnEnemyCountChanged(alive: Int32) {
    this.m_alive = alive;
    this.RefreshHud();
  }

  public func OnEnemyKilled(isBoss: Bool, isElite: Bool) {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    this.m_run.kills += 1;
    this.m_pacing.OnKill();
    if isBoss {
      this.m_run.bossesKilled += 1;
    }
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    // Better healing from the toughest enemies - one drop per arena: always
    // from a boss, one elite in four, up to two steps above the health floor.
    if !this.m_healthDropTaken && (isBoss || (isElite && RandF() < 0.25)) {
      let cap = RLConsumables.HealthFloorStep(this.m_run.Depth(), this.m_run.TotalFloors()) + 2;
      let upgraded = RLConsumables.UpgradeHealthOnce(player, cap);
      if StrLen(upgraded) > 0 {
        this.m_healthDropTaken = true;
        RLLog("Health item dropped: " + upgraded + ".");
        RLNotify(player.GetGame(), "MaxDoc upgraded to " + upgraded + "!", 4.0);
      }
    }
    let statPools = GameInstance.GetStatPoolsSystem(player.GetGame());
    let playerID = Cast<StatsObjectID>(player.GetEntityID());
    let demolitionist = this.m_run.BoonStacks(n"Demolitionist");
    if demolitionist > 0 {
      statPools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.GrenadesCharges, 0.25 * Cast<Float>(demolitionist * player.GetGrenadeThrowCostClean()), null, false, false);
    }
    let bloodlust = this.m_run.BoonStacks(n"Bloodlust");
    if bloodlust > 0 {
      statPools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Health, 4.0 * Cast<Float>(bloodlust), null, false, true);
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
    let service = RogueliteService.Get();
    this.m_run.floorsCleared += 1;
    service.UpdateActiveRun(this.m_run.floorsCleared, this.m_run.kills, this.m_run.bossesKilled);

    // Cred is earned per cleared arena (and only then); eddies for the Fixer.
    let cred = RLMeta.ArenaCred(this.m_run.act, this.m_run.Threat(), this.m_run.IsBossFloor());
    service.AddCred(cred);
    this.m_run.credEarned += cred;
    let player = GetPlayer(game);
    let eddies = this.m_run.IsFinalFloor() ? 0 : RLFixer.ArenaEddies(this.m_run);
    if IsDefined(player) && eddies > 0 {
      RLGear.GiveEddies(player, eddies);
    }

    this.m_state = RLState.Cleared;
    this.m_music.OnCleared();
    this.m_pacing.EndArena(true, this.m_run);
    if this.m_run.IsFinalFloor() {
      RLNotify(game, s"Night City is yours. +\(cred) Cred.", 6.0);
      this.StartCountdown(5, "RUN COMPLETE - HOME IN", n"victoryHome");
      return;
    }

    RLNotify(game, s"Area clear. +\(cred) Cred, +\(eddies) eddies.", 4.0);
    this.m_run.advancePending = true;
    this.RollOffers(IsDefined(this.m_run.door) ? this.m_run.door.category : RLRewardCategory.Boons, this.m_run.Threat());
    if ArraySize(this.m_offers) == 0 {
      this.AdvanceFloor();
    }
    this.ShowStepHud();
    this.After(n"nextStep", 2.5);
  }

  // The reward is behind V: on to the next floor (its Fixer stop and doors).
  private func AdvanceFloor() {
    if !this.m_run.advancePending {
      return;
    }
    this.m_run.advancePending = false;
    this.m_run.Advance();
    this.m_run.fixerPending = this.m_run.IsBossFloor();
    ArrayClear(this.m_doors);
  }

  // --- Rewards -----------------------------------------------------------------------------------

  private func RollOffers(category: RLRewardCategory, threat: Int32) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    this.m_offerCategory = category;
    this.m_offerThreat = threat;
    this.m_offers = RLRewards.RollForCategory(player, RogueliteService.Get().GetPools(), this.m_run, category, threat, this.m_run.offerCount);
  }

  public func OnRewardChosen(index: Int32) {
    if !this.IsBetweenFights() || index < 0 || index >= ArraySize(this.m_offers) {
      return;
    }
    let offer = this.m_offers[index];
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if offer.disabled || !IsDefined(player) {
      return;
    }
    this.ExpectOfferGrant(offer);
    RLRewards.Grant(player, this.m_run, offer);
    // Every reward also brings a level: the only XP V gets.
    PlayerDevelopmentSystem.GetData(player).RL_GrantLevels(1);
    ArrayClear(this.m_offers);
    this.m_run.paidRerolls = 0;
    this.AdvanceFloor();
    RLNotify(game, s"\(offer.title) acquired. +1 level.", 4.0);
    this.ShowStepHud();
    this.After(n"nextStep", 0.6);
  }

  // --- Rerolls -----------------------------------------------------------------------------------
  // A free charge when there is one (every act refills them), otherwise eddies:
  // the price climbs with every paid reroll on the same screen (Balatro).

  public func GetRerollCharges() -> Int32 = IsDefined(this.m_run) ? this.m_run.rerolls : 0

  public func GetRerollPrice() -> Int32 = IsDefined(this.m_run) ? RLRewards.RerollPrice(this.m_run) : 0

  public func GetEddies() -> Int32 {
    let player = GetPlayer(this.GetGameInstance());
    return IsDefined(player) ? RLFixer.Balance(player) : 0;
  }

  public func CanReroll() -> Bool {
    return IsDefined(this.m_run) && (this.m_run.rerolls > 0 || this.GetEddies() >= this.GetRerollPrice());
  }

  private func PayForReroll() -> Bool {
    if !this.IsBetweenFights() {
      return false;
    }
    if this.m_run.rerolls > 0 {
      this.m_run.rerolls -= 1;
      return true;
    }
    let player = GetPlayer(this.GetGameInstance());
    let price = this.GetRerollPrice();
    if !IsDefined(player) || RLFixer.Balance(player) < price {
      return false;
    }
    GameInstance.GetTransactionSystem(player.GetGame()).RemoveItem(player, RLFixer.MoneyID(), price);
    this.m_run.paidRerolls += 1;
    return true;
  }

  public func OnRewardReroll() {
    if ArraySize(this.m_offers) == 0 || !this.PayForReroll() {
      return;
    }
    this.RollOffers(this.m_offerCategory, this.m_offerThreat);
    this.After(n"nextStep", 0.3);
  }

  public func OnDoorReroll() {
    if ArraySize(this.m_doors) <= 1 || !this.PayForReroll() {
      return;
    }
    let paid = this.m_run.paidRerolls;
    this.RollDoors();
    this.m_run.paidRerolls = paid;
    this.After(n"nextStep", 0.3);
  }

  // --- Fixer ---------------------------------------------------------------------------------

  private func OpenFixer() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || this.m_popupOpen {
      return;
    }
    if ArraySize(this.m_fixerStock) == 0 {
      this.m_fixerStock = RLFixer.Stock(player, RogueliteService.Get().GetPools(), this.m_run);
    }
    this.m_popupOpen = true;
    this.m_popup = RLFixerPopup.Open(this);
  }

  public func GetFixerStock() -> array<ref<RLFixerItem>> = this.m_fixerStock

  public func BuyFromFixer(index: Int32) -> Bool {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) || index < 0 || index >= ArraySize(this.m_fixerStock) {
      return false;
    }
    let item = this.m_fixerStock[index];
    if !item.contact && IsDefined(item.offer) {
      this.ExpectOfferGrant(item.offer);
    }
    return RLFixer.Buy(player, this.m_run, item);
  }

  public func OnFixerLeft() {
    if !IsDefined(this.m_run) {
      return;
    }
    this.m_run.fixerPending = false;
    ArrayClear(this.m_fixerStock);
    this.ShowStepHud();
    this.After(n"nextStep", 0.4);
  }

  // --- Death ------------------------------------------------------------------------------------

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
      GameInstance.GetStatPoolsSystem(player.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, 50.0, null, true);
      this.m_deathGuard.Rearm();
      RLNotify(player.GetGame(), "SECOND WIND!", 3.0);
      return;
    }
    this.Flatline();
  }

  // V dies for real: the game's own death (camera drops, the world fades), with
  // its death menu held back and a resurrection set up (Player/Death.reds).
  // While V is down the screen fades to black, and V comes to at home.
  private func Flatline() {
    let player = GetPlayer(this.GetGameInstance());
    this.m_state = RLState.Flatlined;
    this.CancelTimer();
    this.m_music.Stop();
    this.m_pacing.EndArena(false, this.m_run);
    this.m_hud.Hide();
    this.m_dying = true;
    this.m_sawDeath = false;
    this.m_deathElapsed = 0.0;
    this.m_deathGuard.Disarm();
    this.m_deathMenuFact = RLDeath.Begin(player);
    this.After(n"deathFade", 1.8);
    this.After(n"deathCheck", 0.5);
  }

  private func DeathFade() {
    if !Equals(this.m_state, RLState.Flatlined) {
      return;
    }
    this.m_transition.FadeOut("FLATLINED", this.RunSummary(), 1.4);
    this.After(n"deathBlack", 1.5);
  }

  // Polls V's state: once V has died and come to, V goes home. If V never
  // went down, the run ends the old way; if V stays down, the game's own
  // death menu is let through (loading a save counts the run as abandoned).
  private func DeathTick() {
    if !this.m_dying {
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    this.m_deathElapsed += 0.5;
    let down = IsDefined(player) && RLDeath.IsDown(player);
    if down {
      this.m_sawDeath = true;
    }
    let cameBack = this.m_sawDeath && !down;
    let neverDied = !this.m_sawDeath && this.m_deathElapsed >= 3.0;
    if (cameBack || neverDied) && this.m_transition.IsBlack() && this.m_deathElapsed >= 3.5 {
      RLLog(cameBack ? s"V came to after \(this.m_deathElapsed)s." : "V never went down; ending the run anyway.");
      this.EndDying();
      this.EndRun(false, true, false);
      return;
    }
    if this.m_deathElapsed >= 15.0 {
      RLLog("V didn't come back - letting the game's death menu through.");
      this.EndDying();
      RLDeath.ShowDeathMenu(player);
      this.m_transition.FadeIn(0.5);
      return;
    }
    this.After(n"deathCheck", 0.5);
  }

  private func EndDying() {
    this.m_dying = false;
    RLDeath.End(this.GetGameInstance(), this.m_deathMenuFact);
  }

  // --- Run end ------------------------------------------------------------------------------------

  public func AbandonRun() {
    if IsDefined(this.m_run) {
      this.EndRun(false, false, true);
    }
  }

  // Settles the run, then the trip home (fade, teleport, reset, fade in).
  private func EndRun(victory: Bool, alreadyBlack: Bool, abandoned: Bool) {
    if !IsDefined(this.m_run) || Equals(this.m_state, RLState.Ending) {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    let run = this.m_run;
    this.m_state = RLState.Ending;
    this.CancelTimer();
    this.m_music.Stop();
    this.m_pacing.Stop();
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);
    ArrayClear(this.m_fixerStock);

    let service = RogueliteService.Get();
    // Cred was banked arena by arena; a completed run adds a bonus.
    let payout = victory ? RLMeta.VictoryCred() : 0;
    service.AddCred(payout);
    service.RecordRunEnd(run.floorsCleared, run.kills, victory);
    service.ClearRunToken();

    this.m_deathGuard.Disarm();
    RLBoons.RemoveAll(player, run);
    FastTravelSystem.RemoveFastTravelLock(n"NightCityRoguelite", game);
    this.m_hud.Hide();

    this.m_endTitle = victory ? "NIGHT CITY IS YOURS" : (abandoned ? "RUN ABANDONED" : "FLATLINED");
    this.m_endSubtitle = this.RunSummary() + s"   +\(run.credEarned + payout) CRED";
    this.m_lastSummary = (victory ? "RUN COMPLETE" : "RUN OVER")
      + s" - floors cleared \(run.floorsCleared), kills \(run.kills). Cred earned \(run.credEarned + payout) (total \(service.GetCred())).";
    RLLog(this.m_lastSummary);
    this.m_run = null;

    if alreadyBlack {
      this.m_transition.SetText(this.m_endTitle, this.m_endSubtitle);
      this.ArriveHome();
      return;
    }
    if IsDefined(player) {
      this.StartGlitch(player);
    }
    this.m_transition.FadeOut(this.m_endTitle, this.m_endSubtitle, RLConfig.FadeSeconds());
    this.After(n"homeBlack", RLConfig.FadeSeconds() + 0.1);
  }

  private func ArriveHome() {
    let player = GetPlayer(this.GetGameInstance());
    this.m_spawner.Abort();
    this.m_spawner.DeleteAll();
    this.m_arenas.StopWalls();
    RLAtmosphere.Reset(this.GetGameInstance());
    if IsDefined(player) {
      this.ReturnToHub(player);
      RLCharacterReset.HealFull(player);
      RLDeath.ClearAftermath(player);
      RLCharacterReset.ResetProgressionAndUnequip(player);
    }
    this.After(n"endGear", 0.6);
  }

  private func FinishEndRun() {
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      RLCharacterReset.RemoveGear(player);
      RLCharacterReset.RestoreBody(player);
      RLPerks.GrantBaseline(player);
      RLCharacterReset.HealFull(player);
    }
    SaveLocksManager.RequestSaveLockRemove(this.GetGameInstance(), n"NightCityRoguelite.Run");
    this.m_state = RLState.Hub;
    this.m_apartment.StartLeash();
    this.m_waits = 0;
    this.After(n"homeSettle", 1.0);
  }

  // Holds the summary on screen until V is standing in the apartment.
  private func SettleHomeArrival() {
    if !Equals(this.m_state, RLState.Hub) {
      return;
    }
    let settled = this.m_apartment.IsSettled() || !this.m_apartment.IsEnabled();
    if (!settled || this.m_waits < 2) && this.m_waits < 20 {
      this.m_waits += 1;
      this.After(n"homeSettle", 0.5);
      return;
    }
    this.StopGlitch();
    this.m_transition.FadeIn(1.2);
    RLNotify(this.GetGameInstance(), this.m_lastSummary, 10.0);
  }

  // --- Arena loot ----------------------------------------------------------------------------------

  // True while V is in an arena: pickups are filtered (Combat/Loot.reds).
  public func FiltersLoot() -> Bool = this.IsInArenaFight()

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

  private func RunSummary() -> String {
    if !IsDefined(this.m_run) {
      return "";
    }
    return s"FLOORS CLEARED \(this.m_run.floorsCleared)   KILLS \(this.m_run.kills)";
  }

  private func ArenaSummary() -> String {
    if !IsDefined(this.m_run) {
      return "No run in progress.";
    }
    let arena = this.m_arenas.GetArena();
    let arenaName = IsDefined(arena) ? arena.name : "";
    return s"\(this.m_run.FloorLabel()) - \(arenaName). Wave \(this.m_wave)/\(this.m_waveCount), \(this.m_alive) hostiles left. Kills: \(this.m_run.kills).";
  }
}

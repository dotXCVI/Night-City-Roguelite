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
//     --> Deploying (countdown, music) --> InEncounter (waves, objective)
//     --> Cleared: the door's reward, the Fixer before a boss, the next door
//   RunHome / Cleared --"?" door--> an event screen, the next door
//   (a run opens with a gig to take before the first door)
//   InEncounter --health gone--> a Trauma Team cover spent and back up, or
//     with none left Flatlined (V dies for real and comes to)
//     --> Ending (home, reset) --> Hub
//   final floor cleared --> Cleared (countdown) --> Ending --> Hub
//
// Collaborators: doors and offers (Rewards/RewardSystem.reds, Director.reds),
// effects and keywords (Rewards/Boons.reds, BoonEffects.reds,
// Combat/Keywords.reds), the weapon slots (Rewards/Weapons.reds),
// waves (Run/Encounters.reds, Combat/WaveSpawner.reds), pacing and difficulty
// (Run/Pacing.reds, Run/Difficulty.reds), the Fixer (Run/Fixer.reds), music
// (Audio/Music.reds), the death sequence (Player/Death.reds), fades
// (UI/Transition.reds), boons in fights (Rewards/BoonEffects.reds, with the
// damage hooks in Combat/DamageHooks.reds), objectives (Run/Objectives.reds),
// events (Run/Events.reds) and the apartment hub (Hub/ApartmentHub.reds; when
// it is off or fails to load, home is the spot where the takeover happened).
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
  // The fight in progress: boon counters, enemy roles and affixes.
  private let m_combat: ref<RLCombatState>;
  private let m_objective: ref<RLObjective>;
  // An event door's screen, waiting to be resolved.
  private let m_event: ref<RLEvent>;
  // The boss whose health the HUD shows (the first one seen; the next one
  // takes over when it falls).
  private let m_bossFocus: EntityID;

  // The four patrons working the city next run (shown at the terminal).
  private let m_lineup: array<CName>;
  // Items the mod hands out mid-fight, exempt from the arena pickup filter.
  private let m_expectedGrants: array<TweakDBID>;
  // One MaxDoc drop per arena at most.
  private let m_healthDropTaken: Bool;
  private let m_fixerStock: array<ref<RLFixerItem>>;
  // What waits between fights: the reward offers (and their type), the doors.
  private let m_offers: array<ref<RLOffer>>;
  private let m_offerCategory: RLRewardCategory;
  private let m_offerPatron: CName;
  private let m_offerHot: Bool;
  // Cards the screen deals over the usual (Open Line); a reroll keeps them.
  private let m_offerBonus: Int32;
  private let m_doors: array<ref<RLDoor>>;
  // The enemy faction of the fight being travelled to / fought.
  private let m_faction: ref<RLFactionPool>;
  private let m_lastArena: CName;
  // The arena's look (World/Atmosphere.reds), and whether the game's weather
  // states have been logged this session.
  private let m_lastLook: CName;
  private let m_weatherListed: Bool;

  // Trips.
  private let m_travelArena: ref<RLArenaDef>;
  private let m_waits: Int32;
  private let m_endTitle: String;
  // The world glitch over a trip runs until then (a later trip extends it).
  private let m_glitchUntil: Float;
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
  // V is standing in the armory (the HUD says so).
  private let m_inArmory: Bool;
  private let m_guideWaits: Int32;
  // Times the armory door had to be opened this session (it stops trying
  // after a few, in case something keeps shutting it).
  private let m_armoryDoorTries: Int32;
  private let m_armoryReportIn: Int32;
  private let m_takeoverElapsed: Float;
  private let m_readyElapsed: Float;
  private let m_openWaits: Int32;
  // When the next step started waiting for a screen to finish closing.
  private let m_closeWaitAt: Float;
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
  private let m_bugMarks: Int32;
  // Quartermaster unlock: an Armory pick right after the gig.
  private let m_starterPickPending: Bool;
  // A new run's opening screens (the gig) are still being set up: no door
  // can be taken yet.
  private let m_openingPending: Bool;

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
    this.m_combat = new RLCombatState();
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

  public func GetCombat() -> ref<RLCombatState> = this.m_combat

  // A fight is on: effects and keywords act.
  public func IsFighting() -> Bool = IsDefined(this.m_run) && Equals(this.m_state, RLState.InEncounter)

  // The patrons the next run will bring (the terminal shows them).
  public func GetLineup() -> array<CName> {
    if ArraySize(this.m_lineup) == 0 {
      this.m_lineup = RLPatrons.RollLineup();
    }
    // Standing Offer bought or switched on after the lineup was rolled.
    if RLTerminal.Has(n"PatronsEar", 2) {
      let favourite = RLPatrons.MostBacked();
      if IsNameValid(favourite) && !ArrayContains(this.m_lineup, favourite) {
        this.m_lineup[ArraySize(this.m_lineup) - 1] = favourite;
      }
    }
    return this.m_lineup;
  }

  // The fight's view for the effects (Combat/Keywords.reds).
  private func Fx(player: ref<PlayerPuppet>) -> ref<RLFx> = RLFx.Make(this, this.m_run, this.m_combat, player)

  // A one-word tag on the HUD while fighting (an effect firing).
  public func ShowTag(const label: String, color: CName) {
    if this.IsFighting() {
      this.m_hud.Tag(label, color);
    }
  }

  // Living arena enemies near a spot (Overdrive, style signatures).
  public func EnemiesNear(position: Vector4, radius: Float) -> array<ref<ScriptedPuppet>> = this.m_spawner.LivingNear(position, radius)

  // V activated an Operating System (Player/OSHooks.reds): Overdrive when the
  // meter is full.
  public func OnOperatingSystemActivated(os: CName) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(this.m_run) || !IsDefined(player) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    // Only the OS that unlocked Overdrive overdrives.
    if IsNameValid(this.m_run.os) && NotEquals(os, this.m_run.os) {
      return;
    }
    if RLOverdrive.OnActivated(this.m_run, this.m_combat, player, os) {
      RLTelemetry.Record(this.m_run, "ULT", RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.Field("os", NameToString(os)) + RLTelemetry.IntField("wave", this.m_wave));
      this.RefreshHud();
    }
  }

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
    let refund = RLMeta.RefundRetired(service);
    if refund > 0 {
      RLNotify(this.GetGameInstance(), s"Some upgrades are gone with the level-ups. +\(refund) Cred back.", 8.0);
    }
    RLTerminal.Migrate(service);
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
      RLNotify(this.GetGameInstance(), s"You bailed on your last run. Counts as a flatline. +\(abandonedPayout) Cred.", 8.0);
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
      case n"favorNotice":
        RLNotify(this.GetGameInstance(), s"THE FIXERS OWE YOU. \(RogueliteService.Get().GetFavors()) FAVORS TO CALL IN AT THE ARMORY.", 5.0);
        break;
      case n"openingScreens":
        this.OpenOpeningScreens();
        break;
      case n"nextStep":
        this.OpenNextStepWhenReady();
        break;
      case n"travelFade":
        this.FadeToArena();
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
      case n"homeFade":
        this.m_transition.FadeOut(this.m_endTitle, this.m_endSubtitle, RLConfig.FadeSeconds());
        this.After(n"homeBlack", RLConfig.FadeSeconds() + 0.1);
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
        if IsDefined(player) && RLBoonEffects.Now(this.GetGameInstance()) >= this.m_glitchUntil - 0.05 {
          GameObjectEffectHelper.StopEffectEvent(player, n"transition_glitch_loop");
        }
        break;
      case n"lootSweep":
        this.SweepLoot();
        break;
      case n"armory":
        this.OpenArmory();
        break;
      case n"guide":
        this.OpenGuide();
        break;
      case n"popupCheck":
        this.CheckPopupShown();
        break;
      case n"weatherCheck":
        if Equals(this.m_state, RLState.Deploying) || Equals(this.m_state, RLState.InEncounter) {
          RLAtmosphere.Check(this.GetGameInstance(), this.m_lastLook, !this.m_weatherListed);
          this.m_weatherListed = true;
        }
        break;
      case n"styles":
        let stylePlayer = GetPlayer(this.GetGameInstance());
        if IsDefined(this.m_run) && IsDefined(stylePlayer) {
          RLStyles.Refresh(stylePlayer, this.m_run, true);
        }
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
    this.m_inArmory = false;
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
    if !RogueliteService.Get().HasSeenGuide() {
      // The guide covers it all.
      this.m_guideWaits = 0;
      this.After(n"guide", 1.5);
      return;
    }
    let message = firstTime
      ? "Home sweet home. Computer for runs, the back room for gear. Save here."
      : "Home. Computer for runs, back room for gear.";
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
    RLNotify(this.GetGameInstance(), "Apartment didn't load - home is where you started, for now. Share the log.", 8.0);
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
        if IsDefined(player) && this.IsInArmory(player) {
          this.OpenArmory();
        } else {
          this.m_popupOpen = true;
          this.m_popup = RLTerminalPopup.OpenHub(this);
        }
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

  // F8 or the MARK BUG card: a snapshot of where things stand goes into the
  // log, so a report can point at the exact moment.
  public func MarkBug() {
    if !this.m_isRoguelite {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    this.m_bugMarks += 1;
    RLLog(s"===== BUG MARK #\(this.m_bugMarks) =====");
    let state = RLTelemetry.StateName(this.m_state);
    let arena = this.m_arenas.GetArena();
    RLLog(s"State \(state), popup open \(this.m_popupOpen), countdown \(this.m_countdown) (\(NameToString(this.m_countdownAction))), dying \(this.m_dying).");
    if IsDefined(player) {
      let p = player.GetWorldPosition();
      RLLog(s"V at (\(p.X), \(p.Y), \(p.Z)), busy: \(RogueliteSystem.BusyReason(player)).");
    }
    if IsDefined(this.m_run) {
      RLLog(s"\(this.m_run.FloorLabel()), arena \(IsDefined(arena) ? arena.name : "-"), wave \(this.m_wave)/\(this.m_waveCount), alive \(this.m_alive), offers \(ArraySize(this.m_offers)), doors \(ArraySize(this.m_doors)), event \(IsDefined(this.m_event)), objective \(IsDefined(this.m_objective) ? this.m_objective.Status() : "-").");
      for line in this.m_spawner.Describe(player) {
        RLLog(line);
      }
      RLTelemetry.Record(this.m_run, "MARK", RLTelemetry.IntField("n", this.m_bugMarks) + RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.Field("state", state));
    }
    RLNotify(game, s"Bug marked (#\(this.m_bugMarks)). Quit through the menu so the log saves.", 4.0);
  }

  public func OnPopupClosed() {
    this.m_popupOpen = false;
  }

  // --- Armory and guide ----------------------------------------------------------------------

  // Kits are picked in the armory, the weapon room at the back of the
  // apartment (Hub/HomeDevices.reds): its stash, or F7 in there. Only between
  // runs.
  public func OpenArmory() {
    if this.m_popupOpen && !this.IsPopupAlive() {
      this.m_popupOpen = false;
    }
    if !Equals(this.m_state, RLState.Hub) || this.m_popupOpen {
      return;
    }
    this.m_popupOpen = true;
    this.m_popup = RLArmoryPopup.Open(this);
    this.After(n"popupCheck", 1.0);
  }

  // A popup that never showed up leaves nothing open.
  private func CheckPopupShown() {
    if this.m_popupOpen && !this.IsPopupAlive() {
      RLLog("A menu didn't open - cleared.");
      this.m_popupOpen = false;
    }
  }

  // From the terminal: once its fade-out is over (Codeware drops a popup
  // shown while another is still closing).
  public func OpenArmoryLater() {
    this.After(n"armory", 0.6);
  }

  public func OpenGuideLater() {
    this.m_guideWaits = 0;
    this.After(n"guide", 0.6);
  }

  // The armory's stash was used.
  public func OnArmoryUsed() {
    if !Equals(this.m_state, RLState.Hub) {
      RLNotify(this.GetGameInstance(), "Armory's locked till the run's over.", 3.0);
      return;
    }
    if this.m_popupOpen && !this.IsPopupAlive() {
      this.m_popupOpen = false;
    }
    this.OpenArmory();
  }

  // Walking to the back room is possible this session (not stuck in the
  // hallway).
  public func IsArmoryReachable() -> Bool = this.m_apartment.IsInApartment()

  public func IsInArmory(player: ref<PlayerPuppet>) -> Bool {
    return this.IsArmoryReachable() && RLHomeDevices.InArmory(player.GetWorldPosition());
  }

  // Once a second while V is home: the HUD names the armory while V stands
  // in it.
  public func OnHomeTick(player: ref<PlayerPuppet>) {
    let game = this.GetGameInstance();
    if this.m_armoryDoorTries < 5 && this.m_apartment.IsInApartment() && RLHomeDevices.KeepArmoryOpen(game) {
      this.m_armoryDoorTries += 1;
    }
    if !Equals(this.m_state, RLState.Hub) {
      this.m_inArmory = false;
      return;
    }
    // Once per session, after the room has had time to stream in.
    if this.m_armoryReportIn < 10 && this.m_apartment.IsSettled() {
      this.m_armoryReportIn += 1;
      if this.m_armoryReportIn == 10 {
        RLHomeDevices.Report(game);
      }
    }
    // With the stash there and the door open, the stash's prompt is all V
    // needs; otherwise the HUD points at F7.
    let inside = this.IsInArmory(player) && (!RLHomeDevices.IsStashLoaded(game) || !RLHomeDevices.IsArmoryDoorOpen(game));
    if Equals(inside, this.m_inArmory) {
      return;
    }
    this.m_inArmory = inside;
    if inside {
      this.m_hud.Update("ARMORY", "F7: OPEN THE ARMORY");
    } else {
      this.m_hud.Hide();
    }
  }

  // The how-it-works guide: on the first homecoming, and from the terminal.
  // Only at home between runs, once V has been put in the apartment.
  public func OpenGuide() {
    let player = GetPlayer(this.GetGameInstance());
    if this.m_popupOpen && !this.IsPopupAlive() {
      this.m_popupOpen = false;
    }
    if this.m_popupOpen || !IsDefined(player) || !Equals(this.m_state, RLState.Hub) {
      return;
    }
    let settled = this.m_apartment.IsSettled() || !this.m_apartment.IsEnabled();
    if (!settled || StrLen(RogueliteSystem.BusyReason(player)) > 0) && this.m_guideWaits < 30 {
      this.m_guideWaits += 1;
      this.After(n"guide", 1.0);
      return;
    }
    this.m_popupOpen = true;
    this.m_popup = RLGuidePopup.Open(this);
    this.After(n"popupCheck", 1.0);
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
    if this.m_openingPending {
      this.After(n"nextStep", 0.5);
      return;
    }
    if ArraySize(this.m_offers) > 0 {
      this.m_popupOpen = true;
      this.m_popup = RLRewardPopup.Open(this, this.m_offers, this.OfferTitle(), this.OfferTagline());
      return;
    }
    if IsDefined(this.m_event) {
      this.m_popupOpen = true;
      this.m_popup = RLEventPopup.Open(this, this.m_event);
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
    // A screen that was just picked from closes with a short animation: wait
    // it out (briefly - a screen V is still looking at stays put).
    if this.m_popupOpen {
      let now = RLBoonEffects.Now(this.GetGameInstance());
      if now - this.m_closeWaitAt > 5.0 {
        this.m_closeWaitAt = now;
      }
      if now - this.m_closeWaitAt < 1.5 {
        this.After(n"nextStep", 0.3);
      }
      return;
    }
    if this.WaitIfBusy(n"nextStep") {
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
      status = Equals(this.m_offerCategory, RLRewardCategory.Gig) ? "F7: TAKE A GIG" : "F7: CHOOSE YOUR REWARD";
    } else if IsDefined(this.m_event) {
      status = "F7: " + this.m_event.title;
    } else if this.m_run.fixerPending {
      status = "F7: THE FIXER IS IN";
    } else {
      status = "F7: CHOOSE YOUR NEXT FIGHT";
    }
    let title = this.m_run.advancePending ? this.m_run.FloorLabel() + " CLEARED" : "NEXT: " + this.m_run.FloorLabel();
    this.m_hud.Update(title, status);
  }

  // --- Run start ---------------------------------------------------------------------------

  // `testFloor` > 0 starts a test run on that floor (no Cred, no stats).
  public func StartRun(kit: CName, opt testFloor: Int32) {
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
    let isTest = testFloor > 0;
    this.m_run = RLRunState.Create(isTest ? 0 : service.BeginRunToken(), kit);
    if isTest {
      this.m_run.isTest = true;
      this.m_run.SetDepth(testFloor);
      this.m_run.fixerPending = this.m_run.IsBossFloor();
    }
    this.m_run.id = RandRange(1, 2000000000);
    this.m_run.startTime = RLBoonEffects.Now(game);
    RLTelemetry.Record(this.m_run, "RUN", RLTelemetry.Field("kit", NameToString(kit)) + RLTelemetry.IntField("test", isTest ? 1 : 0)
      + RLTelemetry.IntField("from", this.m_run.Depth()) + RLTelemetry.IntField("assist", service.IsAssistOn() ? 1 : 0)
      + RLTelemetry.IntField("runs", service.GetRunsStarted()));
    this.m_pacing.ResetRun();
    this.m_run.patrons = this.GetLineup();
    ArrayClear(this.m_lineup);
    this.m_run.coverMax = RLConfig.CoverPerRun() + (RLTerminal.Has(n"TraumaTeam", 2) ? 1 : 0);
    this.m_run.cover = this.m_run.coverMax;
    this.m_run.rerollsPerAct = RLTerminal.Has(n"FixerContacts", 1) ? 2 : 1;
    this.m_run.rerolls = this.m_run.rerollsPerAct;
    this.m_run.offerCount = RLTerminal.Has(n"WideNet", 1) ? 4 : 3;
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);
    this.m_lastArena = n"";
    this.m_state = RLState.Preparing;
    SaveLocksManager.RequestSaveLockAdd(game, n"NightCityRoguelite.Run");

    RLCharacterReset.ResetProgressionAndUnequip(player);
    this.After(n"prepareGear", 0.6);
    RLLog("Run started: kit " + NameToString(kit) + ", patrons " + RLPatrons.LineupText(this.m_run.patrons) + (isTest ? s", test run from floor \(testFloor)." : "."));
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
    // V's level first: the kit's chrome checks it.
    RLDifficulty.SetPlayerLevel(player, this.m_run.act);
    RLKits.Apply(player, service.GetPools(), this.m_run, RLTerminal.Has(n"BackAlleyDoc", 1) ? 2 : 0);
    RLKits.ApplyTerminal(player, this.m_run);

    if this.m_run.isTest {
      this.PrepareTestRun(player);
    }

    RLCharacterReset.HealFull(player);
    this.m_deathGuard.Arm(player);
    FastTravelSystem.AddFastTravelLock(n"NightCityRoguelite", game);
    // Styles count from the kit; the run opens with a gig, then (Quartermaster)
    // an Armory pick.
    this.m_openingPending = true;
    this.After(n"openingScreens", 0.8);
    this.m_state = RLState.RunHome;
    this.m_apartment.StartLeash();
    this.ShowStepHud();
    RLNotify(game, this.m_run.isTest ? "Test run. No Cred, no stats." : "You're on. In town: " + RLPatrons.LineupText(this.m_run.patrons) + ".", 7.0);
    this.After(n"nextStep", 1.5);
  }

  // The kit's gear has settled: count styles, then offer the gig.
  private func OpenOpeningScreens() {
    let player = GetPlayer(this.GetGameInstance());
    if !this.m_openingPending || !IsDefined(player) || !IsDefined(this.m_run) || !Equals(this.m_state, RLState.RunHome) {
      this.m_openingPending = false;
      return;
    }
    this.m_openingPending = false;
    RLStyles.Refresh(player, this.m_run, false);
    this.m_starterPickPending = RLTerminal.Has(n"Quartermaster", 1);
    this.RollOffers(RLRewardCategory.Gig, n"", false);
    if ArraySize(this.m_offers) == 0 {
      this.AfterGig();
    }
    this.ShowStepHud();
  }

  private func AfterGig() {
    if this.m_starterPickPending {
      this.m_starterPickPending = false;
      this.RollOffers(RLRewardCategory.Armory, n"", RLTerminal.Has(n"Quartermaster", 2));
    }
  }

  // A test run starts where a real one would have got to: the act's level,
  // the eddies and main weapon tier of the floors skipped, three effects
  // from different patrons, and past the Act 1 boss an Operating System.
  private func PrepareTestRun(player: ref<PlayerPuppet>) {
    let depth = this.m_run.Depth();
    if depth > 1 {
      RLGear.GiveEddies(player, 300 * (depth - 1));
    }
    let patrons = this.m_run.patrons;
    let given = 0;
    while given < 3 && ArraySize(patrons) > 0 {
      let i = RandRange(0, ArraySize(patrons));
      let offers = RLRewards.BoonOffers(player, this.m_run, patrons[i], 1, false);
      if ArraySize(offers) > 0 {
        RLBoons.Apply(player, this.m_run, offers[0].boon, false);
        RLLog("Test run effect: " + offers[0].title + ".");
        given += 1;
      }
      ArrayErase(patrons, i);
    }
    this.m_run.mainStep = RLQuality.ExpectedStep(depth, this.m_run.TotalFloors());
    this.m_run.sidearmStep = this.m_run.act - 1;
    RLWeapons.ApplySteps(player, this.m_run);
    if depth > RLConfig.FloorsPerAct() {
      let systems = RLRewards.OperatingSystemOffers(player, RogueliteService.Get().GetPools(), this.m_run);
      if ArraySize(systems) > 0 {
        RLRewards.Grant(player, this.m_run, systems[RandRange(0, ArraySize(systems))]);
      }
    }
  }

  // --- Doors and trips ------------------------------------------------------------------------

  private func RollDoors() {
    if !IsDefined(this.m_run) {
      return;
    }
    let doorCount = RLTerminal.Has(n"StreetMap", 1) ? 4 : 3;
    this.m_doors = RLRewards.RollDoors(GetPlayer(this.GetGameInstance()), RogueliteService.Get().GetPools(), this.m_run, this.m_lastArena, doorCount);
  }

  // Called from the door picker.
  public func DeployToDoor(index: Int32) {
    if !this.IsBetweenFights() || ArraySize(this.m_offers) > 0 || this.m_run.fixerPending || this.m_openingPending {
      return;
    }
    if index < 0 || index >= ArraySize(this.m_doors) {
      return;
    }
    let door = this.m_doors[index];
    RLTelemetry.Record(this.m_run, "PICK", RLTelemetry.Field("screen", "doors") + RLTelemetry.IntField("depth", this.m_run.Depth())
      + RLTelemetry.Field("offered", this.DoorsText()) + RLTelemetry.IntField("idx", index));
    let arena = RLArenas.Get(door.arena);
    let isEvent = Equals(door.category, RLRewardCategory.Event);
    if !isEvent && !IsDefined(arena) {
      return;
    }
    // A workshop door passed over on floor 4 or 10 comes back once.
    if this.m_run.workshopShown {
      let depth = this.m_run.Depth();
      this.m_run.workshopCarry = NotEquals(door.category, RLRewardCategory.Workshop) && RLRewards.IsWorkshopFloor(depth);
    }
    if isEvent {
      this.OpenEvent(door);
      return;
    }
    this.m_run.door = door;
    this.m_faction = door.faction;
    ArrayClear(this.m_doors);
    this.TravelToArena(arena);
  }

  private func IsBetweenFights() -> Bool {
    return IsDefined(this.m_run) && (Equals(this.m_state, RLState.RunHome) || Equals(this.m_state, RLState.Cleared));
  }

  // The world glitches, then fades out with the destination on screen, then
  // V is teleported (ArriveInArena).
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
    this.StartGlitch(player, RLConfig.GlitchLead() + RLConfig.FadeSeconds() + 0.3);
    this.After(n"travelFade", RLConfig.GlitchLead());
  }

  // The glitch has had its moment on screen: the black comes down over it.
  private func FadeToArena() {
    let arena = this.m_travelArena;
    if !IsDefined(arena) || !IsDefined(this.m_run) || !Equals(this.m_state, RLState.Traveling) {
      return;
    }
    this.m_transition.FadeOut(arena.name, this.m_run.FloorLabel() + " - " + this.FightLabel(), RLConfig.FadeSeconds());
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
    RLBoonEffects.EndFight(player, this.m_combat);
    this.m_combat.ResetArena();
    this.m_bossFocus = EntityID();
    this.StopObjective();
    this.m_arenas.Enter(player, arena);
    this.m_lastLook = RLAtmosphere.Apply(this.GetGameInstance(), arena, this.m_run, this.m_lastLook);
    // Every fight starts at full health, and the MaxDoc never falls behind
    // the run.
    RLCharacterReset.HealFull(player);
    this.m_deathGuard.Rearm();
    let upgraded = RLConsumables.ApplyHealthFloor(player, this.m_run.Depth(), this.m_run.TotalFloors());
    if StrLen(upgraded) > 0 {
      RLLog("Health item upgraded: " + upgraded + ".");
    }
    RLLoot.RemoveStrayWeapons(player, this.m_run.grantedWeapons);
    RLArms.Heal(player, this.m_run);
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
    let game = this.GetGameInstance();
    let found = GameInstance.GetNavigationSystem(game)
      .FindPointInSphereOnlyHumanNavmesh(arena.position, 4.0, NavGenAgentSize.Human, false);
    let ready = Equals(found.status, worldNavigationRequestStatus.OK) && RLArenaDirector.HasFloor(game, arena.position);
    if !ready && this.m_waits < 16 {
      this.m_waits += 1;
      this.After(n"travelSettle", 0.5);
      return;
    }
    // The first teleport can land before the ground's collision has
    // streamed in, leaving V inside the floor: now that it's there, put V
    // on it again (the screen is still black).
    let player = GetPlayer(game);
    if IsDefined(player) {
      RLArenaDirector.TeleportToPoint(player, arena.position, arena.yaw);
    }
    this.m_arenas.StartWalls();
    // The arena glitches in as the black lifts.
    if IsDefined(player) {
      this.StartGlitch(player, RLConfig.FadeSeconds() + 0.6);
    }
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
    let reward = RLRewards.DoorTitle(this.m_run.door);
    let objective = this.m_run.door.objective;
    RLLog(s"Deploying to \(arena.name): \(reward), threat \(this.m_run.Threat()), objective \(RLObjectives.Name(objective)).");
    let label = NotEquals(objective, RLObjectiveKind.None) ? RLObjectives.Name(objective) : reward;
    this.StartCountdown(RLConfig.DeployCountdown(), label + " - FIGHT IN", n"spawn");
    this.After(n"weatherCheck", 3.0);
  }

  // The game's own glitch (the one a scene skip plays) on the world, for
  // `seconds`. It renders under the HUD, so a trip shows it before the black
  // comes down and again as the black lifts - under full black it can't be
  // seen.
  private func StartGlitch(player: ref<PlayerPuppet>, seconds: Float) {
    GameObjectEffectHelper.StopEffectEvent(player, n"transition_glitch_loop");
    GameObjectEffectHelper.StartEffectEvent(player, n"transition_glitch_loop", false);
    this.m_glitchUntil = RLBoonEffects.Now(this.GetGameInstance()) + seconds;
    this.After(n"glitchOff", seconds);
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
    let door = this.m_run.door;
    let plan = Equals(door.category, RLRewardCategory.Bounty)
      ? RLEncounters.BuildBounty(this.m_run, faction)
      : RLEncounters.Build(this.m_run, faction, this.m_pacing.GetPressure());
    this.m_state = RLState.InEncounter;
    this.m_healthDropTaken = false;
    RLStyles.Refresh(player, this.m_run, false);
    this.m_pacing.BeginArena();
    let hasObjective = NotEquals(door.objective, RLObjectiveKind.None);
    if hasObjective {
      this.m_objective = RLObjective.Start(door.objective, this.m_run, arena, player);
    }
    this.m_spawner.Start(arena, plan, hasObjective);
    RLBoonEffects.OnFightStart(this.Fx(player));
    this.RefreshHud();
    if hasObjective {
      RLNotify(player.GetGame(), RLObjectives.Name(door.objective) + " - " + RLObjectives.Description(door.objective), 6.0);
    } else {
      RLNotify(player.GetGame(), this.m_run.FloorLabel() + " - " + plan.factionName, 4.0);
    }
  }

  // What the fight is, for the travel screen: "vs Maelstrom", "BOUNTY".
  private func FightLabel() -> String {
    let door = this.m_run.door;
    if IsDefined(door) && Equals(door.category, RLRewardCategory.Bounty) {
      return "CYBERPSYCHO BOUNTY";
    }
    let label = (IsDefined(door) && door.hot ? "HOT - vs " : "vs ") + RLEncounters.FactionName(this.m_faction.faction);
    if IsDefined(door) && NotEquals(door.objective, RLObjectiveKind.None) {
      label += " - " + RLObjectives.Name(door.objective);
    }
    return label;
  }

  private func StopObjective() {
    if IsDefined(this.m_objective) {
      this.m_objective.Stop(this.GetGameInstance());
      this.m_objective = null;
    }
  }

  // --- Encounter events (from RLWaveSpawner) -----------------------------------------------

  public func OnWaveStarted(wave: Int32, waves: Int32, count: Int32) {
    this.m_wave = wave;
    this.m_waveCount = waves;
    this.m_alive = this.m_spawner.GetAliveCount();
    let bossWave = wave == waves && IsDefined(this.m_run) && this.m_run.IsBossFloor();
    this.m_music.OnWaveStarted(wave, waves, bossWave);
    if !IsDefined(this.m_objective) {
      RLNotify(this.GetGameInstance(), bossWave ? "BOSS WAVE" : s"WAVE \(wave)/\(waves)", 3.0);
    }
    this.RefreshHud();
  }

  // Objective fights: a new wave is on its way; top up like a cleared wave.
  public func OnHoldWave() {
    if !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    RLLoot.RefillAfterWave(GetPlayer(this.GetGameInstance()));
    RLNotify(this.GetGameInstance(), "MORE INCOMING", 2.5);
  }

  // Once a second during a fight (from the spawner's tick).
  public func OnFightTick() {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(this.m_run) || !IsDefined(player) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    RLBoonEffects.OnTick(this.Fx(player));
    RLOverdrive.OnTick(this.m_run, this.m_combat, player);
    if IsDefined(this.m_objective) && !this.m_objective.IsDone() {
      if this.m_objective.Tick(player) {
        let bonus = RLObjectives.BonusEddies(this.m_run);
        RLGear.GiveEddies(player, bonus);
        RLNotify(player.GetGame(), s"OBJECTIVE COMPLETE - +\(bonus) eddies. Finish them.", 5.0);
        RLLog("Objective complete: " + RLObjectives.Name(this.m_objective.Kind()) + ".");
        this.m_spawner.ReleaseHold();
      }
      this.RefreshHud();
    }
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
    if newValue < oldValue && IsDefined(this.m_run) && Equals(this.m_state, RLState.InEncounter) {
      RLOverdrive.OnDamageTaken(this.m_run, this.GetGameInstance(), oldValue - newValue);
      let player = GetPlayer(this.GetGameInstance());
      if this.IsFighting() && IsDefined(player) {
        RLBoonEffects.OnHealthDropped(this.Fx(player), oldValue, newValue);
      }
    }
  }

  // Damage V takes: the run's curve, pacing pressure and assist mode.
  public func GetIncomingDamageScale() -> Float {
    if !IsDefined(this.m_run) {
      return 1.0;
    }
    let scale = RLDifficulty.IncomingDamageScale(this.m_run) * this.m_pacing.DamageScale();
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
    if !TDBID.IsValid(offer.record) {
      return;
    }
    switch offer.kind {
      case RLOfferKind.Trade:
      case RLOfferKind.Iconic:
      case RLOfferKind.Evolve:
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
      case RLOfferKind.OperatingSystem:
        this.ExpectGrant(offer.record);
        break;
    }
  }

  public func ConsumeExpectedGrant(record: TweakDBID) -> Bool {
    return ArrayRemove(this.m_expectedGrants, record);
  }

  public func OnEnemyCountChanged(alive: Int32) {
    this.m_alive = alive;
    this.RefreshHud();
  }

  // --- Enemies (from RLWaveSpawner and the death hook) ----------------------------------

  public func OnEnemySpawned(enemy: ref<RLTrackedEnemy>) {
    if !IsDefined(this.m_run) {
      return;
    }
    if enemy.isElite || enemy.isBoss {
      enemy.affixes = RLAffixes.Roll(this.m_run, enemy.isBoss, enemy.isLieutenant);
    }
    this.m_combat.RegisterEnemy(enemy.id, enemy.isBoss, enemy.isElite, enemy.affixes);
  }

  // First sighting: bosses and elites with affixes are announced.
  public func OnEnemySighted(enemy: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>) {
    let game = this.GetGameInstance();
    let affixes = RLAffixes.Names(enemy.affixes);
    if enemy.isBoss {
      let name = puppet.GetDisplayName();
      enemy.name = StrLen(name) > 0 ? name : "BOSS";
      RLNotify(game, StrLen(affixes) > 0 ? enemy.name + " - " + affixes : enemy.name, 4.0);
    } else if enemy.isLieutenant {
      let lieutenant = puppet.GetDisplayName();
      RLNotify(game, "LIEUTENANT - " + (StrLen(lieutenant) > 0 ? lieutenant + " - " : "") + affixes, 4.0);
    } else if StrLen(affixes) > 0 {
      RLNotify(game, "ELITE - " + affixes, 3.5);
    }
    let player = GetPlayer(game);
    if this.IsFighting() && IsDefined(player) {
      RLBoonEffects.OnEnemySighted(this.Fx(player), puppet, enemy.isBoss || enemy.isElite || enemy.isLieutenant, this.m_wave);
    }
  }

  public func OnBossHealth(enemy: ref<RLTrackedEnemy>, health: Float) {
    if !EntityID.IsDefined(this.m_bossFocus) {
      this.m_bossFocus = enemy.id;
    }
    if this.m_bossFocus == enemy.id {
      this.m_hud.SetBoss(enemy.name, health);
    }
  }

  // An enemy left the fight without dying (despawned, stray, never spawned).
  public func OnEnemyLost(enemy: ref<RLTrackedEnemy>) {
    if this.m_bossFocus == enemy.id {
      this.m_bossFocus = EntityID();
      this.m_hud.ClearBoss();
    }
  }

  public func OnBossPhase(enemy: ref<RLTrackedEnemy>, phase: Int32) {
    RLNotify(this.GetGameInstance(), phase == 1 ? enemy.name + " CALLS FOR BACKUP" : enemy.name + " IS ENRAGED", 3.5);
  }

  // The game's death event for an NPC (Combat/DamageHooks.reds): arena
  // enemies set off kill boons and affixes right away.
  public func OnArenaEnemyDied(npc: ref<ScriptedPuppet>) {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    let id = npc.GetEntityID();
    if this.m_combat.IsArenaEnemy(id) && this.m_combat.MarkDead(id) {
      this.FireDeathEffects(npc);
    }
  }

  private func FireDeathEffects(npc: ref<ScriptedPuppet>) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(npc) {
      return;
    }
    let id = npc.GetEntityID();
    let isBoss = this.m_combat.IsBoss(id);
    let isElite = this.m_combat.IsElite(id);
    let flags = this.m_combat.TakeHitFlags(id);
    let styles = RLHitFlag.Styles(flags);
    RLAffixes.OnDeath(npc, this.m_combat.Affixes(id));
    RLBoonEffects.OnKill(this.Fx(player), npc, flags, isBoss, isElite);
    // Style signatures, Overdrive charge, the gig.
    RLStyles.OnKill(this.m_run, this.m_combat, player, npc, styles, flags);
    RLOverdrive.RampageHeal(this.m_combat, player);
    RLOverdrive.OnKill(this.m_run, this.m_combat, player.GetGame(), isBoss, isElite);
    RLGigs.OnKill(this.m_run, player, styles);
  }

  // An enemy stopped counting as alive: killed (`puppet` is the body), or
  // removed because it couldn't be reached (`removed`; no kill effects).
  public func OnEnemyKilled(enemy: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>, removed: Bool) {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) {
      return;
    }
    let isBoss = enemy.isBoss;
    let isElite = enemy.isElite;
    this.m_run.kills += 1;
    this.m_pacing.OnKill();
    this.RefreshHud();
    if isBoss {
      this.m_run.bossesKilled += 1;
      if this.m_bossFocus == enemy.id {
        this.m_bossFocus = EntityID();
        this.m_hud.ClearBoss();
      }
    }
    // Kill effects that the death hook didn't fire (defeated, not dead).
    if this.m_combat.MarkDead(enemy.id) && !removed {
      this.FireDeathEffects(puppet);
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
  }

  // --- Hits (Combat/DamageHooks.reds) ----------------------------------------------------

  // Multiplier on a hit V lands: boons and the target's affixes.
  public func OnOutgoingHit(target: ref<ScriptedPuppet>, hitEvent: ref<gameHitEvent>) -> Float {
    if !IsDefined(this.m_run) || !Equals(this.m_state, RLState.InEncounter) || !this.m_combat.IsArenaEnemy(target.GetEntityID()) {
      return 1.0;
    }
    let player = GetPlayer(this.GetGameInstance());
    return IsDefined(player) ? RLBoonEffects.OnOutgoingHit(this.Fx(player), target, hitEvent) : 1.0;
  }

  // A quickhack V uploaded finished on `target` (Combat/DamageHooks.reds).
  public func OnQuickhackUploaded(target: ref<ScriptedPuppet>, action: TweakDBID) {
    let player = GetPlayer(this.GetGameInstance());
    if this.IsFighting() && IsDefined(player) && this.m_combat.IsArenaEnemy(target.GetEntityID()) {
      RLBoonEffects.OnUpload(this.Fx(player), target, action, RLHacks.IsSpreadAction(action));
    }
  }

  // The escort drone hit an arena enemy (Combat/DamageHooks.reds).
  public func OnDroneHit(target: ref<ScriptedPuppet>) {
    let player = GetPlayer(this.GetGameInstance());
    if this.IsFighting() && IsDefined(player) && this.m_combat.IsArenaEnemy(target.GetEntityID()) {
      RLDrone.OnHit(this.Fx(player), target);
    }
  }

  public func IsEscortDrone(id: EntityID) -> Bool = EntityID.IsDefined(this.m_combat.droneID) && this.m_combat.droneID == id

  // V dodged, dashed or air-dashed (Player/OSHooks.reds).
  public func OnPlayerDashed() {
    let player = GetPlayer(this.GetGameInstance());
    if this.IsFighting() && IsDefined(player) {
      RLBoonEffects.OnDash(this.Fx(player));
    }
  }

  public func OnPlayerSlid() {
    let player = GetPlayer(this.GetGameInstance());
    if this.IsFighting() && IsDefined(player) {
      RLBoonEffects.OnSlide(this.Fx(player));
    }
  }

  // Multiplier on a hit V takes during a run: the act, pacing, assist mode,
  // effects (0 when one absorbs it) and event trade-offs. A Vampiric
  // attacker heals.
  public func ScaleIncomingHit(player: ref<PlayerPuppet>, hitEvent: ref<gameHitEvent>) -> Float {
    let scale = this.GetIncomingDamageScale();
    if !this.IsFighting() {
      return scale;
    }
    let instigator = hitEvent.attackData.GetInstigator();
    if IsDefined(instigator) && instigator.IsPlayer() && this.m_combat.selfBlastUntil > RLBoonEffects.Now(player.GetGame()) {
      return 0.0;
    }
    let attacker = instigator as ScriptedPuppet;
    let effects = RLBoonEffects.OnIncomingHit(this.Fx(player), hitEvent, attacker);
    if effects <= 0.0 {
      return 0.0;
    }
    scale *= effects * RLOverdrive.IncomingFactor(this.m_combat, player.GetGame()) * (1.0 + this.m_run.damageTakenBonus);
    if IsDefined(attacker) {
      let id = attacker.GetEntityID();
      let role = this.m_combat.IsBoss(id) ? "boss" : (this.m_combat.IsElite(id) ? "elite" : "enemy");
      let affixes = RLAffixes.Names(this.m_combat.Affixes(id));
      this.m_combat.lastAttacker = attacker.GetDisplayName() + " (" + role + (StrLen(affixes) > 0 ? ", " + affixes : "") + ")";
    }
    if IsDefined(attacker) && this.m_combat.IsArenaEnemy(attacker.GetEntityID()) {
      RLAffixes.OnHitPlayer(attacker, this.m_combat.Affixes(attacker.GetEntityID()), this.m_combat, hitEvent);
    }
    return scale;
  }

  public func OnEncounterCleared() {
    if !this.IsFighting() {
      return;
    }
    let game = this.GetGameInstance();
    let service = RogueliteService.Get();
    let player = GetPlayer(game);
    let door = this.m_run.door;
    this.m_run.floorsCleared += 1;
    if !this.m_run.isTest {
      service.UpdateActiveRun(this.m_run.floorsCleared, this.m_run.kills, this.m_run.bossesKilled);
    }

    // Cred is earned per cleared arena (and only then); eddies for the Fixer,
    // half again for a hot door.
    let cred = this.m_run.isTest ? 0 : RLMeta.ArenaCred(this.m_run.act, this.m_run.Threat(), this.m_run.IsBossFloor());
    if !this.m_run.isTest && IsDefined(door) && Equals(door.category, RLRewardCategory.Cred) {
      cred += RLRewards.CredDoorAmount(this.m_run);
    }
    service.AddCred(cred);
    this.m_run.credEarned += cred;
    // A boss down: the fixers owe V (Meta/MetaProgression.reds).
    let favors = this.m_run.IsBossFloor() ? RLMeta.PayFavors(service, this.m_run, this.m_run.IsFinalFloor()) : 0;
    if favors > 0 {
      this.After(n"favorNotice", 4.5);
    }
    let eddies = this.m_run.IsFinalFloor() ? 0 : RLFixer.ArenaEddies(this.m_run);
    if IsDefined(door) && Equals(door.category, RLRewardCategory.Bounty) {
      eddies += (400 + 40 * this.m_run.Depth()) * (RLTerminal.Has(n"BountyBoard", 2) ? 2 : 1);
    }
    if IsDefined(player) && eddies > 0 {
      RLGear.GiveEddies(player, eddies);
    }

    this.m_state = RLState.Cleared;
    RLOverdrive.Stop(game, player);
    RLBoonEffects.EndFight(player, this.m_combat);
    this.SettleLoan(player);
    this.m_music.OnCleared();
    this.m_pacing.EndArena(true, this.m_run);
    this.RecordFloor("clear");
    if this.m_run.IsFinalFloor() {
      RLNotify(game, s"Night City is yours. +\(cred) Cred.", 6.0);
      this.StartCountdown(5, "RUN COMPLETE - HOME IN", n"victoryHome");
      return;
    }

    this.StopObjective();
    this.m_hud.ClearBoss();
    RLNotify(game, s"Area clear. +\(cred) Cred, +\(eddies) eddies.", 4.0);
    this.m_run.advancePending = true;
    RLGigs.OnFloorCleared(this.m_run, game);
    if IsDefined(door) && Equals(door.category, RLRewardCategory.Cred) {
      // The Cred was the reward.
      this.AdvanceFloor();
    } else if IsDefined(door) {
      this.RollOffers(door.category, door.patron, door.hot);
    } else {
      this.RollOffers(RLRewardCategory.Boons, RLPatrons.PickForDoor(this.m_run), false);
    }
    if ArraySize(this.m_offers) == 0 {
      this.AdvanceFloor();
    }
    this.ShowStepHud();
    this.After(n"nextStep", 2.5);
  }

  // Loan Shark counts its fights down; the last one pays it off.
  private func SettleLoan(player: ref<PlayerPuppet>) {
    if this.m_run.loanFights <= 0 || !RLBoons.Has(this.m_run, n"LoanShark") {
      return;
    }
    this.m_run.loanFights -= 1;
    if this.m_run.loanFights == 0 {
      RLBoons.SettleLoan(player, this.m_run);
    }
  }

  // The reward is behind V: on to the next floor (its Fixer stop and doors).
  // Past a boss that's a new act: V's level and both weapon slots step up
  // with the enemies.
  private func AdvanceFloor() {
    if !this.m_run.advancePending {
      return;
    }
    this.m_run.advancePending = false;
    if this.m_run.Advance() {
      let player = GetPlayer(this.GetGameInstance());
      if IsDefined(player) {
        RLDifficulty.SetPlayerLevel(player, this.m_run.act);
        RLWeapons.ActStep(player, this.m_run);
        RLNotify(player.GetGame(), s"ACT \(this.m_run.act). Your guns step up. So does everyone else.", 6.0);
        RLLog(s"Act \(this.m_run.act): main weapon \(RLQuality.DisplayName(this.m_run.mainStep)), sidearm \(RLQuality.DisplayName(this.m_run.sidearmStep)).");
      }
    }
    this.m_run.fixerPending = this.m_run.IsBossFloor();
    ArrayClear(this.m_doors);
  }

  // --- Rewards -----------------------------------------------------------------------------------

  // A reward screen. The Director learns from the floor's first deal only: a
  // reroll is the same screen again, not another flat one.
  private func RollOffers(category: RLRewardCategory, patron: CName, hot: Bool, opt reroll: Bool) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.m_run) {
      return;
    }
    this.m_offerCategory = category;
    this.m_offerPatron = patron;
    this.m_offerHot = hot;
    this.m_run.screenRerollUsed = false;
    // Open Line: the run's first patron screen deals a card more.
    if !reroll {
      this.m_offerBonus = 0;
      if Equals(category, RLRewardCategory.Boons) && !this.m_run.firstPatronDealt {
        this.m_run.firstPatronDealt = true;
        if RLTerminal.Has(n"PatronsEar", 1) {
          this.m_offerBonus = 1;
        }
      }
    }
    let count = RLRewards.CardCount(this.m_run, hot) + this.m_offerBonus;
    this.m_offers = RLRewards.RollForCategory(player, RogueliteService.Get().GetPools(), this.m_run, category, patron, hot, count);
    RLRewards.MarkSeen(this.m_run, this.m_offers);
    if !reroll {
      RLRewardDirector.AfterRoll(this.m_run, this.m_offers, null);
    }
    RLTelemetry.Record(this.m_run, "OFFER", RLTelemetry.IntField("depth", this.m_run.Depth())
      + RLTelemetry.Field("screen", RLRewards.CategoryName(category)) + RLTelemetry.Field("patron", NameToString(patron))
      + RLTelemetry.Field("cards", RLTelemetry.OffersText(this.m_offers)));
  }

  // --- Telemetry ---------------------------------------------------------------------------

  private func RecordFloor(const outcome: String) {
    let door = this.m_run.door;
    let arena = this.m_arenas.GetArena();
    let fields = RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.Field("outcome", outcome);
    if IsDefined(door) {
      fields += RLTelemetry.Field("door", RLRewards.CategoryName(door.category)) + RLTelemetry.Field("patron", NameToString(door.patron))
        + RLTelemetry.Field("obj", RLObjectives.Name(door.objective)) + RLTelemetry.IntField("hot", door.hot ? 1 : 0);
    }
    fields += RLTelemetry.IntField("cover", this.m_run.cover) + RLTelemetry.IntField("dmg", RoundF(this.m_combat.damageDealt)) + RLTelemetry.Field("fx", this.m_combat.Ledger());
    if IsDefined(arena) {
      fields += RLTelemetry.Field("arena", NameToString(arena.id));
    }
    if IsDefined(this.m_faction) {
      fields += RLTelemetry.Field("faction", RLEncounters.FactionName(this.m_faction.faction));
    }
    // Quickhacks: uploads and seconds short of RAM (is RAM what holds a
    // netrunner back?).
    if this.m_combat.uploads > 0 || this.m_combat.ramLowSeconds > 0 {
      fields += RLTelemetry.IntField("uploads", this.m_combat.uploads) + RLTelemetry.IntField("ramlow", this.m_combat.ramLowSeconds);
    }
    RLTelemetry.Record(this.m_run, "FLOOR", fields + RLTelemetry.IntField("waves", this.m_waveCount) + this.m_pacing.Summary());
  }

  private func RecordPick(const screen: String, const what: String, index: Int32) {
    let player = GetPlayer(this.GetGameInstance());
    RLTelemetry.Record(this.m_run, "PICK", RLTelemetry.Field("screen", screen) + RLTelemetry.IntField("depth", this.m_run.Depth())
      + RLTelemetry.IntField("idx", index) + RLTelemetry.Field("took", what));
    RLTelemetry.Record(this.m_run, "BUILD", RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.BuildText(player, this.m_run));
  }

  private func DoorsText() -> String {
    let text = "";
    for door in this.m_doors {
      let objective = NotEquals(door.objective, RLObjectiveKind.None) ? "+" + RLObjectives.Name(door.objective) : "";
      text += (StrLen(text) > 0 ? "," : "") + RLTelemetry.Clean(RLRewards.DoorTitle(door) + objective + (door.hot ? ":hot" : ""));
    }
    return text;
  }

  // The reward screen's title: the patron for its effects, else the reward
  // type.
  private func OfferTitle() -> String {
    if IsNameValid(this.m_offerPatron) && ArraySize(this.m_offers) > 0 && Equals(this.m_offers[0].kind, RLOfferKind.Boon) {
      return RLPatrons.Name(this.m_offerPatron);
    }
    return RLRewards.CategoryName(this.m_offerCategory);
  }

  // A patron's tagline over its effects; a hot door's take.
  private func OfferTagline() -> String {
    if this.m_offerHot {
      return "HOT - DOUBLE THE TAKE";
    }
    if ArraySize(this.m_offers) > 0 && Equals(this.m_offers[0].kind, RLOfferKind.Boon) {
      let patron = RLPatrons.Get(this.m_offerPatron);
      if IsDefined(patron) {
        return patron.tagline;
      }
    }
    return "";
  }

  // --- Events ------------------------------------------------------------------------------

  private func OpenEvent(door: ref<RLDoor>) {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    this.m_run.door = door;
    ArrayClear(this.m_doors);
    this.m_event = RLEvents.Build(door.event, player, RogueliteService.Get().GetPools(), this.m_run);
    RLLog("Event: " + this.m_event.title + ".");
    this.ShowStepHud();
    this.After(n"nextStep", 0.3);
  }

  public func GetEventChoiceAffordable(choice: ref<RLEventChoice>) -> Bool {
    return !choice.disabled && (choice.price <= 0 || this.GetEddies() >= choice.price);
  }

  // Called from the event screen. The event counts as a floor.
  public func OnEventChoice(index: Int32) {
    if !this.IsBetweenFights() || !IsDefined(this.m_event) || index < 0 || index >= ArraySize(this.m_event.choices) {
      return;
    }
    let choice = this.m_event.choices[index];
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) || !this.GetEventChoiceAffordable(choice) {
      return;
    }
    if IsDefined(choice.offer) {
      this.ExpectOfferGrant(choice.offer);
    }
    let result = RLEvents.Resolve(choice, player, RogueliteService.Get().GetPools(), this.m_run);
    this.RecordPick("event " + NameToString(this.m_event.id), NameToString(choice.id), index);
    RLLog(s"Event choice: \(choice.title) - \(result)");
    this.m_event = null;
    this.m_run.floorsCleared += 1;
    if !this.m_run.isTest {
      RogueliteService.Get().UpdateActiveRun(this.m_run.floorsCleared, this.m_run.kills, this.m_run.bossesKilled);
    }
    this.m_run.advancePending = true;
    RLStyles.Refresh(player, this.m_run, true);
    this.AdvanceFloor();
    if StrLen(result) > 0 {
      RLNotify(this.GetGameInstance(), result, 5.0);
    }
    this.ShowStepHud();
    this.After(n"nextStep", 0.8);
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
    let category = this.m_offerCategory;
    this.ExpectOfferGrant(offer);
    RLRewards.Grant(player, this.m_run, offer);
    this.RecordPick(RLRewards.ScreenName(category), RLTelemetry.OfferText(offer), index);
    ArrayClear(this.m_offers);
    // Gear lands in the inventory a moment later: recount styles then too.
    RLStyles.Refresh(player, this.m_run, true);
    this.After(n"styles", 1.0);
    if Equals(category, RLRewardCategory.Gig) {
      RLNotify(game, "Gig taken: " + offer.description, 6.0);
      this.AfterGig();
    } else {
      this.AdvanceFloor();
      RLNotify(game, s"\(offer.title) acquired.", 4.0);
    }
    this.ShowStepHud();
    this.After(n"nextStep", 0.6);
  }

  // --- Saying no -------------------------------------------------------------------------

  // A door's reward screen can be turned down for eddies (Slay the Spire's skip).
  public func CanSkipReward() -> Bool {
    return IsDefined(this.m_run) && ArraySize(this.m_offers) > 0 && RLRewards.IsDoorReward(this.m_offerCategory) && this.m_run.advancePending;
  }

  public func GetSkipEddies() -> Int32 = IsDefined(this.m_run) ? RLRewards.SkipEddies(this.m_run) : 0

  public func OnRewardSkip() {
    let player = GetPlayer(this.GetGameInstance());
    if !this.IsBetweenFights() || !this.CanSkipReward() || !IsDefined(player) {
      return;
    }
    let eddies = RLRewards.SkipEddies(this.m_run);
    RLGear.GiveEddies(player, eddies);
    this.RecordPick(RLRewards.ScreenName(this.m_offerCategory), "skip", -1);
    ArrayClear(this.m_offers);
    this.AdvanceFloor();
    RLNotify(this.GetGameInstance(), s"Skipped. +\(eddies) eddies.", 4.0);
    this.ShowStepHud();
    this.After(n"nextStep", 0.6);
  }

  public func GetBanishes() -> Int32 = IsDefined(this.m_run) ? this.m_run.banishes : 0

  // A screen ran out of cards without a pick: move on as a pick would have.
  private func AfterScreenEmptied() {
    if Equals(this.m_offerCategory, RLRewardCategory.Gig) {
      this.AfterGig();
    } else {
      this.AdvanceFloor();
    }
  }

  // Removes a card from the run for good and replaces it on this screen.
  public func OnRewardBanish(index: Int32) {
    let player = GetPlayer(this.GetGameInstance());
    if !this.IsBetweenFights() || !IsDefined(player) || index < 0 || index >= ArraySize(this.m_offers) || this.m_run.banishes <= 0 {
      return;
    }
    let offer = this.m_offers[index];
    if !RLRewards.CanBanish(offer) {
      return;
    }
    this.m_run.banishes -= 1;
    ArrayPush(this.m_run.banished, RLRewards.OfferKey(offer));
    this.RecordPick(RLRewards.ScreenName(this.m_offerCategory), "banish " + RLTelemetry.OfferText(offer), index);
    RLLog("Banished: " + RLRewards.OfferKey(offer) + ".");
    let replacement: ref<RLOffer>;
    let tries = 0;
    while !IsDefined(replacement) && tries < 4 {
      // Blacklist: the replacement is a standout.
      let standout = this.m_offerHot || RLTerminal.Has(n"BurnNotice", 2);
      let fresh = RLRewards.RollForCategory(player, RogueliteService.Get().GetPools(), this.m_run, this.m_offerCategory, this.m_offerPatron, standout, this.m_run.offerCount);
      for candidate in fresh {
        if !IsDefined(replacement) && !RLRewards.ContainsCard(this.m_offers, candidate) {
          replacement = candidate;
        }
      }
      tries += 1;
    }
    if IsDefined(replacement) {
      this.m_offers[index] = replacement;
      let shown: array<ref<RLOffer>>;
      ArrayPush(shown, replacement);
      RLRewards.MarkSeen(this.m_run, shown);
    } else {
      ArrayErase(this.m_offers, index);
    }
    if ArraySize(this.m_offers) == 0 {
      this.AfterScreenEmptied();
    }
    RLNotify(this.GetGameInstance(), offer.title + " banished for this run.", 3.0);
    this.After(n"nextStep", 0.3);
  }

  // --- Rerolls -----------------------------------------------------------------------------------
  // Free charges (one or more an act, Rerolls unlocks), plus one on every
  // reward screen with the Afterlife's favour.

  public func GetRerollCharges() -> Int32 = IsDefined(this.m_run) ? this.m_run.rerolls : 0

  // The Afterlife's free reroll is there on this reward screen.
  public func HasFavourReroll() -> Bool {
    return IsDefined(this.m_run) && ArraySize(this.m_offers) > 0 && !this.m_run.screenRerollUsed && RLBoons.Has(this.m_run, n"Favour_Afterlife");
  }

  public func GetEddies() -> Int32 {
    let player = GetPlayer(this.GetGameInstance());
    return IsDefined(player) ? RLFixer.Balance(player) : 0;
  }

  public func CanReroll() -> Bool {
    return IsDefined(this.m_run) && (this.m_run.rerolls > 0 || this.HasFavourReroll());
  }

  private func PayForReroll() -> Bool {
    if !this.IsBetweenFights() {
      return false;
    }
    if this.HasFavourReroll() {
      this.m_run.screenRerollUsed = true;
      return true;
    }
    if this.m_run.rerolls > 0 {
      this.m_run.rerolls -= 1;
      return true;
    }
    return false;
  }

  public func OnRewardReroll() {
    if ArraySize(this.m_offers) == 0 || !this.PayForReroll() {
      return;
    }
    let favourUsed = this.m_run.screenRerollUsed;
    RLTelemetry.Record(this.m_run, "PICK", RLTelemetry.Field("screen", "reward") + RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.Field("took", "reroll"));
    this.RollOffers(this.m_offerCategory, this.m_offerPatron, this.m_offerHot, true);
    this.m_run.screenRerollUsed = favourUsed;
    this.After(n"nextStep", 0.3);
  }

  // Inner Circle: the first door reroll on each floor costs nothing.
  public func HasFreeDoorReroll() -> Bool {
    return IsDefined(this.m_run) && RLTerminal.Has(n"FixerContacts", 2) && this.m_run.freeDoorRerollDepth != this.m_run.Depth();
  }

  public func OnDoorReroll() {
    let free = this.HasFreeDoorReroll();
    if ArraySize(this.m_doors) <= 1 || (!free && this.m_run.rerolls <= 0) || !this.IsBetweenFights() {
      return;
    }
    if free {
      this.m_run.freeDoorRerollDepth = this.m_run.Depth();
    } else {
      this.m_run.rerolls -= 1;
    }
    RLTelemetry.Record(this.m_run, "PICK", RLTelemetry.Field("screen", "doors") + RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.Field("took", "reroll"));
    this.RollDoors();
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
    let bought = RLFixer.Buy(player, this.m_run, item);
    if bought {
      let what = item.sell ? "sell " + item.sellName : (item.contact ? "contact" : RLTelemetry.OfferText(item.offer));
      this.RecordPick("fixer", what, index);
      RLStyles.Refresh(player, this.m_run, true);
    }
    return bought;
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
    if IsDefined(player) && this.m_run.cover > 0 {
      this.SpendCover(player);
      return;
    }
    this.Flatline();
  }

  // Trauma Team: V gets back up on the spot at half health, and the pulse of
  // the pick-up knocks the enemies close by off their feet.
  private func SpendCover(player: ref<PlayerPuppet>) {
    let game = player.GetGame();
    this.m_run.cover -= 1;
    this.m_run.coverSpent += 1;
    let health = RLTerminal.Has(n"TraumaTeam", 1) ? 75.0 : RLConfig.CoverHealth();
    GameInstance.GetStatPoolsSystem(game).RequestSettingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, health, null, true);
    this.m_deathGuard.Rearm();
    let fx = this.Fx(player);
    for enemy in this.EnemiesNear(player.GetWorldPosition(), 8.0) {
      RLKeywords.Knockdown(fx, enemy);
    }
    GameInstance.GetAudioSystem(game).PlayShockwave(n"explosion", player.GetWorldPosition());
    this.StartGlitch(player, 1.2);
    RLNotify(game, this.m_run.cover > 0 ? s"TRAUMA TEAM. COVER SPENT - \(this.m_run.cover) LEFT." : "TRAUMA TEAM. COVER SPENT - NONE LEFT.", 4.0);
    RLTelemetry.Record(this.m_run, "COVER", RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.IntField("wave", this.m_wave)
      + RLTelemetry.IntField("left", this.m_run.cover) + RLTelemetry.Field("by", this.m_combat.lastAttacker));
    RLLog(s"Trauma Team cover spent (\(this.m_run.cover) left).");
    this.RefreshHud();
  }

  // V dies for real: the game's own death (camera drops, the world fades), with
  // its death menu held back and a resurrection set up (Player/Death.reds).
  // While V is down the screen fades to black, and V comes to at home.
  private func Flatline() {
    let player = GetPlayer(this.GetGameInstance());
    this.m_state = RLState.Flatlined;
    RLOverdrive.Stop(this.GetGameInstance(), player);
    RLBoonEffects.EndFight(player, this.m_combat);
    this.CancelTimer();
    // No new waves while V is down (the bodies stay until the fade).
    this.m_spawner.Halt();
    this.m_music.Stop();
    this.m_pacing.EndArena(false, this.m_run);
    this.RecordFloor("lost");
    RLTelemetry.Record(this.m_run, "DEATH", RLTelemetry.IntField("depth", this.m_run.Depth()) + RLTelemetry.IntField("wave", this.m_wave)
      + RLTelemetry.Field("by", this.m_combat.lastAttacker));
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
    RLTelemetry.Record(run, "END", RLTelemetry.Field("result", victory ? "won" : (abandoned ? "abandoned" : "lost"))
      + RLTelemetry.IntField("floors", run.floorsCleared) + RLTelemetry.IntField("kills", run.kills)
      + RLTelemetry.IntField("mins", RoundF((RLBoonEffects.Now(game) - run.startTime) / 60.0))
      + RLTelemetry.IntField("cred", run.credEarned) + RLTelemetry.IntField("favors", run.favorsEarned));
    this.m_state = RLState.Ending;
    RLOverdrive.Stop(game, player);
    RLBoonEffects.EndFight(player, this.m_combat);
    this.CancelTimer();
    this.m_music.Stop();
    this.m_pacing.Stop();
    ArrayClear(this.m_offers);
    ArrayClear(this.m_doors);
    ArrayClear(this.m_fixerStock);

    let service = RogueliteService.Get();
    // Cred was banked arena by arena; a completed run adds a bonus.
    let payout = victory && !run.isTest ? RLMeta.VictoryCred() : 0;
    service.AddCred(payout);
    if !run.isTest {
      service.RecordRunEnd(run.floorsCleared, run.kills, victory);
    }
    service.ClearRunToken();

    this.m_deathGuard.Disarm();
    RLBoons.RemoveAll(player, run);
    RLArmMods.RemoveAll(player, run);
    RLEvents.RemoveRunMods(player, run);
    this.StopObjective();
    this.m_event = null;
    this.m_hud.ClearBoss();
    FastTravelSystem.RemoveFastTravelLock(n"NightCityRoguelite", game);
    this.m_hud.Hide();

    this.m_endTitle = victory ? "NIGHT CITY IS YOURS" : (abandoned ? "RUN ABANDONED" : "FLATLINED");
    this.m_endSubtitle = this.RunSummary() + s"   +\(run.credEarned + payout) CRED" + (run.favorsEarned > 0 ? s"   +\(run.favorsEarned) FAVORS" : "");
    this.m_lastSummary = (victory ? "RUN COMPLETE" : "RUN OVER")
      + s" - floors cleared \(run.floorsCleared), kills \(run.kills). Cred earned \(run.credEarned + payout) (total \(service.GetCred())), favors \(run.favorsEarned) (total \(service.GetFavors())).";
    RLLog(this.m_lastSummary);
    this.m_run = null;

    if alreadyBlack {
      this.m_transition.SetText(this.m_endTitle, this.m_endSubtitle);
      this.ArriveHome();
      return;
    }
    if IsDefined(player) {
      this.StartGlitch(player, RLConfig.GlitchLead() + RLConfig.FadeSeconds() + 0.3);
    }
    this.After(n"homeFade", RLConfig.GlitchLead());
  }

  private func ArriveHome() {
    let player = GetPlayer(this.GetGameInstance());
    this.m_music.StopEverything(player);
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
    this.m_inArmory = false;
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
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      this.StartGlitch(player, 1.8);
    }
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

  public func RefreshHud() {
    if !this.IsFighting() {
      return;
    }
    this.m_hud.SetBuild(this.m_run, this.m_combat);
    let status = IsDefined(this.m_objective)
      ? s"\(this.m_objective.Status())   HOSTILES \(this.m_alive)   KILLS \(this.m_run.kills)"
      : s"WAVE \(this.m_wave)/\(this.m_waveCount)   HOSTILES \(this.m_alive)   KILLS \(this.m_run.kills)";
    let overdrive = RLOverdrive.Status(this.m_run);
    if StrLen(overdrive) > 0 {
      status += "   " + overdrive;
    }
    let gig = RLGigs.Status(this.m_run);
    if StrLen(gig) > 0 {
      status += "   " + gig;
    }
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

// -----------------------------------------------------------------------------
// Night City Roguelite - meta service
// -----------------------------------------------------------------------------
// A Codeware ScriptableService: lives for the whole game process, independent
// of save files. Fields marked `persistent` are stored by Codeware outside the
// save system, so meta progression survives reloads and new characters.
//
// It also owns the global callbacks (session lifecycle, hotkeys) and forwards
// them to the per-session RogueliteSystem.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RogueliteService extends ScriptableService {
  // Meta progression
  private persistent let m_cred: Int32;
  // Favors fixers owe V (bosses, firsts): what kits cost (Meta/MetaProgression).
  private persistent let m_favors: Int32;
  private persistent let m_unlocks: array<CName>;
  private persistent let m_selectedKit: CName;
  private let m_testFloor: Int32;
  // Assist mode (Hades' God Mode): less damage taken, a little more with every
  // run lost while it is on.
  private persistent let m_assistOn: Bool;
  private persistent let m_assistLevel: Int32;
  // The how-it-works guide has been shown (UI/GuidePopup.reds).
  private persistent let m_guideSeen: Bool;
  // Effects taken in any run: a card for one that isn't here says NEW.
  private persistent let m_takenBoons: array<CName>;

  // Lifetime stats
  private persistent let m_runsStarted: Int32;
  private persistent let m_deaths: Int32;
  private persistent let m_victories: Int32;
  private persistent let m_bestDepth: Int32;
  private persistent let m_totalKills: Int32;

  // Non-zero while a run is in progress (used to detect abandoned runs),
  // plus the progress of that run so an abandoned run can still pay out.
  private persistent let m_activeRunToken: Int32;
  private persistent let m_activeRunFloors: Int32;
  private persistent let m_activeRunKills: Int32;
  private persistent let m_activeRunBosses: Int32;

  // The mod's own log, kept in Codeware's persistent store so it can be read
  // after a session (red4ext/plugins/Codeware/Persistent). Newest last.
  private persistent let m_log: array<CName>;
  // Numbered lines: the save format stores identical names once, so repeated
  // lines would otherwise collapse into one.
  private persistent let m_logSeq: Int32;
  // Run telemetry records (Core/Telemetry.reds), oldest first.
  private persistent let m_telemetry: array<CName>;
  private persistent let m_telemetrySeq: Int32;

  // Content pools and the perk card catalog, built once per game process.
  private let m_pools: ref<RLTweakPools>;
  private let m_perkCatalog: array<ref<RLPerkDef>>;
  private let m_boonCatalog: array<ref<RLBoonDef>>;
  private let m_perkCatalogBuilt: Bool;

  // Main menu -> new game hand-off (not persistent on purpose).
  private let m_pendingStart: Bool;
  private let m_pendingScreenSkipped: Bool;

  // --- Access -------------------------------------------------------------------

  public func AppendLog(const line: String) {
    // CName because Codeware can't persist strings; it stores the text as-is.
    this.m_logSeq += 1;
    let pieces = RogueliteService.Pieces(line);
    let i = 0;
    while i < ArraySize(pieces) {
      ArrayPush(this.m_log, StringToName(s"[\(this.m_logSeq)]" + (i > 0 ? "+ " : " ") + pieces[i]));
      i += 1;
    }
    // Enough to keep a bug mark's snapshot through the rest of the run.
    while ArraySize(this.m_log) > 2000 {
      ArrayErase(this.m_log, 0);
    }
  }

  // About 50 runs' worth of telemetry. Numbered for the same reason as the log
  // (two rerolls on one floor are identical records); the number follows the
  // version tag: T1|<seq>|<run id>|...
  public func AppendTelemetry(const version: String, const record: String) {
    this.m_telemetrySeq += 1;
    let pieces = RogueliteService.Pieces(record);
    let i = 0;
    while i < ArraySize(pieces) {
      ArrayPush(this.m_telemetry, StringToName(version + (i > 0 ? "+|" : "|") + IntToString(this.m_telemetrySeq) + "|" + pieces[i]));
      i += 1;
    }
    while ArraySize(this.m_telemetry) > 4000 {
      ArrayErase(this.m_telemetry, 0);
    }
  }

  // A saved name holds 255 bytes, so a longer line is saved in pieces: every
  // piece after the first carries the same number with a "+" (T1+|<seq>|,
  // [<seq>]+), and tools/runreport.py joins them.
  private static func Pieces(const text: String) -> array<String> {
    let pieces: array<String>;
    let rest = text;
    while StrLen(rest) > 200 {
      ArrayPush(pieces, StrLeft(rest, 200));
      rest = StrRight(rest, StrLen(rest) - 200);
    }
    ArrayPush(pieces, rest);
    return pieces;
  }

  public static func Get() -> ref<RogueliteService> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NightCityRoguelite.RogueliteService") as RogueliteService;
  }

  // --- Lifecycle ----------------------------------------------------------------

  private cb func OnLoad() {
    if !Codeware.Require("1.21.0") {
      RLLog("WARNING: Codeware 1.21.0 or newer is required on game version 2.5.");
    }
    if !TweakXL.Require("1.12.0") {
      RLLog("WARNING: TweakXL 1.12.0 or newer is required on game version 2.5.");
    }
    let callbacks = GameInstance.GetCallbackSystem();
    callbacks.RegisterCallback(n"Session/Start", this, n"OnSessionStart");
    callbacks.RegisterCallback(n"Session/Ready", this, n"OnSessionReady");
    callbacks.RegisterCallback(n"Session/BeforeEnd", this, n"OnSessionBeforeEnd");
    // Bystanders streaming into an arena are moved out (Combat/ArenaCleaner.reds).
    callbacks.RegisterCallback(n"Entity/AfterAttach", this, n"OnNPCAttached")
      .AddTarget(EntityTarget.Type(n"NPCPuppet"));
    // Doors V couldn't open are opened, dropped weapons emptied.
    callbacks.RegisterCallback(n"Entity/AfterAttach", this, n"OnArenaPropAttached")
      .AddTarget(EntityTarget.Type(n"Door"))
      .AddTarget(EntityTarget.Type(n"gameItemDropObject"));
    // 2.5's native InputTarget.Key has no press/release filter; OnKeyInput
    // filters for release itself so each key press fires once.
    callbacks.RegisterCallback(n"Input/Key", this, n"OnKeyInput")
      .AddTarget(InputTarget.Key(RLConfig.TerminalKey()))
      .AddTarget(InputTarget.Key(RLConfig.BugKey()));

    if !IsNameValid(this.m_selectedKit) {
      this.m_selectedKit = n"Solo";
    }
    RLLog(s"Service loaded. Cred \(this.m_cred), runs \(this.m_runsStarted).");
  }

  // Before any quest runs: flag a roguelite start for the quest patch in
  // NightCityRoguelite.archive, which then skips the Phantom Liberty opening
  // (teleport, book scene, Songbird's call) for this character only.
  private cb func OnSessionStart(event: ref<GameSessionEvent>) {
    if event.IsPreGame() || event.IsRestored() || !this.m_pendingStart {
      return;
    }
    GameInstance.GetQuestsSystem(GetGameInstance()).SetFact(n"nc_roguelite_start", 1);
    RLLog("Roguelite start flagged for the quest patch.");
  }

  private cb func OnNPCAttached(event: ref<EntityLifecycleEvent>) {
    let npc = event.GetEntity() as NPCPuppet;
    if !IsDefined(npc) {
      return;
    }
    let system = RogueliteSystem.Get(npc.GetGame());
    if IsDefined(system) && system.IsInArenaFight() {
      system.GetArenaCleaner().OnNPCAttached(npc);
    }
  }

  private cb func OnArenaPropAttached(event: ref<EntityLifecycleEvent>) {
    let entity = event.GetEntity() as GameObject;
    if !IsDefined(entity) {
      return;
    }
    let system = RogueliteSystem.Get(entity.GetGame());
    if !IsDefined(system) {
      return;
    }
    let cleaner = system.GetArenaCleaner();
    let door = entity as Door;
    if IsDefined(door) {
      cleaner.OnDoorAttached(door);
    } else {
      cleaner.OnDropAttached(entity as gameItemDropObject);
    }
  }

  private cb func OnSessionReady(event: ref<GameSessionEvent>) {
    if event.IsPreGame() {
      // Back in the main menu: a pending start that never reached a new game is stale.
      return;
    }
    RLLog(s"===== Session ready (loaded save: \(event.IsRestored())) =====");
    let system = RogueliteSystem.Get(GetGameInstance());
    if IsDefined(system) {
      system.OnSessionReady(event.IsRestored());
    }
  }

  private cb func OnSessionBeforeEnd(event: ref<GameSessionEvent>) {
    if event.IsPreGame() {
      return;
    }
    let system = RogueliteSystem.Get(GetGameInstance());
    if IsDefined(system) {
      system.OnSessionEnding();
    }
  }

  private cb func OnKeyInput(event: ref<KeyInputEvent>) {
    if NotEquals(event.GetAction(), EInputAction.IACT_Release) {
      return;
    }
    let game = GetGameInstance();
    if !GameInstance.IsValid(game) || GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return;
    }
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) {
      return;
    }
    if Equals(event.GetKey(), RLConfig.TerminalKey()) {
      system.OnTerminalKey();
    } else if Equals(event.GetKey(), RLConfig.BugKey()) {
      system.MarkBug();
    }
  }

  // --- Pending start (main menu) -----------------------------------------------

  public func RequestPendingStart() {
    this.m_pendingStart = true;
    this.m_pendingScreenSkipped = false;
    RLLog("Roguelite start requested from the main menu.");
  }

  public func ClearPendingStart() {
    if this.m_pendingStart {
      RLLog("Pending roguelite start cleared.");
    }
    this.m_pendingStart = false;
    this.m_pendingScreenSkipped = false;
  }

  public func HasPendingStart() -> Bool = this.m_pendingStart

  // The expansion-choice screen is skipped once; if the player navigates back
  // to it, the roguelite start is cancelled and the menu behaves normally.
  public func TryConsumeScreenSkip() -> Bool {
    if !this.m_pendingStart {
      return false;
    }
    if this.m_pendingScreenSkipped {
      this.ClearPendingStart();
      return false;
    }
    this.m_pendingScreenSkipped = true;
    return true;
  }

  public func ConsumePendingStart() -> Bool {
    let pending = this.m_pendingStart;
    this.m_pendingStart = false;
    this.m_pendingScreenSkipped = false;
    return pending;
  }

  // --- Meta currency and unlocks -------------------------------------------------

  public func GetCred() -> Int32 = this.m_cred

  public func AddCred(amount: Int32) {
    this.m_cred = Max(0, this.m_cred + amount);
  }

  public func TrySpendCred(amount: Int32) -> Bool {
    if this.m_cred < amount {
      return false;
    }
    this.m_cred -= amount;
    return true;
  }

  public func GetFavors() -> Int32 = this.m_favors

  public func AddFavors(amount: Int32) {
    this.m_favors = Max(0, this.m_favors + amount);
  }

  public func TrySpendFavors(amount: Int32) -> Bool {
    if this.m_favors < amount {
      return false;
    }
    this.m_favors -= amount;
    return true;
  }

  public func HasUnlock(id: CName) -> Bool = ArrayContains(this.m_unlocks, id)

  public func RemoveUnlock(id: CName) {
    ArrayRemove(this.m_unlocks, id);
  }

  public func AddUnlock(id: CName) {
    if !ArrayContains(this.m_unlocks, id) {
      ArrayPush(this.m_unlocks, id);
    }
  }

  // Takes an unlock back (one that no longer exists) and refunds it.
  public func RefundUnlock(id: CName, cost: Int32) -> Bool {
    if !ArrayRemove(this.m_unlocks, id) {
      return false;
    }
    this.m_cred += cost;
    return true;
  }

  public func HasTakenBoon(id: CName) -> Bool = ArrayContains(this.m_takenBoons, id)

  public func GetTakenBoons() -> array<CName> = this.m_takenBoons

  public func MarkBoonTaken(id: CName) {
    if !ArrayContains(this.m_takenBoons, id) {
      ArrayPush(this.m_takenBoons, id);
    }
  }

  // --- Assist mode ------------------------------------------------------------------

  public func IsAssistOn() -> Bool = this.m_assistOn

  public func HasSeenGuide() -> Bool = this.m_guideSeen

  public func MarkGuideSeen() {
    this.m_guideSeen = true;
  }

  public func SetAssist(on: Bool) {
    this.m_assistOn = on;
    RLLog(s"Assist mode \(on ? "on" : "off") (\(RoundF(this.AssistReduction() * 100.0))% less damage).");
  }

  // 20% less damage, +2% for every run lost with assist on, up to 80%.
  public func AssistReduction() -> Float {
    return MinF(0.8, 0.2 + 0.02 * Cast<Float>(this.m_assistLevel));
  }

  // Solo until another kit is picked (and if the picked one isn't owned).
  public func GetSelectedKit() -> CName {
    if !IsNameValid(this.m_selectedKit) || !RLMeta.IsKitAvailable(this, this.m_selectedKit) {
      return n"Solo";
    }
    return this.m_selectedKit;
  }

  // Test runs (terminal): the floor they start on. Session only.
  public static func TestFloors() -> array<Int32> = [1, 5, 6, 7, 11, 12, 13, 17, 18]

  public func GetTestFloor() -> Int32 = Max(1, this.m_testFloor)

  public func CycleTestFloor() {
    let floors = RogueliteService.TestFloors();
    let i = 0;
    while i < ArraySize(floors) && floors[i] != this.GetTestFloor() {
      i += 1;
    }
    this.m_testFloor = floors[(i + 1) % ArraySize(floors)];
  }

  public func SetSelectedKit(kit: CName) {
    this.m_selectedKit = kit;
  }

  // --- Run bookkeeping -----------------------------------------------------------

  public func BeginRunToken() -> Int32 {
    let token = RandRange(1, 2000000000);
    this.m_activeRunToken = token;
    this.m_activeRunFloors = 0;
    this.m_activeRunKills = 0;
    this.m_activeRunBosses = 0;
    this.m_runsStarted += 1;
    return token;
  }

  public func UpdateActiveRun(floorsCleared: Int32, kills: Int32, bosses: Int32) {
    this.m_activeRunFloors = floorsCleared;
    this.m_activeRunKills = kills;
    this.m_activeRunBosses = bosses;
  }

  public func GetActiveRunToken() -> Int32 = this.m_activeRunToken

  // Scores a run that was left without ending (quit or crash) as a flatline.
  // Returns the Cred paid out.
  public func SettleAbandonedRun() -> Int32 {
    if this.m_activeRunToken == 0 {
      return 0;
    }
    // Cred is banked per cleared arena, so an abandoned run pays nothing more.
    let payout = 0;
    this.RecordRunEnd(this.m_activeRunFloors, this.m_activeRunKills, false);
    this.ClearRunToken();
    return payout;
  }

  public func ClearRunToken() {
    this.m_activeRunToken = 0;
    this.m_activeRunFloors = 0;
    this.m_activeRunKills = 0;
    this.m_activeRunBosses = 0;
  }

  public func GetPools() -> ref<RLTweakPools> {
    if !IsDefined(this.m_pools) {
      this.m_pools = new RLTweakPools();
    }
    this.m_pools.EnsureBuilt();
    return this.m_pools;
  }

  public func GetPerkCatalog() -> array<ref<RLPerkDef>> {
    if !this.m_perkCatalogBuilt {
      this.m_perkCatalogBuilt = true;
      this.m_perkCatalog = RLPerkCatalogData.Build();
      RLLog(s"Perk cards: \(ArraySize(this.m_perkCatalog)).");
    }
    return this.m_perkCatalog;
  }

  public func GetBoonCatalog() -> array<ref<RLBoonDef>> {
    if ArraySize(this.m_boonCatalog) == 0 {
      this.m_boonCatalog = RLBoons.Build();
      RLLog(s"Effects: \(ArraySize(this.m_boonCatalog)).");
    }
    return this.m_boonCatalog;
  }

  public func RecordRunEnd(depth: Int32, kills: Int32, victory: Bool) {
    if victory {
      this.m_victories += 1;
    } else {
      this.m_deaths += 1;
      if this.m_assistOn {
        this.m_assistLevel += 1;
      }
    }
    this.m_totalKills += kills;
    if depth > this.m_bestDepth {
      this.m_bestDepth = depth;
    }
  }

  public func GetRunsStarted() -> Int32 = this.m_runsStarted
  public func GetDeaths() -> Int32 = this.m_deaths
  public func GetVictories() -> Int32 = this.m_victories
  public func GetBestDepth() -> Int32 = this.m_bestDepth
  public func GetTotalKills() -> Int32 = this.m_totalKills

}

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
  private persistent let m_unlocks: array<CName>;
  private persistent let m_selectedKit: CName;
  private persistent let m_roguelikeMode: Bool;

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
  private persistent let m_activeRunRoguelike: Bool;

  // The mod's own log, kept in Codeware's persistent store so it can be read
  // after a session (red4ext/plugins/Codeware/Persistent). Newest last.
  private persistent let m_log: array<CName>;

  // Content pools, built once per game process.
  private let m_pools: ref<RLTweakPools>;

  // Main menu -> new game hand-off (not persistent on purpose).
  private let m_pendingStart: Bool;
  private let m_pendingScreenSkipped: Bool;

  // --- Access -------------------------------------------------------------------

  public func AppendLog(const line: String) {
    while ArraySize(this.m_log) >= 600 {
      ArrayErase(this.m_log, 0);
    }
    // CName because Codeware can't persist strings; it stores the text as-is.
    ArrayPush(this.m_log, StringToName(line));
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
    callbacks.RegisterCallback(n"Session/Ready", this, n"OnSessionReady");
    callbacks.RegisterCallback(n"Session/BeforeEnd", this, n"OnSessionBeforeEnd");
    // 2.5's native InputTarget.Key has no press/release filter; OnKeyInput
    // filters for release itself so each key press fires once.
    callbacks.RegisterCallback(n"Input/Key", this, n"OnKeyInput")
      .AddTarget(InputTarget.Key(RLConfig.TerminalKey()));

    if !IsNameValid(this.m_selectedKit) {
      this.m_selectedKit = n"Solo";
    }
    RLLog(s"Service loaded. Cred \(this.m_cred), runs \(this.m_runsStarted).");
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

  public func HasUnlock(id: CName) -> Bool = ArrayContains(this.m_unlocks, id)

  public func AddUnlock(id: CName) {
    if !ArrayContains(this.m_unlocks, id) {
      ArrayPush(this.m_unlocks, id);
    }
  }

  public func GetUnlockCount(prefix: String) -> Int32 {
    let count = 0;
    for id in this.m_unlocks {
      if StrBeginsWith(NameToString(id), prefix) {
        count += 1;
      }
    }
    return count;
  }

  public func IsRoguelikeMode() -> Bool = this.m_roguelikeMode

  public func SetRoguelikeMode(value: Bool) {
    this.m_roguelikeMode = value;
  }

  public func GetSelectedKit() -> CName = this.m_selectedKit

  public func SetSelectedKit(kit: CName) {
    this.m_selectedKit = kit;
  }

  // --- Run bookkeeping -----------------------------------------------------------

  public func BeginRunToken(roguelike: Bool) -> Int32 {
    let token = RandRange(1, 2000000000);
    this.m_activeRunToken = token;
    this.m_activeRunFloors = 0;
    this.m_activeRunKills = 0;
    this.m_activeRunBosses = 0;
    this.m_activeRunRoguelike = roguelike;
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
    let payout = RLMeta.Payout(this.m_activeRunFloors, this.m_activeRunKills, this.m_activeRunBosses, false, this.m_activeRunRoguelike);
    this.AddCred(payout);
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

  public func RecordRunEnd(depth: Int32, kills: Int32, victory: Bool) {
    if victory {
      this.m_victories += 1;
    } else {
      this.m_deaths += 1;
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

// -----------------------------------------------------------------------------
// Night City Roguelite - the city survey (developers)
// -----------------------------------------------------------------------------
// The arena scout at the scale of the whole city. Data/SurveyPoints.reds lists
// several hundred spots (every main quest, side quest, gig and Phantom Liberty
// map pin, and Appearance Menu Mod's locations, thinned to one per 70 m and
// floor). V visits each, invulnerable, waits for it to stream in and reads
// its ground the way an arena is read (Combat/ArenaSite.reds):
//
//   cover20/30/40   share of a 20/30/40 m circle V can walk to from the start
//   rise            height range of the floor reached
//   covered         ground points with cover beside them (of `ground`)
//   perches         points above the floor that look down on it
//   roof            something solid overhead at the start
//   story           journal entries the visit woke and calls that came in -
//                   a spot that sets off a gig, a call or a scene is no arena
//
// Each point is one record in the service's survey store (RogueliteService.
// AppendSurvey); tools/survey.py reads them and builds the arena catalogue.
//
// It runs unattended: every BatchSize() points it exits to the main menu, so
// Codeware saves the store, and with RLConfig.AutoSurvey() the main menu
// continues the last save and the survey resumes at the next point. A crash
// loses one batch at most.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLCitySurvey extends RLDelayTarget {
  private let m_system: wref<RogueliteSystem>;
  private let m_points: array<Vector4>;
  private let m_index: Int32;
  private let m_visited: Int32;
  private let m_waited: Int32;
  private let m_settled: Bool;
  private let m_active: Bool;
  private let m_start: Vector4;
  // What the story did while V was at the current point.
  private let m_story: array<String>;
  private let m_journalRegistered: Bool;

  public static func BatchSize() -> Int32 = 100

  public func IsActive() -> Bool = this.m_active

  public static func Total() -> Int32 {
    let points = RLSurveyPoints.All();
    return ArraySize(points);
  }

  public func Start(system: ref<RogueliteSystem>) {
    let player = GetPlayer(GetGameInstance());
    let service = RogueliteService.Get();
    if this.m_active || !IsDefined(player) || service.IsSurveyDone() {
      return;
    }
    this.m_system = system;
    this.m_points = RLSurveyPoints.All();
    this.m_index = service.GetSurveyNext();
    this.m_visited = 0;
    this.m_active = true;
    GameInstance.GetGodModeSystem(player.GetGame()).AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NCRogueliteSurvey");
    let journal = GameInstance.GetJournalManager(player.GetGame());
    if IsDefined(journal) && !this.m_journalRegistered {
      journal.RegisterScriptCallback(this, n"OnJournalStateChanged", gameJournalListenerType.State);
      this.m_journalRegistered = true;
    }
    RLLog(s"City survey: point \(this.m_index + 1) of \(ArraySize(this.m_points)).");
    this.Visit();
  }

  // The story stirred (a call, an entry): noted against the current point.
  public func NoteStory(const what: String) {
    if this.m_active && ArraySize(this.m_story) < 6 {
      ArrayPush(this.m_story, what);
    }
  }

  protected cb func OnJournalStateChanged(entryHash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if !this.m_active || !RLJournalGuard.IsQuiet(className) {
      return false;
    }
    let journal = GameInstance.GetJournalManager(GetGameInstance());
    let entry = IsDefined(journal) ? journal.GetEntry(entryHash) : null;
    if IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
      this.NoteStory(entry.GetId());
    }
    return false;
  }

  private func Visit() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || this.m_index >= ArraySize(this.m_points) {
      this.Finish(true);
      return;
    }
    ArrayClear(this.m_story);
    this.HoldAtPoint(player);
    RLNotify(player.GetGame(), s"SURVEY \(this.m_index + 1)/\(ArraySize(this.m_points))", 2.0);
    this.m_waited = 0;
    this.m_settled = false;
    RLDelay(player.GetGame(), this, n"check", 2.0);
  }

  // Back at the point (a little above it): a point high in a tower streams in
  // around V, not under a V who fell to the street.
  private func HoldAtPoint(player: ref<PlayerPuppet>) {
    let target = this.m_points[this.m_index];
    RLArenaDirector.TeleportToPoint(player, Vector4(target.X, target.Y, target.Z + 1.5, 1.0), 0.0);
  }

  public func OnDelayed(action: CName) {
    if !this.m_active {
      return;
    }
    switch action {
      case n"check":
        this.Check();
        break;
      case n"record":
        this.Record();
        break;
    }
  }

  // Waits (up to 12 s) for ground and navmesh at the point, puts V on it,
  // gives the rest of the circle two seconds to stream in.
  private func Check() {
    let game = GetGameInstance();
    let player = GetPlayer(game);
    let target = this.m_points[this.m_index];
    let found = GameInstance.GetNavigationSystem(game).FindPointInSphereOnlyHumanNavmesh(target, 10.0, NavGenAgentSize.Human, false);
    let ready = Equals(found.status, worldNavigationRequestStatus.OK) && RLArenaDirector.HasFloor(game, found.point);
    if !ready && this.m_waited < 12 {
      this.m_waited += 1;
      if IsDefined(player) {
        this.HoldAtPoint(player);
      }
      RLDelay(game, this, n"check", 1.0);
      return;
    }
    if ready && !this.m_settled {
      this.m_settled = true;
      this.m_start = found.point;
      if IsDefined(player) {
        RLArenaDirector.TeleportToPoint(player, found.point, 0.0);
      }
      RLDelay(game, this, n"check", 2.0);
      return;
    }
    if !ready {
      this.m_start = target;
      this.m_settled = false;
    }
    // A moment more before writing it down: a call or a quest entry the
    // visit wakes up can take a second to arrive.
    RLDelay(game, this, n"record", 1.5);
  }

  private func Record() {
    let game = GetGameInstance();
    let target = this.m_points[this.m_index];
    let fields = RLTelemetry.IntField("i", this.m_index) + RLTelemetry.Field("pin", RLObjectives.Where(target))
      + RLTelemetry.Field("place", RLArenaScout.PlaceName(game));
    if this.m_settled {
      let start = this.m_start;
      let low = start.Z;
      let high = start.Z;
      let cover20 = RLArenaScout.Coverage(game, start, 20.0, low, high);
      let cover30 = RLArenaScout.Coverage(game, start, 30.0, low, high);
      let cover40 = RLArenaScout.Coverage(game, start, 40.0, low, high);
      let site = RLArenaSite.Read(game, start, 30.0);
      fields += RLTelemetry.Field("result", "ok") + RLTelemetry.Field("at", RLObjectives.Where(start))
        + RLTelemetry.IntField("cover20", cover20) + RLTelemetry.IntField("cover30", cover30) + RLTelemetry.IntField("cover40", cover40)
        + RLTelemetry.IntField("rise", RoundF(high - low)) + RLTelemetry.IntField("ground", ArraySize(site.ground))
        + RLTelemetry.IntField("covered", site.covered) + RLTelemetry.IntField("perches", ArraySize(site.perches))
        + RLTelemetry.IntField("roof", RLArenaScout.HasRoof(game, start) ? 1 : 0) + RLTelemetry.IntField("waited", this.m_waited);
    } else {
      fields += RLTelemetry.Field("result", "no navmesh");
    }
    let story = "";
    for what in this.m_story {
      story += (StrLen(story) > 0 ? "," : "") + what;
    }
    if StrLen(story) > 0 {
      fields += RLTelemetry.Field("story", story);
    }
    RogueliteService.Get().AppendSurvey(fields);
    this.m_index += 1;
    this.m_visited += 1;
    RogueliteService.Get().SetSurveyNext(this.m_index);
    if this.m_index >= ArraySize(this.m_points) {
      this.Finish(true);
      return;
    }
    if RLConfig.AutoSurvey() && this.m_visited >= RLCitySurvey.BatchSize() {
      // Saves the store; the main menu brings the survey back (MainMenuEntry).
      RLLog(s"City survey: \(this.m_index) of \(ArraySize(this.m_points)) done - to the main menu to save.");
      this.Finish(false);
      GameInstance.GetSystemRequestsHandler().GotoMainMenu();
      return;
    }
    this.Visit();
  }

  private func Finish(complete: Bool) {
    this.m_active = false;
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if this.m_journalRegistered {
      let journal = GameInstance.GetJournalManager(game);
      if IsDefined(journal) {
        journal.UnregisterScriptCallback(this, n"OnJournalStateChanged");
      }
      this.m_journalRegistered = false;
    }
    if IsDefined(player) {
      GameInstance.GetGodModeSystem(game).RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NCRogueliteSurvey");
    }
    if complete {
      RogueliteService.Get().SetSurveyDone(true);
      RLLog("City survey: done.");
      if IsDefined(player) {
        RLNotify(game, "SURVEY DONE - quit through the menu so the results save", 8.0);
      }
      let system = this.m_system;
      if IsDefined(system) {
        system.OnScoutDone();
      }
      if RLConfig.AutoSurvey() {
        GameInstance.GetSystemRequestsHandler().GotoMainMenu();
      }
    }
  }
}

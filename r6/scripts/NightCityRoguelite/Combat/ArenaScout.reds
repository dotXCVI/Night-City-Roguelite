// -----------------------------------------------------------------------------
// Night City Roguelite - arena scout (dev tools)
// -----------------------------------------------------------------------------
// Vets arena candidates (Data/ArenaCandidates.reds: gang outposts, cyberpsycho
// spots and gig sites from the game's own map pins) without playing them.
// From the terminal's SCOUT ARENAS card (RLConfig.DevTools()), V is taken to
// each candidate in turn, invulnerable, and once the ground and navmesh have
// streamed in the scout measures it:
//
//   start     the walkable point nearest the pin (where V would arrive)
//   cover30   the share of a 30 m circle around it V can walk to from there
//   cover40   the same for 40 m (sample points on V's floor, each with a
//             full path back to the start - RLObjectives.Walkable)
//   rise      the height range of the points reached
//   roof      something solid within 25 m above the start (inside a building)
//   place     the location name the game shows for it
//
// Every candidate is a SCOUT telemetry record (run id 0);
// tools/runreport.py --scout ranks them. Then V goes home. About ten seconds
// a candidate.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLArenaCandidate {
  public let id: CName;
  public let kind: String;
  public let district: String;
  public let position: Vector4;
  public let factions: array<gamedataAffiliation>;

  public static func Make(id: CName, const kind: String, const district: String, position: Vector4, factions: array<gamedataAffiliation>) -> ref<RLArenaCandidate> {
    let candidate = new RLArenaCandidate();
    candidate.id = id;
    candidate.kind = kind;
    candidate.district = district;
    candidate.position = position;
    candidate.factions = factions;
    return candidate;
  }
}

public class RLArenaScout extends RLDelayTarget {
  private let m_system: wref<RogueliteSystem>;
  private let m_list: array<ref<RLArenaCandidate>>;
  private let m_index: Int32;
  private let m_waited: Int32;
  private let m_settled: Bool;
  private let m_active: Bool;

  public func IsActive() -> Bool = this.m_active

  public func Start(system: ref<RogueliteSystem>) {
    let player = GetPlayer(GetGameInstance());
    if this.m_active || !IsDefined(player) {
      return;
    }
    this.m_system = system;
    this.m_list = RLArenaCandidates.All();
    this.m_index = 0;
    this.m_active = true;
    GameInstance.GetGodModeSystem(player.GetGame()).AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NCRogueliteScout");
    RLLog(s"Arena scout: \(ArraySize(this.m_list)) candidates.");
    this.Visit();
  }

  private func Visit() {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || this.m_index >= ArraySize(this.m_list) {
      this.Finish();
      return;
    }
    let candidate = this.m_list[this.m_index];
    let target = candidate.position;
    RLArenaDirector.TeleportToPoint(player, Vector4(target.X, target.Y, target.Z + 1.5, 1.0), 0.0);
    RLNotify(player.GetGame(), s"SCOUT \(this.m_index + 1)/\(ArraySize(this.m_list)): \(NameToString(candidate.id))", 3.0);
    this.m_waited = 0;
    this.m_settled = false;
    RLDelay(player.GetGame(), this, n"check", 2.0);
  }

  public func OnDelayed(action: CName) {
    if !this.m_active {
      return;
    }
    switch action {
      case n"check":
        this.Check();
        break;
      case n"next":
        this.m_index += 1;
        this.Visit();
        break;
    }
  }

  // Waits for the ground and navmesh around the pin to stream in (up to
  // 15 s), then two seconds more for the rest of the circle.
  private func Check() {
    let game = GetGameInstance();
    let candidate = this.m_list[this.m_index];
    let found = GameInstance.GetNavigationSystem(game).FindPointInSphereOnlyHumanNavmesh(candidate.position, 10.0, NavGenAgentSize.Human, false);
    let ready = Equals(found.status, worldNavigationRequestStatus.OK) && RLArenaDirector.HasFloor(game, found.point);
    if !ready && this.m_waited < 15 {
      this.m_waited += 1;
      RLDelay(game, this, n"check", 1.0);
      return;
    }
    if ready && !this.m_settled {
      this.m_settled = true;
      let player = GetPlayer(game);
      if IsDefined(player) {
        RLArenaDirector.TeleportToPoint(player, found.point, 0.0);
      }
      RLDelay(game, this, n"check", 2.0);
      return;
    }
    this.Measure(candidate, ready ? found.point : candidate.position, ready);
    RLDelay(game, this, n"next", 0.5);
  }

  private func Measure(candidate: ref<RLArenaCandidate>, start: Vector4, ready: Bool) {
    let game = GetGameInstance();
    let fields = RLTelemetry.Field("id", NameToString(candidate.id)) + RLTelemetry.Field("kind", candidate.kind)
      + RLTelemetry.Field("district", candidate.district) + RLTelemetry.Field("place", RLArenaScout.PlaceName(game));
    if !ready {
      RLTelemetry.RecordFor(0, "SCOUT", fields + RLTelemetry.Field("result", "no navmesh"));
      RLLog(s"Arena scout: \(NameToString(candidate.id)) - no navmesh.");
      return;
    }
    let low = start.Z;
    let high = start.Z;
    let cover30 = RLArenaScout.Coverage(game, start, 30.0, low, high);
    let cover40 = RLArenaScout.Coverage(game, start, 40.0, low, high);
    let roof = RLArenaScout.HasRoof(game, start);
    RLTelemetry.RecordFor(0, "SCOUT", fields + RLTelemetry.Field("result", "ok") + RLTelemetry.Field("at", RLObjectives.Where(start))
      + RLTelemetry.IntField("cover30", cover30) + RLTelemetry.IntField("cover40", cover40) + RLTelemetry.IntField("rise", RoundF(high - low))
      + RLTelemetry.IntField("roof", roof ? 1 : 0) + RLTelemetry.IntField("pin", RoundF(Vector4.Distance(start, candidate.position)))
      + RLTelemetry.IntField("waited", this.m_waited));
    RLLog(s"Arena scout: \(NameToString(candidate.id)) cover \(cover30)%/\(cover40)%, rise \(RoundF(high - low)) m, roof \(roof).");
  }

  // The share (0-100) of sample points in a circle around `start`, on its
  // floor, that V can walk to from the start.
  private static func Coverage(game: GameInstance, start: Vector4, radius: Float, out low: Float, out high: Float) -> Int32 {
    let navigation = GameInstance.GetNavigationSystem(game);
    let rings = [0.35, 0.6, 0.85];
    let samples = 0;
    let reached = 0;
    for ring in rings {
      let i = 0;
      while i < 16 {
        let angle = 6.2831853 * Cast<Float>(i) / 16.0;
        let probe = Vector4(start.X + CosF(angle) * radius * ring, start.Y + SinF(angle) * radius * ring, start.Z, 1.0);
        samples += 1;
        let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 3.0, NavGenAgentSize.Human, false);
        if Equals(found.status, worldNavigationRequestStatus.OK) && AbsF(found.point.Z - start.Z) < 4.0 && RLObjectives.Walkable(navigation, found.point, start) {
          reached += 1;
          low = MinF(low, found.point.Z);
          high = MaxF(high, found.point.Z);
        }
        i += 1;
      }
    }
    return RoundF(100.0 * Cast<Float>(reached) / Cast<Float>(samples));
  }

  // Something solid overhead: the start is inside a building.
  private static func HasRoof(game: GameInstance, start: Vector4) -> Bool {
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static");
    let result: TraceResult;
    let from = Vector4(start.X, start.Y, start.Z + 2.0, 1.0);
    let to = Vector4(start.X, start.Y, start.Z + 25.0, 1.0);
    return GameInstance.GetSpatialQueriesSystem(game).SyncRaycastByQueryFilter(from, to, filter, result) && TraceResult.IsValid(result);
  }

  // The location name the minimap shows.
  private static func PlaceName(game: GameInstance) -> String {
    let board = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_Map);
    return IsDefined(board) ? board.GetString(GetAllBlackboardDefs().UI_Map.currentLocation) : "";
  }

  private func Finish() {
    this.m_active = false;
    let player = GetPlayer(GetGameInstance());
    if IsDefined(player) {
      GameInstance.GetGodModeSystem(player.GetGame()).RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"NCRogueliteScout");
      RLNotify(player.GetGame(), "SCOUT DONE - quit through the menu so the results save", 6.0);
    }
    RLLog("Arena scout: done.");
    let system = this.m_system;
    if IsDefined(system) {
      system.OnScoutDone();
    }
  }
}

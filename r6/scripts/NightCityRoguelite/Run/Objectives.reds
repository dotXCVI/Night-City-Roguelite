// -----------------------------------------------------------------------------
// Night City Roguelite - fight objectives
// -----------------------------------------------------------------------------
// Some doors (from floor 3, never the boss) come with a job besides killing.
// The enemies keep coming until the job is done (RLWaveSpawner holds the
// encounter open and cycles its waves); then no one else joins the fight and
// it ends when the last enemy falls.
//
//   SURVIVE     hold out until the timer runs out
//   UPLINK      stand in the marked zone until the upload completes (it
//               pauses while V is outside)
//   SABOTAGE    plant charges at three marked spots (a few seconds each);
//               they go off when the last one is set
//
// The door shows the objective, the HUD its progress, the world map markers.
// Markers are always reachable on foot from where V starts, and an uplink or
// sabotage that drags on past TimeLimit completes on its own - an objective
// can never hold a fight open forever. A finished objective pays a bonus in
// eddies.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLObjectiveKind {
  None = 0,
  Survive = 1,
  Uplink = 2,
  Sabotage = 3,
}

public abstract class RLObjectives {
  public static func RollForDoor(run: ref<RLRunState>, arena: ref<RLArenaDef>) -> RLObjectiveKind {
    // Test runs get one more often, from the first floor.
    let chance = run.isTest ? 0.6 : RLConfig.ObjectiveChance();
    if !IsDefined(arena) || (run.Depth() < 3 && !run.isTest) || run.IsBossFloor() || RandF() >= chance {
      return RLObjectiveKind.None;
    }
    return IntEnum<RLObjectiveKind>(RandRange(1, 4));
  }

  public static func Name(kind: RLObjectiveKind) -> String {
    switch kind {
      case RLObjectiveKind.Survive: return "SURVIVE";
      case RLObjectiveKind.Uplink: return "HOLD THE UPLINK";
      case RLObjectiveKind.Sabotage: return "SABOTAGE";
    }
    return "";
  }

  public static func Description(kind: RLObjectiveKind) -> String {
    switch kind {
      case RLObjectiveKind.Survive: return "Hold out against endless waves";
      case RLObjectiveKind.Uplink: return "Stay in the zone until the upload completes";
      case RLObjectiveKind.Sabotage: return "Plant charges at three spots";
    }
    return "";
  }

  public static func SurviveSeconds(run: ref<RLRunState>) -> Float = 60.0 + 15.0 * Cast<Float>(run.act)

  public static func UplinkSeconds() -> Float = 45.0
  public static func UplinkRadius() -> Float = 7.0

  public static func ChargeSeconds() -> Float = 3.0
  public static func ChargeRadius() -> Float = 3.0

  // Seconds after which an uplink or sabotage completes anyway.
  public static func TimeLimit() -> Float = 150.0

  public static func BonusEddies(run: ref<RLRunState>) -> Int32 = 150 + 30 * run.Depth()
}

// One objective in progress.
public class RLObjective {
  private let m_kind: RLObjectiveKind;
  private let m_goal: Float;
  private let m_progress: Float;
  private let m_points: array<Vector4>;
  private let m_pointProgress: array<Float>;
  private let m_mappins: array<NewMappinID>;
  private let m_done: Bool;
  private let m_elapsed: Float;

  public static func Start(kind: RLObjectiveKind, run: ref<RLRunState>, arena: ref<RLArenaDef>, player: ref<PlayerPuppet>) -> ref<RLObjective> {
    let objective = new RLObjective();
    objective.m_kind = kind;
    let game = player.GetGame();
    switch kind {
      case RLObjectiveKind.Survive:
        objective.m_goal = RLObjectives.SurviveSeconds(run);
        break;
      case RLObjectiveKind.Uplink:
        objective.m_goal = RLObjectives.UplinkSeconds();
        objective.AddPoint(game, arena, player, RandRangeF(0.0, 6.2831853), 0.35);
        break;
      case RLObjectiveKind.Sabotage:
        objective.m_goal = 3.0;
        let start = RandRangeF(0.0, 6.2831853);
        let i = 0;
        while i < 3 {
          objective.AddPoint(game, arena, player, start + 2.0943951 * Cast<Float>(i), 0.55);
          i += 1;
        }
        break;
    }
    RLLog(s"Objective: \(RLObjectives.Name(kind)), \(ArraySize(objective.m_points)) marker(s).");
    return objective;
  }

  public func Kind() -> RLObjectiveKind = this.m_kind

  public func IsDone() -> Bool = this.m_done

  // Advances by one second; true the moment the objective is completed.
  public func Tick(player: ref<PlayerPuppet>) -> Bool {
    if this.m_done || !IsDefined(player) {
      return false;
    }
    let position = player.GetWorldPosition();
    this.m_elapsed += 1.0;
    if this.m_elapsed >= RLObjectives.TimeLimit() && NotEquals(this.m_kind, RLObjectiveKind.Survive) {
      RLLog("Objective timed out - completing it.");
      this.m_progress = this.m_goal;
    }
    switch this.m_kind {
      case RLObjectiveKind.Survive:
        this.m_progress += 1.0;
        break;
      case RLObjectiveKind.Uplink:
        if ArraySize(this.m_points) > 0 && Vector4.Distance(position, this.m_points[0]) <= RLObjectives.UplinkRadius() {
          this.m_progress += 1.0;
        }
        break;
      case RLObjectiveKind.Sabotage:
        this.TickCharges(player, position);
        break;
    }
    if this.m_progress >= this.m_goal {
      this.m_done = true;
      if Equals(this.m_kind, RLObjectiveKind.Sabotage) {
        // The charges go off (not the one V is standing at).
        for point in this.m_points {
          if Vector4.Distance(point, position) > 10.0 {
            RLExplosions.Blast(player, point, t"Attacks.CyberwareExplosion", 8.0);
          }
        }
      }
      this.Stop(player.GetGame());
      return true;
    }
    return false;
  }

  private func TickCharges(player: ref<PlayerPuppet>, position: Vector4) {
    let i = 0;
    while i < ArraySize(this.m_points) {
      if this.m_pointProgress[i] < RLObjectives.ChargeSeconds() && Vector4.Distance(position, this.m_points[i]) <= RLObjectives.ChargeRadius() {
        this.m_pointProgress[i] += 1.0;
        if this.m_pointProgress[i] >= RLObjectives.ChargeSeconds() {
          this.m_progress += 1.0;
          GameInstance.GetMappinSystem(player.GetGame()).UnregisterMappin(this.m_mappins[i]);
          if this.m_progress < this.m_goal {
            RLNotify(player.GetGame(), s"CHARGE SET - \(RoundF(this.m_progress))/3", 3.0);
          }
        }
      }
      i += 1;
    }
  }

  // The HUD line.
  public func Status() -> String {
    switch this.m_kind {
      case RLObjectiveKind.Survive:
        return s"SURVIVE \(Max(0, RoundF(this.m_goal - this.m_progress)))s";
      case RLObjectiveKind.Uplink:
        return s"UPLINK \(Min(100, RoundF(100.0 * this.m_progress / this.m_goal)))%";
      case RLObjectiveKind.Sabotage:
        return s"CHARGES \(RoundF(this.m_progress))/3";
    }
    return "";
  }

  public func Stop(game: GameInstance) {
    let mappins = GameInstance.GetMappinSystem(game);
    for id in this.m_mappins {
      mappins.UnregisterMappin(id);
    }
    ArrayClear(this.m_mappins);
  }

  // A marker on the arena's navmesh: `angle` and `reach` (share of the
  // arena's radius) from its centre, at V's floor level.
  private func AddPoint(game: GameInstance, arena: ref<RLArenaDef>, player: ref<PlayerPuppet>, angle: Float, reach: Float) {
    let navigation = GameInstance.GetNavigationSystem(game);
    let point = arena.position;
    let origin = player.GetWorldPosition();
    let floor = origin.Z;
    let tries = 0;
    while tries < 6 {
      let distance = arena.radius * reach * (1.0 - 0.15 * Cast<Float>(tries));
      let probe = Vector4(arena.position.X + CosF(angle) * distance, arena.position.Y + SinF(angle) * distance, floor, 1.0);
      let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 4.0, NavGenAgentSize.Human, false);
      if Equals(found.status, worldNavigationRequestStatus.OK) && AbsF(found.point.Z - floor) < 4.0 {
        // Reachable on foot from V (not a rooftop or a sealed room).
        let path = navigation.CalculatePathOnlyHumanNavmesh(found.point, origin, NavGenAgentSize.Human, 2.0);
        if IsDefined(path) && ArraySize(path.path) >= 2 && path.CalculateLength() < Vector4.Distance(found.point, origin) * 2.5 + 15.0 {
          point = found.point;
          break;
        }
      }
      tries += 1;
    }
    let data: MappinData;
    // The same static pin as a map waypoint: quest pins need a journal entry.
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.active = true;
    data.visibleThroughWalls = true;
    ArrayPush(this.m_points, point);
    ArrayPush(this.m_pointProgress, 0.0);
    ArrayPush(this.m_mappins, GameInstance.GetMappinSystem(game).RegisterMappin(data, point));
  }
}

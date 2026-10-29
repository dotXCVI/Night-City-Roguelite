// -----------------------------------------------------------------------------
// Night City Roguelite - reading an arena's ground
// -----------------------------------------------------------------------------
// Every arena is read when V arrives, while the screen is still black, so the
// waves can use the ground the way a level designer would:
//
//   ground    points on V's floor, each with a full walking path to the start
//             (RLObjectives.Walkable), and whether something solid stands
//             right next to it (cover);
//   perches   points 3-14 m above the floor with a clear line of sight down
//             to it: balconies, catwalks, container stacks, rooftops.
//
// The wave spawner (Combat/WaveSpawner.reds) places each enemy by its role:
// snipers and netrunners up on a perch, shotgunners and blades close in and
// off to the side, riflemen behind cover at mid range, heavies and bosses out
// in the open ahead. Each wave comes in from one side of V; the first from
// ahead, the next ones from the flanks, so a fight reads and keeps moving.
//
// The city survey (Dev/CitySurvey.reds) reads candidate arenas the same way.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLSpawnRole {
  Mid = 0,
  Close = 1,
  Far = 2,
  Perch = 3,
}

public class RLSitePoint {
  public let position: Vector4;
  public let covered: Bool;
  public let perch: Bool;
}

public class RLArenaSite {
  public let center: Vector4;
  public let radius: Float;
  public let ground: array<ref<RLSitePoint>>;
  public let perches: array<ref<RLSitePoint>>;
  // How many ground points have cover next to them.
  public let covered: Int32;
  // Sample points tried, for the share of the circle that is floor.
  public let samples: Int32;

  // Reads the ground around `start` out to `radius`.
  public static func Read(game: GameInstance, start: Vector4, radius: Float) -> ref<RLArenaSite> {
    let site = new RLArenaSite();
    site.center = start;
    site.radius = radius;
    let navigation = GameInstance.GetNavigationSystem(game);
    let rings = [0.3, 0.5, 0.7, 0.9];
    let spokes = 16;
    let r = 0;
    while r < ArraySize(rings) {
      let ring = rings[r];
      let i = 0;
      while i < spokes {
        // Alternate rings are turned half a step, so the points interleave.
        let angle = 6.2831853 * (Cast<Float>(i) + (r % 2 == 1 ? 0.5 : 0.0)) / Cast<Float>(spokes);
        let probe = Vector4(start.X + CosF(angle) * radius * ring, start.Y + SinF(angle) * radius * ring, start.Z, 1.0);
        site.samples += 1;
        let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 3.0, NavGenAgentSize.Human, false);
        if Equals(found.status, worldNavigationRequestStatus.OK) && AbsF(found.point.Z - start.Z) < 4.0
          && RLObjectives.Walkable(navigation, found.point, start) {
          let point = new RLSitePoint();
          point.position = found.point;
          point.covered = RLArenaSite.HasCover(game, found.point);
          if point.covered {
            site.covered += 1;
          }
          ArrayPush(site.ground, point);
        }
        i += 1;
      }
      r += 1;
    }
    site.FindPerches(game, navigation);
    return site;
  }

  // Elevated navmesh points that look down on the floor around the start.
  private func FindPerches(game: GameInstance, navigation: ref<NavigationSystem>) {
    let probes = 24;
    let i = 0;
    while i < probes {
      let angle = 6.2831853 * Cast<Float>(i) / Cast<Float>(probes);
      let reach = this.radius * (i % 2 == 0 ? 0.55 : 0.85);
      let rise = i % 3 == 0 ? 5.0 : (i % 3 == 1 ? 8.0 : 11.0);
      let probe = Vector4(this.center.X + CosF(angle) * reach, this.center.Y + SinF(angle) * reach, this.center.Z + rise, 1.0);
      let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 4.0, NavGenAgentSize.Human, false);
      if Equals(found.status, worldNavigationRequestStatus.OK) {
        let height = found.point.Z - this.center.Z;
        if height >= 3.0 && height <= 14.0 && Vector4.Distance2D(found.point, this.center) <= this.radius
          && !this.IsNearPerch(found.point) && RLArenaSite.CanSee(game, found.point, this.center) {
          let point = new RLSitePoint();
          point.position = found.point;
          point.perch = true;
          ArrayPush(this.perches, point);
        }
      }
      i += 1;
    }
  }

  private func IsNearPerch(position: Vector4) -> Bool {
    for perch in this.perches {
      if Vector4.Distance(perch.position, position) < 4.0 {
        return true;
      }
    }
    return false;
  }

  // Something solid within reach at waist height on at least two of eight
  // sides: a wall, a car, a crate to fight from.
  public static func HasCover(game: GameInstance, point: Vector4) -> Bool {
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static");
    let from = Vector4(point.X, point.Y, point.Z + 1.0, 1.0);
    let blocked = 0;
    let i = 0;
    while i < 8 {
      let angle = 6.2831853 * Cast<Float>(i) / 8.0;
      let to = Vector4(from.X + CosF(angle) * 2.5, from.Y + SinF(angle) * 2.5, from.Z, 1.0);
      let result: TraceResult;
      if queries.SyncRaycastByQueryFilter(from, to, filter, result) && TraceResult.IsValid(result) {
        blocked += 1;
      }
      i += 1;
    }
    return blocked >= 2;
  }

  // A clear line from head height at `from` to chest height at `to`.
  public static func CanSee(game: GameInstance, from: Vector4, to: Vector4) -> Bool {
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Static");
    QueryFilter.AddGroup(filter, n"Terrain");
    let result: TraceResult;
    let eye = Vector4(from.X, from.Y, from.Z + 1.6, 1.0);
    let target = Vector4(to.X, to.Y, to.Z + 1.2, 1.0);
    return !(GameInstance.GetSpatialQueriesSystem(game).SyncRaycastByQueryFilter(eye, target, filter, result) && TraceResult.IsValid(result));
  }

  // The share (0-100) of the sample points that are floor V can walk to.
  public func Coverage() -> Int32 = this.samples > 0 ? RoundF(100.0 * Cast<Float>(ArraySize(this.ground)) / Cast<Float>(this.samples)) : 0

  // --- Placing enemies -------------------------------------------------------------------

  // The kind of spot an enemy fights from best, by its archetype.
  public static func RoleOf(record: TweakDBID, isBoss: Bool) -> RLSpawnRole {
    if isBoss {
      return RLSpawnRole.Far;
    }
    let kind = RLCombatState.Kind(record);
    if StrContains(kind, "Sniper") || StrContains(kind, "Netrunner") {
      return RLSpawnRole.Perch;
    }
    if StrContains(kind, "Melee") || StrContains(kind, "Shotgun") {
      return RLSpawnRole.Close;
    }
    if StrContains(kind, "Heavy") || StrContains(kind, "Mech") || StrContains(kind, "Techie") {
      return RLSpawnRole.Far;
    }
    return RLSpawnRole.Mid;
  }

  // A spot for `role` near the wave's heading from V (degrees, as
  // Vector4.Heading gives them).
  // Points closer than `minDistance` to V are never used. False when the
  // ground has nothing that fits; the spawner then falls back to any point.
  public func Pick(role: RLSpawnRole, from: Vector4, heading: Float, minDistance: Float, out result: Vector4) -> Bool {
    if Equals(role, RLSpawnRole.Perch) && this.PickFrom(this.perches, role, from, heading, minDistance, 180.0, result) {
      return true;
    }
    // A wave arrives from one side: first within 70 degrees of its heading,
    // then anywhere.
    if this.PickFrom(this.ground, role, from, heading, minDistance, 70.0, result) {
      return true;
    }
    return this.PickFrom(this.ground, role, from, heading, minDistance, 180.0, result);
  }

  private func PickFrom(points: array<ref<RLSitePoint>>, role: RLSpawnRole, from: Vector4, heading: Float, minDistance: Float, spread: Float, out result: Vector4) -> Bool {
    let best: ref<RLSitePoint>;
    let bestScore = -1.0;
    for point in points {
      let offset = point.position - from;
      let distance = Vector4.Length2D(offset);
      if distance >= minDistance && RLArenaSite.AngleBetween(Vector4.Heading(offset), heading) <= spread {
        // Random first, so two enemies of a role don't stack on one point;
        // the role's preferences then weigh in.
        let score = RandRangeF(0.0, 1.0) + this.Fit(role, point, distance);
        if score > bestScore {
          bestScore = score;
          best = point;
        }
      }
    }
    if !IsDefined(best) {
      return false;
    }
    result = best.position;
    return true;
  }

  // How well a point suits a role (0-1.5).
  private func Fit(role: RLSpawnRole, point: ref<RLSitePoint>, distance: Float) -> Float {
    let reach = MaxF(this.radius, 1.0);
    switch role {
      case RLSpawnRole.Close:
        // Just outside arm's reach: 12-18 m.
        return distance <= 18.0 ? 1.0 : 0.0;
      case RLSpawnRole.Far:
        // Out in the open, far off.
        return (point.covered ? 0.0 : 0.5) + distance / reach;
      case RLSpawnRole.Perch:
        return distance / reach;
    }
    // Mid: behind cover at 15-30 m.
    return (point.covered ? 1.0 : 0.0) + (distance >= 15.0 && distance <= 30.0 ? 0.5 : 0.0);
  }

  // 0-180 degrees between two headings.
  public static func AngleBetween(a: Float, b: Float) -> Float {
    let d = AbsF(a - b);
    while d > 360.0 {
      d -= 360.0;
    }
    return d > 180.0 ? 360.0 - d : d;
  }
}

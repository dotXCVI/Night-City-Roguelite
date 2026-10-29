// -----------------------------------------------------------------------------
// Night City Roguelite - routes: every act is a journey
// -----------------------------------------------------------------------------
// An act happens in one part of the city and ends at one of its landmarks,
// the way a Hades biome ends at its boss. The doors on an act's first floor
// each lead into a different route; the one V takes holds for the act:
//
//   arenas     the act's fights are in the route's districts (any arena when
//              the route runs out of new ones)
//   boss       the act's boss waits at the landmark the route's door named
//   gangs      its arenas' gangs, so the route says who V will fight - and
//              where a nemesis runs (Run/Nemesis.reds)
//   patron     the route's patron, when they work the city this run, shows
//              up on its doors more often
//
// A run never takes the same route twice, so it crosses the city: the
// Badlands or Watson in Act 1, Pacifica, Dogtown, Heywood or Westbrook in
// Act 2, and the last act at Arasaka Tower, the spaceport or wherever is left.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLRoute {
  public let id: CName;
  public let name: String;
  // Arena areas (RLArenaDef.area) the route's fights happen in.
  public let areas: array<String>;
  public let patron: CName;
  // A line for the door.
  public let line: String;
}

public abstract class RLRoutes {
  public static func All() -> array<ref<RLRoute>> {
    let list: array<ref<RLRoute>>;
    RLRoutes.Add(list, n"watson", "WATSON", ["Watson"], n"Maelstrom", "Maelstrom country: the Combat Zone, the docks, the Northside yards.");
    RLRoutes.Add(list, n"badlands", "THE BADLANDS", ["Badlands"], n"Aldecaldos", "Open desert, nomad roads and Wraith camps.");
    RLRoutes.Add(list, n"santodomingo", "SANTO DOMINGO", ["Santo Domingo"], n"Militech", "Factories, power plants and 6th Street blocks.");
    RLRoutes.Add(list, n"pacifica", "PACIFICA", ["Pacifica"], n"VoodooBoys", "Voodoo Boy turf and a resort that never opened.");
    RLRoutes.Add(list, n"dogtown", "DOGTOWN", ["Dogtown"], n"Militech", "Kurt Hansen's city inside the city. Barghest on every corner.");
    RLRoutes.Add(list, n"heywood", "HEYWOOD", ["Heywood"], n"Afterlife", "Valentinos, fixers and the money above them.");
    RLRoutes.Add(list, n"westbrook", "WESTBROOK", ["Westbrook", "North Oak"], n"Arasaka", "Japantown's neon and the hills where Arasaka lives.");
    RLRoutes.Add(list, n"citycenter", "ARASAKA TOWER", ["City Center"], n"Arasaka", "Corpo Plaza, then up through the tower itself.");
    return list;
  }

  private static func Add(out list: array<ref<RLRoute>>, id: CName, const name: String, areas: array<String>, patron: CName, const line: String) {
    let route = new RLRoute();
    route.id = id;
    route.name = name;
    route.areas = areas;
    route.patron = patron;
    route.line = line;
    ArrayPush(list, route);
  }

  public static func Get(id: CName) -> ref<RLRoute> {
    for route in RLRoutes.All() {
      if Equals(route.id, id) {
        return route;
      }
    }
    return null;
  }

  public static func Covers(route: ref<RLRoute>, arena: ref<RLArenaDef>) -> Bool {
    return IsDefined(route) && IsDefined(arena) && ArrayContains(route.areas, arena.area);
  }

  // The route's landmarks that can host act `act`'s boss.
  public static func Landmarks(route: ref<RLRoute>, act: Int32) -> array<ref<RLArenaDef>> {
    let result: array<ref<RLArenaDef>>;
    for arena in RLArenas.Landmarks(act) {
      if RLRoutes.Covers(route, arena) {
        ArrayPush(result, arena);
      }
    }
    return result;
  }

  // Routes this act can take: they end at a landmark for the act, and the
  // run hasn't been there yet.
  public static func Open(run: ref<RLRunState>) -> array<ref<RLRoute>> {
    let result: array<ref<RLRoute>>;
    for route in RLRoutes.All() {
      let landmarks = RLRoutes.Landmarks(route, run.act);
      if ArraySize(landmarks) > 0 && !ArrayContains(run.routesTaken, route.id) {
        ArrayPush(result, route);
      }
    }
    return result;
  }

  // Gives each door on an act's first floor its own route (as many different
  // ones as there are) and the landmark its boss will be at.
  public static func Assign(run: ref<RLRunState>, doors: array<ref<RLDoor>>) {
    let open = RLRoutes.Open(run);
    if ArraySize(open) == 0 {
      return;
    }
    let left = open;
    for door in doors {
      // Events have no fight to lead anywhere.
      if IsNameValid(door.arena) {
        // Different routes while they last; then they can repeat.
        if ArraySize(left) == 0 {
          left = open;
        }
        let pick = RandRange(0, ArraySize(left));
        let route = left[pick];
        ArrayErase(left, pick);
        door.route = route.id;
        let landmarks = RLRoutes.Landmarks(route, run.act);
        door.routeBoss = landmarks[RandRange(0, ArraySize(landmarks))].id;
      }
    }
  }

  // A route for an act that has none yet (a test run that starts mid-act).
  public static func PickAny(run: ref<RLRunState>) {
    let open = RLRoutes.Open(run);
    if ArraySize(open) == 0 {
      return;
    }
    let route = open[RandRange(0, ArraySize(open))];
    let landmarks = RLRoutes.Landmarks(route, run.act);
    RLRoutes.Take(run, route.id, landmarks[RandRange(0, ArraySize(landmarks))].id);
  }

  public static func Take(run: ref<RLRunState>, route: CName, boss: CName) {
    if !IsNameValid(route) {
      return;
    }
    run.route = route;
    run.routeBoss = boss;
    ArrayPush(run.routesTaken, route);
    ArrayClear(run.routeArenas);
    let def = RLRoutes.Get(route);
    let landmark = RLArenas.Get(boss);
    RLLog(s"Route for act \(run.act): \(IsDefined(def) ? def.name : NameToString(route)), the boss at \(IsDefined(landmark) ? landmark.name : NameToString(boss)).");
  }

  // The route's arena for a door: one of its districts' arenas the act
  // hasn't used, else any unused arena.
  public static func PickArena(run: ref<RLRunState>, exclude: array<CName>) -> CName {
    let route = RLRoutes.Get(run.route);
    if !IsDefined(route) {
      return n"";
    }
    let candidates: array<CName>;
    for arena in RLArenas.Regular() {
      if RLRoutes.Covers(route, arena) && !ArrayContains(exclude, arena.id) && !ArrayContains(run.routeArenas, arena.id) {
        ArrayPush(candidates, arena.id);
      }
    }
    if ArraySize(candidates) == 0 {
      return n"";
    }
    return candidates[RandRange(0, ArraySize(candidates))];
  }

  public static func Name(id: CName) -> String {
    let route = RLRoutes.Get(id);
    return IsDefined(route) ? route.name : "";
  }
}

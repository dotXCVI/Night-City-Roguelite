// -----------------------------------------------------------------------------
// Night City Roguelite - arena list
// -----------------------------------------------------------------------------
// The arenas offered on the terminal. Positions are the player start point and
// the center of the arena boundary. Coordinates come from Appearance Menu Mod's
// location database. Factions are preferred enemy gangs for the location; any
// that don't exist in the installed game's pools are skipped.
//
// Terrain (OPEN GROUND, MIXED, CLOSE QUARTERS) is shown on the door so the
// ground is part of the choice.
//
// To tune an arena after testing: change its radius, move its start point
// (stand where you want it and read the position from the log line
// "Arena start: ..."), or set `enabled` to false.
//
// The later open-world arenas are gang outposts, cyberpsycho spots and gig
// sites the arena scout (Combat/ArenaScout.reds) measured: start points are
// the scout's, radii follow how much of the circle V can walk. Gig sites that
// set off their gig, a call or a scene when V arrived were left out, with
// their neighbours.
//
// Landmarks are story-mission fight sites, kept for boss floors: each names
// the acts it can host, and the act's boss door picks among them (any
// arena when none is enabled for the act). The scout found ground and
// navmesh at every one - the open world streams even the story interiors.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLArenaDef {
  public let id: CName;
  public let name: String;
  public let area: String;
  public let position: Vector4;
  public let yaw: Float;
  public let radius: Float;
  public let factions: array<gamedataAffiliation>;
  public let enabled: Bool;
  // What the ground is like, shown on the door: OPEN GROUND favours long
  // guns, CLOSE QUARTERS shotguns and blades.
  public let terrain: String;
  // Spots enemies must never spawn in or be brought to (x, y, z, radius in
  // w): rooms the navmesh reaches through a locked door.
  public let avoid: array<Vector4>;
  // A story landmark: boss floors only, in these acts.
  public let landmark: Bool;
  public let acts: array<Int32>;
}

public abstract class RLArenas {
  public static func All() -> array<ref<RLArenaDef>> {
    let list: array<ref<RLArenaDef>>;
    ArrayPush(list, RLArenas.Def(n"petrochem", "Petrochem Off-Limits", "Santo Domingo",
      Vector4(-118.0461, -486.5356, 7.2969, 1.0), 79.31, 40.0,
      [gamedataAffiliation.Militech, gamedataAffiliation.KangTao], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"industrial", "Industrial Park", "Santo Domingo",
      Vector4(-235.5454, -1428.8181, 10.4, 1.0), 55.0, 40.0,
      [gamedataAffiliation.SixthStreet, gamedataAffiliation.Maelstrom], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"oilfields", "Oil Fields", "Northside",
      Vector4(-1818.8236, 3858.0295, 7.1613, 1.0), 142.58, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"drivein", "Old Drive-In", "Badlands",
      Vector4(-81.2295, 1963.3094, 100.6824, 1.0), 145.04, 40.0,
      [gamedataAffiliation.Maelstrom, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"junkyard", "Junkyard", "Badlands",
      Vector4(1374.8585, -1674.9177, 49.2959, 1.0), -173.32, 40.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "MIXED"));
    // The locked garage on the west side.
    ArrayPush(list[ArraySize(list) - 1].avoid, Vector4(1360.0, -1682.1, 49.3, 7.0));
    ArrayPush(list, RLArenas.Def(n"windfarm", "Wind Farm", "Badlands",
      Vector4(3810.4736, -1560.9727, 130.1068, 1.0), -11.6, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Militech], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"crater", "The Crater", "Badlands",
      Vector4(2555.4883, -1819.0264, 90.9741, 1.0), -39.73, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Militech], "OPEN GROUND"));

    // Scouted open-world sites.
    ArrayPush(list, RLArenas.Def(n"rockyridge", "Rocky Ridge", "Badlands",
      Vector4(4759.0, -1287.0, 137.6, 1.0), 0.0, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"jacksonplains", "Jackson Plains", "Badlands",
      Vector4(-118.0, -5209.0, 87.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"coronado", "Coronado Hideout", "Santo Domingo",
      Vector4(439.0, -1233.0, 28.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.SixthStreet, gamedataAffiliation.Animals], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"eastcoronado", "East Coronado", "Santo Domingo",
      Vector4(770.0, -1590.0, 46.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.SixthStreet, gamedataAffiliation.Animals], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"westwind", "West Wind Estate", "Pacifica",
      Vector4(-478.0, -1941.0, 7.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.VoodooBoys, gamedataAffiliation.Animals], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"longshore", "Longshore Stacks", "Dogtown",
      Vector4(-2552.0, -2441.0, 17.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.Barghest], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"dogtownblock", "Dogtown Back Streets", "Dogtown",
      Vector4(-2185.0, -2280.0, 16.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.Barghest], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"japantownlot", "Japantown Backlot", "Westbrook",
      Vector4(-379.0, 1444.0, 36.6, 1.0), 0.0, 40.0,
      [gamedataAffiliation.TygerClaws], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"sweatshop", "Tyger Sweatshop", "Westbrook",
      Vector4(-558.0, 497.0, 18.6, 1.0), 0.0, 35.0,
      [gamedataAffiliation.TygerClaws], "CLOSE QUARTERS"));
    ArrayPush(list, RLArenas.Def(n"charterhill", "Charter Hill", "Westbrook",
      Vector4(436.0, -435.0, 3.6, 1.0), 0.0, 30.0,
      [gamedataAffiliation.TygerClaws, gamedataAffiliation.Arasaka], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"wellsprings", "Wellsprings", "Heywood",
      Vector4(-2248.0, -401.0, 7.6, 1.0), 0.0, 35.0,
      [gamedataAffiliation.Valentinos], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"westdowntown", "West Downtown", "City Center",
      Vector4(-2444.0, 60.0, 4.6, 1.0), 0.0, 30.0,
      [gamedataAffiliation.Animals, gamedataAffiliation.TygerClaws], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"northsideyards", "Northside Yards", "Watson",
      Vector4(-1816.0, 2551.0, 26.6, 1.0), 0.0, 35.0,
      [gamedataAffiliation.Maelstrom, gamedataAffiliation.Scavengers], "MIXED"));

    // Landmarks (boss floors). Act 1 plays Royce's music, act 2 the mall's,
    // act 3 Smasher's. Start points are the scout's; interiors get small
    // radii (the scout's 30 m circle runs through their walls). Off: the
    // ones too cramped for a boss wave where the scout stood.
    RLArenas.Landmark(list, n"allfoods", "All Foods Plant", "Watson", Vector4(-820.0, 2196.0, 53.6, 1.0), 25.0,
      [gamedataAffiliation.Maelstrom], "CLOSE QUARTERS", [1], true);
    RLArenas.Landmark(list, n"totentanz", "Totentanz", "Watson", Vector4(-1721.0, 2199.0, 86.6, 1.0), 25.0,
      [gamedataAffiliation.Maelstrom], "CLOSE QUARTERS", [1], true);
    RLArenas.Landmark(list, n"ghosttown", "Ghost Town", "Badlands", Vector4(2575.0, -39.0, 81.6, 1.0), 40.0,
      [gamedataAffiliation.Wraiths], "OPEN GROUND", [1], true);
    RLArenas.Landmark(list, n"konpekiplaza", "Konpeki Plaza", "Watson", Vector4(-2228.0, 1736.0, 19.6, 1.0), 35.0,
      [gamedataAffiliation.Arasaka], "MIXED", [1], true);
    RLArenas.Landmark(list, n"konpekiroof", "Konpeki Plaza Roof", "Watson", Vector4(-2222.0, 1763.0, 320.6, 1.0), 22.0,
      [gamedataAffiliation.Arasaka], "MIXED", [1], true);
    // Proven in the open world (it was a regular arena first).
    RLArenas.Landmark(list, n"mall", "Grand Imperial Mall", "Pacifica", Vector4(-2278.2095, -1992.3286, 20.57, 1.0), 35.0,
      [gamedataAffiliation.Animals, gamedataAffiliation.VoodooBoys], "CLOSE QUARTERS", [2], true);
    list[ArraySize(list) - 1].yaw = -157.14;
    RLArenas.Landmark(list, n"batty", "Batty's Hotel", "Pacifica", Vector4(-1899.0, -1888.0, 58.6, 1.0), 22.0,
      [gamedataAffiliation.VoodooBoys], "CLOSE QUARTERS", [2], true);
    RLArenas.Landmark(list, n"embers", "Embers", "Heywood", Vector4(-1795.0, -527.0, 74.6, 1.0), 20.0,
      [gamedataAffiliation.Arasaka], "CLOSE QUARTERS", [2, 3], true);
    RLArenas.Landmark(list, n"estate", "Arasaka Estate", "North Oak", Vector4(301.0, 1039.0, 226.6, 1.0), 35.0,
      [gamedataAffiliation.Arasaka], "MIXED", [2, 3], true);
    RLArenas.Landmark(list, n"stadium", "Dogtown Stadium", "Dogtown", Vector4(-1384.0, -2109.0, 70.6, 1.0), 28.0,
      [gamedataAffiliation.Barghest], "MIXED", [2], true);
    RLArenas.Landmark(list, n"sapphire", "Black Sapphire", "Dogtown", Vector4(-1872.0, -2258.0, 440.6, 1.0), 25.0,
      [gamedataAffiliation.Barghest], "CLOSE QUARTERS", [2, 3], true);
    RLArenas.Landmark(list, n"towerceo", "Arasaka Tower CEO Floor", "City Center", Vector4(-1444.0, 152.0, 565.6, 1.0), 25.0,
      [gamedataAffiliation.Arasaka], "CLOSE QUARTERS", [3], true);
    RLArenas.Landmark(list, n"towerroof", "Arasaka Tower Roof", "City Center", Vector4(-1453.0, 179.0, 616.6, 1.0), 25.0,
      [gamedataAffiliation.Arasaka], "OPEN GROUND", [3], true);
    RLArenas.Landmark(list, n"mikoshi", "Mikoshi", "City Center", Vector4(-1443.0, 147.0, -26.4, 1.0), 28.0,
      [gamedataAffiliation.Arasaka], "CLOSE QUARTERS", [3], true);
    RLArenas.Landmark(list, n"spaceport", "Spaceport Roof", "Pacifica", Vector4(-3617.0, 353.0, 85.6, 1.0), 28.0,
      [gamedataAffiliation.Militech, gamedataAffiliation.Barghest], "MIXED", [3], true);
    // Too cramped where the scout stood; a better start point could open them.
    RLArenas.Landmark(list, n"toweratrium", "Arasaka Tower Atrium", "City Center", Vector4(-1407.0, 102.0, 326.6, 1.0), 20.0,
      [gamedataAffiliation.Arasaka], "MIXED", [3], false);
    RLArenas.Landmark(list, n"parade", "Dashi Parade Rooftops", "Westbrook", Vector4(-514.0, 717.0, 116.6, 1.0), 20.0,
      [gamedataAffiliation.TygerClaws, gamedataAffiliation.Arasaka], "MIXED", [2], false);
    RLArenas.Landmark(list, n"cynosure", "Cynosure", "Dogtown", Vector4(-2067.0, -2212.0, -196.4, 1.0), 20.0,
      [gamedataAffiliation.Militech, gamedataAffiliation.Barghest], "CLOSE QUARTERS", [3], false);
    RLArenas.Landmark(list, n"stadiumroof", "Stadium Roof", "Dogtown", Vector4(-1374.0, -2209.0, 154.6, 1.0), 25.0,
      [gamedataAffiliation.Barghest], "OPEN GROUND", [2], false);
    return list;
  }

  // The arenas for ordinary doors.
  public static func Regular() -> array<ref<RLArenaDef>> {
    let result: array<ref<RLArenaDef>>;
    for def in RLArenas.All() {
      if def.enabled && !def.landmark {
        ArrayPush(result, def);
      }
    }
    return result;
  }

  // The landmarks that can host act `act`'s boss.
  public static func Landmarks(act: Int32) -> array<ref<RLArenaDef>> {
    let result: array<ref<RLArenaDef>>;
    for def in RLArenas.All() {
      if def.enabled && def.landmark && ArrayContains(def.acts, act) {
        ArrayPush(result, def);
      }
    }
    return result;
  }

  public static func Get(id: CName) -> ref<RLArenaDef> {
    for def in RLArenas.All() {
      if Equals(def.id, id) {
        return def;
      }
    }
    return null;
  }

  private static func Landmark(out list: array<ref<RLArenaDef>>, id: CName, name: String, area: String, position: Vector4, radius: Float, factions: array<gamedataAffiliation>, const terrain: String, acts: array<Int32>, enabled: Bool) {
    let def = RLArenas.Def(id, name, area, position, 0.0, radius, factions, terrain);
    def.landmark = true;
    def.acts = acts;
    def.enabled = enabled;
    ArrayPush(list, def);
  }

  private static func Def(id: CName, name: String, area: String, position: Vector4, yaw: Float, radius: Float, factions: array<gamedataAffiliation>, const terrain: String) -> ref<RLArenaDef> {
    let def = new RLArenaDef();
    def.id = id;
    def.name = name;
    def.area = area;
    def.position = position;
    def.yaw = yaw;
    def.radius = radius;
    def.factions = factions;
    def.terrain = terrain;
    def.enabled = true;
    return def;
  }
}

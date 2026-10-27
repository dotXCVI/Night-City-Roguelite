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
    ArrayPush(list, RLArenas.Def(n"mall", "Grand Imperial Mall", "Pacifica",
      Vector4(-2278.2095, -1992.3286, 20.57, 1.0), -157.14, 35.0,
      [gamedataAffiliation.Animals, gamedataAffiliation.VoodooBoys], "CLOSE QUARTERS"));
    ArrayPush(list, RLArenas.Def(n"oilfields", "Oil Fields", "Northside",
      Vector4(-1818.8236, 3858.0295, 7.1613, 1.0), 142.58, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"drivein", "Old Drive-In", "Badlands",
      Vector4(-81.2295, 1963.3094, 100.6824, 1.0), 145.04, 40.0,
      [gamedataAffiliation.Maelstrom, gamedataAffiliation.Scavengers], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"junkyard", "Junkyard", "Badlands",
      Vector4(1374.8585, -1674.9177, 49.2959, 1.0), -173.32, 40.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Scavengers], "MIXED"));
    ArrayPush(list, RLArenas.Def(n"windfarm", "Wind Farm", "Badlands",
      Vector4(3810.4736, -1560.9727, 130.1068, 1.0), -11.6, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Militech], "OPEN GROUND"));
    ArrayPush(list, RLArenas.Def(n"crater", "The Crater", "Badlands",
      Vector4(2555.4883, -1819.0264, 90.9741, 1.0), -39.73, 45.0,
      [gamedataAffiliation.Wraiths, gamedataAffiliation.Militech], "OPEN GROUND"));
    return list;
  }

  public static func Enabled() -> array<ref<RLArenaDef>> {
    let result: array<ref<RLArenaDef>>;
    for def in RLArenas.All() {
      if def.enabled {
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

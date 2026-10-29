// -----------------------------------------------------------------------------
// Night City Roguelite - nemeses
// -----------------------------------------------------------------------------
// The one who flatlines V remembers - Shadow of Mordor's Nemesis system, kept
// across runs:
//
//   born       the enemy that lands the killing blow (never a boss) gets a
//              name - a handle from how it killed V - and keeps its face, its
//              gang and its affixes
//   returns    in a later run, a door against its gang can say NEMESIS: it's
//              waiting in that fight's last wave, an elite a few levels up.
//              A route (Run/Routes.reds) shows where it runs.
//   learns     every time it kills V again it ranks up (to three) and picks
//              up another affix; whenever it lives through a fight V lost, it
//              studies V's build and shrugs off the keyword V leans on most
//              (MARK, SHOCK, GLITCH, BURN or BLEED won't stick)
//   falls      V killing it ends the grudge: Cred and eddies, a favor from
//              the fixers for a ranked one, and its story in the database
//
// At most three are at large; a new one pushes out the oldest of the lowest
// rank. Test runs show nemeses but never change them.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLNemesis {
  public persistent let id: Int32;
  public persistent let record: TweakDBID;
  public persistent let appearance: CName;
  // gamedataAffiliation, as a number.
  public persistent let faction: Int32;
  public persistent let first: CName;
  public persistent let handle: CName;
  public persistent let last: CName;
  // 1 nemesis, 2 lieutenant, 3 warlord.
  public persistent let rank: Int32;
  public persistent let affixes: Int32;
  // The keyword it shrugs off (none until it has studied V).
  public persistent let immune: CName;
  public persistent let kills: Int32;
  public persistent let meetings: Int32;
  public persistent let alive: Bool;
  // Its story, oldest first (a few lines).
  public persistent let story: array<CName>;

  public func Affiliation() -> gamedataAffiliation = IntEnum<gamedataAffiliation>(this.faction)

  public func FullName() -> String = NameToString(this.first) + " \"" + NameToString(this.handle) + "\" " + NameToString(this.last)

  public func RankTitle() -> String {
    switch this.rank {
      case 2: return "NEMESIS - LIEUTENANT";
      case 3: return "NEMESIS - WARLORD";
    }
    return "NEMESIS";
  }

  // "Killed you twice. BURN won't stick."
  public func Threat() -> String {
    let text = this.kills >= 2 ? s"Killed you \(this.kills) times." : "Killed you once.";
    if IsNameValid(this.immune) {
      text += " " + NameToString(this.immune) + " won't stick.";
    }
    return text;
  }

  public func Tell(const line: String) {
    ArrayPush(this.story, StringToName(line));
    while ArraySize(this.story) > 6 {
      ArrayErase(this.story, 0);
    }
  }
}

public abstract class RLNemeses {
  public static func MaxAtLarge() -> Int32 = 3

  public static func AtLarge() -> array<ref<RLNemesis>> {
    let result: array<ref<RLNemesis>>;
    for nemesis in RogueliteService.Get().GetNemeses() {
      if nemesis.alive {
        ArrayPush(result, nemesis);
      }
    }
    return result;
  }

  public static func Get(id: Int32) -> ref<RLNemesis> {
    if id <= 0 {
      return null;
    }
    for nemesis in RogueliteService.Get().GetNemeses() {
      if nemesis.id == id {
        return nemesis;
      }
    }
    return null;
  }

  // At large and running with this gang.
  public static func OfFaction(faction: gamedataAffiliation) -> array<ref<RLNemesis>> {
    let result: array<ref<RLNemesis>>;
    for nemesis in RLNemeses.AtLarge() {
      if Equals(nemesis.Affiliation(), faction) {
        ArrayPush(result, nemesis);
      }
    }
    return result;
  }

  // --- Doors -----------------------------------------------------------------------------

  // A nemesis waiting behind this door, or 0: a fight against its gang from
  // the run's second floor, one it hasn't been met in this run (nor offered
  // on another door of the screen). The higher its rank, the likelier.
  public static func ForDoor(run: ref<RLRunState>, door: ref<RLDoor>) -> Int32 {
    if door.boss || !IsDefined(door.faction) || run.Depth() < 2 {
      return 0;
    }
    switch door.category {
      case RLRewardCategory.Event:
      case RLRewardCategory.Bounty:
        return 0;
    }
    for nemesis in RLNemeses.OfFaction(door.faction.faction) {
      if !ArrayContains(run.nemesesMet, nemesis.id) && !ArrayContains(run.nemesesOffered, nemesis.id)
        && RandF() < 0.25 + 0.1 * Cast<Float>(nemesis.rank) {
        ArrayPush(run.nemesesOffered, nemesis.id);
        return nemesis.id;
      }
    }
    return 0;
  }

  // --- Fights ------------------------------------------------------------------------------

  // The level it fights at over the floor's elites.
  public static func LevelBonus(nemesis: ref<RLNemesis>) -> Int32 = 1 + nemesis.rank

  // V went down for good. The killer becomes (or ranks up as) a nemesis;
  // any nemesis that lived through the fight studies V. Returns the line
  // for the death screen ("" when nobody noticed).
  public static func OnVKilled(run: ref<RLRunState>, killer: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>, survivors: array<Int32>, const arena: String, faction: gamedataAffiliation) -> String {
    if run.isTest {
      return "";
    }
    let keyword = RLNemeses.StudyBuild(run);
    let line = "";
    for id in survivors {
      let nemesis = RLNemeses.Get(id);
      if IsDefined(nemesis) && nemesis.alive && (!IsDefined(killer) || killer.nemesis != id) {
        RLNemeses.Study(nemesis, keyword);
        nemesis.Tell(s"Watched you fall at \(arena).");
      }
    }
    if !IsDefined(killer) || killer.isBoss {
      return line;
    }
    if killer.nemesis > 0 {
      let nemesis = RLNemeses.Get(killer.nemesis);
      if IsDefined(nemesis) {
        nemesis.kills += 1;
        if nemesis.rank < 3 {
          nemesis.rank += 1;
          nemesis.affixes = RLNemeses.AddAffix(nemesis.affixes);
        }
        RLNemeses.Study(nemesis, keyword);
        nemesis.Tell(s"Killed you again at \(arena). Moved up: \(nemesis.RankTitle()).");
        RLTelemetry.Record(run, "NEMESIS", RLTelemetry.Field("event", "rankup") + RLTelemetry.IntField("id", nemesis.id) + RLTelemetry.IntField("rank", nemesis.rank));
        return nemesis.FullName() + " moves up.";
      }
      return line;
    }
    let nemesis = RLNemeses.Create(run, killer, puppet, arena, faction);
    return IsDefined(nemesis) ? nemesis.FullName() + " will remember you." : line;
  }

  // `faction` is the fight's gang: the doors that bring it back are its
  // gang's doors.
  private static func Create(run: ref<RLRunState>, killer: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>, const arena: String, faction: gamedataAffiliation) -> ref<RLNemesis> {
    let service = RogueliteService.Get();
    if Equals(faction, gamedataAffiliation.Unaffiliated) || Equals(faction, gamedataAffiliation.Unknown) {
      return null;
    }
    // Room for the new one: the oldest of the lowest rank moves on.
    let atLarge = RLNemeses.AtLarge();
    if ArraySize(atLarge) >= RLNemeses.MaxAtLarge() {
      let out = atLarge[0];
      for nemesis in atLarge {
        if nemesis.rank < out.rank {
          out = nemesis;
        }
      }
      out.alive = false;
      out.Tell("Left town.");
    }
    let nemesis = new RLNemesis();
    nemesis.id = service.NextNemesisId();
    nemesis.record = killer.record;
    nemesis.appearance = IsDefined(puppet) ? puppet.GetCurrentAppearanceName() : n"";
    nemesis.faction = EnumInt(faction);
    let kind = RLCombatState.Kind(killer.record);
    nemesis.first = RLNemeses.PickName(RLNemeses.FirstNames());
    nemesis.last = RLNemeses.PickName(RLNemeses.LastNames());
    nemesis.handle = RLNemeses.PickName(RLNemeses.Handles(kind));
    nemesis.rank = 1;
    nemesis.affixes = killer.affixes != 0 ? killer.affixes : RLNemeses.AddAffix(0);
    nemesis.kills = 1;
    nemesis.meetings = 1;
    nemesis.alive = true;
    nemesis.Tell(s"Killed you at \(arena), Act \(run.act).");
    service.AddNemesis(nemesis);
    RLLog(s"New nemesis: \(nemesis.FullName()) (\(RLEncounters.FactionName(faction)), \(kind)).");
    RLTelemetry.Record(run, "NEMESIS", RLTelemetry.Field("event", "born") + RLTelemetry.IntField("id", nemesis.id)
      + RLTelemetry.Field("kind", kind) + RLTelemetry.Field("faction", RLEncounters.FactionName(faction)));
    return nemesis;
  }

  // Met in a fight that V won: it fell.
  public static func OnKilled(run: ref<RLRunState>, nemesis: ref<RLNemesis>, const arena: String) -> Int32 {
    if run.isTest || !nemesis.alive {
      return 0;
    }
    nemesis.alive = false;
    nemesis.Tell(s"Taken down by you at \(arena).");
    let cred = 20 * nemesis.rank + 10 * nemesis.kills;
    let service = RogueliteService.Get();
    service.AddCred(cred);
    if nemesis.rank >= 2 {
      service.AddFavors(1);
    }
    RLLog(s"Nemesis down: \(nemesis.FullName()), +\(cred) Cred.");
    RLTelemetry.Record(run, "NEMESIS", RLTelemetry.Field("event", "down") + RLTelemetry.IntField("id", nemesis.id) + RLTelemetry.IntField("rank", nemesis.rank));
    return cred;
  }

  public static func OnMet(run: ref<RLRunState>, nemesis: ref<RLNemesis>) {
    if !run.isTest {
      nemesis.meetings += 1;
    }
  }

  // It learns V's build: the keyword V's effects and mods put on enemies most
  // is the one it shrugs off.
  private static func Study(nemesis: ref<RLNemesis>, keyword: CName) {
    if IsNameValid(keyword) {
      nemesis.immune = keyword;
    }
  }

  public static func StudyBuild(run: ref<RLRunState>) -> CName {
    let keywords = RLNemeses.Resistable();
    let counts: array<Int32>;
    for keyword in keywords {
      ArrayPush(counts, 0);
    }
    for boon in run.boons {
      let def = RLBoons.Get(boon.id);
      if IsDefined(def) {
        let i = 0;
        while i < ArraySize(keywords) {
          if ArrayContains(def.makes, keywords[i]) {
            counts[i] += 1;
          }
          i += 1;
        }
      }
    }
    for mod in run.armMods {
      let def = RLArmMods.Get(mod.id);
      if IsDefined(def) {
        let i = 0;
        while i < ArraySize(keywords) {
          if ArrayContains(def.makes, keywords[i]) {
            counts[i] += 1;
          }
          i += 1;
        }
      }
    }
    let best = -1;
    let bestCount = 0;
    let i = 0;
    while i < ArraySize(keywords) {
      if counts[i] > bestCount {
        bestCount = counts[i];
        best = i;
      }
      i += 1;
    }
    return best >= 0 ? keywords[best] : n"";
  }

  // The keywords a nemesis can learn to shrug off: the ones V puts on enemies.
  public static func Resistable() -> array<CName> = [n"MARK", n"SHOCK", n"GLITCH", n"BURN", n"BLEED"]

  private static func AddAffix(affixes: Int32) -> Int32 {
    let pool: array<Int32>;
    for affix in RLAffix.All() {
      if !RLAffixes.Has(affixes, affix) {
        ArrayPush(pool, affix);
      }
    }
    return ArraySize(pool) > 0 ? affixes | pool[RandRange(0, ArraySize(pool))] : affixes;
  }

  // --- Names ---------------------------------------------------------------------------

  private static func PickName(names: array<String>) -> CName = StringToName(names[RandRange(0, ArraySize(names))])

  // A handle from how it fights.
  private static func Handles(const kind: String) -> array<String> {
    if StrContains(kind, "Sniper") {
      return ["Longshot", "Scope", "Deadeye", "Eagle", "Spotter"];
    }
    if StrContains(kind, "Netrunner") {
      return ["Static", "Ghost", "Daemon", "Ping", "Backdoor"];
    }
    if StrContains(kind, "Shotgun") {
      return ["Buckshot", "Slug", "Scattergun", "Boom", "Twelve"];
    }
    if StrContains(kind, "Melee") {
      return ["Razor", "Knuckles", "Cleaver", "Butcher", "Edge"];
    }
    if StrContains(kind, "Heavy") || StrContains(kind, "Mech") {
      return ["Tank", "Bulldozer", "Ironside", "Brick", "Rhino"];
    }
    if StrContains(kind, "Techie") {
      return ["Sparks", "Wrench", "Fuse", "Tinker", "Circuit"];
    }
    return ["Trigger", "Hollowpoint", "Tracer", "Lucky", "Smiles", "Vex", "Rebar", "Jinx"];
  }

  private static func FirstNames() -> array<String> = ["Kenji", "Mara", "Dante", "Yuki", "Rosa", "Tomas", "Ines", "Viktor", "Lena", "Malik", "Sasha", "Marco", "Aiko", "Bruno", "Nadia", "Theo", "Carmen", "Ivan", "Priya", "Rico", "Hana", "Emeka", "Zoe", "Luis", "Mei", "Oskar", "Fatima", "Jax", "Nina", "Kofi"]

  private static func LastNames() -> array<String> = ["Ito", "Okafor", "Reyes", "Novak", "Tanaka", "Silva", "Kowalski", "Mendez", "Park", "Volkov", "Chen", "Haddad", "Morales", "Sato", "Ivanova", "Diaz", "Nakamura", "Adeyemi", "Ortega", "Kim", "Petrov", "Alvarez", "Mori", "Santos", "Wu", "Baptiste", "Ruiz", "Hale", "Moreau", "Grant"]
}

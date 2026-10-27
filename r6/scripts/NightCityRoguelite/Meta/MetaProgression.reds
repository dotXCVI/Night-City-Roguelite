// -----------------------------------------------------------------------------
// Night City Roguelite - meta progression
// -----------------------------------------------------------------------------
// Cred is earned for every cleared arena (never for a lost one), plus a bonus
// for a completed run, and spent at the hub terminal.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLUnlockDef {
  public let id: CName;
  public let name: String;
  public let description: String;
  public let cost: Int32;
  // Another unlock that must be owned first (for tiered perks).
  public let requires: CName;
}

public abstract class RLMeta {
  // Meta unlocks lean towards more choice (Roboquest's basecamp): rerolls,
  // more options, more doors, a starting pick - with a few small head starts.
  public static func Unlocks() -> array<ref<RLUnlockDef>> {
    let list: array<ref<RLUnlockDef>>;
    ArrayPush(list, RLMeta.Def(n"kit.Netrunner", "Kit: Netrunner", "Cyberdeck, two quickhacks, pistol, Optimization.", 150, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Marksman", "Kit: Marksman", "Precision or sniper rifle, pistol, Focus.", 150, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Brawler", "Kit: Brawler", "Gorilla Arms, shotgun, Die! Die! Die!", 250, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Gunslinger", "Kit: Gunslinger", "Revolver, pistol, Double Trouble.", 250, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Demolitions", "Kit: Demolitions", "SMG, frag grenades, Glutton for War.", 300, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Juggernaut", "Kit: Juggernaut", "Light machine gun, pistol, Painkiller.", 350, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Reroll", "Fixer Contacts I", "+1 free reroll every act.", 200, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Reroll2", "Fixer Contacts II", "+1 more free reroll every act.", 450, n"perk.Reroll"));
    ArrayPush(list, RLMeta.Def(n"perk.FourthChoice", "Wide Net", "Reward screens show 4 options.", 400, n""));
    ArrayPush(list, RLMeta.Def(n"perk.FourthDoor", "Street Map", "Choose between 4 doors instead of 3.", 350, n""));
    ArrayPush(list, RLMeta.Def(n"perk.StarterPick", "Quartermaster", "Every run opens with an Armory pick.", 300, n""));
    ArrayPush(list, RLMeta.Def(n"perk.StreetSmart", "Street Smart", "The Fixer charges 20% less.", 200, n""));
    ArrayPush(list, RLMeta.Def(n"perk.MedKit", "Med Kit", "Start every run with an Uncommon MaxDoc.", 150, n""));
    ArrayPush(list, RLMeta.Def(n"perk.HeadStart", "Head Start", "Start every run at level 3.", 300, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Vitality1", "Vitality I", "Start every run with Reinforced Frame.", 120, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Vitality2", "Vitality II", "A second stack of Reinforced Frame.", 240, n"perk.Vitality1"));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute1", "Edge I", "+1 to your kit's main attribute.", 100, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute2", "Edge II", "Another +1 to it.", 200, n"perk.Attribute1"));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute3", "Edge III", "Another +1 to it.", 350, n"perk.Attribute2"));
    return list;
  }

  private static func Def(id: CName, name: String, description: String, cost: Int32, requires: CName) -> ref<RLUnlockDef> {
    let def = new RLUnlockDef();
    def.id = id;
    def.name = name;
    def.description = description;
    def.cost = cost;
    def.requires = requires;
    return def;
  }

  public static func Get(id: CName) -> ref<RLUnlockDef> {
    for def in RLMeta.Unlocks() {
      if Equals(def.id, id) {
        return def;
      }
    }
    return null;
  }

  public static func CanBuy(service: ref<RogueliteService>, def: ref<RLUnlockDef>) -> Bool {
    if service.HasUnlock(def.id) {
      return false;
    }
    if IsNameValid(def.requires) && !service.HasUnlock(def.requires) {
      return false;
    }
    return service.GetCred() >= def.cost;
  }

  public static func TryBuy(service: ref<RogueliteService>, id: CName) -> Bool {
    let def = RLMeta.Get(id);
    if !IsDefined(def) || !RLMeta.CanBuy(service, def) {
      return false;
    }
    if !service.TrySpendCred(def.cost) {
      return false;
    }
    service.AddUnlock(def.id);
    return true;
  }

  public static func PerkActive(service: ref<RogueliteService>, id: CName) -> Bool {
    return service.HasUnlock(id);
  }

  public static func BonusAttributePoints(service: ref<RogueliteService>) -> Int32 {
    let bonus = 0;
    if RLMeta.PerkActive(service, n"perk.Attribute1") { bonus += 1; }
    if RLMeta.PerkActive(service, n"perk.Attribute2") { bonus += 1; }
    if RLMeta.PerkActive(service, n"perk.Attribute3") { bonus += 1; }
    return bonus;
  }

  // Free reroll charges per act (Rewards and doors): one for everyone, more
  // with the Fixer Contacts unlocks. Out of charges, rerolls cost eddies.
  public static func RerollsPerAct(service: ref<RogueliteService>) -> Int32 {
    let charges = 1;
    if RLMeta.PerkActive(service, n"perk.Reroll") { charges += 1; }
    if RLMeta.PerkActive(service, n"perk.Reroll2") { charges += 1; }
    return charges;
  }

  // Cred for a cleared arena: more for later acts, harder fights and bosses.
  public static func ArenaCred(act: Int32, threat: Int32, boss: Bool) -> Int32 {
    let cred = 6 + act * 4 + threat * 3;
    if boss {
      cred += 30;
    }
    return cred;
  }

  public static func VictoryCred() -> Int32 = 150

  // --- Kits -------------------------------------------------------------------------

  public static func Kits() -> array<CName> {
    return [n"Solo", n"Blade", n"Netrunner", n"Marksman", n"Brawler", n"Gunslinger", n"Demolitions", n"Juggernaut"];
  }

  public static func KitName(kit: CName) -> String = NameToString(kit)

  public static func KitDescription(kit: CName) -> String {
    switch kit {
      case n"Solo": return "Assault rifle, pistol, Ready, Rested, Reloaded.";
      case n"Blade": return "Katana, pistol, Lead and Steel.";
      case n"Netrunner": return "Cyberdeck, two quickhacks, pistol, Optimization.";
      case n"Marksman": return "Precision or sniper rifle, pistol, Focus.";
      case n"Brawler": return "Gorilla Arms, shotgun, Die! Die! Die!";
      case n"Gunslinger": return "Revolver, pistol, Double Trouble.";
      case n"Demolitions": return "SMG, frag grenades, Glutton for War.";
      case n"Juggernaut": return "Light machine gun, pistol, Painkiller.";
    }
    return "";
  }

  public static func IsKitAvailable(service: ref<RogueliteService>, kit: CName) -> Bool {
    if Equals(kit, n"Solo") || Equals(kit, n"Blade") {
      return true;
    }
    return service.HasUnlock(StringToName("kit." + NameToString(kit)));
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - meta progression
// -----------------------------------------------------------------------------
// Cred is earned at the end of every run (flatline or victory) and spent at the
// hub terminal. In roguelike mode unlock perks are ignored for the run, but
// Cred is still earned (at a 50% bonus) and kits remain usable.
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
  public static func Unlocks() -> array<ref<RLUnlockDef>> {
    let list: array<ref<RLUnlockDef>>;
    ArrayPush(list, RLMeta.Def(n"kit.Netrunner", "Kit: Netrunner", "Start with a cyberdeck, two quickhacks and a pistol.", 150, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Marksman", "Kit: Marksman", "Start with a precision or sniper rifle and a pistol.", 150, n""));
    ArrayPush(list, RLMeta.Def(n"kit.Brawler", "Kit: Brawler", "Start with Gorilla Arms and a shotgun.", 250, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute1", "Edge I", "+1 starting attribute point.", 100, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute2", "Edge II", "+1 more starting attribute point.", 200, n"perk.Attribute1"));
    ArrayPush(list, RLMeta.Def(n"perk.Attribute3", "Edge III", "+1 more starting attribute point.", 350, n"perk.Attribute2"));
    ArrayPush(list, RLMeta.Def(n"perk.Vitality1", "Vitality I", "Start every run with Reinforced Frame.", 120, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Vitality2", "Vitality II", "Start with a second stack of Reinforced Frame.", 240, n"perk.Vitality1"));
    ArrayPush(list, RLMeta.Def(n"perk.HeadStart", "Head Start", "Start every run at level 3.", 300, n""));
    ArrayPush(list, RLMeta.Def(n"perk.Reroll", "Fixer Contacts", "One reward reroll per floor.", 200, n""));
    ArrayPush(list, RLMeta.Def(n"perk.FourthChoice", "Wide Net", "Reward picks show 4 options.", 400, n""));
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

  // Unlock perks only apply outside roguelike mode.
  public static func PerkActive(service: ref<RogueliteService>, id: CName) -> Bool {
    return !service.IsRoguelikeMode() && service.HasUnlock(id);
  }

  public static func BonusAttributePoints(service: ref<RogueliteService>) -> Int32 {
    let bonus = 0;
    if RLMeta.PerkActive(service, n"perk.Attribute1") { bonus += 1; }
    if RLMeta.PerkActive(service, n"perk.Attribute2") { bonus += 1; }
    if RLMeta.PerkActive(service, n"perk.Attribute3") { bonus += 1; }
    return bonus;
  }

  public static func Payout(floorsCleared: Int32, kills: Int32, bossesKilled: Int32, victory: Bool, roguelike: Bool) -> Int32 {
    let cred = floorsCleared * 10 + kills + bossesKilled * 25;
    if victory {
      cred += 150;
    }
    if roguelike {
      cred = cred * 3 / 2;
    }
    return cred;
  }

  // --- Kits -------------------------------------------------------------------------

  public static func Kits() -> array<CName> {
    return [n"Solo", n"Blade", n"Netrunner", n"Marksman", n"Brawler"];
  }

  public static func KitName(kit: CName) -> String {
    switch kit {
      case n"Solo": return "Solo";
      case n"Blade": return "Blade";
      case n"Netrunner": return "Netrunner";
      case n"Marksman": return "Marksman";
      case n"Brawler": return "Brawler";
    }
    return NameToString(kit);
  }

  public static func KitDescription(kit: CName) -> String {
    switch kit {
      case n"Solo": return "Assault rifle and pistol.";
      case n"Blade": return "Katana and pistol.";
      case n"Netrunner": return "Cyberdeck, two quickhacks, pistol.";
      case n"Marksman": return "Precision or sniper rifle and pistol.";
      case n"Brawler": return "Gorilla Arms and shotgun.";
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

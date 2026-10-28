// -----------------------------------------------------------------------------
// Night City Roguelite - meta progression
// -----------------------------------------------------------------------------
// Two currencies, kept outside saves (RogueliteService):
//
//   CRED     every cleared arena (never a lost one) and a won run; spent on
//            the terminal's upgrades (Meta/Terminal.reds).
//   FAVORS   what fixers owe V for putting bosses down: one per boss, one
//            more for winning, and one the first time V reaches Act 2, Act 3
//            and the end. Spent on kits in the armory, priced like Hades'
//            weapons: the first comes in a few runs, the last is a long goal
//            (30 favors for all seven, around 20 runs).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLUnlockDef {
  public let id: CName;
  public let name: String;
  public let description: String;
  // Kits: favors.
  public let cost: Int32;
}

public abstract class RLMeta {
  // The kits to call in. Unlock IDs are stored on disk: never rename them.
  public static func Unlocks() -> array<ref<RLUnlockDef>> {
    let list: array<ref<RLUnlockDef>>;
    ArrayPush(list, RLMeta.Def(n"kit.Netrunner", "Kit: Netrunner", 2));
    ArrayPush(list, RLMeta.Def(n"kit.Marksman", "Kit: Marksman", 2));
    ArrayPush(list, RLMeta.Def(n"kit.Gunslinger", "Kit: Gunslinger", 3));
    ArrayPush(list, RLMeta.Def(n"kit.Juggernaut", "Kit: Juggernaut", 4));
    ArrayPush(list, RLMeta.Def(n"kit.Demolitions", "Kit: Demolitions", 5));
    ArrayPush(list, RLMeta.Def(n"kit.Brawler", "Kit: Brawler", 6));
    ArrayPush(list, RLMeta.Def(n"kit.Wireman", "Kit: Wireman", 8));
    return list;
  }

  private static func Def(id: CName, const name: String, cost: Int32) -> ref<RLUnlockDef> {
    let def = new RLUnlockDef();
    def.id = id;
    def.name = name;
    def.cost = cost;
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

  // Unlocks that no longer exist (levels and flat health went with the
  // level-ups): whoever bought one gets the Cred back. Returns the refund.
  public static func RefundRetired(service: ref<RogueliteService>) -> Int32 {
    let ids = [n"perk.HeadStart", n"perk.Vitality1", n"perk.Vitality2"];
    let costs = [300, 120, 240];
    let refund = 0;
    let i = 0;
    while i < ArraySize(ids) {
      if service.RefundUnlock(ids[i], costs[i]) {
        refund += costs[i];
      }
      i += 1;
    }
    if refund > 0 {
      RLLog(s"Refunded \(refund) Cred for retired unlocks.");
    }
    return refund;
  }

  public static func CanBuy(service: ref<RogueliteService>, def: ref<RLUnlockDef>) -> Bool {
    return !service.HasUnlock(def.id) && service.GetFavors() >= def.cost;
  }

  public static func TryBuy(service: ref<RogueliteService>, id: CName) -> Bool {
    let def = RLMeta.Get(id);
    if !IsDefined(def) || !RLMeta.CanBuy(service, def) || !service.TrySpendFavors(def.cost) {
      return false;
    }
    service.AddUnlock(def.id);
    return true;
  }

  // --- Favors ----------------------------------------------------------------------------

  // A boss down (or the run won): what the fixers owe V, plus the firsts.
  // Returns the favors paid. Test runs pay nothing.
  public static func PayFavors(service: ref<RogueliteService>, run: ref<RLRunState>, won: Bool) -> Int32 {
    if run.isTest {
      return 0;
    }
    let paid = 1;
    if won {
      paid += 1 + RLMeta.First(service, n"milestone.Win");
    } else if run.act == 1 {
      paid += RLMeta.First(service, n"milestone.Act2");
    } else if run.act == 2 {
      paid += RLMeta.First(service, n"milestone.Act3");
    }
    service.AddFavors(paid);
    run.favorsEarned += paid;
    RLLog(s"Favors: +\(paid) (now \(service.GetFavors())).");
    return paid;
  }

  // 1 the first time a milestone is reached.
  private static func First(service: ref<RogueliteService>, id: CName) -> Int32 {
    if service.HasUnlock(id) {
      return 0;
    }
    service.AddUnlock(id);
    return 1;
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
    return [n"Solo", n"Blade", n"Netrunner", n"Marksman", n"Brawler", n"Gunslinger", n"Demolitions", n"Juggernaut", n"Wireman"];
  }

  public static func KitName(kit: CName) -> String = NameToString(kit)

  // One line of attitude above the loadout.
  public static func KitTagline(kit: CName) -> String {
    switch kit {
      case n"Solo": return "Point. Shoot. Repeat.";
      case n"Blade": return "Get close. Stay close.";
      case n"Netrunner": return "Fry 'em from across the room.";
      case n"Marksman": return "Pick your shots.";
      case n"Brawler": return "Fists first. Questions never.";
      case n"Gunslinger": return "Two guns, no waiting.";
      case n"Demolitions": return "Everything's a fuse.";
      case n"Juggernaut": return "Walk it in. Don't stop.";
      case n"Wireman": return "Whip, hack, repeat.";
    }
    return "";
  }

  public static func KitDescription(kit: CName) -> String {
    switch kit {
      case n"Solo": return "Assault rifle, pistol, Ready, Rested, Reloaded.";
      case n"Blade": return "Katana, pistol, Lead and Steel.";
      case n"Netrunner": return "Cyberdeck as the main, two quickhacks, pistol, Optimization.";
      case n"Marksman": return "Precision or sniper rifle, pistol, Focus.";
      case n"Brawler": return "Gorilla Arms as the main, pistol, Wrecking Ball.";
      case n"Gunslinger": return "Revolver, pistol, Double Trouble.";
      case n"Demolitions": return "Projectile Launcher as the main, SMG, frag grenades, Glutton for War.";
      case n"Juggernaut": return "Light machine gun, pistol, Painkiller.";
      case n"Wireman": return "Monowire as the main, cyberdeck, a quickhack, pistol, Siphon.";
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

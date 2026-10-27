// -----------------------------------------------------------------------------
// Night City Roguelite - level-ups
// -----------------------------------------------------------------------------
// The small pick after every floor (the door's reward is the big one): one
// card of three, each deepening what V already has, and the level that comes
// with it.
//
//   attribute   +1 to one of V's two best attributes (or another, rarely)
//   perk        from a perk tree V is already in
//   third card  an evolution when a weapon is ready for one; otherwise a
//               weapon mod, a quality step for an equipped weapon, a boon one
//               rarity up, or cyberware capacity
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLLevelUp {
  public static func Offers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let attribute = RLLevelUp.AttributeOffer(player);
    if IsDefined(attribute) {
      ArrayPush(offers, attribute);
    }
    let perk = RLLevelUp.PerkOffer(player, run);
    if IsDefined(perk) {
      ArrayPush(offers, perk);
    }
    let third = RLLevelUp.ThirdOffer(player, pools, run);
    if IsDefined(third) {
      ArrayPush(offers, third);
    }
    // Never fewer than three cards: another attribute fills in.
    let guard = 0;
    while ArraySize(offers) < 3 && guard < 5 {
      let extra = RLLevelUp.AttributeOffer(player);
      if IsDefined(extra) && !RLLevelUp.HasStat(offers, extra.stat) {
        ArrayPush(offers, extra);
      }
      guard += 1;
    }
    return offers;
  }

  private static func HasStat(offers: array<ref<RLOffer>>, stat: gamedataStatType) -> Bool {
    for offer in offers {
      if Equals(offer.kind, RLOfferKind.Attribute) && Equals(offer.stat, stat) {
        return true;
      }
    }
    return false;
  }

  // --- Attributes ----------------------------------------------------------------------------

  public static func Attributes() -> array<gamedataStatType> {
    return [gamedataStatType.Strength, gamedataStatType.Reflexes, gamedataStatType.TechnicalAbility, gamedataStatType.Intelligence, gamedataStatType.Cool];
  }

  public static func AttributeName(stat: gamedataStatType) -> String {
    switch stat {
      case gamedataStatType.Strength: return "BODY";
      case gamedataStatType.Reflexes: return "REFLEXES";
      case gamedataStatType.TechnicalAbility: return "TECHNICAL ABILITY";
      case gamedataStatType.Intelligence: return "INTELLIGENCE";
      case gamedataStatType.Cool: return "COOL";
    }
    return "";
  }

  // What an attribute point does in 2.x, in a few words.
  public static func AttributeText(stat: gamedataStatType) -> String {
    switch stat {
      case gamedataStatType.Strength: return "Health, stamina, melee. Shotguns, LMGs, blunt weapons.";
      case gamedataStatType.Reflexes: return "Crit chance, mobility. Rifles, SMGs, blades.";
      case gamedataStatType.TechnicalAbility: return "Armor, chrome capacity. Tech weapons, explosives.";
      case gamedataStatType.Intelligence: return "RAM, quickhack damage. Netrunning, smart guns, monowire.";
      case gamedataStatType.Cool: return "Crit damage, stealth. Pistols, precision rifles, throwing.";
    }
    return "";
  }

  public static func AttributeValue(player: ref<PlayerPuppet>, stat: gamedataStatType) -> Int32 {
    return RoundF(GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), stat));
  }

  // The best attribute half the time, the second best a third of the time,
  // any other otherwise; never one already at 20.
  public static func AttributeOffer(player: ref<PlayerPuppet>) -> ref<RLOffer> {
    let ranked: array<gamedataStatType>;
    for stat in RLLevelUp.Attributes() {
      if RLLevelUp.AttributeValue(player, stat) < 20 {
        let i = 0;
        while i < ArraySize(ranked) && RLLevelUp.AttributeValue(player, ranked[i]) >= RLLevelUp.AttributeValue(player, stat) {
          i += 1;
        }
        ArrayInsert(ranked, i, stat);
      }
    }
    if ArraySize(ranked) == 0 {
      return null;
    }
    let roll = RandF();
    let index = roll < 0.5 ? 0 : (roll < 0.83 ? 1 : RandRange(2, Max(3, ArraySize(ranked))));
    let stat = ranked[Min(index, ArraySize(ranked) - 1)];
    let value = RLLevelUp.AttributeValue(player, stat);
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Attribute;
    offer.stat = stat;
    offer.title = RLLevelUp.AttributeName(stat) + " +1";
    offer.subtitle = s"ATTRIBUTE - \(value) > \(value + 1)";
    offer.description = RLLevelUp.AttributeText(stat) + (value + 1 == 15 ? " Hits 15: signature perks open up." : "");
    offer.step = 4;
    return offer;
  }

  // --- Perks -----------------------------------------------------------------------------------

  // The tree a perk sits in: its attribute and branch ("Reflexes_Left").
  public static func TreeOf(perk: gamedataNewPerkType) -> String {
    let name = EnumValueToString("gamedataNewPerkType", Cast<Int64>(EnumInt(perk)));
    let first = StrFindFirst(name, "_");
    if first < 0 {
      return name;
    }
    let rest = StrMid(name, first + 1);
    let second = StrFindFirst(rest, "_");
    return second < 0 ? name : StrLeft(name, first + 1 + second);
  }

  public static func AttributeOf(perk: gamedataNewPerkType) -> String {
    let name = EnumValueToString("gamedataNewPerkType", Cast<Int64>(EnumInt(perk)));
    let first = StrFindFirst(name, "_");
    return first < 0 ? name : StrLeft(name, first);
  }

  // A perk from a tree V already has a perk in (Master and in-between perks
  // count for their attribute); any perk when there is none.
  public static func PerkOffer(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> ref<RLOffer> {
    let data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return null;
    }
    let profile = RLBuildProfile.Read(player);
    let trees: array<String>;
    let attributes: array<String>;
    for def in RLPerkCatalog.All() {
      if RLPerkCatalog.IsOwned(data, def.perk) {
        ArrayPush(trees, RLLevelUp.TreeOf(def.perk));
        ArrayPush(attributes, RLLevelUp.AttributeOf(def.perk));
      }
    }
    let expected = RLPerkCatalog.ExpectedPower(run.Depth(), run.TotalFloors());
    let candidates: array<ref<RLPerkDef>>;
    for def in RLPerkCatalog.All() {
      let tree = RLLevelUp.TreeOf(def.perk);
      let inTree = ArrayContains(trees, tree) || ((StrContains(tree, "Master") || StrContains(tree, "Inbetween")) && ArrayContains(attributes, RLLevelUp.AttributeOf(def.perk)));
      if inTree && def.power <= expected + 1 && !ArrayContains(run.banished, "perk:" + EnumValueToString("gamedataNewPerkType", Cast<Int64>(EnumInt(def.perk))))
        && RLPerkCatalog.IsOfferable(data, def, profile) {
        ArrayPush(candidates, def);
      }
    }
    if ArraySize(candidates) == 0 {
      let none: array<gamedataNewPerkType>;
      let any = RLPerkCatalog.Pick(player, run, profile, 1, false, none);
      return ArraySize(any) > 0 ? RLRewards.PerkOffer(run, any[0]) : null;
    }
    let total = 0.0;
    for def in candidates {
      total += RLPerkCatalog.Weight(def, expected, profile);
    }
    let roll = RandRangeF(0.0, total);
    for def in candidates {
      roll -= RLPerkCatalog.Weight(def, expected, profile);
      if roll <= 0.0 {
        return RLRewards.PerkOffer(run, def);
      }
    }
    return RLRewards.PerkOffer(run, candidates[ArraySize(candidates) - 1]);
  }

  // --- The third card ---------------------------------------------------------------------------

  private static func ThirdOffer(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> ref<RLOffer> {
    let evolutions = RLRewards.EvolveOffers(player, pools, run, 1);
    if ArraySize(evolutions) > 0 {
      return evolutions[0];
    }
    let roll = RandF();
    if roll < 0.35 {
      let mods = RLWeaponMods.Offers(player, run, 1);
      if ArraySize(mods) > 0 {
        return mods[0];
      }
    }
    if roll < 0.55 {
      let boon = RLLevelUp.BoonUpgradeOffer(run);
      if IsDefined(boon) {
        return boon;
      }
    }
    if roll < 0.70 && (run.overclock > 0 || RLStyles.Rank(run, RLStyle.Netrunner()) > 0 || RandF() < 0.5) {
      return RLLevelUp.CapacityOffer(run);
    }
    let tuneUps = RLRewards.WeaponUpgradeOffers(player, 1, 1);
    if ArraySize(tuneUps) > 0 {
      return tuneUps[0];
    }
    return RLLevelUp.CapacityOffer(run);
  }

  public static func BoonUpgradeOffer(run: ref<RLRunState>) -> ref<RLOffer> {
    let ids: array<CName>;
    for owned in run.boons {
      let boon = RLBoons.Get(owned.id);
      if IsDefined(boon) && owned.rarity < RLBoons.HighestRarity(boon) && !ArrayContains(run.banished, "boon:" + NameToString(owned.id)) {
        ArrayPush(ids, owned.id);
      }
    }
    if ArraySize(ids) == 0 {
      return null;
    }
    let id = ids[RandRange(0, ArraySize(ids))];
    let def = RLBoons.Get(id);
    let state = RLBoons.Owned(run, id);
    let offer = new RLOffer();
    offer.kind = RLOfferKind.BoonUpgrade;
    offer.boon = id;
    offer.patron = def.patron;
    offer.rarity = state.rarity + 1;
    offer.title = def.name;
    offer.subtitle = RLBoons.RarityName(state.rarity) + " > " + RLBoons.RarityName(offer.rarity);
    offer.description = RLBoons.Text(def, offer.rarity);
    offer.tags = def.tags;
    offer.step = RLBoons.RarityStep(offer.rarity);
    offer.excitement = 1;
    return offer;
  }

  public static func CapacityAmount() -> Int32 = 4

  public static func CapacityOffer(run: ref<RLRunState>) -> ref<RLOffer> {
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Capacity;
    offer.amount = RLLevelUp.CapacityAmount();
    offer.title = s"Capacity +\(offer.amount)";
    offer.subtitle = "CYBERWARE CAPACITY";
    offer.description = run.overclock > 0
      ? s"Room for more chrome. Pays down your overclock (\(run.overclock) over)."
      : "Room for more chrome.";
    offer.step = 4;
    ArrayPush(offer.tags, n"chrome");
    return offer;
  }
}

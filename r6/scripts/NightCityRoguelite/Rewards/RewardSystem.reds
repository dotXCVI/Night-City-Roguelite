// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// After every cleared floor the player picks one of three (or four) offers.
// Offer kinds never repeat within one pick. Item quality and iconic chance
// scale with depth.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLOfferKind {
  Weapon = 0,
  Iconic = 1,
  Cyberware = 2,
  Quickhack = 3,
  Boon = 4,
  Levels = 5,
  AttributePoints = 6,
  PerkPoints = 7,
  Supplies = 8,
}

public class RLOffer {
  public let kind: RLOfferKind;
  public let record: TweakDBID;
  public let tier: CName;
  public let boon: CName;
  public let amount: Int32;
  public let title: String;
  public let subtitle: String;
  public let description: String;
  public let disabled: Bool;
}

public abstract class RLRewards {
  // --- Depth scaling ---------------------------------------------------------------

  public static func WeaponTier(depth: Int32) -> CName {
    if depth <= 2 { return n"Uncommon"; }
    if depth <= 4 { return n"UncommonPlus"; }
    if depth <= 6 { return n"Rare"; }
    if depth <= 8 { return n"RarePlus"; }
    if depth <= 10 { return n"Epic"; }
    if depth <= 12 { return n"EpicPlus"; }
    if depth <= 14 { return n"Legendary"; }
    return n"LegendaryPlus";
  }

  public static func Band(depth: Int32) -> Int32 {
    // 0..4 over a 15-floor run.
    return Min(4, (depth - 1) / 3);
  }

  public static func IconicChance(depth: Int32) -> Float {
    return 0.04 + Cast<Float>(depth) * 0.015;
  }

  // --- Rolling ---------------------------------------------------------------------

  public static func Roll(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let usedKinds: array<RLOfferKind>;
    let guard = 0;
    while ArraySize(offers) < count && guard < 40 {
      guard += 1;
      let kind = RLRewards.RollKind(run, pools);
      if ArrayContains(usedKinds, kind) {
        continue;
      }
      let offer = RLRewards.Build(player, pools, run, kind);
      if IsDefined(offer) {
        ArrayPush(offers, offer);
        ArrayPush(usedKinds, kind);
      }
    }
    return offers;
  }

  private static func RollKind(run: ref<RLRunState>, pools: ref<RLTweakPools>) -> RLOfferKind {
    let depth = run.Depth();
    if RandF() < RLRewards.IconicChance(depth) {
      return RLOfferKind.Iconic;
    }
    // Weighted table.
    let weights: array<Int32> = [22, 0, 22, 0, 22, 8, 8, 10, 8];
    if pools.HasQuickhacks() {
      weights[3] = 8; // RLOfferKind.Quickhack
    }
    let total = 0;
    for w in weights {
      total += w;
    }
    let roll = RandRange(0, total);
    let i = 0;
    while i < ArraySize(weights) {
      if roll < weights[i] {
        return IntEnum<RLOfferKind>(i);
      }
      roll -= weights[i];
      i += 1;
    }
    return RLOfferKind.Boon;
  }

  private static func Build(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, kind: RLOfferKind) -> ref<RLOffer> {
    let depth = run.Depth();
    let offer = new RLOffer();
    offer.kind = kind;
    let noIDs: array<TweakDBID>;
    let noTypes: array<gamedataItemType>;
    switch kind {
      case RLOfferKind.Weapon:
        offer.record = pools.PickWeapon(noTypes);
        offer.tier = RLRewards.WeaponTier(depth);
        if !TDBID.IsValid(offer.record) {
          return null;
        }
        offer.title = RLRewards.ItemName(offer.record);
        offer.subtitle = "WEAPON - " + NameToString(offer.tier);
        offer.description = RLRewards.ItemTypeName(offer.record);
        break;
      case RLOfferKind.Iconic:
        offer.record = pools.PickIconic();
        offer.tier = RLRewards.WeaponTier(depth + 2);
        if !TDBID.IsValid(offer.record) {
          return null;
        }
        offer.title = RLRewards.ItemName(offer.record);
        offer.subtitle = "ICONIC WEAPON";
        offer.description = RLRewards.ItemTypeName(offer.record);
        break;
      case RLOfferKind.Cyberware:
        offer.record = pools.PickCyberware(RLRewards.Band(depth), false, gamedataItemType.Invalid, noIDs);
        if !TDBID.IsValid(offer.record) {
          return null;
        }
        offer.title = RLRewards.ItemName(offer.record);
        let cost = RLGear.CapacityCost(player, offer.record);
        let available = RLGear.CapacityAvailable(player);
        offer.subtitle = s"CYBERWARE - capacity \(RoundF(cost))";
        offer.disabled = cost > available;
        offer.description = offer.disabled
          ? s"Not enough capacity (\(RoundF(available)) free)."
          : "Installed immediately.";
        break;
      case RLOfferKind.Quickhack:
        offer.record = pools.PickQuickhack(RLRewards.Band(depth), noIDs);
        if !TDBID.IsValid(offer.record) {
          return null;
        }
        offer.title = RLRewards.ItemName(offer.record);
        offer.subtitle = "QUICKHACK";
        offer.description = "Needs a cyberdeck to use.";
        break;
      case RLOfferKind.Boon:
        let boon = RLRewards.PickBoon(run);
        if !IsDefined(boon) {
          return null;
        }
        offer.boon = boon.id;
        offer.title = boon.name;
        offer.subtitle = s"BOON - \(run.BoonStacks(boon.id) + 1)/\(boon.maxStacks)";
        offer.description = boon.description;
        break;
      case RLOfferKind.Levels:
        offer.amount = depth >= 8 ? 3 : 2;
        offer.title = s"+\(offer.amount) Levels";
        offer.subtitle = "EXPERIENCE";
        offer.description = "Gain levels instantly, with their perk and attribute points.";
        break;
      case RLOfferKind.AttributePoints:
        offer.amount = 2;
        offer.title = "+2 Attribute Points";
        offer.subtitle = "TRAINING";
        offer.description = "Spend them in the Character menu.";
        break;
      case RLOfferKind.PerkPoints:
        offer.amount = depth >= 8 ? 4 : 3;
        offer.title = s"+\(offer.amount) Perk Points";
        offer.subtitle = "TRAINING";
        offer.description = "Spend them in the Character menu.";
        break;
      case RLOfferKind.Supplies:
        offer.amount = 300 + depth * 150;
        offer.title = "Supply Drop";
        offer.subtitle = "SUPPLIES";
        offer.description = s"3 heals, 3 grenades, \(offer.amount) eddies.";
        break;
    }
    return offer;
  }

  private static func PickBoon(run: ref<RLRunState>) -> ref<RLBoonDef> {
    let candidates: array<ref<RLBoonDef>>;
    let total = 0;
    for def in RLBoons.All() {
      if run.BoonStacks(def.id) < def.maxStacks {
        ArrayPush(candidates, def);
        total += def.weight;
      }
    }
    if total == 0 {
      return null;
    }
    let roll = RandRange(0, total);
    for def in candidates {
      if roll < def.weight {
        return def;
      }
      roll -= def.weight;
    }
    return candidates[0];
  }

  // --- Granting ----------------------------------------------------------------------

  public static func Grant(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, offer: ref<RLOffer>) {
    switch offer.kind {
      case RLOfferKind.Weapon:
      case RLOfferKind.Iconic:
        RLGear.GiveWeapon(player, offer.record, offer.tier, false);
        break;
      case RLOfferKind.Cyberware:
        RLGear.InstallCyberware(player, offer.record);
        break;
      case RLOfferKind.Quickhack:
        RLGear.GiveQuickhacks(player, [offer.record]);
        break;
      case RLOfferKind.Boon:
        ArrayPush(run.boons, offer.boon);
        RLBoons.ApplyStack(player, offer.boon, run);
        break;
      case RLOfferKind.Levels:
        PlayerDevelopmentSystem.GetData(player).RL_GrantLevels(offer.amount);
        break;
      case RLOfferKind.AttributePoints:
        PlayerDevelopmentSystem.GetData(player).AddDevelopmentPoints(offer.amount, gamedataDevelopmentPointType.Attribute);
        PlayerDevelopmentSystem.GetData(player).UpdateUIBB();
        break;
      case RLOfferKind.PerkPoints:
        PlayerDevelopmentSystem.GetData(player).AddDevelopmentPoints(offer.amount, gamedataDevelopmentPointType.Primary);
        PlayerDevelopmentSystem.GetData(player).UpdateUIBB();
        break;
      case RLOfferKind.Supplies:
        RLGear.GiveStack(player, pools.PickHealing(), 3);
        RLGear.GiveStack(player, pools.PickGrenade(), 3);
        RLGear.GiveEddies(player, offer.amount);
        break;
    }
    RLLog(s"Reward granted: \(offer.title)");
  }

  // --- Names -------------------------------------------------------------------------

  public static func ItemName(record: TweakDBID) -> String {
    let item = TweakDBInterface.GetItemRecord(record);
    if IsDefined(item) {
      let name = GetLocalizedTextByKey(item.DisplayName());
      if StrLen(name) > 0 {
        return name;
      }
    }
    return "Unknown item";
  }

  public static func ItemTypeName(record: TweakDBID) -> String {
    let item = TweakDBInterface.GetItemRecord(record);
    if IsDefined(item) && IsDefined(item.ItemType()) {
      let name = GetLocalizedText(UIItemsHelper.GetItemTypeKey(item.ItemType().Type()));
      if StrLen(name) > 0 {
        return name;
      }
    }
    return "";
  }
}

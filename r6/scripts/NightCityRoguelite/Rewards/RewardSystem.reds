// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// Hades-style: between arenas the player picks the next fight by its reward
// type (a "door"). The reward type sets how hard the fight is: training is a
// light fight, chrome and iconics are heavy ones. Clearing the arena then
// offers three (or four) rewards of that type to choose from. Item quality
// scales with depth and with the fight's threat.
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

public enum RLRewardCategory {
  Armory = 0,
  Chrome = 1,
  Daemons = 2,
  Boons = 3,
  Training = 4,
  Iconic = 5,
}

// One choice for the next fight.
public class RLDoor {
  public let category: RLRewardCategory;
  public let threat: Int32;
  public let arena: CName;
  public let boss: Bool;
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

  // --- Categories (doors) -----------------------------------------------------------

  public static func CategoryName(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "ARMORY";
      case RLRewardCategory.Chrome: return "CHROME";
      case RLRewardCategory.Daemons: return "DAEMONS";
      case RLRewardCategory.Boons: return "BOONS";
      case RLRewardCategory.Training: return "TRAINING";
      case RLRewardCategory.Iconic: return "ICONIC";
    }
    return "REWARD";
  }

  public static func CategoryDescription(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "Pick a new weapon";
      case RLRewardCategory.Chrome: return "Pick cyberware, installed on the spot";
      case RLRewardCategory.Daemons: return "Pick a quickhack";
      case RLRewardCategory.Boons: return "Pick a run-only bonus";
      case RLRewardCategory.Training: return "Pick levels, attribute points or perk points";
      case RLRewardCategory.Iconic: return "Pick an iconic weapon";
    }
    return "";
  }

  // 1 = light, 2 = standard, 3 = heavy.
  public static func CategoryThreat(category: RLRewardCategory) -> Int32 {
    switch category {
      case RLRewardCategory.Training: return 1;
      case RLRewardCategory.Chrome:
      case RLRewardCategory.Iconic: return 3;
    }
    return 2;
  }

  public static func ThreatName(threat: Int32) -> String {
    if threat <= 1 {
      return "LIGHT";
    }
    if threat >= 3 {
      return "HEAVY";
    }
    return "STANDARD";
  }

  public static func ThreatDescription(threat: Int32) -> String {
    if threat <= 1 {
      return "Fewer, weaker enemies.";
    }
    if threat >= 3 {
      return "Bigger waves, tougher enemies, an extra wave.";
    }
    return "A regular fight.";
  }

  // Doors for the next floor: one boss door before a boss floor, otherwise
  // three different reward types, each in a different arena.
  public static func RollDoors(pools: ref<RLTweakPools>, run: ref<RLRunState>, lastArena: CName) -> array<ref<RLDoor>> {
    let doors: array<ref<RLDoor>>;
    let usedArenas: array<CName>;
    ArrayPush(usedArenas, lastArena);
    if run.IsBossFloor() {
      let boss = new RLDoor();
      boss.category = RandF() < 0.5 ? RLRewardCategory.Iconic : RLRewardCategory.Chrome;
      boss.threat = 3;
      boss.boss = true;
      boss.arena = RLRewards.PickArena(usedArenas);
      ArrayPush(doors, boss);
      return doors;
    }
    if run.floorsCleared == 0 {
      // The first fight of a run is always a light Training fight.
      let first = new RLDoor();
      first.category = RLRewardCategory.Training;
      first.threat = 1;
      first.arena = RLRewards.PickArena(usedArenas);
      ArrayPush(doors, first);
      return doors;
    }
    let count = 3;
    let used: array<RLRewardCategory>;
    let guard = 0;
    while ArraySize(doors) < count && guard < 40 {
      guard += 1;
      let category = RLRewards.RollCategory(pools, run);
      if !ArrayContains(used, category) {
        ArrayPush(used, category);
        let door = new RLDoor();
        door.category = category;
        door.threat = RLRewards.CategoryThreat(category);
        door.arena = RLRewards.PickArena(usedArenas);
        ArrayPush(usedArenas, door.arena);
        ArrayPush(doors, door);
      }
    }
    return doors;
  }

  private static func RollCategory(pools: ref<RLTweakPools>, run: ref<RLRunState>) -> RLRewardCategory {
    // The very first fight is never a heavy one.
    let first = run.floorsCleared == 0;
    if !first && RandF() < 0.12 {
      return RLRewardCategory.Iconic;
    }
    // Armory, Chrome, Daemons, Boons, Training
    let weights: array<Int32> = [24, first ? 0 : 22, pools.HasQuickhacks() && !first ? 12 : 0, 24, 18];
    let total = 0;
    for w in weights {
      total += w;
    }
    let roll = RandRange(0, total);
    let i = 0;
    while i < ArraySize(weights) {
      if roll < weights[i] {
        return IntEnum<RLRewardCategory>(i);
      }
      roll -= weights[i];
      i += 1;
    }
    return RLRewardCategory.Boons;
  }

  public static func PickArena(exclude: array<CName>) -> CName {
    let candidates: array<CName>;
    let all: array<CName>;
    for arena in RLArenas.Enabled() {
      ArrayPush(all, arena.id);
      if !ArrayContains(exclude, arena.id) {
        ArrayPush(candidates, arena.id);
      }
    }
    if ArraySize(candidates) == 0 {
      candidates = all;
    }
    if ArraySize(candidates) == 0 {
      return n"";
    }
    return candidates[RandRange(0, ArraySize(candidates))];
  }

  // The offers for a cleared fight: all of the door's reward type.
  public static func RollForCategory(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let records: array<TweakDBID>;
    let boons: array<CName>;
    let bonus = threat - 2;
    if Equals(category, RLRewardCategory.Training) {
      let kinds = [RLOfferKind.Levels, RLOfferKind.AttributePoints, RLOfferKind.PerkPoints];
      for kind in kinds {
        let offer = RLRewards.Build(player, pools, run, kind, bonus);
        if IsDefined(offer) {
          ArrayPush(offers, offer);
        }
      }
      return offers;
    }
    let guard = 0;
    while ArraySize(offers) < count && guard < 30 {
      guard += 1;
      let kind = RLRewards.KindFor(category, run);
      let offer = RLRewards.Build(player, pools, run, kind, bonus);
      if IsDefined(offer) {
        let duplicate = (TDBID.IsValid(offer.record) && ArrayContains(records, offer.record))
          || (IsNameValid(offer.boon) && ArrayContains(boons, offer.boon));
        if !duplicate {
          ArrayPush(offers, offer);
          if TDBID.IsValid(offer.record) {
            ArrayPush(records, offer.record);
          }
          if IsNameValid(offer.boon) {
            ArrayPush(boons, offer.boon);
          }
        }
      }
    }
    if ArraySize(offers) == 0 && NotEquals(category, RLRewardCategory.Boons) {
      // Nothing of that type is available (e.g. no quickhacks): boons instead.
      return RLRewards.RollForCategory(player, pools, run, RLRewardCategory.Boons, threat, count);
    }
    return offers;
  }

  private static func KindFor(category: RLRewardCategory, run: ref<RLRunState>) -> RLOfferKind {
    switch category {
      case RLRewardCategory.Armory:
        return RandF() < RLRewards.IconicChance(run.Depth()) ? RLOfferKind.Iconic : RLOfferKind.Weapon;
      case RLRewardCategory.Chrome:
        return RLOfferKind.Cyberware;
      case RLRewardCategory.Daemons:
        return RLOfferKind.Quickhack;
      case RLRewardCategory.Iconic:
        return RLOfferKind.Iconic;
    }
    return RLOfferKind.Boon;
  }

  private static func Build(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, kind: RLOfferKind, bonus: Int32) -> ref<RLOffer> {
    // Heavier fights pay out better quality.
    let depth = Max(1, run.Depth() + bonus * 2);
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

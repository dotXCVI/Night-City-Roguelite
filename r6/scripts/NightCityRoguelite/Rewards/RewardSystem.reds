// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// Hades-style: between arenas the player picks the next fight by its reward
// type (a "door"). Each door shows the reward, the arena, the enemy faction
// and the threat - all the planning happens here, between fights:
//
//   TRAINING  perk cards (Rewards/PerkCatalog.reds)            light
//   ARMORY    weapons, grenades, sometimes an iconic           standard
//   BOONS     run-only bonuses (Rewards/Boons.reds)            standard
//   DAEMONS   quickhacks                                       standard
//   WORKSHOP  upgrade gear you own (floors 4 and 10)           standard
//   CHROME    cyberware, installed on the spot                 heavy
//   ICONIC    iconic weapons (rare door)                       heavy
//
// Heavy doors appear from floor 3. Before a boss floor there is a single boss
// door. Card quality, pity, spikes and build weighting are the reward
// director's (Rewards/Director.reds).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLOfferKind {
  Weapon = 0,
  Iconic = 1,
  Cyberware = 2,
  Quickhack = 3,
  Boon = 4,
  Perk = 5,
  Grenade = 6,
  WeaponUpgrade = 7,
  HealthUpgrade = 8,
}

public enum RLRewardCategory {
  Armory = 0,
  Chrome = 1,
  Daemons = 2,
  Boons = 3,
  Training = 4,
  Iconic = 5,
  Workshop = 6,
}

// One choice for the next fight.
public class RLDoor {
  public let category: RLRewardCategory;
  public let threat: Int32;
  public let arena: CName;
  public let faction: ref<RLFactionPool>;
  public let boss: Bool;
}

public class RLOffer {
  public let kind: RLOfferKind;
  public let record: TweakDBID;
  public let itemID: ItemID;
  public let perk: gamedataNewPerkType;
  public let tier: CName;
  public let step: Int32;
  public let boon: CName;
  public let tags: array<CName>;
  public let title: String;
  public let subtitle: String;
  public let description: String;
  public let disabled: Bool;
  // How far above the floor's expectation the card is (reward director).
  public let excitement: Int32;
}

public abstract class RLRewards {
  // --- Categories ----------------------------------------------------------------------

  public static func CategoryName(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "ARMORY";
      case RLRewardCategory.Chrome: return "CHROME";
      case RLRewardCategory.Daemons: return "DAEMONS";
      case RLRewardCategory.Boons: return "BOONS";
      case RLRewardCategory.Training: return "TRAINING";
      case RLRewardCategory.Iconic: return "ICONIC";
      case RLRewardCategory.Workshop: return "WORKSHOP";
    }
    return "REWARD";
  }

  public static func CategoryDescription(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "Pick a weapon or a grenade";
      case RLRewardCategory.Chrome: return "Pick cyberware, installed on the spot";
      case RLRewardCategory.Daemons: return "Pick a quickhack";
      case RLRewardCategory.Boons: return "Pick a run-only bonus";
      case RLRewardCategory.Training: return "Pick a perk";
      case RLRewardCategory.Iconic: return "Pick an iconic weapon";
      case RLRewardCategory.Workshop: return "Upgrade gear you already own";
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
    return threat >= 3 ? "HEAVY" : "STANDARD";
  }

  public static func ThreatDescription(threat: Int32) -> String {
    if threat <= 1 {
      return "Fewer, weaker enemies.";
    }
    return threat >= 3 ? "Bigger waves, tougher enemies, better rewards." : "A regular fight.";
  }

  // Iconics show up from floor 4 on, a little more often each floor.
  public static func IconicChance(depth: Int32) -> Float {
    return depth < 4 ? 0.0 : 0.02 + Cast<Float>(depth) * 0.01;
  }

  // Smart weapons are strong for new characters, so the weapon classes open
  // up as the run goes on: Tech from floor 4, Smart from floor 7.
  public static func AllowedEvolutions(depth: Int32) -> array<gamedataWeaponEvolution> {
    let allowed = [gamedataWeaponEvolution.Power, gamedataWeaponEvolution.Blade, gamedataWeaponEvolution.Blunt, gamedataWeaponEvolution.Throwable, gamedataWeaponEvolution.None];
    if depth >= 4 {
      ArrayPush(allowed, gamedataWeaponEvolution.Tech);
    }
    if depth >= 7 {
      ArrayPush(allowed, gamedataWeaponEvolution.Smart);
    }
    return allowed;
  }

  // Cyberware and quickhack quality bands (0 Common .. 4 Legendary).
  public static func BandForStep(step: Int32) -> Int32 = Clamp(step / 2, 0, 4)

  // --- Doors ---------------------------------------------------------------------------

  // Doors for the run's next floor: a single boss door before a boss floor, a
  // light Training fight first, otherwise `count` different reward types in
  // different arenas, each with its enemy faction already known.
  public static func RollDoors(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, lastArena: CName, count: Int32) -> array<ref<RLDoor>> {
    let doors: array<ref<RLDoor>>;
    let usedArenas: array<CName>;
    ArrayPush(usedArenas, lastArena);
    run.workshopShown = false;
    if run.IsBossFloor() {
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RandF() < 0.5 ? RLRewardCategory.Iconic : RLRewardCategory.Chrome, true, usedArenas));
      return doors;
    }
    if run.floorsCleared == 0 {
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Training, false, usedArenas));
      return doors;
    }
    let used: array<RLRewardCategory>;
    // The workshop is one of the doors on floors 4 and 10 (and once more on
    // the next floor if it was passed over), like Hades' Daedalus hammers.
    let depth = run.Depth();
    if depth == 4 || depth == 10 || run.workshopCarry {
      run.workshopShown = true;
      ArrayPush(used, RLRewardCategory.Workshop);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Workshop, false, usedArenas));
    }
    let profile = RLBuildProfile.Read(player);
    let guard = 0;
    while ArraySize(doors) < count && guard < 40 {
      guard += 1;
      let category = RLRewards.RollCategory(pools, run, profile);
      if !ArrayContains(used, category) {
        ArrayPush(used, category);
        ArrayPush(doors, RLRewards.MakeDoor(pools, run, category, false, usedArenas));
      }
    }
    return doors;
  }

  private static func MakeDoor(pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, boss: Bool, out usedArenas: array<CName>) -> ref<RLDoor> {
    let door = new RLDoor();
    door.category = category;
    door.threat = boss ? 3 : RLRewards.CategoryThreat(category);
    door.boss = boss;
    door.arena = RLRewards.PickArena(usedArenas);
    ArrayPush(usedArenas, door.arena);
    let arena = RLArenas.Get(door.arena);
    if IsDefined(arena) {
      door.faction = pools.PickFactionPreferred(arena.factions, run.act >= 3);
    }
    return door;
  }

  private static func RollCategory(pools: ref<RLTweakPools>, run: ref<RLRunState>, profile: ref<RLBuildProfile>) -> RLRewardCategory {
    // No heavy fights (Chrome, Iconic) before floor 3.
    let early = run.Depth() < 3;
    if !early && RandF() < 0.10 {
      return RLRewardCategory.Iconic;
    }
    // Daemons doors show up more for netrunner builds.
    let daemons = 0;
    if pools.HasQuickhacks() && !early {
      daemons = 10 + RoundF(10.0 * MinF(profile.Weight(n"netrunner"), 3.0) / 3.0);
    }
    // Armory, Chrome, Daemons, Boons, Training
    let weights: array<Int32> = [26, early ? 0 : 20, daemons, 24, 20];
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

  // --- Offers --------------------------------------------------------------------------

  // The reward screen for a cleared fight: all of the door's reward type.
  public static func RollForCategory(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, count: Int32) -> array<ref<RLOffer>> {
    let profile = RLBuildProfile.Read(player);
    let spike = RLRewardDirector.SpikeDue(run);
    let offers: array<ref<RLOffer>>;
    switch category {
      case RLRewardCategory.Training:
        offers = RLRewards.PerkOffers(player, run, profile, count, spike);
        break;
      case RLRewardCategory.Workshop:
        offers = RLRewards.WorkshopOffers(player, run, count);
        break;
      default:
        offers = RLRewards.ItemOffers(player, pools, run, category, threat, count, profile, spike);
    }
    if ArraySize(offers) == 0 && NotEquals(category, RLRewardCategory.Boons) {
      // Nothing of that type is available: boons instead.
      offers = RLRewards.ItemOffers(player, pools, run, RLRewardCategory.Boons, threat, count, profile, false);
    }
    RLRewards.KeepOneOffBuild(player, pools, run, category, threat, profile, offers);
    RLRewardDirector.AfterRoll(run, offers, profile);
    return offers;
  }

  private static func ItemOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, count: Int32, profile: ref<RLBuildProfile>, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let guard = 0;
    while ArraySize(offers) < count && guard < 30 {
      guard += 1;
      let kind = RLRewards.KindFor(category, run);
      // The spike goes on the first card.
      let offer = RLRewards.BuildOffer(player, pools, run, kind, threat, profile, spike && ArraySize(offers) == 0);
      if IsDefined(offer) && !RLRewards.IsDuplicate(offers, offer) {
        ArrayPush(offers, offer);
      }
    }
    return offers;
  }

  private static func PerkOffers(player: ref<PlayerPuppet>, run: ref<RLRunState>, profile: ref<RLBuildProfile>, count: Int32, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let none: array<gamedataNewPerkType>;
    for def in RLPerkCatalog.Pick(player, run, profile, count, spike, none) {
      ArrayPush(offers, RLRewards.PerkOffer(run, def));
    }
    return offers;
  }

  public static func PerkOffer(run: ref<RLRunState>, def: ref<RLPerkDef>) -> ref<RLOffer> {
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Perk;
    offer.perk = def.perk;
    offer.tags = def.tags;
    offer.title = def.name;
    offer.subtitle = (def.power >= 4 ? "SIGNATURE PERK - " : "PERK - ") + RLPerkCatalog.AttributeName(def.perk);
    offer.description = def.text;
    offer.excitement = def.power - RLPerkCatalog.ExpectedPower(run.Depth(), run.TotalFloors());
    return offer;
  }

  // Every screen keeps at least one card that doesn't match the build, so
  // the director nudges and never decides.
  private static func KeepOneOffBuild(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, profile: ref<RLBuildProfile>, out offers: array<ref<RLOffer>>) {
    let count = ArraySize(offers);
    if count < 3 || Equals(category, RLRewardCategory.Workshop) || Equals(category, RLRewardCategory.Boons) {
      return;
    }
    for offer in offers {
      if !profile.HasAny(offer.tags) {
        return;
      }
    }
    let last = count - 1;
    let tries = 0;
    while tries < 8 {
      tries += 1;
      let replacement: ref<RLOffer>;
      if Equals(category, RLRewardCategory.Training) {
        let exclude: array<gamedataNewPerkType>;
        for offer in offers {
          ArrayPush(exclude, offer.perk);
        }
        let picks = RLPerkCatalog.Pick(player, run, null, 1, false, exclude);
        if ArraySize(picks) > 0 {
          replacement = RLRewards.PerkOffer(run, picks[0]);
        }
      } else {
        replacement = RLRewards.BuildOffer(player, pools, run, RLRewards.KindFor(category, run), threat, null, false);
      }
      if IsDefined(replacement) && !profile.HasAny(replacement.tags) && !RLRewards.IsDuplicate(offers, replacement) {
        offers[last] = replacement;
        return;
      }
    }
  }

  private static func IsDuplicate(offers: array<ref<RLOffer>>, candidate: ref<RLOffer>) -> Bool {
    for offer in offers {
      if Equals(offer.kind, candidate.kind) {
        if TDBID.IsValid(candidate.record) && offer.record == candidate.record {
          return true;
        }
        if IsNameValid(candidate.boon) && Equals(offer.boon, candidate.boon) {
          return true;
        }
        if Equals(candidate.kind, RLOfferKind.Perk) && Equals(offer.perk, candidate.perk) {
          return true;
        }
      }
    }
    return false;
  }

  private static func KindFor(category: RLRewardCategory, run: ref<RLRunState>) -> RLOfferKind {
    switch category {
      case RLRewardCategory.Armory:
        if RandF() < RLRewards.IconicChance(run.Depth()) {
          return RLOfferKind.Iconic;
        }
        return RandF() < 0.25 ? RLOfferKind.Grenade : RLOfferKind.Weapon;
      case RLRewardCategory.Chrome:
        return RLOfferKind.Cyberware;
      case RLRewardCategory.Daemons:
        return RLOfferKind.Quickhack;
      case RLRewardCategory.Iconic:
        return RLOfferKind.Iconic;
    }
    return RLOfferKind.Boon;
  }

  // One card of the given kind, its quality from the reward director.
  public static func BuildOffer(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, kind: RLOfferKind, threat: Int32, profile: ref<RLBuildProfile>, spike: Bool) -> ref<RLOffer> {
    let depth = run.Depth();
    let expected = RLQuality.ExpectedStep(depth, run.TotalFloors());
    let step = RLRewardDirector.RollStep(run, threat, spike);
    let offer = new RLOffer();
    offer.kind = kind;
    offer.step = step;
    let noIDs: array<TweakDBID>;
    switch kind {
      case RLOfferKind.Weapon:
        offer.record = RLRewards.PickWeighted(pools, profile, kind, step, RLRewards.AllowedEvolutions(depth));
        offer.tier = RLQuality.TierName(step);
        offer.subtitle = "WEAPON - " + RLQuality.DisplayName(step);
        offer.excitement = step - expected;
        break;
      case RLOfferKind.Iconic:
        offer.record = pools.PickIconic();
        offer.step = Min(RLQuality.MaxStep(), step + 2);
        offer.tier = RLQuality.TierName(offer.step);
        offer.subtitle = "ICONIC WEAPON";
        offer.excitement = offer.step - expected;
        break;
      case RLOfferKind.Cyberware:
        offer.record = RLRewards.PickWeighted(pools, profile, kind, step, RLRewards.AllowedEvolutions(depth));
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          let cost = RLGear.CapacityCost(player, offer.record);
          let available = RLGear.CapacityAvailable(player);
          offer.subtitle = s"CYBERWARE - \(RLQuality.DisplayName(offer.step)) - capacity \(RoundF(cost))";
          offer.disabled = cost > available;
          offer.description = offer.disabled ? s"Not enough capacity (\(RoundF(available)) free)." : "Installed immediately.";
          offer.excitement = offer.step - expected;
        }
        break;
      case RLOfferKind.Quickhack:
        offer.record = pools.PickQuickhack(RLRewards.BandForStep(step), noIDs);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "QUICKHACK - " + RLQuality.DisplayName(offer.step);
          offer.description = "Needs a cyberdeck to use.";
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"netrunner");
        }
        break;
      case RLOfferKind.Grenade:
        offer.record = RLConsumables.PickGrenade(step, noIDs);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "GRENADE - " + RLQuality.DisplayName(offer.step);
          offer.description = "Equipped on the spot. Replaces your current grenade.";
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"explosive");
        }
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
        return offer;
    }
    if !TDBID.IsValid(offer.record) {
      return null;
    }
    if ArraySize(offer.tags) == 0 {
      offer.tags = RLBuildProfile.RecordTags(offer.record);
    }
    offer.title = RLRewards.ItemName(offer.record);
    if StrLen(offer.description) == 0 {
      offer.description = RLRewards.ItemTypeName(offer.record);
    }
    return offer;
  }

  // A few candidates from the pool, picked by build weight.
  private static func PickWeighted(pools: ref<RLTweakPools>, profile: ref<RLBuildProfile>, kind: RLOfferKind, step: Int32, evolutions: array<gamedataWeaponEvolution>) -> TweakDBID {
    let candidates: array<TweakDBID>;
    let noTypes: array<gamedataItemType>;
    let i = 0;
    while i < 4 {
      let candidate = Equals(kind, RLOfferKind.Weapon)
        ? pools.PickWeapon(noTypes, evolutions)
        : pools.PickCyberware(RLRewards.BandForStep(step), false, gamedataItemType.Invalid, candidates);
      if TDBID.IsValid(candidate) && !ArrayContains(candidates, candidate) {
        ArrayPush(candidates, candidate);
      }
      i += 1;
    }
    if ArraySize(candidates) == 0 {
      return TDBID.None();
    }
    let total = 0.0;
    for candidate in candidates {
      total += RLBuildProfile.Multiplier(profile, RLBuildProfile.RecordTags(candidate));
    }
    let roll = RandRangeF(0.0, total);
    for candidate in candidates {
      roll -= RLBuildProfile.Multiplier(profile, RLBuildProfile.RecordTags(candidate));
      if roll <= 0.0 {
        return candidate;
      }
    }
    return candidates[ArraySize(candidates) - 1];
  }

  public static func PickBoon(run: ref<RLRunState>) -> ref<RLBoonDef> {
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

  // --- Workshop ------------------------------------------------------------------------

  // Upgrades for gear V owns: the weapons (equipped first), the MaxDoc and the
  // grenade - up to `count` cards.
  public static func WorkshopOffers(player: ref<PlayerPuppet>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let health = RLRewards.HealthUpgradeOffer(player);
    let grenade = RLRewards.GrenadeUpgradeOffer(player);
    let gearSlots = (IsDefined(health) ? 1 : 0) + (IsDefined(grenade) ? 1 : 0);
    for offer in RLRewards.WeaponUpgradeOffers(player, Max(1, count - gearSlots)) {
      ArrayPush(offers, offer);
    }
    if IsDefined(health) && ArraySize(offers) < count {
      ArrayPush(offers, health);
    }
    if IsDefined(grenade) && ArraySize(offers) < count {
      ArrayPush(offers, grenade);
    }
    return offers;
  }

  public static func WeaponUpgradeOffers(player: ref<PlayerPuppet>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let stowed: array<ref<RLOffer>>;
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    for item in items {
      if IsDefined(item) && Equals(RPGManager.GetItemCategory(item.GetID()), gamedataItemCategory.Weapon) {
        let area = EquipmentSystem.GetEquipAreaType(item.GetID());
        let step = RLRewards.ItemStep(item);
        if NotEquals(area, gamedataEquipmentArea.BaseFists) && NotEquals(area, gamedataEquipmentArea.VDefaultHandgun) && step < RLQuality.MaxStep() {
          let offer = new RLOffer();
          offer.kind = RLOfferKind.WeaponUpgrade;
          offer.itemID = item.GetID();
          offer.record = ItemID.GetTDBID(item.GetID());
          offer.step = Min(RLQuality.MaxStep(), step + 2);
          offer.title = RLRewards.ItemName(offer.record);
          offer.subtitle = "UPGRADE - " + RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
          offer.description = "Two quality steps up. Keep the weapon you like and make it hit harder.";
          offer.excitement = 1;
          // Equipped weapons first.
          if IsDefined(equipment) && equipment.IsEquipped(item.GetID()) {
            ArrayPush(offers, offer);
          } else {
            ArrayPush(stowed, offer);
          }
        }
      }
    }
    for offer in stowed {
      ArrayPush(offers, offer);
    }
    while ArraySize(offers) > count {
      ArrayPop(offers);
    }
    return offers;
  }

  public static func HealthUpgradeOffer(player: ref<PlayerPuppet>) -> ref<RLOffer> {
    let ladder = RLConsumables.HealthLadder();
    let current = RLConsumables.CurrentHealthIndex(player, ladder);
    if current < 0 || current + 1 >= ArraySize(ladder) {
      return null;
    }
    let offer = new RLOffer();
    offer.kind = RLOfferKind.HealthUpgrade;
    offer.record = ladder[current + 1];
    offer.step = RLQuality.StepOfRecord(offer.record);
    offer.title = RLRewards.ItemName(offer.record);
    offer.subtitle = "UPGRADE - " + RLQuality.DisplayName(RLQuality.StepOfRecord(ladder[current])) + " > " + RLQuality.DisplayName(offer.step);
    offer.description = "A stronger health item: every charge heals more.";
    offer.excitement = 1;
    return offer;
  }

  // A better grenade than the one V carries (two steps up), or none.
  public static func GrenadeUpgradeOffer(player: ref<PlayerPuppet>) -> ref<RLOffer> {
    let current = RLConsumables.CurrentGrenade(player);
    if !TDBID.IsValid(current) {
      return null;
    }
    let step = RLQuality.StepOfRecord(current);
    let exclude = [current];
    let record = RLConsumables.PickGrenade(Min(RLQuality.MaxStep(), step + 2), exclude);
    if !TDBID.IsValid(record) || RLQuality.StepOfRecord(record) <= step {
      return null;
    }
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Grenade;
    offer.record = record;
    offer.step = RLQuality.StepOfRecord(record);
    offer.title = RLRewards.ItemName(record);
    offer.subtitle = "UPGRADE - " + RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
    offer.description = "Replaces your current grenade.";
    offer.excitement = 1;
    ArrayPush(offer.tags, n"explosive");
    return offer;
  }

  // Quality step of an owned item (0 Common .. 10 Legendary++).
  public static func ItemStep(item: wref<gameItemData>) -> Int32 {
    return RoundF(item.GetStatValueByType(gamedataStatType.Quality) * 2.0 + item.GetStatValueByType(gamedataStatType.IsItemPlus));
  }

  // --- Granting ------------------------------------------------------------------------

  public static func Grant(player: ref<PlayerPuppet>, run: ref<RLRunState>, offer: ref<RLOffer>) {
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
      case RLOfferKind.Perk:
        let def = RLPerkCatalog.Find(offer.perk);
        if IsDefined(def) {
          RLPerkCatalog.Grant(player, def);
        }
        break;
      case RLOfferKind.Grenade:
        RLConsumables.SetGrenade(player, offer.record);
        break;
      case RLOfferKind.WeaponUpgrade:
        let itemData = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, offer.itemID);
        if IsDefined(itemData) {
          RPGManager.ForceItemTier(player, itemData, RLQuality.TierName(offer.step));
        }
        break;
      case RLOfferKind.HealthUpgrade:
        RLConsumables.UpgradeHealthOnce(player, RLQuality.MaxStep());
        break;
    }
    RLRewardDirector.OnPicked(run, offer);
    RLLog("Reward granted: " + offer.title + " (" + offer.subtitle + ").");
  }

  // --- Names ---------------------------------------------------------------------------

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

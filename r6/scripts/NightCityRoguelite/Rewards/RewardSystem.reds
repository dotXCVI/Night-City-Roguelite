// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// Hades-style: between arenas the player picks the next fight by its reward
// type (a "door"). Each door shows the reward, the arena, the enemy faction
// and the threat - all the planning happens here, between fights:
//
//   TRAINING  perk cards (Rewards/PerkCatalog.reds)            light
//   ARMORY    weapons, grenades, sometimes an iconic           standard
//   PATRON    three boons from one patron (Rewards/Patrons)   standard
//   DAEMONS   quickhacks                                       standard
//   WORKSHOP  upgrade gear you own (floors 4 and 10)           standard
//   CHROME    cyberware, installed on the spot                 heavy
//   ICONIC    iconic weapons (rare door)                       heavy
//   BOUNTY    a lone cyberpsycho; boons and eddies (Act 2+)    heavy
//   ?         an event instead of a fight (Run/Events.reds)    -
//
// Heavy doors appear from floor 3. Some fights come with an objective
// (Run/Objectives.reds). Before a boss floor there is a single boss door.
// Card quality, pity, spikes and build weighting are the reward director's
// (Rewards/Director.reds).
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
  Event = 7,
  Bounty = 8,
}

// One choice for the next fight.
public class RLDoor {
  public let category: RLRewardCategory;
  public let threat: Int32;
  public let arena: CName;
  public let faction: ref<RLFactionPool>;
  public let boss: Bool;
  // Patron doors (and bounties): whose boons the reward screen offers.
  public let patron: CName;
  // Event doors: which event (Run/Events.reds).
  public let event: CName;
  // The fight's objective (Run/Objectives.reds); none = clear the waves.
  public let objective: RLObjectiveKind;
}

public class RLOffer {
  public let kind: RLOfferKind;
  public let record: TweakDBID;
  public let itemID: ItemID;
  public let perk: gamedataNewPerkType;
  public let tier: CName;
  public let step: Int32;
  public let boon: CName;
  // Boons: the rarity taken (an upgrade's new rarity) and the patron.
  public let rarity: Int32;
  public let patron: CName;
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
      case RLRewardCategory.Event: return "?";
      case RLRewardCategory.Bounty: return "BOUNTY";
    }
    return "REWARD";
  }

  // A door's title: the patron for patron doors.
  public static func DoorTitle(door: ref<RLDoor>) -> String {
    if Equals(door.category, RLRewardCategory.Boons) && IsNameValid(door.patron) {
      return RLPatrons.Name(door.patron);
    }
    return RLRewards.CategoryName(door.category);
  }

  // What a door's reward is, where the name alone doesn't say.
  public static func CategoryDescription(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "Weapons and grenades";
      case RLRewardCategory.Chrome: return "Cyberware";
      case RLRewardCategory.Daemons: return "Quickhacks";
      case RLRewardCategory.Boons: return "Run bonuses";
      case RLRewardCategory.Training: return "Perks";
      case RLRewardCategory.Iconic: return "Iconic weapons";
      case RLRewardCategory.Workshop: return "Upgrade your gear";
      case RLRewardCategory.Event: return "No fight. Something else.";
      case RLRewardCategory.Bounty: return "A cyberpsycho. NCPD pays well.";
    }
    return "";
  }

  // 1 = light, 2 = standard, 3 = heavy.
  public static func CategoryThreat(category: RLRewardCategory) -> Int32 {
    switch category {
      case RLRewardCategory.Event: return 0;
      case RLRewardCategory.Training: return 1;
      case RLRewardCategory.Chrome:
      case RLRewardCategory.Iconic:
      case RLRewardCategory.Bounty: return 3;
    }
    return 2;
  }

  public static func ThreatName(threat: Int32) -> String {
    if threat <= 0 {
      return "NO FIGHT";
    }
    if threat <= 1 {
      return "LIGHT";
    }
    return threat >= 3 ? "HEAVY" : "STANDARD";
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
    // Now and then a door is an event (no fight) or, from Act 2, a bounty.
    if depth >= 2 && !run.IsEliteFloor() && ArraySize(doors) < count && RandF() < RLConfig.EventDoorChance() {
      ArrayPush(used, RLRewardCategory.Event);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Event, false, usedArenas));
    }
    if run.act >= 2 && ArraySize(doors) < count && RandF() < RLConfig.BountyDoorChance() {
      ArrayPush(used, RLRewardCategory.Bounty);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Bounty, false, usedArenas));
    }
    let profile = RLBuildProfile.Read(player);
    let guard = 0;
    while ArraySize(doors) < count && guard < 40 {
      guard += 1;
      let category = RLRewards.RollCategory(pools, run, profile);
      if !ArrayContains(used, category) {
        ArrayPush(used, category);
        ArrayPush(doors, RLRewards.MakeDoor(pools, run, category, false, usedArenas));
      } else if Equals(category, RLRewardCategory.Boons) && RLRewards.CountCategory(doors, category) < 2 {
        // Two patrons can compete for V (never the same one twice).
        let door = RLRewards.MakeDoor(pools, run, category, false, usedArenas);
        if !RLRewards.HasPatronDoor(doors, door.patron) {
          ArrayPush(doors, door);
        }
      }
    }
    return doors;
  }

  private static func CountCategory(doors: array<ref<RLDoor>>, category: RLRewardCategory) -> Int32 {
    let count = 0;
    for door in doors {
      if Equals(door.category, category) {
        count += 1;
      }
    }
    return count;
  }

  private static func HasPatronDoor(doors: array<ref<RLDoor>>, patron: CName) -> Bool {
    for door in doors {
      if Equals(door.category, RLRewardCategory.Boons) && Equals(door.patron, patron) {
        return true;
      }
    }
    return false;
  }

  private static func MakeDoor(pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, boss: Bool, out usedArenas: array<CName>) -> ref<RLDoor> {
    let door = new RLDoor();
    door.category = category;
    door.threat = boss ? 3 : RLRewards.CategoryThreat(category);
    door.boss = boss;
    switch category {
      case RLRewardCategory.Boons:
      case RLRewardCategory.Bounty:
        door.patron = RLPatrons.PickForDoor(run);
        break;
      case RLRewardCategory.Event:
        door.event = RLEvents.Pick(run);
        return door;
    }
    door.arena = RLRewards.PickArena(usedArenas);
    ArrayPush(usedArenas, door.arena);
    let arena = RLArenas.Get(door.arena);
    if IsDefined(arena) {
      door.faction = pools.PickFactionPreferred(arena.factions, run.act >= 3);
    }
    if !boss && NotEquals(category, RLRewardCategory.Bounty) {
      door.objective = RLObjectives.RollForDoor(run, arena);
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
  public static func RollForCategory(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, patron: CName, threat: Int32, count: Int32) -> array<ref<RLOffer>> {
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
      case RLRewardCategory.Boons:
      case RLRewardCategory.Bounty:
        offers = RLRewards.BoonOffers(run, patron, threat, Min(count, 3), spike);
        break;
      default:
        offers = RLRewards.ItemOffers(player, pools, run, category, threat, count, profile, spike);
    }
    // Nothing of that type is available (or the patron has nothing left):
    // another patron's boons instead.
    if ArraySize(offers) == 0 {
      offers = RLRewards.BoonOffers(run, RLPatrons.PickForDoor(run), threat, Min(count, 3), false);
    }
    for other in RLPatrons.All() {
      if ArraySize(offers) == 0 {
        offers = RLRewards.BoonOffers(run, other.id, threat, Min(count, 3), false);
      }
    }
    RLRewards.KeepOneOffBuild(player, pools, run, category, threat, profile, offers);
    RLRewardDirector.AfterRoll(run, offers, profile);
    return offers;
  }

  // A screen never shows the same item twice (in any quality), at most one
  // grenade, and no weapon or grenade V already carries - the Workshop is
  // where owned gear gets better.
  private static func ItemOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, count: Int32, profile: ref<RLBuildProfile>, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let owned = RLRewards.OwnedNames(player);
    let guard = 0;
    while ArraySize(offers) < count && guard < 40 {
      guard += 1;
      let kind = RLRewards.KindFor(category, run);
      if Equals(kind, RLOfferKind.Grenade) && RLRewards.HasKind(offers, RLOfferKind.Grenade) {
        kind = RLOfferKind.Weapon;
      }
      // The spike goes on the first card.
      let offer = RLRewards.BuildOffer(player, pools, run, kind, threat, profile, spike && ArraySize(offers) == 0);
      if IsDefined(offer) && !RLRewards.IsDuplicate(offers, offer) && !RLRewards.IsOwned(owned, offer) {
        ArrayPush(offers, offer);
      }
    }
    return offers;
  }

  // Names of the weapons and grenades V carries.
  private static func OwnedNames(player: ref<PlayerPuppet>) -> array<String> {
    let names: array<String>;
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) {
        let category = RPGManager.GetItemCategory(item.GetID());
        if Equals(category, gamedataItemCategory.Weapon) || Equals(RPGManager.GetItemType(item.GetID()), gamedataItemType.Gad_Grenade) {
          ArrayPush(names, RLRewards.ItemName(ItemID.GetTDBID(item.GetID())));
        }
      }
    }
    return names;
  }

  private static func IsOwned(owned: array<String>, offer: ref<RLOffer>) -> Bool {
    switch offer.kind {
      case RLOfferKind.Weapon:
      case RLOfferKind.Iconic:
      case RLOfferKind.Grenade:
        return ArrayContains(owned, offer.title);
    }
    return false;
  }

  private static func HasKind(offers: array<ref<RLOffer>>, kind: RLOfferKind) -> Bool {
    for offer in offers {
      if Equals(offer.kind, kind) {
        return true;
      }
    }
    return false;
  }

  // The price of a reroll once the free ones are used: it grows with the run
  // and by half again for every paid reroll on the same screen.
  public static func RerollPrice(run: ref<RLRunState>) -> Int32 {
    let base = Cast<Float>(60 + 20 * run.Depth());
    let price = base * (1.0 + 0.5 * Cast<Float>(run.paidRerolls));
    return RLFixer.Discounted(run, 5 * RoundF(price / 5.0));
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
    offer.subtitle = (def.power >= 4 ? "SIGNATURE PERK - " : "PERK - ") + RLPerkCatalog.AttributeName(def.perk) + " +1";
    offer.description = def.text;
    offer.excitement = def.power - RLPerkCatalog.ExpectedPower(run.Depth(), run.TotalFloors());
    return offer;
  }

  // Every screen keeps at least one card that doesn't match the build, so
  // the director nudges and never decides.
  private static func KeepOneOffBuild(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, threat: Int32, profile: ref<RLBuildProfile>, out offers: array<ref<RLOffer>>) {
    let count = ArraySize(offers);
    if count < 3 || Equals(category, RLRewardCategory.Workshop) || Equals(category, RLRewardCategory.Boons) || Equals(category, RLRewardCategory.Bounty) {
      return;
    }
    for offer in offers {
      if !profile.HasAny(offer.tags) {
        return;
      }
    }
    let last = count - 1;
    let owned = RLRewards.OwnedNames(player);
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
      if IsDefined(replacement) && !profile.HasAny(replacement.tags) && !RLRewards.IsDuplicate(offers, replacement) && !RLRewards.IsOwned(owned, replacement) {
        offers[last] = replacement;
        return;
      }
    }
  }

  private static func IsDuplicate(offers: array<ref<RLOffer>>, candidate: ref<RLOffer>) -> Bool {
    for offer in offers {
      if Equals(offer.kind, candidate.kind) {
        if TDBID.IsValid(candidate.record) && (offer.record == candidate.record || Equals(offer.title, candidate.title)) {
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
        return RandF() < 0.3 ? RLOfferKind.Grenade : RLOfferKind.Weapon;
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
        // Iconics are never below Rare.
        offer.record = pools.PickIconic();
        offer.step = Clamp(step + 2, 4, RLQuality.MaxStep());
        offer.tier = RLQuality.TierName(offer.step);
        offer.subtitle = "ICONIC - " + RLQuality.DisplayName(offer.step);
        offer.excitement = offer.step - expected;
        break;
      case RLOfferKind.Cyberware:
        offer.record = RLRewards.PickWeighted(pools, profile, kind, step, RLRewards.AllowedEvolutions(depth));
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          let cost = RLGear.CapacityCost(player, offer.record);
          let available = RLGear.CapacityAvailable(player);
          offer.subtitle = "CYBERWARE - " + RLQuality.DisplayName(offer.step);
          offer.disabled = cost > available;
          offer.description = offer.disabled ? s"Needs \(RoundF(cost)) capacity - \(RoundF(available)) free" : s"Capacity \(RoundF(cost))";
          offer.excitement = offer.step - expected;
        }
        break;
      case RLOfferKind.Quickhack:
        offer.record = pools.PickQuickhack(RLRewards.BandForStep(step), noIDs);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "QUICKHACK - " + RLQuality.DisplayName(offer.step);
          if !EquipmentSystem.IsCyberdeckEquipped(player) {
            offer.description = "Needs a cyberdeck";
          }
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"netrunner");
        }
        break;
      case RLOfferKind.Grenade:
        offer.record = RLConsumables.PickGrenade(step, noIDs);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "GRENADE - " + RLQuality.DisplayName(offer.step);
          if TDBID.IsValid(RLConsumables.CurrentGrenade(player)) {
            offer.description = "Replaces your grenade";
          }
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"explosive");
        }
        break;
      case RLOfferKind.Boon:
        let boons = RLRewards.BoonOffers(run, RLPatrons.PickForDoor(run), threat, 1, spike);
        return ArraySize(boons) > 0 ? boons[0] : null;
    }
    if !TDBID.IsValid(offer.record) {
      return null;
    }
    if ArraySize(offer.tags) == 0 {
      offer.tags = RLBuildProfile.RecordTags(offer.record);
    }
    offer.title = RLRewards.ItemName(offer.record);
    // Weapons say what they are (the name alone often doesn't).
    if StrLen(offer.description) == 0 && (Equals(kind, RLOfferKind.Weapon) || Equals(kind, RLOfferKind.Iconic)) {
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

  // --- Boons ---------------------------------------------------------------------------

  // A patron's reward screen: up to `count` of its boons V can take now -
  // new ones, upgrades of ones V holds, its legendary, and duos shared with
  // patrons V already serves.
  public static func BoonOffers(run: ref<RLRunState>, patron: CName, threat: Int32, count: Int32, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let candidates: array<ref<RLBoonDef>>;
    let weights: array<Int32>;
    for def in RLBoons.All() {
      if (Equals(def.patron, patron) || Equals(def.partner, patron)) && RLBoons.IsOfferable(run, def) {
        ArrayPush(candidates, def);
        ArrayPush(weights, RLRewards.BoonWeight(run, def));
      }
    }
    while ArraySize(offers) < count && ArraySize(candidates) > 0 {
      let total = 0;
      for weight in weights {
        total += weight;
      }
      let roll = RandRange(0, Max(1, total));
      let i = 0;
      while i < ArraySize(candidates) - 1 && roll >= weights[i] {
        roll -= weights[i];
        i += 1;
      }
      ArrayPush(offers, RLRewards.BoonOffer(run, candidates[i], patron, threat, spike && ArraySize(offers) == 0));
      ArrayErase(candidates, i);
      ArrayErase(weights, i);
    }
    return offers;
  }

  // New boons are the bread and butter; upgrades, duos and the legendary are
  // the exciting finds.
  private static func BoonWeight(run: ref<RLRunState>, def: ref<RLBoonDef>) -> Int32 {
    switch def.kind {
      case RLBoonKind.Legendary: return 4;
      case RLBoonKind.Duo: return 6;
    }
    return RLBoons.Has(run, def.id) ? 6 : 10;
  }

  // One boon card. A new boon's rarity comes from the reward director (a
  // better roll is a rarer boon, and deep runs start at Rare); an upgrade is
  // one rarity up (two on a lucky roll).
  public static func BoonOffer(run: ref<RLRunState>, def: ref<RLBoonDef>, patron: CName, threat: Int32, spike: Bool) -> ref<RLOffer> {
    let roll = RLRewardDirector.RollStep(run, threat, spike) - RLQuality.ExpectedStep(run.Depth(), run.TotalFloors());
    let owned = RLBoons.Owned(run, def.id);
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Boon;
    offer.boon = def.id;
    offer.patron = Equals(def.kind, RLBoonKind.Duo) ? def.patron : patron;
    offer.tags = def.tags;
    offer.title = def.name;
    let top = RLBoons.HighestRarity(def);
    if IsDefined(owned) {
      offer.rarity = Min(top, owned.rarity + (roll >= 2 ? 2 : 1));
      offer.subtitle = RLBoons.RarityName(owned.rarity) + " > " + RLBoons.RarityName(offer.rarity);
      offer.excitement = 1;
    } else if Equals(def.kind, RLBoonKind.Core) {
      offer.rarity = Clamp(Max(0, roll) + (run.Depth() >= 10 ? 1 : 0), 0, top);
      offer.subtitle = RLPatrons.Name(def.patron) + " - " + RLBoons.RarityName(offer.rarity);
      offer.excitement = offer.rarity;
    } else {
      offer.subtitle = Equals(def.kind, RLBoonKind.Legendary)
        ? "LEGENDARY - " + RLPatrons.Name(def.patron)
        : "DUO - " + RLPatrons.Name(def.patron) + " + " + RLPatrons.Name(def.partner);
      offer.excitement = 2;
    }
    offer.step = RLRewards.BoonStep(def, offer.rarity);
    offer.description = RLBoons.Text(def, offer.rarity);
    return offer;
  }

  // Card colour: the rarity, gold for a legendary, green for a duo.
  public static func BoonStep(def: ref<RLBoonDef>, rarity: Int32) -> Int32 {
    switch def.kind {
      case RLBoonKind.Legendary: return 8;
      case RLBoonKind.Duo: return 2;
    }
    return RLBoons.RarityStep(rarity);
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
          offer.subtitle = RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
          offer.description = RLRewards.ItemTypeName(offer.record);
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
    offer.subtitle = RLQuality.DisplayName(RLQuality.StepOfRecord(ladder[current])) + " > " + RLQuality.DisplayName(offer.step);
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
    offer.subtitle = RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
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
        RLBoons.Apply(player, run, offer.boon, offer.rarity);
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

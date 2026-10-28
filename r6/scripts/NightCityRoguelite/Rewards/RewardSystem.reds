// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// Hades-style: between arenas the player picks the next fight by its reward
// type (a "door"). Each door shows the reward, the arena, the enemy faction
// and the threat - all the planning happens here, between fights:
//
//   TRAINING  perk cards (Rewards/PerkCatalog.reds)            light
//   ARMORY    a better weapon, an upgrade or mod for yours,   standard
//             grenades
//   PATRON    three boons from one patron (Rewards/Patrons)   standard
//   DAEMONS   quickhacks                                       standard
//   WORKSHOP  upgrades, mods and evolutions for gear you own   standard
//             (floors 4, 10 and 16)
//   CHROME    cyberware, installed on the spot                 heavy
//   BOUNTY    a lone cyberpsycho; boons and eddies (Act 2+)    heavy
//   ?         an event instead of a fight (Run/Events.reds)    -
//
// Heavy doors appear from floor 3. Some fights come with an objective
// (Run/Objectives.reds). Before a boss floor there is a single boss door: the
// Act 1 boss pays out an Operating System (and Overdrive), the others chrome.
// Iconics aren't a door any more: weapons evolve into them
// (Rewards/Weapons.reds).
//
// Besides the door rewards: the level-up after every floor
// (Rewards/LevelUp.reds), the gig at the start (Run/Gigs.reds). A reward
// screen can be skipped for eddies, and one card per act banished for the
// rest of the run. Card quality, pity, spikes and build weighting are the
// reward director's (Rewards/Director.reds).
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
  WeaponMod = 9,
  Evolve = 10,
  Attribute = 11,
  Capacity = 12,
  BoonUpgrade = 13,
  OperatingSystem = 14,
  Gig = 15,
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
  // Not doors: the screens between them.
  LevelUp = 9,
  System = 10,
  Gig = 11,
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
  // Weapon mods: the mod. Operating Systems: the kind (Sandevistan,
  // Berserk, Cyberdeck).
  public let mod: CName;
  // Attribute cards: the attribute. Capacity and gig cards: the amount or
  // the style.
  public let stat: gamedataStatType;
  public let amount: Int32;
  // Weapon cards: DPS against V's best equipped weapon.
  public let dpsLine: String;
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
      case RLRewardCategory.LevelUp: return "LEVEL UP";
      case RLRewardCategory.System: return "OPERATING SYSTEM";
      case RLRewardCategory.Gig: return "TAKE A GIG";
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

  // What a door pays, in plain words ("Pick 1 of 4 quickhacks").
  public static func DoorPromise(door: ref<RLDoor>, count: Int32) -> String {
    let pick = s"Pick 1 of \(count) ";
    switch door.category {
      case RLRewardCategory.Armory: return pick + "guns, upgrades and mods for yours, or grenades.";
      case RLRewardCategory.Chrome: return pick + "cyberware, installed on the spot.";
      case RLRewardCategory.Daemons: return pick + "quickhacks.";
      case RLRewardCategory.Training: return pick + "perks.";
      case RLRewardCategory.Iconic: return pick + "iconic weapons.";
      case RLRewardCategory.Workshop: return "Evolve or upgrade a weapon, mod it, or upgrade your MaxDoc.";
      case RLRewardCategory.Boons: return pick + RLPatrons.Name(door.patron) + " boons.";
      case RLRewardCategory.Bounty: return "One cyberpsycho. Pays big in eddies, plus a " + RLPatrons.Name(door.patron) + " boon pick.";
      case RLRewardCategory.Event: return "No fight - " + RLEvents.Title(door.event);
      case RLRewardCategory.System: return "Pick your operating system. It unlocks Overdrive, your ultimate.";
    }
    return "";
  }

  // What a door's reward is, where the name alone doesn't say.
  public static func CategoryDescription(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "Fresh iron and frags.";
      case RLRewardCategory.Chrome: return "New chrome, straight off the table.";
      case RLRewardCategory.Daemons: return "Quickhacks. Fry their optics.";
      case RLRewardCategory.Boons: return "Someone powerful backs you.";
      case RLRewardCategory.Training: return "Perks. Sharpen what works.";
      case RLRewardCategory.Iconic: return "One-of-a-kind iron.";
      case RLRewardCategory.Workshop: return "Tune up what you're packing.";
      case RLRewardCategory.Event: return "No fight. Something else.";
      case RLRewardCategory.Bounty: return "Cyberpsycho loose. NCPD pays.";
      case RLRewardCategory.System: return "Your operating system. And Overdrive.";
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

  // The floors with a Workshop door (and the one after, when it was passed over).
  public static func IsWorkshopFloor(depth: Int32) -> Bool = depth == 4 || depth == 10 || depth == 16

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
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, run.act == 1 && !run.overdriveUnlocked ? RLRewardCategory.System : RLRewardCategory.Chrome, true, usedArenas));
      return doors;
    }
    if run.floorsCleared == 0 && !run.isTest {
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Training, false, usedArenas));
      return doors;
    }
    let used: array<RLRewardCategory>;
    // The workshop is one of the doors on floors 4, 10 and 16 (and once more
    // on the next floor if it was passed over), like Hades' Daedalus hammers.
    let depth = run.Depth();
    if RLRewards.IsWorkshopFloor(depth) || run.workshopCarry {
      run.workshopShown = true;
      ArrayPush(used, RLRewardCategory.Workshop);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Workshop, false, usedArenas));
    }
    // Now and then a door is an event (no fight) or, from Act 2, a bounty.
    // Test runs always show both.
    if (depth >= 2 || run.isTest) && !run.IsEliteFloor() && ArraySize(doors) < count && (run.isTest || RandF() < RLConfig.EventDoorChance()) {
      ArrayPush(used, RLRewardCategory.Event);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Event, false, usedArenas));
    }
    if run.act >= 2 && ArraySize(doors) < count && (run.isTest || RandF() < RLConfig.BountyDoorChance()) {
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
    // No heavy fights (Chrome) before floor 3.
    let early = run.Depth() < 3;
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
      case RLRewardCategory.LevelUp:
        return RLLevelUp.Offers(player, pools, run);
      case RLRewardCategory.System:
        return RLRewards.OperatingSystemOffers(player, pools, run);
      case RLRewardCategory.Gig:
        return RLGigs.Offers(run);
      case RLRewardCategory.Training:
        offers = RLRewards.PerkOffers(player, run, profile, count, spike);
        break;
      case RLRewardCategory.Workshop:
        offers = RLRewards.WorkshopOffers(player, pools, run, count);
        break;
      case RLRewardCategory.Boons:
      case RLRewardCategory.Bounty:
        offers = RLRewards.BoonOffers(run, patron, threat, Min(count, 3), spike);
        break;
      case RLRewardCategory.Armory:
        offers = RLRewards.ArmoryOffers(player, pools, run, threat, count, profile, spike);
        break;
      default:
        offers = RLRewards.ItemOffers(player, pools, run, category, threat, count, profile, spike);
    }
    RLRewards.DropBanished(run, offers);
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

  // The Armory: one card that improves a weapon V carries (a mod, or two
  // quality steps), then new weapons that are never worse than V's best and
  // the odd grenade.
  private static func ArmoryOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, threat: Int32, count: Int32, profile: ref<RLBuildProfile>, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let own = RandF() < 0.5 ? RLWeaponMods.Offers(player, run, 1) : RLRewards.WeaponUpgradeOffers(player, 1, 2);
    if ArraySize(own) == 0 {
      own = RLWeaponMods.Offers(player, run, 1);
    }
    // The upgrade goes first: the off-build card KeepOneOffBuild may swap in
    // is always the last one.
    for offer in own {
      ArrayPush(offers, offer);
    }
    for offer in RLRewards.ItemOffers(player, pools, run, RLRewardCategory.Armory, threat, count - ArraySize(own), profile, spike) {
      ArrayPush(offers, offer);
    }
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
    let raises = NotEquals(RLPerks.AttributeStat(def.perk), gamedataStatType.Invalid);
    offer.subtitle = (def.power >= 4 ? "SIGNATURE PERK - " : "PERK - ") + RLPerkCatalog.AttributeName(def.perk) + (raises ? " +1" : "");
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
        return RandF() < 0.25 ? RLOfferKind.Grenade : RLOfferKind.Weapon;
      case RLRewardCategory.Chrome:
        return RLOfferKind.Cyberware;
      case RLRewardCategory.Daemons:
        return RLOfferKind.Quickhack;
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
        // Never worse than the best weapon V has equipped, never far above the floor.
        offer.step = Min(RLQuality.MaxStep(), Max(step, RLWeapons.BestEquippedStep(player)));
        offer.record = RLRewards.PickWeighted(pools, profile, kind, offer.step, RLRewards.AllowedEvolutions(depth));
        offer.tier = RLQuality.TierName(offer.step);
        offer.subtitle = RLQuality.DisplayName(offer.step);
        offer.excitement = offer.step - expected;
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
        // Once Overdrive is unlocked the Operating System stays the one it came with.
        offer.record = RLRewards.PickWeighted(pools, profile, kind, step, RLRewards.AllowedEvolutions(depth), run.overdriveUnlocked);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          // What it adds (less anything it replaces) against what's free.
          let cost = RLGear.NetCapacityCost(player, offer.record);
          let available = RLGear.CapacityAvailable(player);
          offer.subtitle = "CYBERWARE - " + RLQuality.DisplayName(offer.step);
          // Chrome that doesn't fit can go in anyway: capacity overclock.
          offer.amount = Max(0, CeilF(cost - available));
          offer.description = offer.amount > 0
            ? s"OVERCLOCK: \(offer.amount) over capacity. Risks cyberpsychosis episodes."
            : s"Capacity \(RoundF(cost)) of \(RoundF(available)) free";
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
    // Weapons say what they are, how they play and how they compare.
    if Equals(kind, RLOfferKind.Weapon) || Equals(kind, RLOfferKind.Iconic) {
      offer.subtitle = (Equals(kind, RLOfferKind.Iconic) ? "ICONIC " : "") + RLWeapons.ClassLine(offer.record) + " - " + RLQuality.DisplayName(offer.step);
      offer.description = RLWeapons.Playstyle(offer.record);
      offer.dpsLine = RLWeapons.CompareLine(player, RLWeapons.PreviewDPS(player, offer.record, offer.step));
    }
    return offer;
  }

  // A few candidates from the pool, picked by build weight.
  private static func PickWeighted(pools: ref<RLTweakPools>, profile: ref<RLBuildProfile>, kind: RLOfferKind, step: Int32, evolutions: array<gamedataWeaponEvolution>, opt noOperatingSystem: Bool) -> TweakDBID {
    let candidates: array<TweakDBID>;
    let noTypes: array<gamedataItemType>;
    let i = 0;
    while i < 4 {
      let candidate = Equals(kind, RLOfferKind.Weapon)
        ? pools.PickWeapon(noTypes, evolutions)
        : pools.PickCyberware(RLRewards.BandForStep(step), false, gamedataItemType.Invalid, candidates);
      if TDBID.IsValid(candidate) && !ArrayContains(candidates, candidate) && !(noOperatingSystem && RLRewards.IsOperatingSystem(candidate)) {
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

  // Upgrades for gear V owns: an evolution when a weapon is ready for one,
  // two quality steps for the weapons (equipped first), a mod, the MaxDoc and
  // the grenade - up to `count` cards.
  public static func WorkshopOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers = RLRewards.EvolveOffers(player, pools, run, 1);
    let health = RLRewards.HealthUpgradeOffer(player);
    let grenade = RLRewards.GrenadeUpgradeOffer(player);
    let mods = RLWeaponMods.Offers(player, run, 1);
    let gearSlots = (IsDefined(health) ? 1 : 0) + (IsDefined(grenade) ? 1 : 0) + ArraySize(mods);
    for offer in RLRewards.WeaponUpgradeOffers(player, Max(1, count - gearSlots - ArraySize(offers)), 2) {
      ArrayPush(offers, offer);
    }
    for offer in mods {
      if ArraySize(offers) < count {
        ArrayPush(offers, offer);
      }
    }
    if IsDefined(health) && ArraySize(offers) < count {
      ArrayPush(offers, health);
    }
    if IsDefined(grenade) && ArraySize(offers) < count {
      ArrayPush(offers, grenade);
    }
    return offers;
  }

  // `steps` quality steps for V's weapons (equipped first).
  public static func WeaponUpgradeOffers(player: ref<PlayerPuppet>, count: Int32, steps: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let stowed: array<ref<RLOffer>>;
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    for item in items {
      if IsDefined(item) && RLWeapons.IsRealWeapon(item.GetID()) {
        let step = RLRewards.ItemStep(item);
        if step < RLQuality.MaxStep() {
          let offer = new RLOffer();
          offer.kind = RLOfferKind.WeaponUpgrade;
          offer.itemID = item.GetID();
          offer.record = ItemID.GetTDBID(item.GetID());
          offer.step = Min(RLQuality.MaxStep(), step + steps);
          offer.title = RLRewards.ItemName(offer.record);
          offer.subtitle = RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
          let before = item.GetStatValueByType(gamedataStatType.EffectiveDPS);
          let after = RLWeapons.PreviewDPS(player, offer.record, offer.step);
          offer.description = RLWeapons.ClassLine(offer.record);
          if before > 0.0 && after > 0.0 {
            offer.dpsLine = s"DPS \(RoundF(before)) > \(RoundF(after))";
          }
          let tag = RLWeapons.FamilyTag(RLWeapons.FamilyOf(RPGManager.GetItemType(offer.itemID)));
          if IsNameValid(tag) {
            ArrayPush(offer.tags, tag);
          }
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

  // Evolution cards: a weapon ready to evolve becomes an iconic of its type
  // (or of its family when its type has none).
  public static func EvolveOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    for itemID in RLWeapons.Evolvable(player, run) {
      if ArraySize(offers) < count {
        let iconic = pools.PickIconicFor(RPGManager.GetItemType(itemID));
        if TDBID.IsValid(iconic) {
          let item = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, itemID);
          let offer = new RLOffer();
          offer.kind = RLOfferKind.Evolve;
          offer.itemID = itemID;
          offer.record = iconic;
          offer.step = IsDefined(item) ? RLRewards.ItemStep(item) : 8;
          offer.title = RLRewards.ItemName(iconic);
          offer.subtitle = "EVOLVE - " + RLRewards.ItemName(ItemID.GetTDBID(itemID));
          offer.description = "Becomes this iconic, keeps its mods, gains a third mod slot. " + RLWeapons.Playstyle(iconic);
          offer.dpsLine = RLWeapons.CompareLine(player, RLWeapons.PreviewDPS(player, iconic, offer.step));
          offer.excitement = 3;
          let tag = RLWeapons.FamilyTag(RLWeapons.FamilyOf(RPGManager.GetItemType(itemID)));
          if IsNameValid(tag) {
            ArrayPush(offer.tags, tag);
          }
          ArrayPush(offers, offer);
        }
      }
    }
    return offers;
  }

  // --- Operating Systems -------------------------------------------------------------------

  public static func OperatingSystems() -> array<CName> = [n"Sandevistan", n"Berserk", n"Cyberdeck"]

  public static func IsOperatingSystem(record: TweakDBID) -> Bool {
    let item = TweakDBInterface.GetItemRecord(record);
    return IsDefined(item) && IsDefined(item.EquipArea()) && Equals(item.EquipArea().Type(), gamedataEquipmentArea.SystemReplacementCW);
  }

  // The Act 1 boss's reward: one of each Operating System, at the boss's
  // quality. Each unlocks its own Overdrive.
  public static func OperatingSystemOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let step = RLRewardDirector.RollStep(run, 3, true);
    for os in RLRewards.OperatingSystems() {
      let record = pools.PickOperatingSystem(os, RLRewards.BandForStep(step));
      if TDBID.IsValid(record) {
        let offer = new RLOffer();
        offer.kind = RLOfferKind.OperatingSystem;
        offer.record = record;
        offer.mod = os;
        offer.step = RLQuality.StepOfRecord(record);
        offer.title = RLRewards.ItemName(record);
        offer.subtitle = "OPERATING SYSTEM - " + RLQuality.DisplayName(offer.step);
        offer.description = "OVERDRIVE: " + RLOverdrive.Name(os) + ". " + RLOverdrive.Description(os);
        offer.excitement = 2;
        if Equals(os, n"Cyberdeck") {
          ArrayPush(offer.tags, n"netrunner");
        }
        ArrayPush(offers, offer);
      }
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
    offer.description = "Your MaxDoc heals more.";
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
    offer.description = "Replaces your grenade.";
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
        if offer.amount > 0 {
          RLRewards.Overclock(player, run, offer.amount);
        }
        RLGear.InstallCyberware(player, offer.record);
        break;
      case RLOfferKind.OperatingSystem:
        RLRewards.InstallOperatingSystem(player, run, offer);
        break;
      case RLOfferKind.WeaponMod:
        RLWeaponMods.Install(run, offer.itemID, offer.mod);
        break;
      case RLOfferKind.Evolve:
        RLWeapons.Evolve(player, run, offer.itemID, offer.record, offer.step);
        break;
      case RLOfferKind.Attribute:
        let development = PlayerDevelopmentSystem.GetData(player);
        if IsDefined(development) {
          development.RL_RaiseAttribute(offer.stat, 1);
          development.UpdateUIBB();
        }
        break;
      case RLOfferKind.Capacity:
        RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, Cast<Float>(offer.amount));
        run.overclock = Max(0, run.overclock - offer.amount);
        break;
      case RLOfferKind.BoonUpgrade:
        RLBoons.Apply(player, run, offer.boon, offer.rarity);
        break;
      case RLOfferKind.Gig:
        RLGigs.Take(run, offer.amount);
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

  // Chrome over capacity: the capacity is raised to fit, and the run keeps
  // count of the overclock (Run/Overdrive.reds rolls episodes from it).
  public static func Overclock(player: ref<PlayerPuppet>, run: ref<RLRunState>, amount: Int32) {
    RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, Cast<Float>(amount));
    run.overclock += amount;
    RLLog(s"Capacity overclock +\(amount) (now \(run.overclock)).");
  }

  // An Operating System brings its own capacity, unlocks Overdrive, and a
  // cyberdeck comes with the Overclock perk that activates it.
  private static func InstallOperatingSystem(player: ref<PlayerPuppet>, run: ref<RLRunState>, offer: ref<RLOffer>) {
    let cost = RLGear.NetCapacityCost(player, offer.record);
    if cost > 0.0 {
      RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, cost);
    }
    RLGear.InstallCyberware(player, offer.record);
    if Equals(offer.mod, n"Cyberdeck") {
      let overclock = RLPerkCatalog.Find(gamedataNewPerkType.Intelligence_Central_Milestone_3);
      if IsDefined(overclock) && !RLPerkCatalog.IsOwned(PlayerDevelopmentSystem.GetData(player), overclock.perk) {
        RLPerkCatalog.Grant(player, overclock);
      }
    }
    run.os = offer.mod;
    run.overdriveUnlocked = true;
    run.overdrive = 50.0;
    RLNotify(player.GetGame(), "OVERDRIVE ONLINE: " + RLOverdrive.Name(offer.mod) + ". Fill the meter, then activate your OS.", 8.0);
  }

  // --- Saying no ---------------------------------------------------------------------------

  // What a banish removes: the item, perk, boon or mod, in any quality.
  public static func OfferKey(offer: ref<RLOffer>) -> String {
    switch offer.kind {
      case RLOfferKind.Perk:
        return "perk:" + EnumValueToString("gamedataNewPerkType", Cast<Int64>(EnumInt(offer.perk)));
      case RLOfferKind.Boon:
      case RLOfferKind.BoonUpgrade:
        return "boon:" + NameToString(offer.boon);
      case RLOfferKind.WeaponMod:
        return "mod:" + NameToString(offer.mod);
      case RLOfferKind.Weapon:
      case RLOfferKind.Iconic:
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
        return "item:" + offer.title;
    }
    return "";
  }

  public static func CanBanish(offer: ref<RLOffer>) -> Bool = StrLen(RLRewards.OfferKey(offer)) > 0

  // Takes banished cards off a freshly rolled screen.
  public static func DropBanished(run: ref<RLRunState>, out offers: array<ref<RLOffer>>) {
    let i = ArraySize(offers) - 1;
    while i >= 0 {
      let key = RLRewards.OfferKey(offers[i]);
      if StrLen(key) > 0 && ArrayContains(run.banished, key) {
        ArrayErase(offers, i);
      }
      i -= 1;
    }
  }

  // A door's reward screen (not a level-up, gig or the Operating System).
  public static func IsDoorReward(category: RLRewardCategory) -> Bool {
    switch category {
      case RLRewardCategory.LevelUp:
      case RLRewardCategory.Gig:
      case RLRewardCategory.System:
        return false;
    }
    return true;
  }

  // The screen's name in telemetry.
  public static func ScreenName(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.LevelUp: return "levelup";
      case RLRewardCategory.Gig: return "gig";
      case RLRewardCategory.System: return "os";
    }
    return "reward";
  }

  // The screen already shows this card (same item, perk, boon or mod).
  public static func ContainsCard(offers: array<ref<RLOffer>>, candidate: ref<RLOffer>) -> Bool {
    let key = RLRewards.OfferKey(candidate);
    for offer in offers {
      if Equals(offer.title, candidate.title) || (StrLen(key) > 0 && Equals(RLRewards.OfferKey(offer), key)) {
        return true;
      }
    }
    return false;
  }

  // Eddies for skipping a reward screen.
  public static func SkipEddies(run: ref<RLRunState>) -> Int32 = 100 + 25 * run.Depth()

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

// -----------------------------------------------------------------------------
// Night City Roguelite - rewards
// -----------------------------------------------------------------------------
// Between fights V picks the next fight by what it pays (a "door"), and after
// it, one card from that door's screen - two decisions a floor, both at the
// terminal-free moments between arenas:
//
//   PATRON    effects from one of the run's four patrons (Rewards/Boons.reds)
//   ARMORY    the main weapon: a Tune-Up, weapon effects, a TRADE, grenades
//   TUNE-UP   floors 4, 10 and 16: the evolution, big Tune-Ups, the MaxDoc
//   CHROME    cyberware, installed on the spot
//   DAEMONS   quickhacks
//   TRAINING  perks (the only place they come from)
//   BOUNTY    a lone cyberpsycho (Act 2 on): eddies and a patron pick
//   CRED      now and then: Cred for the meta, no card at all
//   ?         an event instead of a fight (Run/Events.reds)
//
// Every regular door is the same fight; danger lives only on HOT doors, which
// the Director places when V needs a spike most (Rewards/Director.reds). A
// hot door pays its own reward two quality steps up, one card more, a big
// card on patron screens, and half again the eddies.
//
// Patron screens are dealt, not drawn: one card that builds on what V holds
// (an overclock, a duo, an effect that uses what V's effects make), one V
// hasn't seen this run, one open. The first screen of a run deals only
// effects that make something, so the first pick always starts a build.
//
// A screen can be skipped for eddies, and one card per act banished for the
// rest of the run.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLOfferKind {
  Trade = 0,
  Iconic = 1,
  Cyberware = 2,
  Quickhack = 3,
  Boon = 4,
  Perk = 5,
  Grenade = 6,
  TuneUp = 7,
  HealthUpgrade = 8,
  Evolve = 9,
  Capacity = 10,
  OperatingSystem = 11,
  Gig = 12,
  Rewire = 13,
  ArmMod = 14,
}

public enum RLRewardCategory {
  Armory = 0,
  Chrome = 1,
  Daemons = 2,
  Boons = 3,
  Training = 4,
  Workshop = 5,
  Event = 6,
  Bounty = 7,
  Cred = 8,
  // Not doors: the screens between them.
  System = 9,
  Gig = 10,
}

// One choice for the next fight.
public class RLDoor {
  public let category: RLRewardCategory;
  public let threat: Int32;
  public let hot: Bool;
  public let arena: CName;
  public let faction: ref<RLFactionPool>;
  public let boss: Bool;
  // Patron doors (and bounties): whose effects the reward screen offers.
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
  // Effects: which, its overclock or not, its patron.
  public let boon: CName;
  public let overclock: Bool;
  public let patron: CName;
  // Effects V holds that this card works with (BUILDS ON), and a card V has
  // never taken in any run (NEW).
  public let links: array<CName>;
  public let isNew: Bool;
  // Keywords it makes and uses (effects, arm mods, a rewire's element).
  public let makes: array<CName>;
  public let uses: array<CName>;
  public let tags: array<CName>;
  // Operating Systems: the kind (Sandevistan, Berserk, Cyberdeck).
  public let mod: CName;
  // Capacity and gig cards: the amount or the style.
  public let amount: Int32;
  // Numbers that matter on the card ("DPS 212 > 268").
  public let dpsLine: String;
  public let title: String;
  public let subtitle: String;
  public let description: String;
  public let disabled: Bool;
  // How far above the floor's expectation the card is (reward director).
  public let excitement: Int32;
  // Quickhacks into a full deck: the slotted hack it swaps out (the slot
  // picker's choice, UI/RewardPopup.reds).
  public let replaces: ItemID;
}

public abstract class RLRewards {
  // --- Categories ----------------------------------------------------------------------

  public static func CategoryName(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "ARMORY";
      case RLRewardCategory.Chrome: return "CHROME";
      case RLRewardCategory.Daemons: return "DAEMONS";
      case RLRewardCategory.Boons: return "PATRON";
      case RLRewardCategory.Training: return "TRAINING";
      case RLRewardCategory.Workshop: return "TUNE-UP";
      case RLRewardCategory.Event: return "?";
      case RLRewardCategory.Bounty: return "BOUNTY";
      case RLRewardCategory.Cred: return "CRED";
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

  // How many cards the door's screen deals.
  // What a door's screen will deal, as its card promises it (Open Line's
  // extra card on the run's first patron screen included).
  public static func DoorCardCount(run: ref<RLRunState>, door: ref<RLDoor>) -> Int32 {
    let count = RLRewards.CardCount(run, door.hot);
    if Equals(door.category, RLRewardCategory.Boons) && !run.firstPatronDealt && RLTerminal.Has(n"PatronsEar", 1) {
      count += 1;
    }
    return count;
  }

  // Cards on a reward screen: a hot door deals one more (two with Hot
  // Streak).
  public static func CardCount(run: ref<RLRunState>, hot: Bool) -> Int32 {
    if !hot {
      return run.offerCount;
    }
    return run.offerCount + (RLTerminal.Has(n"HotStreak", 1) ? 2 : 1);
  }

  // What a door pays, in plain words ("Pick 1 of 3 Voodoo Boys effects.").
  public static func DoorPromise(run: ref<RLRunState>, door: ref<RLDoor>, count: Int32) -> String {
    let pick = s"Pick 1 of \(count) ";
    let deck = RLArms.IsMainDeck(run);
    let chrome = RLArms.IsMainChrome(run);
    switch door.category {
      case RLRewardCategory.Armory:
        if deck {
          return pick + "for your deck: tune-ups, weapon effects, a new quickhack.";
        }
        return pick + (RLArms.IsMainArms(run) ? "for your chrome: tune-ups, weapon effects, a rewire." : "for your main weapon: tune-ups, weapon effects, a trade.");
      case RLRewardCategory.Chrome: return pick + "cyberware, installed on the spot.";
      case RLRewardCategory.Daemons: return pick + (deck ? "quickhacks for your deck." : "quickhacks.");
      case RLRewardCategory.Training: return pick + "perks.";
      case RLRewardCategory.Workshop: return chrome ? "Evolve, tune up or mod your chrome." : "Evolve or tune up your main weapon, or upgrade your MaxDoc.";
      case RLRewardCategory.Boons: return pick + RLPatrons.Name(door.patron) + " effects.";
      case RLRewardCategory.Bounty: return "One cyberpsycho. Pays big in eddies, plus a " + RLPatrons.Name(door.patron) + " pick.";
      case RLRewardCategory.Cred: return "No card. Cred, kept for good.";
      case RLRewardCategory.Event: return "No fight - " + RLEvents.Title(door.event);
      case RLRewardCategory.System: return "Pick your operating system. It unlocks Overdrive, your ultimate.";
    }
    return "";
  }

  // What a door's reward is, where the name alone doesn't say.
  public static func CategoryDescription(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Armory: return "Make your gun yours.";
      case RLRewardCategory.Chrome: return "New chrome, straight off the table.";
      case RLRewardCategory.Daemons: return "Quickhacks. Fry their optics.";
      case RLRewardCategory.Boons: return "Someone powerful backs you.";
      case RLRewardCategory.Training: return "Perks. Sharpen what works.";
      case RLRewardCategory.Workshop: return "Tune up what you're packing.";
      case RLRewardCategory.Event: return "No fight. Something else.";
      case RLRewardCategory.Bounty: return "Cyberpsycho loose. NCPD pays.";
      case RLRewardCategory.Cred: return "Skip the shopping. Bank it.";
      case RLRewardCategory.System: return "Your operating system. And Overdrive.";
    }
    return "";
  }

  // Cred a Cred door pays.
  public static func CredDoorAmount(run: ref<RLRunState>) -> Int32 = 30 + 15 * run.act

  // The floors with a Tune-Up door (and the one after, when it was passed over).
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
  // Training fight first, otherwise `count` different reward types in
  // different arenas, each with its enemy faction already known - and now
  // and then one of them HOT.
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
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Boons, false, usedArenas));
      return doors;
    }
    let used: array<RLRewardCategory>;
    let depth = run.Depth();
    // The Tune-Up is one of the doors on floors 4, 10 and 16 (and once more
    // on the next floor if it was passed over), like Hades' Daedalus hammers.
    if RLRewards.IsWorkshopFloor(depth) || run.workshopCarry {
      run.workshopShown = true;
      ArrayPush(used, RLRewardCategory.Workshop);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Workshop, false, usedArenas));
    }
    // Now and then a door is an event (no fight), a bounty (Act 2 on) or
    // Cred. Test runs always show the event and the bounty.
    let eventChance = RLConfig.EventDoorChance() * (RLTerminal.Has(n"InsideMan", 1) ? 2.0 : 1.0);
    if (depth >= 2 || run.isTest) && !run.IsEliteFloor() && ArraySize(doors) < count && (run.isTest || RandF() < eventChance) {
      ArrayPush(used, RLRewardCategory.Event);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Event, false, usedArenas));
    }
    let bountyAct = RLTerminal.Has(n"BountyBoard", 1) ? 1 : 2;
    if run.act >= bountyAct && depth >= 2 && ArraySize(doors) < count && (run.isTest || RandF() < RLConfig.BountyDoorChance()) {
      ArrayPush(used, RLRewardCategory.Bounty);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Bounty, false, usedArenas));
    }
    if depth >= 3 && !run.isTest && ArraySize(doors) < count && RandF() < RLConfig.CredDoorChance() {
      ArrayPush(used, RLRewardCategory.Cred);
      ArrayPush(doors, RLRewards.MakeDoor(pools, run, RLRewardCategory.Cred, false, usedArenas));
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
    if RLRewardDirector.WantsHotDoor(player, run) {
      RLRewards.MakeOneHot(player, pools, run, doors, usedArenas);
    }
    // Inside Man: Acts 2 and 3 open with a door from V's lead patron (a
    // reroll of those doors keeps it).
    if run.floor == 1 && run.act > 1 && RLTerminal.Has(n"InsideMan", 2) {
      RLRewards.PlacePatronDoor(pools, run, doors, usedArenas);
    }
    return doors;
  }

  // The Director's door: the family V's build lacks most - the Armory when
  // the main weapon is behind the floor, otherwise the patron V leans on.
  // An existing door of that kind turns hot, or takes the last regular
  // door's place (an event, bounty or Cred door's when there is none; the
  // Tune-Up door always stays).
  private static func MakeOneHot(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, out doors: array<ref<RLDoor>>, out usedArenas: array<CName>) {
    let behind = run.mainStep < RLQuality.ExpectedStep(run.Depth(), run.TotalFloors()) - 1;
    let category = behind ? RLRewardCategory.Armory : RLRewardCategory.Boons;
    let patron = RLPatrons.Lead(run);
    for door in doors {
      let matches = behind
        ? Equals(door.category, RLRewardCategory.Armory)
        : Equals(door.category, RLRewardCategory.Boons) && (!IsNameValid(patron) || Equals(door.patron, patron));
      if matches {
        RLRewards.SetHot(run, door);
        return;
      }
    }
    let replace = RLRewards.LastDoorWhere(doors, true);
    if replace < 0 {
      replace = RLRewards.LastDoorWhere(doors, false);
    }
    if replace < 0 {
      return;
    }
    let door = RLRewards.MakeDoor(pools, run, category, false, usedArenas);
    if Equals(category, RLRewardCategory.Boons) && IsNameValid(patron) && !RLRewards.HasPatronDoor(doors, patron) {
      door.patron = patron;
    }
    doors[replace] = door;
    RLRewards.SetHot(run, door);
  }

  // The last regular door (or, `regular` false, the last that isn't the
  // Tune-Up); -1 when there is none.
  private static func LastDoorWhere(doors: array<ref<RLDoor>>, regular: Bool) -> Int32 {
    let i = ArraySize(doors) - 1;
    while i >= 0 {
      let fits = regular ? RLRewards.IsRegular(doors[i]) : !Equals(doors[i].category, RLRewardCategory.Workshop);
      if fits {
        return i;
      }
      i -= 1;
    }
    return -1;
  }

  // The lead patron's door, in place of the last regular door that isn't
  // already one of theirs.
  private static func PlacePatronDoor(pools: ref<RLTweakPools>, run: ref<RLRunState>, out doors: array<ref<RLDoor>>, out usedArenas: array<CName>) {
    let patron = RLPatrons.Lead(run);
    if !IsNameValid(patron) || RLRewards.HasPatronDoor(doors, patron) {
      return;
    }
    let i = ArraySize(doors) - 1;
    while i >= 0 {
      if RLRewards.IsRegular(doors[i]) && !doors[i].hot {
        let door = RLRewards.MakeDoor(pools, run, RLRewardCategory.Boons, false, usedArenas);
        door.patron = patron;
        doors[i] = door;
        return;
      }
      i -= 1;
    }
  }

  private static func SetHot(run: ref<RLRunState>, door: ref<RLDoor>) {
    door.hot = true;
    door.threat = 3;
    door.objective = RLObjectiveKind.None;
    RLRewardDirector.OnHotPlaced(run);
  }

  // A plain fight door (not the Tune-Up, an event, a bounty or Cred).
  private static func IsRegular(door: ref<RLDoor>) -> Bool {
    switch door.category {
      case RLRewardCategory.Workshop:
      case RLRewardCategory.Event:
      case RLRewardCategory.Bounty:
      case RLRewardCategory.Cred:
        return false;
    }
    return !door.boss;
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
    door.threat = boss ? 3 : (Equals(category, RLRewardCategory.Event) ? 0 : 2);
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
    // No chrome before floor 3.
    let early = run.Depth() < 3;
    // Daemons doors show up more for netrunner builds.
    let daemons = 0;
    if pools.HasQuickhacks() && !early {
      daemons = 8 + RoundF(10.0 * MinF(profile.Weight(n"netrunner"), 3.0) / 3.0);
    }
    // Armory, Chrome, Daemons, Boons, Training
    let weights: array<Int32> = [24, early ? 0 : 16, daemons, 32, 16];
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

  // The reward screen for a cleared fight. `hot`: the door was hot - two
  // quality steps up and a big card.
  public static func RollForCategory(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, patron: CName, hot: Bool, count: Int32) -> array<ref<RLOffer>> {
    let profile = RLBuildProfile.Read(player);
    // Sure Thing: an act's first reward screen always has a standout.
    let spike = hot || RLRewardDirector.SpikeDue(run) || run.floor == 1 && RLTerminal.Has(n"LuckyStar", 2);
    let offers: array<ref<RLOffer>>;
    switch category {
      case RLRewardCategory.System:
        return RLRewards.OperatingSystemOffers(player, pools, run);
      case RLRewardCategory.Gig:
        return RLGigs.Offers(run);
      case RLRewardCategory.Training:
        offers = RLRewards.PerkOffers(player, run, profile, count, hot ? count : (spike ? 1 : 0));
        break;
      case RLRewardCategory.Workshop:
        offers = RLRewards.WorkshopOffers(player, pools, run, count);
        break;
      case RLRewardCategory.Boons:
      case RLRewardCategory.Bounty:
        offers = RLRewards.BoonOffers(player, run, patron, count, hot);
        break;
      case RLRewardCategory.Armory:
        offers = RLRewards.ArmoryOffers(player, pools, run, count, hot, spike);
        break;
      default:
        offers = RLRewards.ItemOffers(player, pools, run, category, count, profile, spike, hot);
    }
    RLRewards.DropBanished(run, offers);
    // Nothing of that type is available (or the patron has nothing left):
    // another patron's effects instead.
    for other in run.patrons {
      if ArraySize(offers) == 0 {
        offers = RLRewards.BoonOffers(player, run, other, count, hot);
      }
    }
    RLRewards.KeepOneOffBuild(player, pools, run, category, profile, offers);
    return offers;
  }

  // Cards V actually got to see: patron cards stop counting as unseen.
  public static func MarkSeen(run: ref<RLRunState>, offers: array<ref<RLOffer>>) {
    for offer in offers {
      if Equals(offer.kind, RLOfferKind.Boon) && !ArrayContains(run.seen, offer.boon) {
        ArrayPush(run.seen, offer.boon);
      }
    }
  }

  // --- Patron screens ---------------------------------------------------------------------

  // A patron's screen, dealt: a card that builds on V's effects, a card V
  // hasn't seen this run, then open picks. `big`: a hot door - one card is
  // an overclock, a duo or a legendary when V qualifies for one.
  public static func BoonOffers(player: ref<PlayerPuppet>, run: ref<RLRunState>, patron: CName, count: Int32, big: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let builds: array<ref<RLBoonDef>>;
    let fresh: array<ref<RLBoonDef>>;
    let open: array<ref<RLBoonDef>>;
    let bigs: array<ref<RLBoonDef>>;
    let starting = RLRewards.HeldEffects(run) == 0;
    for def in RLBoons.All() {
      if (Equals(def.patron, patron) || Equals(def.partner, patron)) && RLBoons.IsOfferable(run, def) && RLRewards.FitsSlots(run, def) {
        let owned = RLBoons.Has(run, def.id);
        // The first pick of a run starts a build: only effects that make something.
        if !starting || (ArraySize(def.makes) > 0 && !owned && (Equals(def.kind, RLBoonKind.Effect) || Equals(def.kind, RLBoonKind.Weapon))) {
          let special = owned || Equals(def.kind, RLBoonKind.Duo) || Equals(def.kind, RLBoonKind.Legendary);
          let links = RLBoons.Links(run, def);
          if special || ArraySize(links) > 0 {
            ArrayPush(builds, def);
          }
          if special {
            ArrayPush(bigs, def);
          }
          if !owned && !ArrayContains(run.seen, def.id) {
            ArrayPush(fresh, def);
          }
          ArrayPush(open, def);
        }
      }
    }
    let taken: array<CName>;
    if big {
      RLRewards.DealOne(player, run, bigs, taken, offers);
    }
    RLRewards.DealOne(player, run, builds, taken, offers);
    RLRewards.DealOne(player, run, fresh, taken, offers);
    while ArraySize(offers) < count && RLRewards.DealOne(player, run, open, taken, offers) {
    }
    while ArraySize(offers) > count {
      ArrayPop(offers);
    }
    return offers;
  }

  // Effects V holds (favours aside).
  public static func HeldEffects(run: ref<RLRunState>) -> Int32 {
    let count = 0;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && NotEquals(def.kind, RLBoonKind.Favour) {
        count += 1;
      }
    }
    return count;
  }

  // Weapon effects need a main weapon.
  private static func FitsSlots(run: ref<RLRunState>, def: ref<RLBoonDef>) -> Bool {
    return NotEquals(def.kind, RLBoonKind.Weapon) || ItemID.IsValid(run.mainWeapon);
  }

  // Deals one card from `pool` that isn't on the screen yet; false when
  // there is none.
  private static func DealOne(player: ref<PlayerPuppet>, run: ref<RLRunState>, pool: array<ref<RLBoonDef>>, out taken: array<CName>, out offers: array<ref<RLOffer>>) -> Bool {
    let candidates: array<ref<RLBoonDef>>;
    for def in pool {
      if !ArrayContains(taken, def.id) {
        ArrayPush(candidates, def);
      }
    }
    if ArraySize(candidates) == 0 {
      return false;
    }
    let def = candidates[RandRange(0, ArraySize(candidates))];
    ArrayPush(taken, def.id);
    ArrayPush(offers, RLRewards.BoonOffer(run, def));
    return true;
  }

  // One effect card: the effect, or its overclock when V holds it.
  public static func BoonOffer(run: ref<RLRunState>, def: ref<RLBoonDef>) -> ref<RLOffer> {
    let overclock = RLBoons.Has(run, def.id);
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Boon;
    offer.boon = def.id;
    offer.overclock = overclock;
    offer.patron = def.patron;
    offer.tags = def.tags;
    offer.makes = def.makes;
    offer.uses = def.uses;
    offer.title = overclock ? def.name + "+" : def.name;
    offer.description = RLWeaponActions.Text(run, def, overclock);
    let patrons = Equals(def.kind, RLBoonKind.Duo) ? RLPatrons.Name(def.patron) + " + " + RLPatrons.Name(def.partner) : RLPatrons.Name(def.patron);
    offer.subtitle = (overclock ? "OVERCLOCK" : RLBoons.KindName(def.kind)) + " - " + patrons;
    if overclock {
      ArrayPush(offer.links, def.id);
      offer.step = 6;
      offer.excitement = 2;
    } else {
      offer.links = RLBoons.Links(run, def);
      offer.isNew = !RogueliteService.Get().HasTakenBoon(def.id);
      switch def.kind {
        case RLBoonKind.Legendary:
          offer.step = 8;
          offer.excitement = 3;
          break;
        case RLBoonKind.Duo:
          offer.step = 6;
          offer.excitement = 2;
          break;
        default:
          offer.step = 4;
          offer.excitement = ArraySize(offer.links) > 0 ? 1 : 0;
      }
    }
    return offer;
  }

  // A random effect from one of the run's patrons (the Fixer, events).
  public static func AnyBoonOffer(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> ref<RLOffer> {
    let patrons = run.patrons;
    while ArraySize(patrons) > 0 {
      let i = RandRange(0, ArraySize(patrons));
      let offers = RLRewards.BoonOffers(player, run, patrons[i], 1, false);
      if ArraySize(offers) > 0 {
        return offers[0];
      }
      ArrayErase(patrons, i);
    }
    return null;
  }

  // --- The Armory ---------------------------------------------------------------------------

  // The main weapon's screen: the evolution when it's ready, a Tune-Up,
  // weapon effects from the run's patrons, one TRADE (a REWIRE for arms, a
  // quickhack for a deck), now and then a grenade. Chrome's mods are the
  // Tune-Up door's.
  private static func ArmoryOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, count: Int32, hot: Bool, spike: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let evolve = RLRewards.EvolveOffer(player, pools, run);
    if IsDefined(evolve) {
      ArrayPush(offers, evolve);
    }
    let tune = RLRewards.TuneUpOffer(player, run, hot ? 3 : (spike ? 2 : 1));
    if IsDefined(tune) {
      ArrayPush(offers, tune);
    }
    let effects: array<ref<RLBoonDef>>;
    for def in RLBoons.All() {
      if Equals(def.kind, RLBoonKind.Weapon) && ArrayContains(run.patrons, def.patron) && RLBoons.IsOfferable(run, def) && RLRewards.FitsSlots(run, def) {
        ArrayPush(effects, def);
      }
    }
    // One TRADE after at least one weapon effect: another gun, the same arms
    // in another element (REWIRE), or for a deck a quickhack it doesn't run.
    let trade: ref<RLOffer>;
    if RLArms.IsMainDeck(run) {
      let none: array<CName>;
      trade = RLHacks.DeckOffer(player, run, none, spike);
    } else {
      trade = RLArms.IsMainArms(run) ? RLArms.RewireOffer(run) : RLRewards.TradeOffer(player, pools, run);
    }
    let taken: array<CName>;
    let room = Max(1, count - ArraySize(offers) - (IsDefined(trade) ? 1 : 0));
    while room > 0 && RLRewards.DealOne(player, run, effects, taken, offers) {
      room -= 1;
    }
    if IsDefined(trade) && ArraySize(offers) < count {
      ArrayPush(offers, trade);
    }
    let guard = 0;
    while ArraySize(offers) < count && guard < 6 {
      guard += 1;
      let grenade = RLRewards.BuildOffer(player, pools, run, RLOfferKind.Grenade, null, spike);
      if IsDefined(grenade) && !RLRewards.IsDuplicate(offers, grenade) {
        ArrayPush(offers, grenade);
      }
    }
    return offers;
  }

  // `steps` quality steps for the main weapon's slot, with its DPS before and
  // after (arm chrome: the record it becomes).
  public static func TuneUpOffer(player: ref<PlayerPuppet>, run: ref<RLRunState>, steps: Int32) -> ref<RLOffer> {
    if !ItemID.IsValid(run.mainWeapon) || run.mainStep >= RLQuality.MaxStep() {
      return null;
    }
    let target = Min(RLQuality.MaxStep(), run.mainStep + steps);
    let record = RLArms.IsMainChrome(run) ? RLArms.MainRecordAt(run, target) : RLWeapons.MainRecord(run);
    // A deck at the end of its upgrade chain has nowhere to go.
    if RLArms.IsMainDeck(run) && record == ItemID.GetTDBID(run.mainWeapon) {
      return null;
    }
    let offer = new RLOffer();
    offer.kind = RLOfferKind.TuneUp;
    offer.itemID = run.mainWeapon;
    offer.record = record;
    offer.amount = Min(RLQuality.MaxStep(), run.mainStep + steps) - run.mainStep;
    offer.step = run.mainStep + offer.amount;
    offer.title = RLRewards.ItemName(record);
    offer.subtitle = "TUNE-UP - " + RLQuality.DisplayName(run.mainStep) + " > " + RLQuality.DisplayName(offer.step);
    offer.description = offer.amount > 1 ? s"Your main weapon, \(offer.amount) steps up." : "Your main weapon, a step up.";
    let item = RLWeapons.MainItem(player, run);
    let before = IsDefined(item) ? item.GetStatValueByType(gamedataStatType.EffectiveDPS) : 0.0;
    let after = RLWeapons.PreviewDPS(player, record, offer.step);
    if before > 0.0 && after > before {
      offer.dpsLine = s"DPS \(RoundF(before)) > \(RoundF(after))";
    }
    let recipe = RLWeapons.EvolveRecipe(run);
    if StrLen(recipe) > 0 {
      offer.description += " " + recipe;
    }
    offer.excitement = offer.amount;
    return offer;
  }

  // A different gun for the main slot, at the slot's step, keeping every
  // weapon effect: it's about how it plays.
  public static func TradeOffer(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> ref<RLOffer> {
    if !ItemID.IsValid(run.mainWeapon) {
      return null;
    }
    let current = RLWeapons.MainRecord(run);
    let noTypes: array<gamedataItemType>;
    let tries = 0;
    while tries < 6 {
      tries += 1;
      let record = pools.PickWeapon(noTypes, RLRewards.AllowedEvolutions(run.Depth()));
      if TDBID.IsValid(record) && record != current && NotEquals(RLRewards.ItemName(record), RLRewards.ItemName(current)) {
        let offer = new RLOffer();
        offer.kind = RLOfferKind.Trade;
        offer.record = record;
        offer.step = run.mainStep;
        offer.tier = RLQuality.TierName(run.mainStep);
        offer.title = RLRewards.ItemName(record);
        offer.subtitle = "TRADE - " + RLWeapons.ClassLine(record) + " - " + RLQuality.DisplayName(run.mainStep);
        offer.description = RLWeapons.Playstyle(record) + " Same tier, same weapon effects.";
        offer.tags = RLBuildProfile.RecordTags(record);
        return offer;
      }
    }
    return null;
  }

  // The evolution, when the main weapon is ready for it.
  public static func EvolveOffer(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> ref<RLOffer> {
    if !RLWeapons.CanEvolve(run) {
      return null;
    }
    if RLArms.IsMainChrome(run) {
      return RLArms.EvolveOffer(run);
    }
    let iconic = pools.PickIconicFor(RPGManager.GetItemType(run.mainWeapon));
    if !TDBID.IsValid(iconic) {
      return null;
    }
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Evolve;
    offer.itemID = run.mainWeapon;
    offer.record = iconic;
    offer.step = run.mainStep;
    offer.title = RLRewards.ItemName(iconic);
    offer.subtitle = "EVOLVE - " + RLRewards.ItemName(RLWeapons.MainRecord(run));
    offer.description = "Becomes this iconic, effects and all, with a third weapon effect slot. " + RLWeapons.Playstyle(iconic);
    offer.excitement = 3;
    return offer;
  }

  // --- Tune-Up doors ---------------------------------------------------------------------

  // Upgrades for what V carries: the evolution when it's ready, two steps for
  // the main weapon, the main chrome's mods (Hades' hammers), the MaxDoc, the
  // grenade, room for chrome when overclocked.
  public static func WorkshopOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let evolve = RLRewards.EvolveOffer(player, pools, run);
    if IsDefined(evolve) {
      ArrayPush(offers, evolve);
    }
    let tune = RLRewards.TuneUpOffer(player, run, 2);
    if IsDefined(tune) {
      ArrayPush(offers, tune);
    }
    let dealt: array<CName>;
    let mods = 0;
    while mods < 2 && ArraySize(offers) < count {
      let mod = RLArmMods.DealOne(run, dealt);
      if !IsDefined(mod) {
        mods = 2;
      } else {
        ArrayPush(dealt, mod.boon);
        ArrayPush(offers, mod);
        mods += 1;
      }
    }
    let health = RLRewards.HealthUpgradeOffer(player);
    if IsDefined(health) && ArraySize(offers) < count {
      ArrayPush(offers, health);
    }
    let grenade = RLRewards.GrenadeUpgradeOffer(player);
    if IsDefined(grenade) && ArraySize(offers) < count {
      ArrayPush(offers, grenade);
    }
    if run.overclock > 0 && ArraySize(offers) < count {
      ArrayPush(offers, RLRewards.CapacityOffer(run));
    }
    return offers;
  }

  public static func CapacityAmount() -> Int32 = 4

  public static func CapacityOffer(run: ref<RLRunState>) -> ref<RLOffer> {
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Capacity;
    offer.amount = RLRewards.CapacityAmount();
    offer.title = s"Capacity +\(offer.amount)";
    offer.subtitle = "CYBERWARE CAPACITY";
    offer.description = run.overclock > 0
      ? s"Room for more chrome. Pays down your overclock (\(run.overclock) over)."
      : "Room for more chrome.";
    offer.step = 4;
    ArrayPush(offer.tags, n"chrome");
    return offer;
  }

  // --- Item screens (chrome, quickhacks, perks) ---------------------------------------------

  // A screen never shows the same item twice (in any quality) or one V
  // already carries.
  // A spike puts one card two steps up; a hot door all of them.
  private static func ItemOffers(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, count: Int32, profile: ref<RLBuildProfile>, spike: Bool, hot: Bool) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    // A deck in the main slot: quickhacks it doesn't run, at its quality.
    if Equals(category, RLRewardCategory.Daemons) && RLArms.IsMainDeck(run) {
      let dealt: array<CName>;
      while ArraySize(offers) < count {
        let hack = RLHacks.DeckOffer(player, run, dealt, hot || spike);
        if !IsDefined(hack) {
          return offers;
        }
        ArrayPush(dealt, RLHacks.FamilyOf(hack.record).id);
        ArrayPush(offers, hack);
      }
      return offers;
    }
    let owned = RLRewards.OwnedNames(player);
    let kind = Equals(category, RLRewardCategory.Daemons) ? RLOfferKind.Quickhack : RLOfferKind.Cyberware;
    let guard = 0;
    while ArraySize(offers) < count && guard < 40 {
      guard += 1;
      let offer = RLRewards.BuildOffer(player, pools, run, kind, profile, hot || spike && ArraySize(offers) == 0);
      if IsDefined(offer) && !RLRewards.IsDuplicate(offers, offer) && !ArrayContains(owned, offer.title) {
        ArrayPush(offers, offer);
      }
    }
    return offers;
  }

  // Names of the weapons, grenades and chrome V carries.
  private static func OwnedNames(player: ref<PlayerPuppet>) -> array<String> {
    let names: array<String>;
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) {
        let category = RPGManager.GetItemCategory(item.GetID());
        if Equals(category, gamedataItemCategory.Weapon) || Equals(category, gamedataItemCategory.Cyberware) || Equals(RPGManager.GetItemType(item.GetID()), gamedataItemType.Gad_Grenade) {
          ArrayPush(names, RLRewards.ItemName(ItemID.GetTDBID(item.GetID())));
        }
      }
    }
    return names;
  }

  private static func PerkOffers(player: ref<PlayerPuppet>, run: ref<RLRunState>, profile: ref<RLBuildProfile>, count: Int32, strong: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let none: array<gamedataNewPerkType>;
    for def in RLPerkCatalog.Pick(player, run, profile, count, strong, none) {
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

  // Item screens keep at least one card that doesn't match the build, so the
  // director nudges and never decides.
  private static func KeepOneOffBuild(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, category: RLRewardCategory, profile: ref<RLBuildProfile>, out offers: array<ref<RLOffer>>) {
    let count = ArraySize(offers);
    if count < 3 || (NotEquals(category, RLRewardCategory.Chrome) && NotEquals(category, RLRewardCategory.Daemons) && NotEquals(category, RLRewardCategory.Training)) {
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
        let picks = RLPerkCatalog.Pick(player, run, null, 1, 0, exclude);
        if ArraySize(picks) > 0 {
          replacement = RLRewards.PerkOffer(run, picks[0]);
        }
      } else {
        replacement = RLRewards.BuildOffer(player, pools, run, Equals(category, RLRewardCategory.Daemons) ? RLOfferKind.Quickhack : RLOfferKind.Cyberware, null, false);
      }
      if IsDefined(replacement) && !profile.HasAny(replacement.tags) && !RLRewards.IsDuplicate(offers, replacement) && !ArrayContains(owned, replacement.title) {
        offers[last] = replacement;
        return;
      }
    }
  }

  public static func IsDuplicate(offers: array<ref<RLOffer>>, candidate: ref<RLOffer>) -> Bool {
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

  // One item card, its quality from the reward director.
  public static func BuildOffer(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, kind: RLOfferKind, profile: ref<RLBuildProfile>, spike: Bool) -> ref<RLOffer> {
    let depth = run.Depth();
    let expected = RLQuality.ExpectedStep(depth, run.TotalFloors());
    let step = RLRewardDirector.RollStep(run, spike);
    let offer = new RLOffer();
    offer.kind = kind;
    offer.step = step;
    let noIDs: array<TweakDBID>;
    switch kind {
      case RLOfferKind.Iconic:
        // The stranger's iconic: never below Rare.
        offer.record = pools.PickIconic();
        offer.step = Clamp(step + 2, 4, RLQuality.MaxStep());
        offer.tier = RLQuality.TierName(offer.step);
        offer.subtitle = "ICONIC - " + RLWeapons.ClassLine(offer.record) + " - " + RLQuality.DisplayName(offer.step);
        offer.description = RLWeapons.Playstyle(offer.record);
        offer.excitement = offer.step - expected;
        break;
      case RLOfferKind.Cyberware:
        // Once Overdrive is unlocked the Operating System stays the one it came with.
        offer.record = RLRewards.PickWeighted(pools, profile, step, run.overdriveUnlocked);
        // Chrome in the main slot stays: no other arms over arms, no
        // Operating System over a deck.
        if RLArms.IsMainArms(run) && RLArms.IsArmsRecord(offer.record) {
          return null;
        }
        if RLArms.IsMainDeck(run) && Equals(EquipmentSystem.GetEquipAreaType(ItemID.FromTDBID(offer.record)), gamedataEquipmentArea.SystemReplacementCW) {
          return null;
        }
        // Arm chrome for a gun build takes over the main slot.
        if !RLArms.IsMainChrome(run) && RLArms.IsArmsRecord(offer.record) && ItemID.IsValid(run.mainWeapon) {
          // It comes in at the main slot's tier, so the card shows that record.
          let family = RLArms.Family(TweakDBInterface.GetItemRecord(offer.record).ItemType().Type());
          let slotRecord = RLArms.Record(family, "", Max(run.mainStep, RLArms.MinStep()));
          if TDBID.IsValid(slotRecord) {
            offer.record = slotRecord;
          }
          offer.mod = n"TakeMain";
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "CYBERWARE - YOUR NEW MAIN";
          offer.description = "Takes the main slot at your main's tier, weapon effects and all. " + RLRewards.ItemName(RLWeapons.MainRecord(run)) + " becomes your sidearm.";
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"chrome");
          offer.title = RLRewards.ItemName(offer.record);
          return offer;
        }
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
          RLHacks.Describe(offer);
          offer.links = RLHacks.Links(run, offer.makes);
          if !EquipmentSystem.IsCyberdeckEquipped(player) {
            offer.description = "Needs a cyberdeck";
          }
          offer.excitement = offer.step - expected;
        }
        break;
      case RLOfferKind.Grenade:
        offer.record = RLConsumables.PickGrenade(step, noIDs);
        if TDBID.IsValid(offer.record) {
          offer.step = RLQuality.StepOfRecord(offer.record);
          offer.subtitle = "GRENADE - " + RLQuality.DisplayName(offer.step);
          if TDBID.IsValid(RLConsumables.CurrentGrenade(player)) {
            offer.description = "Replaces your grenade. Grenades count as BLASTs.";
          }
          offer.excitement = offer.step - expected;
          ArrayPush(offer.tags, n"explosive");
        }
        break;
    }
    if !TDBID.IsValid(offer.record) {
      return null;
    }
    if ArraySize(offer.tags) == 0 {
      offer.tags = RLBuildProfile.RecordTags(offer.record);
    }
    offer.title = RLRewards.ItemName(offer.record);
    return offer;
  }

  // A few cyberware candidates from the pool, picked by build weight.
  private static func PickWeighted(pools: ref<RLTweakPools>, profile: ref<RLBuildProfile>, step: Int32, noOperatingSystem: Bool) -> TweakDBID {
    let candidates: array<TweakDBID>;
    let i = 0;
    while i < 4 {
      let candidate = pools.PickCyberware(RLRewards.BandForStep(step), false, gamedataItemType.Invalid, candidates);
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
    // A deck in the main slot is the Operating System: it goes into Overdrive
    // itself, two steps up.
    if RLArms.IsMainDeck(run) {
      let offer = new RLOffer();
      offer.kind = RLOfferKind.OperatingSystem;
      offer.mod = n"Cyberdeck";
      offer.record = RLArms.MainRecordAt(run, run.mainStep + 2);
      offer.step = RLQuality.StepOfRecord(offer.record);
      let steps = offer.record != ItemID.GetTDBID(run.mainWeapon) ? "Two steps up, and " : "";
      offer.title = RLRewards.ItemName(offer.record);
      offer.subtitle = "YOUR DECK - " + RLQuality.DisplayName(offer.step);
      offer.description = steps + "OVERDRIVE: " + RLOverdrive.Name(n"Cyberdeck") + ". " + RLOverdrive.Description(n"Cyberdeck");
      offer.excitement = 2;
      ArrayPush(offer.tags, n"netrunner");
      ArrayPush(offers, offer);
      return offers;
    }
    let step = RLRewardDirector.RollStep(run, true);
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
    offer.subtitle = "UPGRADE - " + RLQuality.DisplayName(RLQuality.StepOfRecord(ladder[current])) + " > " + RLQuality.DisplayName(offer.step);
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
    offer.subtitle = "UPGRADE - " + RLQuality.DisplayName(step) + " > " + RLQuality.DisplayName(offer.step);
    offer.description = "Replaces your grenade.";
    offer.excitement = 1;
    ArrayPush(offer.tags, n"explosive");
    return offer;
  }

  // --- Granting ------------------------------------------------------------------------

  public static func Grant(player: ref<PlayerPuppet>, run: ref<RLRunState>, offer: ref<RLOffer>) {
    switch offer.kind {
      case RLOfferKind.Trade:
        RLWeapons.ReplaceMain(player, run, offer.record);
        break;
      case RLOfferKind.Evolve:
        if RLArms.IsMainChrome(run) {
          RLArms.Evolve(player, run);
        } else {
          RLWeapons.ReplaceMain(player, run, offer.record);
        }
        break;
      case RLOfferKind.Rewire:
        RLArms.Rewire(player, run, offer);
        break;
      case RLOfferKind.ArmMod:
        RLArmMods.Apply(player, run, offer.boon, offer.overclock);
        break;
      case RLOfferKind.Iconic:
        RLGear.GiveWeapon(player, offer.record, offer.tier, false);
        break;
      case RLOfferKind.TuneUp:
        RLWeapons.TuneUp(player, run, offer.amount);
        break;
      case RLOfferKind.Cyberware:
        if Equals(offer.mod, n"TakeMain") {
          RLArms.TakeOverMain(player, run, offer.record);
          break;
        }
        if offer.amount > 0 {
          RLRewards.Overclock(player, run, offer.amount);
        }
        RLGear.InstallCyberware(player, offer.record);
        break;
      case RLOfferKind.OperatingSystem:
        RLRewards.InstallOperatingSystem(player, run, offer);
        break;
      case RLOfferKind.Capacity:
        RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, Cast<Float>(offer.amount));
        run.overclock = Max(0, run.overclock - offer.amount);
        break;
      case RLOfferKind.Gig:
        RLGigs.Take(run, offer.amount);
        break;
      case RLOfferKind.Quickhack:
        RLHacks.Install(player, offer.record, offer.replaces);
        break;
      case RLOfferKind.Boon:
        RLBoons.Apply(player, run, offer.boon, offer.overclock);
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
    if RLArms.IsMainDeck(run) {
      RLWeapons.TuneUp(player, run, 2);
    } else {
      let cost = RLGear.NetCapacityCost(player, offer.record);
      if cost > 0.0 {
        RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, cost);
      }
      RLGear.InstallCyberware(player, offer.record);
    }
    if Equals(offer.mod, n"Cyberdeck") {
      let overclock = RLPerkCatalog.Find(gamedataNewPerkType.Intelligence_Central_Milestone_3);
      if IsDefined(overclock) && !RLPerkCatalog.IsOwned(PlayerDevelopmentSystem.GetData(player), overclock.perk) {
        RLPerkCatalog.Grant(player, overclock);
      }
    }
    run.os = offer.mod;
    run.overdriveUnlocked = true;
    run.overdrive = RLTerminal.Has(n"Primed", 1) ? RLOverdrive.Full() : 50.0;
    RLNotify(player.GetGame(), "OVERDRIVE ONLINE: " + RLOverdrive.Name(offer.mod) + ". Fill the meter, then activate your OS.", 8.0);
  }

  // --- Saying no ---------------------------------------------------------------------------

  // What a banish removes: the item, perk or effect, in any quality.
  public static func OfferKey(offer: ref<RLOffer>) -> String {
    switch offer.kind {
      case RLOfferKind.Perk:
        return "perk:" + EnumValueToString("gamedataNewPerkType", Cast<Int64>(EnumInt(offer.perk)));
      case RLOfferKind.Boon:
        return "boon:" + NameToString(offer.boon);
      case RLOfferKind.ArmMod:
        return "mod:" + NameToString(offer.boon);
      case RLOfferKind.Trade:
      case RLOfferKind.Iconic:
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
        return "item:" + offer.title;
    }
    return "";
  }

  public static func CanBanish(offer: ref<RLOffer>) -> Bool = StrLen(RLRewards.OfferKey(offer)) > 0

  // An effect card made earlier (a Fixer's shelf) can have gone stale: V
  // took it meanwhile, or the main weapon's slots filled up.
  public static func StillGrantable(run: ref<RLRunState>, offer: ref<RLOffer>) -> Bool {
    if !IsDefined(offer) {
      return false;
    }
    if NotEquals(offer.kind, RLOfferKind.Boon) {
      return true;
    }
    if offer.overclock {
      return RLBoons.Has(run, offer.boon) && !RLBoons.IsOverclocked(run, offer.boon);
    }
    let def = RLBoons.Get(offer.boon);
    return IsDefined(def) && !RLBoons.Has(run, offer.boon) && RLBoons.IsOfferable(run, def);
  }

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

  // A door's reward screen (not the gig or the Operating System).
  public static func IsDoorReward(category: RLRewardCategory) -> Bool {
    return NotEquals(category, RLRewardCategory.Gig) && NotEquals(category, RLRewardCategory.System);
  }

  // The screen's name in telemetry.
  public static func ScreenName(category: RLRewardCategory) -> String {
    switch category {
      case RLRewardCategory.Gig: return "gig";
      case RLRewardCategory.System: return "os";
    }
    return "reward";
  }

  // The screen already shows this card (same item, perk or effect).
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
  // Off the Books doubles it.
  public static func SkipEddies(run: ref<RLRunState>) -> Int32 = (100 + 25 * run.Depth()) * (RLTerminal.Has(n"Skim", 2) ? 2 : 1)

  // Quality step of an owned item (0 Common .. 10 Legendary++).
  public static func ItemStep(item: wref<gameItemData>) -> Int32 {
    return RoundF(item.GetStatValueByType(gamedataStatType.Quality) * 2.0 + item.GetStatValueByType(gamedataStatType.IsItemPlus));
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

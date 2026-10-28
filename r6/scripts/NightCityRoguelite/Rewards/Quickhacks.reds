// -----------------------------------------------------------------------------
// Night City Roguelite - quickhacks
// -----------------------------------------------------------------------------
// A cyberdeck's quickhacks are what it fires, so they're read as weapons:
// each family (every quality of Overheat is one family) has a role, a line
// and the keyword it speaks when an upload lands (Combat/Keywords.reds):
//
//   damage    Overheat BURN, Short Circuit SHOCK, Contagion BLEED (its poison
//             counts as BLEED), Synapse Burnout, Detonate Grenade BLAST
//   control   Ping MARK, Weapon Glitch GLITCH, Cyberware Malfunction GLITCH,
//             Cripple Movement, Reboot Optics, Memory Wipe, Cyberpsychosis
//   ultimate  Suicide, System Collapse
//
// The loadout is what's slotted in the deck. With the deck as the main weapon
// (Rewards/ArmChrome.reds) the slotted quickhacks run at the deck's quality:
// every deck Tune-Up takes them up with it. Its quickhack cards are at that
// quality too - they're about which hack, never a step down - and a full deck
// asks which one to swap out (UI/RewardPopup.reds).
//
// Families are known by the game's own record names (Items.<name>...Program
// for the item, QuickHack.<name>...Hack for the upload), so an upload says
// which hack it was however it got into the deck.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLHackFamily {
  public let id: CName;
  // The game's name for it (English; cards use the item's own localized one).
  public let name: String;
  // Record names: Items.<item><tier>Program, QuickHack.<action><tier>Hack.
  public let item: String;
  public let action: String;
  public let role: Int32;
  public let keyword: CName;
  public let line: String;
}

public abstract class RLHacks {
  public static func Damage() -> Int32 = 0
  public static func Control() -> Int32 = 1
  public static func Ultimate() -> Int32 = 2

  // --- Families -------------------------------------------------------------------------

  public static func Families() -> array<ref<RLHackFamily>> {
    let list: array<ref<RLHackFamily>>;
    let damage = RLHacks.Damage();
    let control = RLHacks.Control();
    RLHacks.Add(list, n"Overheat", "Overheat", "Overheat", "Overheat", damage, n"BURN", "Cooks them from the inside.");
    RLHacks.Add(list, n"ShortCircuit", "Short Circuit", "EMPOverload", "Overload", damage, n"SHOCK", "Fries their chrome. Androids hate it.");
    RLHacks.Add(list, n"Contagion", "Contagion", "Contagion", "Contagion", damage, n"BLEED", "Poison that jumps. It counts as BLEED.");
    RLHacks.Add(list, n"SynapseBurnout", "Synapse Burnout", "BrainMelt", "BrainMelt", damage, n"", "Burns out their brain. Worse the lower they are.");
    RLHacks.Add(list, n"DetonateGrenade", "Detonate Grenade", "GrenadeExplode", "Grenade", damage, n"BLAST", "Sets off the grenade on their belt.");
    RLHacks.Add(list, n"Ping", "Ping", "Ping", "Ping", control, n"MARK", "Lights up them and their whole crew.");
    RLHacks.Add(list, n"WeaponGlitch", "Weapon Glitch", "WeaponMalfunction", "WeaponMalfunction", control, n"GLITCH", "Jams their gun.");
    RLHacks.Add(list, n"CyberwareMalfunction", "Cyberware Malfunction", "DisableCyberware", "CyberwareMalfunction", control, n"GLITCH", "Shuts their chrome down.");
    RLHacks.Add(list, n"CrippleMovement", "Cripple Movement", "LocomotionMalfunction", "LocomotionMalfunction", control, n"", "Locks their legs.");
    RLHacks.Add(list, n"RebootOptics", "Reboot Optics", "Blind", "Blind", control, n"", "Blinds them.");
    RLHacks.Add(list, n"MemoryWipe", "Memory Wipe", "MemoryWipe", "MemoryWipe", control, n"", "They forget you were ever there.");
    RLHacks.Add(list, n"Cyberpsychosis", "Cyberpsychosis", "Madness", "Madness", control, n"", "Turns them on their own crew.");
    RLHacks.Add(list, n"Suicide", "Suicide", "Suicide", "Suicide", RLHacks.Ultimate(), n"", "They pull the trigger on themselves.");
    RLHacks.Add(list, n"SystemCollapse", "System Collapse", "SystemCollapse", "SystemCollapse", RLHacks.Ultimate(), n"", "Drops them where they stand.");
    return list;
  }

  private static func Add(out list: array<ref<RLHackFamily>>, id: CName, const name: String, const item: String, const action: String, role: Int32, keyword: CName, const line: String) {
    let family = new RLHackFamily();
    family.id = id;
    family.name = name;
    family.item = item;
    family.action = action;
    family.role = role;
    family.keyword = keyword;
    family.line = line;
    ArrayPush(list, family);
  }

  public static func Get(id: CName) -> ref<RLHackFamily> {
    for family in RLHacks.Families() {
      if Equals(family.id, id) {
        return family;
      }
    }
    return null;
  }

  private static func ItemTiers() -> array<String> = ["", "Lvl0", "Lvl1", "Lvl2", "Lvl3", "Lvl4", "Lvl4PlusPlus"]

  private static func ActionTiers() -> array<String> = ["", "Base", "Lvl0", "Lvl1", "Lvl2", "Lvl3", "Lvl4", "Lvl4PlusPlus"]

  // The family of a quickhack item, or null. Stocked ones were sorted when
  // the pools were built.
  public static func FamilyOf(record: TweakDBID) -> ref<RLHackFamily> {
    if !TDBID.IsValid(record) {
      return null;
    }
    let service = RogueliteService.Get();
    let known = IsDefined(service) ? service.GetPools().QuickhackFamily(record) : n"";
    if IsNameValid(known) {
      return RLHacks.Get(known);
    }
    return RLHacks.Identify(record);
  }

  // Works a family out from the record's name.
  public static func Identify(record: TweakDBID) -> ref<RLHackFamily> {
    for family in RLHacks.Families() {
      for tier in RLHacks.ItemTiers() {
        if TDBID.Create("Items." + family.item + tier + "Program") == record {
          return family;
        }
      }
    }
    return null;
  }

  // The family of an uploaded quickhack (its object action, or the spread
  // copy the game uploads to the next enemy), or null.
  public static func FamilyOfAction(action: TweakDBID) -> ref<RLHackFamily> {
    if !TDBID.IsValid(action) {
      return null;
    }
    for family in RLHacks.Families() {
      for tier in RLHacks.ActionTiers() {
        let name = "QuickHack." + family.action + tier + "Hack";
        if TDBID.Create(name) == action || TDBID.Create(name + "Spread") == action {
          return family;
        }
      }
    }
    return null;
  }

  // The game spreads a quickhack by uploading its ...HackSpread copy.
  public static func IsSpreadAction(action: TweakDBID) -> Bool {
    if !TDBID.IsValid(action) {
      return false;
    }
    for family in RLHacks.Families() {
      for tier in RLHacks.ActionTiers() {
        if TDBID.Create("QuickHack." + family.action + tier + "HackSpread") == action {
          return true;
        }
      }
    }
    return false;
  }

  public static func Keyword(record: TweakDBID) -> CName {
    let family = RLHacks.FamilyOf(record);
    return IsDefined(family) ? family.keyword : n"";
  }

  public static func Line(record: TweakDBID) -> String {
    let family = RLHacks.FamilyOf(record);
    return IsDefined(family) ? family.line : "";
  }

  // --- Qualities ------------------------------------------------------------------------

  // Every quality of a family the vendors stock (the run's item pool).
  private static func Records(family: ref<RLHackFamily>) -> array<TweakDBID> = RogueliteService.Get().GetPools().QuickhackRecords(family.id)

  // The family at a quality: the best one at or under `step`, else its
  // lowest (the big hacks start at Rare and up).
  public static func RecordAt(family: ref<RLHackFamily>, step: Int32) -> TweakDBID {
    let best: TweakDBID;
    let bestStep = -1;
    let lowest: TweakDBID;
    let lowestStep = 99;
    for id in RLHacks.Records(family) {
      let s = RLQuality.StepOfRecord(id);
      if s <= step && s > bestStep {
        best = id;
        bestStep = s;
      }
      if s < lowestStep {
        lowest = id;
        lowestStep = s;
      }
    }
    return bestStep >= 0 ? best : lowest;
  }

  public static func LowestStep(family: ref<RLHackFamily>) -> Int32 {
    let lowest = 99;
    for id in RLHacks.Records(family) {
      lowest = Min(lowest, RLQuality.StepOfRecord(id));
    }
    return lowest;
  }

  // --- The deck -------------------------------------------------------------------------

  // The deck V runs, or none.
  public static func Deck(player: ref<PlayerPuppet>) -> ItemID {
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) {
      return ItemID.None();
    }
    let deck = data.GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
    return EquipmentSystem.IsItemCyberdeck(deck) ? deck : ItemID.None();
  }

  // The quickhacks slotted in the deck.
  public static func Slotted(player: ref<PlayerPuppet>) -> array<ItemID> {
    let hacks: array<ItemID>;
    let deck = RLHacks.Deck(player);
    if !ItemID.IsValid(deck) {
      return hacks;
    }
    for slot in ItemModificationSystem.GetAllSlots(player, deck) {
      if Equals(slot.status, ESlotState.Taken) && Equals(RPGManager.GetItemType(slot.installedPart), gamedataItemType.Prt_Program) {
        ArrayPush(hacks, slot.installedPart);
      }
    }
    return hacks;
  }

  // Families slotted in the deck.
  public static func SlottedFamilies(player: ref<PlayerPuppet>) -> array<CName> {
    let ids: array<CName>;
    for hack in RLHacks.Slotted(player) {
      let family = RLHacks.FamilyOf(ItemID.GetTDBID(hack));
      if IsDefined(family) {
        ArrayPush(ids, family.id);
      }
    }
    return ids;
  }

  public static func FreeSlots(player: ref<PlayerPuppet>) -> Int32 {
    let deck = RLHacks.Deck(player);
    if !ItemID.IsValid(deck) {
      return 0;
    }
    let free: array<TweakDBID>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetAvailableSlotsOnItem(player, deck, free);
    return ArraySize(free);
  }

  // A quickhack card that has to swap one out: the deck is full.
  public static func NeedsSlot(player: ref<PlayerPuppet>, offer: ref<RLOffer>) -> Bool {
    if !IsDefined(player) || !Equals(offer.kind, RLOfferKind.Quickhack) || !ItemID.IsValid(RLHacks.Deck(player)) {
      return false;
    }
    let slotted = RLHacks.Slotted(player);
    return RLHacks.FreeSlots(player) == 0 && ArraySize(slotted) > 0;
  }

  // Slots a quickhack, in place of `replace` when that's given (the slot
  // picker's choice). The one swapped out is gone.
  public static func Install(player: ref<PlayerPuppet>, record: TweakDBID, replace: ItemID) {
    if ItemID.IsValid(replace) {
      RLHacks.Remove(player, replace);
    }
    RLGear.GiveQuickhacks(player, [record]);
    RLLog("Quickhack slotted: " + RLRewards.ItemName(record) + " (" + RLQuality.DisplayName(RLQuality.StepOfRecord(record)) + ")" + (ItemID.IsValid(replace) ? " in place of " + RLRewards.ItemName(ItemID.GetTDBID(replace)) + "." : "."));
  }

  private static func Remove(player: ref<PlayerPuppet>, hack: ItemID) {
    let deck = RLHacks.Deck(player);
    if !ItemID.IsValid(deck) {
      return;
    }
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    for slot in ItemModificationSystem.GetAllSlots(player, deck) {
      if Equals(slot.status, ESlotState.Taken) && slot.installedPart == hack {
        let removed = transactions.RemovePart(player, deck, slot.slotID);
        if ItemID.IsValid(removed) {
          transactions.RemoveItem(player, removed, 1);
        }
        return;
      }
    }
  }

  // Quickhacks taken out of a deck, brought to a quality (a deck Tune-Up
  // takes its hacks up with it): the ones to slot into the new deck.
  public static func Retier(player: ref<PlayerPuppet>, hacks: array<ItemID>, step: Int32) -> array<ItemID> {
    let result: array<ItemID>;
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    for hack in hacks {
      let record = ItemID.GetTDBID(hack);
      let family = RLHacks.FamilyOf(record);
      let target = IsDefined(family) ? RLHacks.RecordAt(family, step) : TDBID.None();
      if TDBID.IsValid(target) && target != record && RLHacks.Expect(player, target) && transactions.GiveItemByTDBID(player, target, 1) {
        transactions.RemoveItem(player, hack, 1);
        ArrayPush(result, ItemID.CreateQuery(target));
      } else {
        ArrayPush(result, hack);
      }
    }
    return result;
  }

  // Quickhacks moved or given in the arena (a Tune-Up picked after a fight)
  // aren't pickups: the loot filter lets them through (Combat/Loot.reds).
  public static func Expect(player: ref<PlayerPuppet>, record: TweakDBID) -> Bool {
    let system = RogueliteSystem.Get(player.GetGame());
    if IsDefined(system) {
      system.ExpectGrant(record);
    }
    return true;
  }

  // --- Picks ----------------------------------------------------------------------------

  // A family of a role at a quality, none of `exclude`; none when there's
  // nothing that low.
  public static func Pick(role: Int32, step: Int32, exclude: array<CName>) -> TweakDBID {
    let candidates: array<ref<RLHackFamily>>;
    for family in RLHacks.Families() {
      if family.role == role && !ArrayContains(exclude, family.id) && RLHacks.LowestStep(family) <= Max(step, 2) {
        ArrayPush(candidates, family);
      }
    }
    if ArraySize(candidates) == 0 {
      return TDBID.None();
    }
    return RLHacks.RecordAt(candidates[RandRange(0, ArraySize(candidates))], step);
  }

  // The Netrunner's start: a hack that kills and one that controls, at the
  // deck's quality. Starters come from the plain picks (no ultimates).
  public static func Starters(step: Int32) -> array<TweakDBID> {
    let starters: array<TweakDBID>;
    let damage = RLHacks.Pick(RLHacks.Damage(), step, [n"SynapseBurnout", n"DetonateGrenade"]);
    let control = RLHacks.Pick(RLHacks.Control(), step, [n"MemoryWipe", n"Cyberpsychosis"]);
    if TDBID.IsValid(damage) {
      ArrayPush(starters, damage);
    }
    if TDBID.IsValid(control) {
      ArrayPush(starters, control);
    }
    return starters;
  }

  // A quickhack card for a deck in the main slot: a family it doesn't run,
  // at the deck's quality. A spike lets in the big hacks up to two qualities
  // early.
  public static func DeckOffer(player: ref<PlayerPuppet>, run: ref<RLRunState>, exclude: array<CName>, spike: Bool) -> ref<RLOffer> {
    let slotted = RLHacks.SlottedFamilies(player);
    let reach = run.mainStep + (spike ? 2 : 0);
    let candidates: array<ref<RLHackFamily>>;
    for family in RLHacks.Families() {
      if !ArrayContains(slotted, family.id) && !ArrayContains(exclude, family.id) && RLHacks.LowestStep(family) <= reach {
        let record = RLHacks.RecordAt(family, run.mainStep);
        if TDBID.IsValid(record) && !ArrayContains(run.banished, "item:" + RLRewards.ItemName(record)) {
          ArrayPush(candidates, family);
        }
      }
    }
    if ArraySize(candidates) == 0 {
      return null;
    }
    let family = candidates[RandRange(0, ArraySize(candidates))];
    let offer = RLHacks.Offer(RLHacks.RecordAt(family, run.mainStep));
    offer.links = RLHacks.Links(run, offer.makes);
    offer.excitement = family.role == RLHacks.Ultimate() ? 2 : (ArraySize(offer.links) > 0 ? 1 : 0);
    return offer;
  }

  // Effects V holds that use what a quickhack makes (BUILDS ON).
  public static func Links(run: ref<RLRunState>, makes: array<CName>) -> array<CName> {
    let links: array<CName>;
    for state in run.boons {
      let effect = RLBoons.Get(state.id);
      if IsDefined(effect) && NotEquals(effect.kind, RLBoonKind.Favour) {
        for keyword in makes {
          if ArrayContains(effect.uses, keyword) && !ArrayContains(links, state.id) {
            ArrayPush(links, state.id);
          }
        }
      }
    }
    return links;
  }

  // A quickhack card: its line and the keyword it speaks.
  public static func Offer(record: TweakDBID) -> ref<RLOffer> {
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Quickhack;
    offer.record = record;
    offer.step = RLQuality.StepOfRecord(record);
    offer.title = RLRewards.ItemName(record);
    RLHacks.Describe(offer);
    return offer;
  }

  // Kicker, line and keyword chip of a quickhack card.
  public static func Describe(offer: ref<RLOffer>) {
    let family = RLHacks.FamilyOf(offer.record);
    offer.subtitle = "QUICKHACK - " + RLQuality.DisplayName(offer.step);
    ArrayClear(offer.makes);
    ArrayPush(offer.tags, n"netrunner");
    if !IsDefined(family) {
      return;
    }
    offer.subtitle = RLHacks.RoleName(family.role) + " QUICKHACK - " + RLQuality.DisplayName(offer.step);
    offer.description = family.line;
    if IsNameValid(family.keyword) {
      ArrayPush(offer.makes, family.keyword);
    }
  }

  public static func RoleName(role: Int32) -> String {
    switch role {
      case 0: return "DAMAGE";
      case 1: return "CONTROL";
    }
    return "ULTIMATE";
  }

  // "Overheat, Ping" - the deck's loadout.
  public static func Summary(player: ref<PlayerPuppet>) -> String {
    let text = "";
    if !IsDefined(player) {
      return text;
    }
    for hack in RLHacks.Slotted(player) {
      text += (StrLen(text) > 0 ? ", " : "") + RLRewards.ItemName(ItemID.GetTDBID(hack));
    }
    return text;
  }

  // --- Uploads --------------------------------------------------------------------------

  // An upload landed: the hack speaks its keyword on the target.
  public static func Speak(fx: ref<RLFx>, target: ref<ScriptedPuppet>, family: ref<RLHackFamily>) {
    if !IsDefined(family) {
      return;
    }
    switch family.keyword {
      case n"MARK":
        RLKeywords.Mark(fx, target, 10.0);
        break;
      case n"SHOCK":
        RLKeywords.Shock(fx, target);
        break;
      case n"BURN":
        RLKeywords.Burn(fx, target);
        break;
      case n"BLEED":
        RLKeywords.Bleed(fx, target, 1);
        break;
      case n"GLITCH":
        RLKeywords.Glitch(fx, target);
        break;
    }
  }

  // Poison counts as BLEED (Contagion's above all): once a second, every
  // poisoned enemy keeps bleeding.
  public static func PoisonBleeds(fx: ref<RLFx>, target: ref<ScriptedPuppet>, foe: ref<RLFoe>) {
    if !StatusEffectSystem.ObjectHasStatusEffectOfType(target, gamedataStatusEffectType.Poisoned) {
      return;
    }
    if fx.combat.IsBleeding(foe, fx.now) {
      foe.bleedUntil = MaxF(foe.bleedUntil, fx.now + 2.0);
    } else {
      RLKeywords.Bleed(fx, target, 1);
    }
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - chrome as the main weapon
// -----------------------------------------------------------------------------
// Gorilla Arms, Mantis Blades, Monowire and the Projectile Launcher are the
// point of the kits that start with them (Brawler, Wireman, Demolitions), and
// the cyberdeck is the Netrunner's, so they take the main slot
// (Rewards/Weapons.reds) the way a gun does - weapon effects and all (a
// deck's quickhacks are its hits) - with their own take on the slot's
// rewards, and two mod slots of their own (Rewards/ArmMods.reds):
//
//   Tune-Up   the game's own upgrade path. Each quality of arm chrome is its
//             own record (Items.Advanced<Family><Element><Tier>), the way a
//             ripperdoc upgrades it, so a step up swaps the installed arms
//             for the next record. There is no Common arm chrome: it starts
//             at Uncommon.
//   Rewire    in place of a TRADE: the same arms in another element, and
//             the element speaks a keyword (Combat/Keywords.reds) - Thermal
//             hits BURN, Electric hits SHOCK, Chemical hits BLEED.
//   Evolve    at Legendary with two weapon effects: Legendary++ and a third
//             weapon effect slot (there are no iconic arms to evolve into).
//
// A deck has no elements and no records by name: its Tune-Ups follow the
// game's own upgrade chain (each record's next upgrade), and it is never
// traded or rewired. At the Act 1 boss it goes into Overdrive itself rather
// than making way for another Operating System.
//
// Arm chrome a Chrome door turns up for a gun build can take over the main
// slot (TakeOverMain): the gun steps down to sidearm.
//
// The arms bring their own capacity, like an Operating System: what a swap
// costs is added to V's capacity as it goes in, so the kit's arms are never
// refused and a Tune-Up never pushes V over. Arm chrome that goes missing
// (anything that strips it) is put back on the next trip (Heal).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLArms {
  public static func IsArmsType(itemType: gamedataItemType) -> Bool {
    switch itemType {
      case gamedataItemType.Cyb_StrongArms:
      case gamedataItemType.Cyb_MantisBlades:
      case gamedataItemType.Cyb_NanoWires:
      case gamedataItemType.Cyb_Launcher:
        return true;
    }
    return false;
  }

  public static func IsArms(itemID: ItemID) -> Bool = ItemID.IsValid(itemID) && RLArms.IsArmsType(RPGManager.GetItemType(itemID))

  public static func IsArmsRecord(record: TweakDBID) -> Bool {
    let item = TweakDBInterface.GetItemRecord(record);
    return IsDefined(item) && IsDefined(item.ItemType()) && RLArms.IsArmsType(item.ItemType().Type());
  }

  public static func IsMainArms(run: ref<RLRunState>) -> Bool = IsDefined(run) && RLArms.IsArms(run.mainWeapon)

  public static func IsDeck(itemID: ItemID) -> Bool {
    let item = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    return ItemID.IsValid(itemID) && IsDefined(item) && item.TagsContains(n"Cyberdeck");
  }

  public static func IsMainDeck(run: ref<RLRunState>) -> Bool = IsDefined(run) && RLArms.IsDeck(run.mainWeapon)

  // Arms or a deck: chrome that swaps records to step up.
  public static func IsMainChrome(run: ref<RLRunState>) -> Bool = RLArms.IsMainArms(run) || RLArms.IsMainDeck(run)

  // The lowest step arm chrome comes in (Uncommon).
  public static func MinStep() -> Int32 = 2

  // --- Records --------------------------------------------------------------------------

  // The record name's family part.
  public static func Family(itemType: gamedataItemType) -> String {
    switch itemType {
      case gamedataItemType.Cyb_StrongArms: return "StrongArms";
      case gamedataItemType.Cyb_MantisBlades: return "MantisBlades";
      case gamedataItemType.Cyb_NanoWires: return "NanoWires";
      case gamedataItemType.Cyb_Launcher: return "ProjectileLauncher";
    }
    return "";
  }

  private static func TierSuffix(step: Int32) -> String {
    switch step {
      case 3: return "UncommonPlus";
      case 4: return "Rare";
      case 5: return "RarePlus";
      case 6: return "Epic";
      case 7: return "EpicPlus";
      case 8: return "Legendary";
      case 9: return "LegendaryPlus";
      case 10: return "LegendaryPlusPlus";
    }
    return "Uncommon";
  }

  // The arm chrome of a family, element and quality step - or the nearest
  // step below it that exists (a few element tiers are missing).
  public static func Record(family: String, element: String, step: Int32) -> TweakDBID {
    let s = Clamp(step, RLArms.MinStep(), RLQuality.MaxStep());
    while s >= RLArms.MinStep() {
      let id = TDBID.Create("Items.Advanced" + family + element + RLArms.TierSuffix(s));
      if IsDefined(TweakDBInterface.GetItemRecord(id)) {
        return id;
      }
      s -= 1;
    }
    return TDBID.None();
  }

  // The main slot's chrome at `step`: arms in their element, a deck along
  // its upgrade chain (as far as the chain goes).
  public static func MainRecordAt(run: ref<RLRunState>, step: Int32) -> TweakDBID {
    if RLArms.IsMainArms(run) {
      return RLArms.Record(RLArms.Family(RPGManager.GetItemType(run.mainWeapon)), run.mainElement, step);
    }
    let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(run.mainWeapon));
    let guard = 0;
    while IsDefined(record) && RLQuality.StepOfRecord(record.GetID()) < step && guard < 12 {
      let next = record.NextUpgradeItem();
      if !IsDefined(next) || !TDBID.IsValid(next.GetID()) {
        guard = 12;
      } else {
        record = next;
      }
      guard += 1;
    }
    return IsDefined(record) ? record.GetID() : TDBID.None();
  }

  // --- Elements -------------------------------------------------------------------------

  public static func Elements() -> array<String> = ["", "Thermal", "Electric", "Chemical"]

  public static func ElementName(element: String) -> String {
    switch element {
      case "Thermal": return "THERMAL";
      case "Electric": return "ELECTRIC";
      case "Chemical": return "CHEMICAL";
    }
    return "PHYSICAL";
  }

  // The keyword an element's hits put on enemies.
  public static func ElementKeyword(element: String) -> CName {
    switch element {
      case "Thermal": return n"BURN";
      case "Electric": return n"SHOCK";
      case "Chemical": return n"BLEED";
    }
    return n"";
  }

  public static func ElementLine(element: String) -> String {
    switch element {
      case "Thermal": return "Your hits BURN.";
      case "Electric": return "Your hits SHOCK.";
      case "Chemical": return "Your hits make them BLEED.";
    }
    return "Clean hits, no element.";
  }

  // A main weapon hit with elemental arms: the element's keyword.
  public static func OnMainHit(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    switch fx.run.mainElement {
      case "Thermal":
        RLKeywords.Burn(fx, target);
        break;
      case "Electric":
        RLKeywords.Shock(fx, target);
        break;
      case "Chemical":
        RLKeywords.Bleed(fx, target, 1);
        break;
    }
  }

  // --- Installing ------------------------------------------------------------------------

  // Puts `record` in the arms slot in place of `old` (none for the kit's),
  // with the capacity it needs; returns the new arms' item ID.
  public static func Install(player: ref<PlayerPuppet>, run: ref<RLRunState>, record: TweakDBID, old: ItemID) -> ItemID {
    if !IsDefined(player) || !TDBID.IsValid(record) {
      return ItemID.None();
    }
    let cost = RLGear.NetCapacityCost(player, record);
    if cost > 0.0 {
      RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, cost);
    }
    // Rewards go in inside the arena, where pickups are filtered.
    let system = RogueliteSystem.Get(player.GetGame());
    if IsDefined(system) {
      system.ExpectGrant(record);
    }
    // A deck carries its quickhacks inside it: take them out before the old
    // one goes, and slot them into the new one once it's in (the same queue,
    // so the equip lands first).
    let programs: array<ItemID>;
    if RLArms.IsDeck(old) && ItemID.GetTDBID(old) != record {
      programs = RLArms.StripPrograms(player, old);
    }
    let itemID = RLGear.InstallCyberwareItem(player, record);
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    if ItemID.IsValid(old) && old != itemID && transactions.HasItem(player, old) {
      transactions.RemoveItem(player, old, 1);
    }
    if ArraySize(programs) > 0 {
      let request = new GameplayEquipProgramsRequest();
      request.owner = player;
      request.programIDs = programs;
      EquipmentSystem.GetInstance(player).QueueRequest(request);
    }
    RLLog("Arm chrome: " + RLRewards.ItemName(record) + " (" + RLQuality.DisplayName(RLQuality.StepOfRecord(record)) + ").");
    return itemID;
  }

  // The quickhacks slotted in a deck, taken out into V's inventory.
  private static func StripPrograms(player: ref<PlayerPuppet>, deck: ItemID) -> array<ItemID> {
    let programs: array<ItemID>;
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    for slot in ItemModificationSystem.GetAllSlots(player, deck) {
      if Equals(slot.status, ESlotState.Taken) && ItemID.GetTDBID(slot.installedPart) != t"Items.GenericItemRoot" {
        let program = transactions.RemovePart(player, deck, slot.slotID);
        if ItemID.IsValid(program) {
          ArrayPush(programs, program);
        }
      }
    }
    return programs;
  }

  // Swaps the main arms for `record` (Tune-Up, Rewire, Evolve, act step).
  public static func ReplaceMain(player: ref<PlayerPuppet>, run: ref<RLRunState>, record: TweakDBID) {
    if !TDBID.IsValid(record) || record == ItemID.GetTDBID(run.mainWeapon) {
      return;
    }
    let given = RLArms.Install(player, run, record, run.mainWeapon);
    if ItemID.IsValid(given) {
      run.mainWeapon = given;
    }
  }

  // On every trip: the main arms are where they belong, or they go back in.
  public static func Heal(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    if !RLArms.IsMainChrome(run) || !IsDefined(player) {
      return;
    }
    let equipment = EquipmentSystem.GetData(player);
    let held = GameInstance.GetTransactionSystem(player.GetGame()).HasItem(player, run.mainWeapon);
    if held && IsDefined(equipment) && equipment.IsEquipped(run.mainWeapon) {
      return;
    }
    RLLog("Arm chrome was missing (" + (held ? "not installed" : "gone") + "); putting it back.");
    let given = RLArms.Install(player, run, ItemID.GetTDBID(run.mainWeapon), held ? run.mainWeapon : ItemID.None());
    if ItemID.IsValid(given) {
      run.mainWeapon = given;
    }
  }

  // Arm chrome from a Chrome door takes the main slot, effects and all (the
  // card already carries the record at the slot's tier); the gun it replaces
  // becomes the sidearm (the old sidearm stays in the bag).
  public static func TakeOverMain(player: ref<PlayerPuppet>, run: ref<RLRunState>, record: TweakDBID) {
    let oldMain = run.mainWeapon;
    let given = RLArms.Install(player, run, record, ItemID.None());
    if !ItemID.IsValid(given) {
      return;
    }
    run.sidearm = oldMain;
    run.sidearmStep = run.mainStep;
    run.mainWeapon = given;
    run.mainStep = RLQuality.StepOfRecord(ItemID.GetTDBID(given));
    run.mainEvolved = run.mainEvolved || RLWeapons.IsIconic(oldMain);
    run.mainElement = "";
    RLLog("Arm chrome takes the main slot; " + RLRewards.ItemName(ItemID.GetTDBID(oldMain)) + " is the sidearm now.");
  }

  // --- Cards -----------------------------------------------------------------------------

  // The Armory's REWIRE: the same arms, another element.
  public static func RewireOffer(run: ref<RLRunState>) -> ref<RLOffer> {
    if !RLArms.IsMainArms(run) {
      return null;
    }
    let family = RLArms.Family(RPGManager.GetItemType(run.mainWeapon));
    let options: array<String>;
    for element in RLArms.Elements() {
      if NotEquals(element, run.mainElement) && TDBID.IsValid(RLArms.Record(family, element, run.mainStep)) {
        ArrayPush(options, element);
      }
    }
    if ArraySize(options) == 0 {
      return null;
    }
    let element = options[RandRange(0, ArraySize(options))];
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Rewire;
    offer.record = RLArms.Record(family, element, run.mainStep);
    offer.mod = StringToName(RLArms.ElementName(element));
    offer.step = run.mainStep;
    offer.title = RLRewards.ItemName(offer.record);
    offer.subtitle = "REWIRE - " + RLArms.ElementName(element);
    offer.description = RLArms.ElementLine(element) + " Same tier, same weapon effects.";
    let keyword = RLArms.ElementKeyword(element);
    if IsNameValid(keyword) {
      ArrayPush(offer.makes, keyword);
    }
    offer.tags = RLBuildProfile.RecordTags(offer.record);
    return offer;
  }

  // The element a REWIRE card carries.
  public static func OfferElement(offer: ref<RLOffer>) -> String {
    for element in RLArms.Elements() {
      if Equals(StringToName(RLArms.ElementName(element)), offer.mod) {
        return element;
      }
    }
    return "";
  }

  public static func Rewire(player: ref<PlayerPuppet>, run: ref<RLRunState>, offer: ref<RLOffer>) {
    run.mainElement = RLArms.OfferElement(offer);
    RLArms.ReplaceMain(player, run, RLArms.MainRecordAt(run, run.mainStep));
  }

  // The chrome's evolution: the top of its line and a third weapon effect slot.
  public static func EvolveOffer(run: ref<RLRunState>) -> ref<RLOffer> {
    let record = RLArms.MainRecordAt(run, RLQuality.MaxStep());
    if !TDBID.IsValid(record) {
      return null;
    }
    let offer = new RLOffer();
    offer.kind = RLOfferKind.Evolve;
    offer.itemID = run.mainWeapon;
    offer.record = record;
    offer.step = RLQuality.MaxStep();
    offer.title = RLRewards.ItemName(record);
    offer.subtitle = "EVOLVE - " + RLQuality.DisplayName(RLQuality.MaxStep());
    offer.description = "Top of the line, effects and all, with a third weapon effect slot.";
    offer.excitement = 3;
    return offer;
  }

  public static func Evolve(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    run.mainEvolved = true;
    run.mainStep = RLQuality.MaxStep();
    RLArms.ReplaceMain(player, run, RLArms.MainRecordAt(run, run.mainStep));
  }
}

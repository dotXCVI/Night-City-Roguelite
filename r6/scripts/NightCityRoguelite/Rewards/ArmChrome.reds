// -----------------------------------------------------------------------------
// Night City Roguelite - arm chrome as the main weapon
// -----------------------------------------------------------------------------
// Gorilla Arms, Mantis Blades, Monowire and the Projectile Launcher are the
// point of the kits that start with them (Brawler, Wireman), so they take the
// main slot (Rewards/Weapons.reds) the way a gun does - weapon effects and
// all - with their own take on the slot's rewards:
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

  // The main slot's arms at `step`, in its element.
  public static func MainRecordAt(run: ref<RLRunState>, step: Int32) -> TweakDBID {
    return RLArms.Record(RLArms.Family(RPGManager.GetItemType(run.mainWeapon)), run.mainElement, step);
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
    let itemID = RLGear.InstallCyberwareItem(player, record);
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    if ItemID.IsValid(old) && old != itemID && transactions.HasItem(player, old) {
      transactions.RemoveItem(player, old, 1);
    }
    RLLog("Arm chrome: " + RLRewards.ItemName(record) + " (" + RLQuality.DisplayName(RLQuality.StepOfRecord(record)) + ").");
    return itemID;
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
    if !RLArms.IsMainArms(run) || !IsDefined(player) {
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

  // The arms' evolution: Legendary++ and a third weapon effect slot.
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

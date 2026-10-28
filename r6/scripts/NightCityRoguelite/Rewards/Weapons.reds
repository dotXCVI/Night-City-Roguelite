// -----------------------------------------------------------------------------
// Night City Roguelite - weapons
// -----------------------------------------------------------------------------
// You play one gun, so the run builds one gun (Hades' one weapon a run,
// Returnal's power that a new gun never resets):
//
//   MAIN      the kit's weapon. It takes every weapon reward: Tune-Ups (the
//             slot's quality step), weapon effects (Rewards/Boons.reds - they
//             live on the slot, so they work on blades too and stay through
//             a trade) and the evolution into an iconic.
//   SIDEARM   the kit's backup. It never takes a reward card; it steps up
//             with every act.
//
//   tier      the slot holds the quality step, not the gun: a gun traded in
//             (a TRADE card on an Armory screen) arrives at the slot's step,
//             so swapping is about how a gun plays, never a step down.
//   evolution a Legendary main weapon with two weapon effects can become an
//             iconic of its type, effects and all.
//
// Families (pistol, rifle, heavy, precision, blade, blunt) set a weapon's
// style, the attribute it leans on and a line on how it plays.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLWeaponFamily {
  public static func None() -> Int32 = 0
  public static func Pistol() -> Int32 = 1
  public static func Rifle() -> Int32 = 2
  public static func Heavy() -> Int32 = 3
  public static func Precision() -> Int32 = 4
  public static func Blade() -> Int32 = 5
  public static func Blunt() -> Int32 = 6
}

public abstract class RLWeapons {
  // --- The slots ------------------------------------------------------------------------------

  // A hit's weapon is the main one. Drawn arm chrome is matched by record
  // too, in case the game hands the hit a copy of the installed item.
  public static func IsMain(run: ref<RLRunState>, itemID: ItemID) -> Bool {
    if !ItemID.IsValid(run.mainWeapon) || !ItemID.IsValid(itemID) {
      return false;
    }
    return run.mainWeapon == itemID || RLArms.IsArms(itemID) && ItemID.GetTDBID(itemID) == ItemID.GetTDBID(run.mainWeapon);
  }

  // Weapon effects the main weapon can hold: two, three once it's evolved.
  public static func EffectSlots(run: ref<RLRunState>) -> Int32 {
    return ItemID.IsValid(run.mainWeapon) && (RLWeapons.IsIconic(run.mainWeapon) || run.mainEvolved) ? 3 : 2;
  }

  // The style the main weapon's weapon effects count for.
  public static func MainStyle(run: ref<RLRunState>) -> Int32 {
    if !ItemID.IsValid(run.mainWeapon) {
      return -1;
    }
    if RLArms.IsDeck(run.mainWeapon) {
      return RLStyle.Netrunner();
    }
    let styles = RLStyles.ItemStyles(run.mainWeapon);
    return ArraySize(styles) > 0 ? styles[0] : -1;
  }

  public static func MainItem(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> wref<gameItemData> {
    if !IsDefined(player) || !ItemID.IsValid(run.mainWeapon) {
      return null;
    }
    return GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, run.mainWeapon);
  }

  public static func MainRecord(run: ref<RLRunState>) -> TweakDBID {
    return ItemID.IsValid(run.mainWeapon) ? ItemID.GetTDBID(run.mainWeapon) : TDBID.None();
  }

  // The kit's weapons, in the order it gave them: the first is the main.
  public static func AssignSlots(run: ref<RLRunState>, weapons: array<ItemID>) {
    run.mainWeapon = ArraySize(weapons) > 0 ? weapons[0] : ItemID.None();
    run.sidearm = ArraySize(weapons) > 1 ? weapons[1] : ItemID.None();
    if RLArms.IsArms(run.mainWeapon) {
      run.mainStep = RLArms.MinStep();
    } else if RLArms.IsDeck(run.mainWeapon) {
      run.mainStep = RLQuality.StepOfRecord(ItemID.GetTDBID(run.mainWeapon));
    } else {
      run.mainStep = 0;
    }
    run.sidearmStep = 0;
    run.mainElement = "";
    run.mainEvolved = false;
  }

  // Puts both slots' weapons at their steps (arm chrome by swapping records,
  // Rewards/ArmChrome.reds).
  public static func ApplySteps(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    if RLArms.IsMainChrome(run) {
      if RLArms.IsMainArms(run) {
        run.mainStep = Max(run.mainStep, RLArms.MinStep());
      }
      RLArms.ReplaceMain(player, run, RLArms.MainRecordAt(run, run.mainStep));
      // A deck's chain can end short of the step: the slot is what it holds.
      if RLArms.IsMainDeck(run) {
        run.mainStep = Min(run.mainStep, RLQuality.StepOfRecord(ItemID.GetTDBID(run.mainWeapon)));
      }
    } else if ItemID.IsValid(run.mainWeapon) {
      let main = transactions.GetItemData(player, run.mainWeapon);
      if IsDefined(main) {
        RPGManager.ForceItemTier(player, main, RLQuality.TierName(run.mainStep));
      }
    }
    if ItemID.IsValid(run.sidearm) {
      let side = transactions.GetItemData(player, run.sidearm);
      if IsDefined(side) {
        RPGManager.ForceItemTier(player, side, RLQuality.TierName(run.sidearmStep));
      }
    }
  }

  // A Tune-Up: the main weapon's slot `steps` quality steps up.
  public static func TuneUp(player: ref<PlayerPuppet>, run: ref<RLRunState>, steps: Int32) {
    run.mainStep = Min(RLQuality.MaxStep(), run.mainStep + steps);
    RLWeapons.ApplySteps(player, run);
  }

  // A boss beaten: both slots a step up.
  public static func ActStep(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    run.mainStep = Min(RLQuality.MaxStep(), run.mainStep + 1);
    run.sidearmStep = Min(RLQuality.MaxStep(), run.sidearmStep + 1);
    RLWeapons.ApplySteps(player, run);
  }

  // A trade (or an evolution): the new gun takes the main slot at the slot's
  // step, and the old one goes. The weapon effects stay: they belong to the
  // slot.
  public static func ReplaceMain(player: ref<PlayerPuppet>, run: ref<RLRunState>, record: TweakDBID) -> Bool {
    let given = RLGear.GiveWeaponItem(player, record, RLQuality.TierName(run.mainStep), false);
    if !ItemID.IsValid(given) {
      return false;
    }
    let old = run.mainWeapon;
    run.mainWeapon = given;
    if ItemID.IsValid(old) {
      GameInstance.GetTransactionSystem(player.GetGame()).RemoveItem(player, old, 1);
    }
    let equip = new GameplayEquipRequest();
    equip.owner = player;
    equip.itemID = given;
    equip.blockUpdateWeaponActiveSlots = true;
    EquipmentSystem.GetInstance(player).QueueRequest(equip);
    RLLog("Main weapon: " + RLRewards.ItemName(record) + " at " + RLQuality.DisplayName(run.mainStep) + ".");
    return true;
  }

  // The main weapon can evolve now: Legendary, two weapon effects, not
  // already an iconic.
  public static func CanEvolve(run: ref<RLRunState>) -> Bool {
    return ItemID.IsValid(run.mainWeapon) && !RLWeapons.IsIconic(run.mainWeapon) && !run.mainEvolved
      && run.mainStep >= 8 && RLBoons.WeaponEffectCount(run) >= 2;
  }

  // What evolving still needs, for the Armory's cards ("" once it can, or
  // when it never will).
  public static func EvolveRecipe(run: ref<RLRunState>) -> String {
    if !ItemID.IsValid(run.mainWeapon) || RLWeapons.IsIconic(run.mainWeapon) || run.mainEvolved || RLWeapons.CanEvolve(run) {
      return "";
    }
    return s"Evolves at Legendary with 2 weapon effects (now \(RLQuality.DisplayName(run.mainStep)), \(RLBoons.WeaponEffectCount(run))/2).";
  }

  // DPS of a record at a quality step, from a throwaway copy of the item
  // (the way the crafting screen previews items); 0 when unknown.
  public static func PreviewDPS(player: ref<PlayerPuppet>, record: TweakDBID, step: Int32) -> Float {
    if !IsDefined(player) || !TDBID.IsValid(record) {
      return 0.0;
    }
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(record);
    params.quantity = 1;
    let itemData = Inventory.CreateItemData(params, player);
    if !IsDefined(itemData) {
      return 0.0;
    }
    CraftingSystem.SetItemLevel(player, itemData);
    RPGManager.ForceItemTier(player, itemData, RLQuality.TierName(step));
    return itemData.GetStatValueByType(gamedataStatType.EffectiveDPS);
  }

  // --- Families ------------------------------------------------------------------------------

  public static func FamilyOf(itemType: gamedataItemType) -> Int32 {
    switch itemType {
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
        return RLWeaponFamily.Pistol();
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_SubmachineGun:
      case gamedataItemType.Wea_Rifle:
        return RLWeaponFamily.Rifle();
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
        return RLWeaponFamily.Heavy();
      case gamedataItemType.Wea_PrecisionRifle:
      case gamedataItemType.Wea_SniperRifle:
        return RLWeaponFamily.Precision();
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_Chainsword:
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Axe:
      case gamedataItemType.Cyb_MantisBlades:
        return RLWeaponFamily.Blade();
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_TwoHandedClub:
      case gamedataItemType.Wea_Fists:
      case gamedataItemType.Cyb_StrongArms:
        return RLWeaponFamily.Blunt();
    }
    return RLWeaponFamily.None();
  }

  public static func FamilyOfRecord(record: TweakDBID) -> Int32 {
    let item = TweakDBInterface.GetItemRecord(record);
    return IsDefined(item) && IsDefined(item.ItemType()) ? RLWeapons.FamilyOf(item.ItemType().Type()) : RLWeaponFamily.None();
  }

  public static func FamilyStyle(family: Int32) -> Int32 {
    switch family {
      case 1: return RLStyle.Gunslinger();
      case 2: return RLStyle.Rifles();
      case 3: return RLStyle.Heavy();
      case 4: return RLStyle.Marksman();
      case 5: return RLStyle.Blades();
      case 6: return RLStyle.Brawler();
    }
    return -1;
  }

  // The build tag of a family (for cards and the build profile).
  public static func FamilyTag(family: Int32) -> CName {
    switch family {
      case 1: return n"handgun";
      case 2: return n"rifle";
      case 3: return n"shotgun";
      case 4: return n"precision";
      case 5: return n"blade";
      case 6: return n"blunt";
    }
    return n"";
  }

  // The attribute a weapon class leans on in 2.x (its perk tree).
  public static func AttributeName(itemType: gamedataItemType) -> String {
    switch itemType {
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
      case gamedataItemType.Wea_PrecisionRifle:
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_Axe:
        return "COOL";
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_TwoHandedClub:
        return "BODY";
    }
    return "REFLEXES";
  }

  // One line on how a weapon plays: its class, then its evolution.
  public static func Playstyle(record: TweakDBID) -> String {
    let item = TweakDBInterface.GetItemRecord(record);
    if !IsDefined(item) || !IsDefined(item.ItemType()) {
      return "";
    }
    let text: String;
    switch item.ItemType().Type() {
      case gamedataItemType.Wea_Handgun: text = "Quick and precise. Headshots pay."; break;
      case gamedataItemType.Wea_Revolver: text = "Slow and heavy. Make every round count."; break;
      case gamedataItemType.Wea_AssaultRifle: text = "Steady auto fire at any range."; break;
      case gamedataItemType.Wea_SubmachineGun: text = "Bullet hose. Stay close, keep moving."; break;
      case gamedataItemType.Wea_Shotgun: text = "Point blank or don't bother."; break;
      case gamedataItemType.Wea_ShotgunDual: text = "Two barrels. One big problem."; break;
      case gamedataItemType.Wea_LightMachineGun: text = "Big mag. Plant your feet and shred."; break;
      case gamedataItemType.Wea_PrecisionRifle: text = "Semi-auto. Rewards a steady hand."; break;
      case gamedataItemType.Wea_SniperRifle: text = "One shot, one kill. From way out."; break;
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_LongBlade: text = "Fast cuts. Deflect bullets. Finishers."; break;
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_ShortBlade: text = "Quick stabs, or throw it."; break;
      case gamedataItemType.Wea_Axe: text = "Heavy chops, or throw it."; break;
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_Chainsword: text = "Wide, messy swings."; break;
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_TwoHandedClub: text = "Slow, crushing. Sends bodies flying."; break;
      case gamedataItemType.Wea_OneHandedClub: text = "Quick, blunt beatings."; break;
      default: text = "";
    }
    let weapon = item as WeaponItem_Record;
    if IsDefined(weapon) && IsDefined(weapon.Evolution()) {
      switch weapon.Evolution().Type() {
        case gamedataWeaponEvolution.Smart: text += " Smart: rounds home in."; break;
        case gamedataWeaponEvolution.Tech: text += " Tech: charge it, shoot through walls."; break;
        case gamedataWeaponEvolution.Power: text += " Power: rounds ricochet."; break;
      }
    }
    return text;
  }

  // "REVOLVER · COOL"
  public static func ClassLine(record: TweakDBID) -> String {
    let item = TweakDBInterface.GetItemRecord(record);
    if !IsDefined(item) || !IsDefined(item.ItemType()) {
      return "";
    }
    return RLRewards.ItemTypeName(record) + " · " + RLWeapons.AttributeName(item.ItemType().Type());
  }

  public static func IsRealWeapon(itemID: ItemID) -> Bool {
    if !Equals(RPGManager.GetItemCategory(itemID), gamedataItemCategory.Weapon) {
      return false;
    }
    let area = EquipmentSystem.GetEquipAreaType(itemID);
    return NotEquals(area, gamedataEquipmentArea.BaseFists) && NotEquals(area, gamedataEquipmentArea.VDefaultHandgun);
  }

  public static func IsIconic(itemID: ItemID) -> Bool {
    let item = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    return IsDefined(item) && item.TagsContains(n"IconicWeapon");
  }
}

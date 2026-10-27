// -----------------------------------------------------------------------------
// Night City Roguelite - weapons
// -----------------------------------------------------------------------------
// What makes a weapon pick an upgrade instead of a sidegrade:
//
//   families   every weapon belongs to one (pistol, rifle, heavy, precision,
//              blade, blunt), which sets its style, the attribute it leans on
//              and a one-line description of how it plays.
//   DPS        cards show the weapon's DPS at the offered quality next to the
//              best weapon V has equipped ("DPS 312  +38%").
//   mods       our own weapon mods (Hades' hammers): two slots per weapon,
//              three on iconics, each one a rule for that family's hits
//              (Rewards/WeaponMods.reds).
//   evolution  a Legendary weapon with its mod slots full can evolve into an
//              iconic of its type, mods included. It is the only way to an
//              iconic besides the stranger's deal.
//   curve      a weapon far below the floor's expected quality deals less
//              damage (UnderCurveFactor), so the main gun has to keep up.
//
// The run keeps one RLWeaponState per weapon that has mods (by item ID).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLWeaponState {
  public let itemID: ItemID;
  public let record: TweakDBID;
  public let mods: array<CName>;
}

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

  public static func FamilyName(family: Int32) -> String {
    switch family {
      case 1: return "PISTOL";
      case 2: return "RIFLE";
      case 3: return "HEAVY";
      case 4: return "PRECISION";
      case 5: return "BLADE";
      case 6: return "BLUNT";
    }
    return "WEAPON";
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

  // --- DPS -------------------------------------------------------------------------------------

  // DPS of a record at a quality step, from a throwaway copy of the item
  // (the way the crafting screen previews items).
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

  // The best DPS among V's equipped weapons (fists and the default handgun
  // don't count), and its name.
  public static func BestEquippedDPS(player: ref<PlayerPuppet>, out name: String) -> Float {
    let best = 0.0;
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && IsDefined(equipment) && RLWeapons.IsRealWeapon(item.GetID()) && equipment.IsEquipped(item.GetID()) {
        let dps = item.GetStatValueByType(gamedataStatType.EffectiveDPS);
        if dps > best {
          best = dps;
          name = RLRewards.ItemName(ItemID.GetTDBID(item.GetID()));
        }
      }
    }
    return best;
  }

  // The highest quality step among V's equipped weapons (-1 when none).
  public static func BestEquippedStep(player: ref<PlayerPuppet>) -> Int32 {
    let best = -1;
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && IsDefined(equipment) && RLWeapons.IsRealWeapon(item.GetID()) && equipment.IsEquipped(item.GetID()) {
        best = Max(best, RLRewards.ItemStep(item));
      }
    }
    return best;
  }

  public static func IsRealWeapon(itemID: ItemID) -> Bool {
    if !Equals(RPGManager.GetItemCategory(itemID), gamedataItemCategory.Weapon) {
      return false;
    }
    let area = EquipmentSystem.GetEquipAreaType(itemID);
    return NotEquals(area, gamedataEquipmentArea.BaseFists) && NotEquals(area, gamedataEquipmentArea.VDefaultHandgun);
  }

  // "DPS 312  +38% vs Lexington", or "" when either side is unknown.
  public static func CompareLine(player: ref<PlayerPuppet>, dps: Float) -> String {
    if dps <= 0.0 {
      return "";
    }
    let name: String;
    let current = RLWeapons.BestEquippedDPS(player, name);
    let line = s"DPS \(RoundF(dps))";
    if current > 0.0 {
      let delta = RoundF(100.0 * (dps / current - 1.0));
      line += (delta >= 0 ? s"  +\(delta)%" : s"  \(delta)%") + " vs " + name;
    }
    return line;
  }

  // --- Run state ---------------------------------------------------------------------------------

  public static func State(run: ref<RLRunState>, itemID: ItemID) -> ref<RLWeaponState> {
    if IsDefined(run) {
      for state in run.weapons {
        if state.itemID == itemID {
          return state;
        }
      }
    }
    return null;
  }

  // Forgets a weapon V no longer has (sold, evolved).
  public static func Forget(run: ref<RLRunState>, itemID: ItemID) {
    let state = RLWeapons.State(run, itemID);
    if IsDefined(state) {
      ArrayRemove(run.weapons, state);
    }
  }

  public static func StateOrNew(run: ref<RLRunState>, itemID: ItemID) -> ref<RLWeaponState> {
    let state = RLWeapons.State(run, itemID);
    if !IsDefined(state) {
      state = new RLWeaponState();
      state.itemID = itemID;
      state.record = ItemID.GetTDBID(itemID);
      ArrayPush(run.weapons, state);
    }
    return state;
  }

  public static func ModCount(run: ref<RLRunState>, itemID: ItemID) -> Int32 {
    let state = RLWeapons.State(run, itemID);
    return IsDefined(state) ? ArraySize(state.mods) : 0;
  }

  public static func IsIconic(itemID: ItemID) -> Bool {
    let item = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    return IsDefined(item) && item.TagsContains(n"IconicWeapon");
  }

  public static func ModSlots(itemID: ItemID) -> Int32 = RLWeapons.IsIconic(itemID) ? 3 : 2

  public static func HasMod(run: ref<RLRunState>, itemID: ItemID, mod: CName) -> Bool {
    let state = RLWeapons.State(run, itemID);
    return IsDefined(state) && ArrayContains(state.mods, mod);
  }

  // --- Quality curve -----------------------------------------------------------------------------

  // A weapon hit's multiplier for how the weapon's quality compares with the
  // floor's: -5% per step below (down to -30%), +4% per step above (up to +8%).
  public static func CurveFactor(run: ref<RLRunState>, weapon: wref<WeaponObject>) -> Float {
    if !IsDefined(weapon) || !IsDefined(run) || !RLWeapons.IsRealWeapon(weapon.GetItemID()) {
      return 1.0;
    }
    let item = weapon.GetItemData();
    if !IsDefined(item) {
      return 1.0;
    }
    let gap = RLRewards.ItemStep(item) - RLQuality.ExpectedStep(run.Depth(), run.TotalFloors());
    if gap < 0 {
      return MaxF(0.7, 1.0 + 0.05 * Cast<Float>(gap));
    }
    return 1.0 + 0.04 * Cast<Float>(Min(gap, 2));
  }

  // --- Evolution ---------------------------------------------------------------------------------

  // Equipped weapons that can evolve now: Legendary or better, both mod slots
  // filled, not already iconic.
  public static func Evolvable(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> array<ItemID> {
    let result: array<ItemID>;
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && IsDefined(equipment) && RLWeapons.IsRealWeapon(item.GetID()) && equipment.IsEquipped(item.GetID())
        && !RLWeapons.IsIconic(item.GetID()) && RLRewards.ItemStep(item) >= 8 && RLWeapons.ModCount(run, item.GetID()) >= 2 {
        ArrayPush(result, item.GetID());
      }
    }
    return result;
  }

  // Swaps a weapon for an iconic at the same quality, moving its mods over,
  // and equips it.
  public static func Evolve(player: ref<PlayerPuppet>, run: ref<RLRunState>, from: ItemID, iconic: TweakDBID, step: Int32) {
    // The old weapon goes only once the iconic is in hand.
    let given = RLGear.GiveWeaponItem(player, iconic, RLQuality.TierName(step), false);
    if !ItemID.IsValid(given) {
      return;
    }
    let old = RLWeapons.State(run, from);
    let mods: array<CName>;
    if IsDefined(old) {
      mods = old.mods;
      ArrayRemove(run.weapons, old);
    }
    GameInstance.GetTransactionSystem(player.GetGame()).RemoveItem(player, from, 1);
    let equip = new GameplayEquipRequest();
    equip.owner = player;
    equip.itemID = given;
    equip.blockUpdateWeaponActiveSlots = true;
    EquipmentSystem.GetInstance(player).QueueRequest(equip);
    let state = RLWeapons.StateOrNew(run, given);
    state.mods = mods;
    RLLog("Evolved " + RLRewards.ItemName(ItemID.GetTDBID(from)) + " into " + RLRewards.ItemName(iconic) + ".");
  }
}

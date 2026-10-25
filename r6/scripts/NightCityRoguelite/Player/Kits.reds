// -----------------------------------------------------------------------------
// Night City Roguelite - starting kits
// -----------------------------------------------------------------------------
// Kits pick concrete items from the runtime pools, so they always use records
// that exist in the installed game version. Gear is granted the same way the
// game grants progression-build equipment (GiveItem + GameplayEquipRequest for
// weapons, EquipRequest for cyberware, GameplayEquipProgramsRequest for
// quickhacks).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLGear {
  public static func GiveWeapon(player: ref<PlayerPuppet>, recordID: TweakDBID, tier: CName, equip: Bool) -> Bool {
    if !TDBID.IsValid(recordID) {
      return false;
    }
    let game = player.GetGame();
    let transactionSystem = GameInstance.GetTransactionSystem(game);
    let itemID = ItemID.FromTDBID(recordID);
    if !transactionSystem.GiveItem(player, itemID, 1) {
      RLLog(s"GiveItem failed for weapon \(TDBID.ToStringDEBUG(recordID))");
      return false;
    }
    let itemData = transactionSystem.GetItemData(player, itemID);
    if IsDefined(itemData) && IsNameValid(tier) {
      RPGManager.ForceItemTier(player, itemData, tier);
    }
    if equip {
      let request = new GameplayEquipRequest();
      request.owner = player;
      request.itemID = itemID;
      request.blockUpdateWeaponActiveSlots = true;
      EquipmentSystem.GetInstance(player).QueueRequest(request);
    }
    return true;
  }

  public static func InstallCyberware(player: ref<PlayerPuppet>, recordID: TweakDBID) -> Bool {
    if !TDBID.IsValid(recordID) {
      return false;
    }
    let itemID = ItemID.FromTDBID(recordID);
    let area = EquipmentSystem.GetEquipAreaType(itemID);
    let request = new EquipRequest();
    request.owner = player;
    request.itemID = itemID;
    request.addToInventory = !GameInstance.GetTransactionSystem(player.GetGame()).HasItem(player, itemID);
    request.slotIndex = RLGear.FindFreeSlot(player, area);
    EquipmentSystem.GetInstance(player).QueueRequest(request);
    return true;
  }

  // First empty slot in the area, or 0 (replace) when all are taken.
  public static func FindFreeSlot(player: ref<PlayerPuppet>, area: gamedataEquipmentArea) -> Int32 {
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) {
      return 0;
    }
    let slots = data.GetNumberOfSlots(area, false);
    let i = 0;
    while i < slots {
      if !ItemID.IsValid(data.GetItemInEquipSlot(area, i)) {
        return i;
      }
      i += 1;
    }
    return 0;
  }

  public static func GiveQuickhacks(player: ref<PlayerPuppet>, recordIDs: array<TweakDBID>) {
    if ArraySize(recordIDs) == 0 {
      return;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let request = new GameplayEquipProgramsRequest();
    request.owner = player;
    for id in recordIDs {
      if TDBID.IsValid(id) {
        transactionSystem.GiveItemByTDBID(player, id, 1);
        ArrayPush(request.programIDs, ItemID.CreateQuery(id));
      }
    }
    EquipmentSystem.GetInstance(player).QueueRequest(request);
  }

  public static func GiveStack(player: ref<PlayerPuppet>, recordID: TweakDBID, amount: Int32) {
    if TDBID.IsValid(recordID) && amount > 0 {
      GameInstance.GetTransactionSystem(player.GetGame()).GiveItemByTDBID(player, recordID, amount);
    }
  }

  public static func GiveEddies(player: ref<PlayerPuppet>, amount: Int32) {
    RLGear.GiveStack(player, t"Items.money", amount);
  }

  // Capacity (Humanity) the item needs, read the same way PlayerPuppet does.
  public static func CapacityCost(player: ref<PlayerPuppet>, recordID: TweakDBID) -> Float {
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(recordID);
    params.quantity = 1;
    let itemData = Inventory.CreateItemData(params, player);
    let requirements = RPGManager.GetEquipRequirements(player, itemData);
    for requirement in requirements {
      if Equals(requirement.statType, gamedataStatType.HumanityAvailable) {
        return requirement.requiredValue;
      }
    }
    return 0.0;
  }

  public static func CapacityAvailable(player: ref<PlayerPuppet>) -> Float {
    let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
    let objectID = Cast<StatsObjectID>(player.GetEntityID());
    return statsSystem.GetStatValue(objectID, gamedataStatType.HumanityAvailable)
      - statsSystem.GetStatValue(objectID, gamedataStatType.HumanityOverallocated);
  }
}

public abstract class RLKits {
  public static func Apply(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, kit: CName) {
    let pistolTypes = [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_Revolver];
    let noIDs: array<TweakDBID>;
    switch kit {
      case n"Blade":
        RLGear.GiveWeapon(player, pools.PickWeapon([gamedataItemType.Wea_Katana, gamedataItemType.Wea_Sword]), n"Common", true);
        RLGear.GiveWeapon(player, pools.PickWeapon(pistolTypes), n"Common", true);
        break;
      case n"Netrunner":
        RLGear.InstallCyberware(player, pools.PickCyberware(0, true, gamedataItemType.Invalid, noIDs));
        let first = pools.PickQuickhack(0, noIDs);
        let second = pools.PickQuickhack(0, [first]);
        RLGear.GiveQuickhacks(player, [first, second]);
        RLGear.GiveWeapon(player, pools.PickWeapon(pistolTypes), n"Common", true);
        break;
      case n"Marksman":
        RLGear.GiveWeapon(player, pools.PickWeapon([gamedataItemType.Wea_PrecisionRifle, gamedataItemType.Wea_SniperRifle]), n"Common", true);
        RLGear.GiveWeapon(player, pools.PickWeapon(pistolTypes), n"Common", true);
        break;
      case n"Brawler":
        RLGear.InstallCyberware(player, pools.PickCyberware(0, false, gamedataItemType.Cyb_StrongArms, noIDs));
        RLGear.GiveWeapon(player, pools.PickWeapon([gamedataItemType.Wea_Shotgun, gamedataItemType.Wea_ShotgunDual]), n"Common", true);
        break;
      default:
        RLGear.GiveWeapon(player, pools.PickWeapon([gamedataItemType.Wea_AssaultRifle, gamedataItemType.Wea_SubmachineGun]), n"Common", true);
        RLGear.GiveWeapon(player, pools.PickWeapon(pistolTypes), n"Common", true);
    }
    // Everyone gets a couple of heals and grenades.
    RLGear.GiveStack(player, pools.PickHealing(), 2);
    RLGear.GiveStack(player, pools.PickGrenade(), 2);
    RLLog(s"Kit applied: \(NameToString(kit))");
  }
}

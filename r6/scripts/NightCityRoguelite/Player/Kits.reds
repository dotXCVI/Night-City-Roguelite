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

  // Gives one of the item and puts it in its slot (health item, grenade...).
  public static func GiveAndEquip(player: ref<PlayerPuppet>, recordID: TweakDBID) -> Bool {
    if !TDBID.IsValid(recordID) {
      return false;
    }
    let itemID = ItemID.FromTDBID(recordID);
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    if !transactionSystem.HasItem(player, itemID) && !transactionSystem.GiveItem(player, itemID, 1) {
      RLLog(s"GiveItem failed for \(TDBID.ToStringDEBUG(recordID))");
      return false;
    }
    let request = new EquipRequest();
    request.owner = player;
    request.itemID = itemID;
    request.slotIndex = 0;
    EquipmentSystem.GetInstance(player).QueueRequest(request);
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

// Starting kits: Common weapons (no Smart or Tech weapons at the start), one
// identity perk, the kit's attributes, and a basic MaxDoc (an Uncommon one with
// the Med Kit unlock). Grenades are rewards, except for the Demolitions kit.
//
// Attributes are the kit's, not spent by hand: from the base 3, the kit's main
// attribute gets +4 and its second +3 (the Edge unlocks add to the main one).
// After that they grow with the perks V takes.
public abstract class RLKits {
  public static func MainAttribute(kit: CName) -> gamedataStatType {
    switch kit {
      case n"Blade": return gamedataStatType.Reflexes;
      case n"Netrunner": return gamedataStatType.Intelligence;
      case n"Marksman": return gamedataStatType.Cool;
      case n"Brawler": return gamedataStatType.Strength;
      case n"Gunslinger": return gamedataStatType.Cool;
      case n"Demolitions": return gamedataStatType.TechnicalAbility;
      case n"Juggernaut": return gamedataStatType.Strength;
    }
    return gamedataStatType.Reflexes;
  }

  public static func SecondAttribute(kit: CName) -> gamedataStatType {
    switch kit {
      case n"Blade": return gamedataStatType.Cool;
      case n"Netrunner": return gamedataStatType.TechnicalAbility;
      case n"Marksman": return gamedataStatType.Reflexes;
      case n"Brawler": return gamedataStatType.TechnicalAbility;
      case n"Gunslinger": return gamedataStatType.Reflexes;
      case n"Demolitions": return gamedataStatType.Strength;
      case n"Juggernaut": return gamedataStatType.TechnicalAbility;
    }
    return gamedataStatType.Strength;
  }

  public static func Apply(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, kit: CName, healthStep: Int32, bonusAttributePoints: Int32) {
    let basic = RLRewards.AllowedEvolutions(1);
    let pistols = [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_Revolver];
    let noIDs: array<TweakDBID>;
    let perk = gamedataNewPerkType.Reflexes_Left_Milestone_2;
    switch kit {
      case n"Blade":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Katana, gamedataItemType.Wea_Sword], basic);
        RLKits.Weapon(player, pools, pistols, basic);
        perk = gamedataNewPerkType.Reflexes_Right_Milestone_2;
        break;
      case n"Netrunner":
        RLGear.InstallCyberware(player, pools.PickCyberware(0, true, gamedataItemType.Invalid, noIDs));
        let first = pools.PickQuickhack(0, noIDs);
        let second = pools.PickQuickhack(0, [first]);
        RLGear.GiveQuickhacks(player, [first, second]);
        RLKits.Weapon(player, pools, pistols, basic);
        perk = gamedataNewPerkType.Intelligence_Central_Milestone_1;
        break;
      case n"Marksman":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_PrecisionRifle, gamedataItemType.Wea_SniperRifle], basic);
        RLKits.Weapon(player, pools, pistols, basic);
        perk = gamedataNewPerkType.Cool_Left_Milestone_2;
        break;
      case n"Brawler":
        RLGear.InstallCyberware(player, pools.PickCyberware(0, false, gamedataItemType.Cyb_StrongArms, noIDs));
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Shotgun, gamedataItemType.Wea_ShotgunDual], basic);
        perk = gamedataNewPerkType.Body_Left_Milestone_2;
        break;
      case n"Gunslinger":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Revolver], basic);
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Handgun], basic);
        perk = gamedataNewPerkType.Cool_Central_Milestone_2;
        break;
      case n"Demolitions":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_SubmachineGun], basic);
        RLConsumables.SetGrenade(player, RLConsumables.PickGrenadeOfFamily("Frag", 2));
        perk = gamedataNewPerkType.Tech_Left_Milestone_1;
        break;
      case n"Juggernaut":
        if !RLKits.Weapon(player, pools, [gamedataItemType.Wea_LightMachineGun], basic) {
          RLKits.Weapon(player, pools, [gamedataItemType.Wea_AssaultRifle], basic);
        }
        RLKits.Weapon(player, pools, pistols, basic);
        perk = gamedataNewPerkType.Body_Central_Milestone_1;
        break;
      default:
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_AssaultRifle, gamedataItemType.Wea_SubmachineGun], basic);
        RLKits.Weapon(player, pools, pistols, basic);
    }
    let data = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(data) {
      data.RL_RaiseAttribute(RLKits.MainAttribute(kit), 4 + bonusAttributePoints);
      data.RL_RaiseAttribute(RLKits.SecondAttribute(kit), 3);
      RLPerks.Grant(data, perk, 0);
      data.UpdateUIBB();
    }
    RLConsumables.GiveStarterHealth(player, healthStep);
    RLLog("Kit applied: " + NameToString(kit) + ".");
  }

  private static func Weapon(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, types: array<gamedataItemType>, evolutions: array<gamedataWeaponEvolution>) -> Bool {
    let record = pools.PickWeapon(types, evolutions);
    if !TDBID.IsValid(record) {
      record = pools.PickWeapon(types);
    }
    return RLGear.GiveWeapon(player, record, n"Common", true);
  }
}

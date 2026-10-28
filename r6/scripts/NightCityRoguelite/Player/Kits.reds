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
    return ItemID.IsValid(RLGear.GiveWeaponItem(player, recordID, tier, equip));
  }

  // Gives a weapon and returns its item ID (ItemID.FromTDBID seeds unique
  // items afresh on every call, so this is the only handle on the new copy);
  // an invalid ID when it fails.
  public static func GiveWeaponItem(player: ref<PlayerPuppet>, recordID: TweakDBID, tier: CName, equip: Bool) -> ItemID {
    if !TDBID.IsValid(recordID) {
      return ItemID.None();
    }
    let game = player.GetGame();
    let transactionSystem = GameInstance.GetTransactionSystem(game);
    let itemID = ItemID.FromTDBID(recordID);
    if !transactionSystem.GiveItem(player, itemID, 1) {
      RLLog(s"GiveItem failed for weapon \(TDBID.ToStringDEBUG(recordID))");
      return ItemID.None();
    }
    let system = RogueliteSystem.Get(game);
    let run = IsDefined(system) ? system.GetRun() : null;
    if IsDefined(run) {
      ArrayPush(run.grantedWeapons, recordID);
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
    return itemID;
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

  public static func InstallCyberware(player: ref<PlayerPuppet>, recordID: TweakDBID) -> Bool = ItemID.IsValid(RLGear.InstallCyberwareItem(player, recordID))

  // Installs chrome and returns the installed copy's item ID. The item is
  // given here rather than by the request: a request that adds the item
  // itself seeds a new ID, and this one would be no handle on it.
  public static func InstallCyberwareItem(player: ref<PlayerPuppet>, recordID: TweakDBID) -> ItemID {
    if !TDBID.IsValid(recordID) {
      return ItemID.None();
    }
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    let itemID = ItemID.FromTDBID(recordID);
    if !transactions.HasItem(player, itemID) && !transactions.GiveItem(player, itemID, 1) {
      RLLog("GiveItem failed for chrome " + RLRewards.ItemName(recordID) + ".");
      return ItemID.None();
    }
    let area = EquipmentSystem.GetEquipAreaType(itemID);
    let request = new EquipRequest();
    request.owner = player;
    request.itemID = itemID;
    request.slotIndex = RLGear.FindFreeSlot(player, area);
    EquipmentSystem.GetInstance(player).QueueRequest(request);
    RLGear.ExplainRefusal(player, itemID);
    return itemID;
  }

  // The game drops an equip it won't do without a word (item level above
  // V's, an unmet requirement): say so in the log.
  private static func ExplainRefusal(player: ref<PlayerPuppet>, itemID: ItemID) {
    let data = EquipmentSystem.GetData(player);
    let itemData = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, itemID);
    if !IsDefined(data) || !IsDefined(itemData) || data.IsEquippable(itemData) {
      return;
    }
    let stats = GameInstance.GetStatsSystem(player.GetGame());
    let level = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.Level);
    RLLog(s"Chrome refused: \(RLRewards.ItemName(ItemID.GetTDBID(itemID))) (item level \(itemData.GetStatValueByType(gamedataStatType.Level)), V level \(level) - or an unmet requirement).");
  }

  // What installing into the area would replace: the item in slot 0 when
  // every slot is taken (see FindFreeSlot), else none.
  public static func ReplacedBy(player: ref<PlayerPuppet>, recordID: TweakDBID) -> ItemID {
    let data = EquipmentSystem.GetData(player);
    let area = EquipmentSystem.GetEquipAreaType(ItemID.FromTDBID(recordID));
    if !IsDefined(data) {
      return ItemID.None();
    }
    let slots = data.GetNumberOfSlots(area, false);
    let i = 0;
    while i < slots {
      if !ItemID.IsValid(data.GetItemInEquipSlot(area, i)) {
        return ItemID.None();
      }
      i += 1;
    }
    return slots > 0 ? data.GetItemInEquipSlot(area, 0) : ItemID.None();
  }

  // Capacity an install really adds: its cost less what it replaces.
  public static func NetCapacityCost(player: ref<PlayerPuppet>, recordID: TweakDBID) -> Float {
    let cost = RLGear.CapacityCost(player, recordID);
    let replaced = RLGear.ReplacedBy(player, recordID);
    if ItemID.IsValid(replaced) {
      cost -= RLGear.CapacityCost(player, ItemID.GetTDBID(replaced));
    }
    return cost;
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
// the Med Kit unlock), and a Common frag grenade (Demolitions starts with a
// better one); better grenades are rewards.
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
      case n"Wireman": return gamedataStatType.Intelligence;
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
      case n"Wireman": return gamedataStatType.TechnicalAbility;
    }
    return gamedataStatType.Strength;
  }

  public static func AttributeName(stat: gamedataStatType) -> String {
    switch stat {
      case gamedataStatType.Strength: return "BODY";
      case gamedataStatType.Reflexes: return "REFLEXES";
      case gamedataStatType.TechnicalAbility: return "TECHNICAL ABILITY";
      case gamedataStatType.Intelligence: return "INTELLIGENCE";
      case gamedataStatType.Cool: return "COOL";
    }
    return "";
  }

  // Gives the kit and puts its weapons in the run's slots: the first weapon
  // is the main, the second the sidearm (Rewards/Weapons.reds).
  public static func Apply(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, healthStep: Int32, bonusAttributePoints: Int32) {
    let kit = run.kit;
    let weapons: array<ItemID>;
    let basic = RLRewards.AllowedEvolutions(1);
    let pistols = [gamedataItemType.Wea_Handgun, gamedataItemType.Wea_Revolver];
    let noIDs: array<TweakDBID>;
    let perk = gamedataNewPerkType.Reflexes_Left_Milestone_2;
    switch kit {
      case n"Blade":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Katana, gamedataItemType.Wea_Sword], basic, weapons);
        RLKits.Weapon(player, pools, pistols, basic, weapons);
        perk = gamedataNewPerkType.Reflexes_Right_Milestone_2;
        break;
      case n"Netrunner":
        RLKits.Chrome(player, run, pools.PickCyberware(0, true, gamedataItemType.Invalid, noIDs));
        let first = pools.PickQuickhack(0, noIDs);
        let second = pools.PickQuickhack(0, [first]);
        RLGear.GiveQuickhacks(player, [first, second]);
        RLKits.Weapon(player, pools, pistols, basic, weapons);
        perk = gamedataNewPerkType.Intelligence_Central_Milestone_1;
        break;
      case n"Marksman":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_PrecisionRifle, gamedataItemType.Wea_SniperRifle], basic, weapons);
        RLKits.Weapon(player, pools, pistols, basic, weapons);
        perk = gamedataNewPerkType.Cool_Left_Milestone_2;
        break;
      case n"Brawler":
        // The arms are the main weapon; the shotgun backs them up.
        RLKits.Arms(player, pools, run, gamedataItemType.Cyb_StrongArms, weapons);
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Shotgun, gamedataItemType.Wea_ShotgunDual], basic, weapons);
        perk = gamedataNewPerkType.Body_Left_Milestone_2;
        break;
      case n"Gunslinger":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Revolver], basic, weapons);
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_Handgun], basic, weapons);
        perk = gamedataNewPerkType.Cool_Central_Milestone_2;
        break;
      case n"Demolitions":
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_SubmachineGun], basic, weapons);
        RLConsumables.SetGrenade(player, RLConsumables.PickGrenadeOfFamily("Frag", 2));
        perk = gamedataNewPerkType.Tech_Left_Milestone_1;
        break;
      case n"Wireman":
        // Monowire with a deck behind it: Siphon turns every lash into RAM.
        RLKits.Arms(player, pools, run, gamedataItemType.Cyb_NanoWires, weapons);
        RLKits.Chrome(player, run, pools.PickCyberware(0, true, gamedataItemType.Invalid, noIDs));
        RLGear.GiveQuickhacks(player, [pools.PickQuickhack(0, noIDs)]);
        RLKits.Weapon(player, pools, pistols, basic, weapons);
        perk = gamedataNewPerkType.Intelligence_Inbetween_Left_2;
        break;
      case n"Juggernaut":
        if !RLKits.Weapon(player, pools, [gamedataItemType.Wea_LightMachineGun], basic, weapons) {
          RLKits.Weapon(player, pools, [gamedataItemType.Wea_AssaultRifle], basic, weapons);
        }
        RLKits.Weapon(player, pools, pistols, basic, weapons);
        perk = gamedataNewPerkType.Body_Central_Milestone_1;
        break;
      default:
        RLKits.Weapon(player, pools, [gamedataItemType.Wea_AssaultRifle, gamedataItemType.Wea_SubmachineGun], basic, weapons);
        RLKits.Weapon(player, pools, pistols, basic, weapons);
    }
    let data = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(data) {
      data.RL_RaiseAttribute(RLKits.MainAttribute(kit), 4 + bonusAttributePoints);
      data.RL_RaiseAttribute(RLKits.SecondAttribute(kit), 3);
      RLPerks.Grant(data, perk, 0);
      data.UpdateUIBB();
    }
    RLWeapons.AssignSlots(run, weapons);
    RLConsumables.GiveStarterHealth(player, healthStep);
    // Everyone starts with a basic grenade; rewards replace or upgrade it.
    if !TDBID.IsValid(RLConsumables.CurrentGrenade(player)) {
      RLConsumables.SetGrenade(player, RLConsumables.PickGrenadeOfFamily("Frag", 0));
    }
    RLLog("Kit applied: " + NameToString(kit) + ".");
  }

  // Kit chrome brings its own capacity: a level-1 V never has it refused.
  private static func Chrome(player: ref<PlayerPuppet>, run: ref<RLRunState>, record: TweakDBID) {
    let cost = RLGear.NetCapacityCost(player, record);
    if cost > 0.0 {
      RLEvents.AddRunMod(player, run, gamedataStatType.Humanity, gameStatModifierType.Additive, cost);
    }
    if !RLGear.InstallCyberware(player, record) {
      RLLog("Kit chrome missing: no record to install.");
    }
  }

  // The kit's arm chrome, plain and Uncommon, as its main weapon.
  private static func Arms(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>, itemType: gamedataItemType, out weapons: array<ItemID>) {
    let noIDs: array<TweakDBID>;
    let record = RLArms.Record(RLArms.Family(itemType), "", RLArms.MinStep());
    if !TDBID.IsValid(record) {
      record = pools.PickCyberware(0, false, itemType, noIDs);
    }
    let given = RLArms.Install(player, run, record, ItemID.None());
    if ItemID.IsValid(given) {
      ArrayPush(weapons, given);
    } else {
      RLLog("Kit arms missing: no record to install.");
    }
  }

  private static func Weapon(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, types: array<gamedataItemType>, evolutions: array<gamedataWeaponEvolution>, out weapons: array<ItemID>) -> Bool {
    let record = pools.PickWeapon(types, evolutions);
    if !TDBID.IsValid(record) {
      record = pools.PickWeapon(types);
    }
    let given = RLGear.GiveWeaponItem(player, record, n"Common", true);
    if !ItemID.IsValid(given) {
      return false;
    }
    ArrayPush(weapons, given);
    return true;
  }
}

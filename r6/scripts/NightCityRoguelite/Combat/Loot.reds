// -----------------------------------------------------------------------------
// Night City Roguelite - ammo and loot
// -----------------------------------------------------------------------------
// No looting in arenas - all thinking happens between fights:
//   - V arrives with every weapon's ammo full and health/grenade charges full;
//   - clearing a wave refills part of every ammo type and one health charge;
//   - bodies are emptied (only clothes stay), so there is nothing to search;
//   - anything V picks up in an arena anyway (junk, weapons, consumables) is
//     taken away again right after.
// Health items and grenades are gear upgrades instead (Player/Consumables.reds,
// Rewards/RewardSystem.reds).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLLoot {
  // --- Arrival -------------------------------------------------------------------------

  public static func RefillForArena(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    RLLoot.TopUpAmmo(player);
    let pools = GameInstance.GetStatPoolsSystem(player.GetGame());
    let id = Cast<StatsObjectID>(player.GetEntityID());
    pools.RequestSettingStatPoolValue(id, gamedataStatPoolType.HealingItemsCharges, 100.0, null, true);
    pools.RequestSettingStatPoolValue(id, gamedataStatPoolType.GrenadesCharges, 100.0, null, true);
  }

  // Fills every ammo type V's weapons use up to the game's carry limit.
  public static func TopUpAmmo(player: ref<PlayerPuppet>) {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let filled = 0;
    for ammo in RLLoot.PlayerAmmoTypes(player) {
      let ammoID = ItemID.CreateQuery(ammo);
      if transactionSystem.GetItemQuantity(player, ammoID) <= 0 {
        transactionSystem.GiveItem(player, ammoID, 1);
      }
      let have = transactionSystem.GetItemQuantity(player, ammoID);
      let cap = RLLoot.AmmoCap(player, ammoID);
      if cap > have {
        transactionSystem.GiveItem(player, ammoID, cap - have);
        filled += 1;
      }
    }
    RLDebug(s"Ammo topped up for \(filled) ammo type(s).");
  }

  // Carry limit of an ammo type (the item's Quantity stat), or a sane default.
  public static func AmmoCap(player: ref<PlayerPuppet>, ammoID: ItemID) -> Int32 {
    let data = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, ammoID);
    if IsDefined(data) {
      let cap = Cast<Int32>(data.GetStatValueByType(gamedataStatType.Quantity));
      if cap >= 20 {
        return cap;
      }
    }
    return 250;
  }

  public static func PlayerAmmoTypes(player: ref<PlayerPuppet>) -> array<TweakDBID> {
    let result: array<TweakDBID>;
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && Equals(RPGManager.GetItemCategory(item.GetID()), gamedataItemCategory.Weapon) {
        let weapon = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(item.GetID()));
        if IsDefined(weapon) && IsDefined(weapon.Ammo()) {
          let ammo = weapon.Ammo().GetID();
          if TDBID.IsValid(ammo) && !ArrayContains(result, ammo) {
            ArrayPush(result, ammo);
          }
        }
      }
    }
    return result;
  }

  // --- Bodies --------------------------------------------------------------------------

  // Empties a body: everything but its clothes goes. Two passes are made (the
  // game may still be generating the body's loot on the first one).
  public static func EmptyCorpse(npc: ref<ScriptedPuppet>) {
    if !IsDefined(npc) {
      return;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(npc.GetGame());
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(npc, items);
    for item in items {
      if IsDefined(item) && !item.HasTag(n"Quest") && !EquipmentSystem.IsClothing(item.GetID()) {
        transactionSystem.RemoveItem(npc, item.GetID(), item.GetQuantity());
      }
    }
  }

  // --- Wave cleared --------------------------------------------------------------------

  // Part of every ammo type back, plus one health item charge.
  public static func RefillAfterWave(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    RLLoot.RefillAmmo(player, RLConfig.WaveAmmoRefill());
    ConsumablesChargesHelper.RefreshAmountOfCharges(player.GetGame(), gamedataStatPoolType.HealingItemsCharges, 1);
  }

  // A share of every ammo type's carry limit back, never past the limit.
  public static func RefillAmmo(player: ref<PlayerPuppet>, share: Float) {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    for ammo in RLLoot.PlayerAmmoTypes(player) {
      let ammoID = ItemID.CreateQuery(ammo);
      let cap = RLLoot.AmmoCap(player, ammoID);
      let have = transactionSystem.GetItemQuantity(player, ammoID);
      let amount = Min(cap - have, Max(1, RoundF(Cast<Float>(cap) * share)));
      if amount > 0 {
        transactionSystem.GiveItem(player, ammoID, amount);
      }
    }
  }

  // --- Pickups ---------------------------------------------------------------------------

  // Safety net behind the pickup filter (run on every trip): weapons the run
  // didn't hand out - one an enemy dropped that slipped past the filter - are
  // taken away. V's fists and default handgun slot are never touched.
  public static func RemoveStrayWeapons(player: ref<PlayerPuppet>, granted: array<TweakDBID>) {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    let stray: array<ItemID>;
    for item in items {
      if IsDefined(item) && Equals(RPGManager.GetItemCategory(item.GetID()), gamedataItemCategory.Weapon) {
        let area = EquipmentSystem.GetEquipAreaType(item.GetID());
        if NotEquals(area, gamedataEquipmentArea.BaseFists) && NotEquals(area, gamedataEquipmentArea.VDefaultHandgun)
          && !ArrayContains(granted, ItemID.GetTDBID(item.GetID())) && !RLCharacterReset.IsBodyItem(ItemID.GetTDBID(item.GetID())) {
          ArrayPush(stray, item.GetID());
        }
      }
    }
    for itemID in stray {
      transactionSystem.RemoveItem(player, itemID, 1);
      RLLog("Removed a weapon picked up in an arena: " + RLRewards.ItemName(ItemID.GetTDBID(itemID)) + ".");
    }
  }

  // Arena pickups that are taken away again: everything except ammo, money,
  // quest items and hidden system items (V's own body parts).
  public static func ShouldDiscardPickup(itemID: ItemID, itemData: ref<gameItemData>) -> Bool {
    if IsDefined(itemData) && (itemData.HasTag(n"Ammo") || itemData.HasTag(n"Currency") || itemData.HasTag(n"Quest")
      || itemData.HasTag(n"HideInUI") || itemData.HasTag(n"TppHead") || itemData.HasTag(n"UnequipBlocked")) {
      return false;
    }
    let tdbid = ItemID.GetTDBID(itemID);
    if RLCharacterReset.IsBodyItem(tdbid) {
      return false;
    }
    let record = TweakDBInterface.GetItemRecord(tdbid);
    if !IsDefined(record) || record.TagsContains(n"Ammo") || record.TagsContains(n"Currency") || record.TagsContains(n"Quest") {
      return false;
    }
    switch RPGManager.GetItemCategory(itemID) {
      case gamedataItemCategory.Weapon:
      case gamedataItemCategory.Clothing:
      case gamedataItemCategory.Cyberware:
      case gamedataItemCategory.Part:
      case gamedataItemCategory.WeaponMod:
      case gamedataItemCategory.General:
      case gamedataItemCategory.Consumable:
      case gamedataItemCategory.Gadget:
        return true;
    }
    return false;
  }
}

// Arena pickups V shouldn't carry are queued for removal (the game's own
// bookkeeping runs first so inventory weight stays right). The mod's own
// grants are exempt (RogueliteSystem.FiltersLoot is off while they happen).
@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let system = RogueliteSystem.Get(this.GetGame());
  if IsDefined(system) && system.FiltersLoot() && ItemID.IsValid(evt.itemID) && !system.ConsumeExpectedGrant(ItemID.GetTDBID(evt.itemID)) {
    if RLLoot.ShouldDiscardPickup(evt.itemID, evt.itemData) {
      system.QueueLootRemoval(evt.itemID);
    }
  }
  return result;
}

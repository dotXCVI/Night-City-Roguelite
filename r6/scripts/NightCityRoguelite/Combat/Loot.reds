// -----------------------------------------------------------------------------
// Night City Roguelite - ammo and loot
// -----------------------------------------------------------------------------
// In an arena the only loot is what keeps V fighting:
//   - V arrives with every weapon's ammo full and health/grenade charges full;
//   - bodies are stripped of their junk and carry ammo for V's weapons, and
//     sometimes a health item or grenade;
//   - picking up a health item or grenade also restores one charge;
//   - anything else V picks up in an arena (junk, crafting parts, weapons,
//     clothes) is taken away again right after.
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

  // Removes everything from a body except its clothes. With `stock`, also puts
  // in ammo for V's weapons and maybe a health item or grenade.
  public static func PrepareCorpse(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, stock: Bool) {
    if !IsDefined(npc) || !IsDefined(player) {
      return;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(npc.GetGame());
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(npc, items);
    for item in items {
      if IsDefined(item) && RLLoot.IsCorpseJunk(item) {
        transactionSystem.RemoveItem(npc, item.GetID(), item.GetQuantity());
      }
    }
    if !stock {
      return;
    }
    for ammo in RLLoot.PlayerAmmoTypes(player) {
      let ammoID = ItemID.CreateQuery(ammo);
      let amount = Max(6, RLLoot.AmmoCap(player, ammoID) / 10) + RandRange(0, 8);
      transactionSystem.GiveItem(npc, ammoID, amount);
    }
    let pools = RogueliteService.Get().GetPools();
    if RandF() < 0.3 {
      let heal = pools.PickHealing();
      if TDBID.IsValid(heal) {
        transactionSystem.GiveItem(npc, ItemID.FromTDBID(heal), 1);
      }
    }
    if RandF() < 0.2 {
      let grenade = pools.PickGrenade();
      if TDBID.IsValid(grenade) {
        transactionSystem.GiveItem(npc, ItemID.FromTDBID(grenade), 1);
      }
    }
  }

  private static func IsCorpseJunk(item: wref<gameItemData>) -> Bool {
    if item.HasTag(n"Quest") || item.HasTag(n"HideInUI") || item.HasTag(n"Ammo") {
      return false;
    }
    return !EquipmentSystem.IsClothing(item.GetID());
  }

  // --- Pickups ---------------------------------------------------------------------------

  public static func IsHealing(itemID: ItemID) -> Bool {
    let itemType = RPGManager.GetItemType(itemID);
    return Equals(itemType, gamedataItemType.Con_Inhaler) || Equals(itemType, gamedataItemType.Con_Injector);
  }

  public static func IsGrenade(itemID: ItemID) -> Bool {
    return Equals(RPGManager.GetItemType(itemID), gamedataItemType.Gad_Grenade);
  }

  // Arena pickups that are taken away again: junk, crafting parts, mods,
  // weapons, clothes, cyberware, food. Ammo, money, health items, grenades,
  // quest and hidden system items (V's own body parts) always stay.
  public static func ShouldDiscardPickup(itemID: ItemID, itemData: ref<gameItemData>) -> Bool {
    if IsDefined(itemData) && (itemData.HasTag(n"Ammo") || itemData.HasTag(n"Currency") || itemData.HasTag(n"Quest")
      || itemData.HasTag(n"HideInUI") || itemData.HasTag(n"TppHead") || itemData.HasTag(n"UnequipBlocked")) {
      return false;
    }
    let tdbid = ItemID.GetTDBID(itemID);
    if RLCharacterReset.IsBodyItem(tdbid) || RLLoot.IsHealing(itemID) || RLLoot.IsGrenade(itemID) {
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

  // One charge back for a picked-up health item or grenade.
  public static func RestoreCharge(player: ref<PlayerPuppet>, itemID: ItemID) {
    let pools = GameInstance.GetStatPoolsSystem(player.GetGame());
    let id = Cast<StatsObjectID>(player.GetEntityID());
    if RLLoot.IsHealing(itemID) {
      pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.HealingItemsCharges, Cast<Float>(player.GetHealingItemUseCost()), null, false, false);
    } else if RLLoot.IsGrenade(itemID) {
      pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.GrenadesCharges, Cast<Float>(player.GetGrenadeThrowCostClean()), null, false, false);
    }
  }
}

// Arena pickups: health items and grenades also restore a charge, anything V
// shouldn't carry is queued for removal (the game's own bookkeeping runs first
// so inventory weight stays right).
@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let system = RogueliteSystem.Get(this.GetGame());
  if IsDefined(system) && system.FiltersLoot() && ItemID.IsValid(evt.itemID) {
    if RLLoot.ShouldDiscardPickup(evt.itemID, evt.itemData) {
      system.QueueLootRemoval(evt.itemID);
    } else {
      RLLoot.RestoreCharge(this, evt.itemID);
    }
  }
  return result;
}

// -----------------------------------------------------------------------------
// Night City Roguelite - character reset
// -----------------------------------------------------------------------------
// Puts V back to a level-1 baseline. Modelled on the game's own
// PlayerDevelopmentData.FlushDevelopment (used by the Phantom Liberty start),
// with one difference: clothing is kept so V isn't left in underwear.
//
// The reset happens in two phases because unequipping is queued:
//   Phase 1 (immediate): progression reset, unequip requests queued.
//   Phase 2 (~0.5 s later): non-clothing items removed from the inventory.
// -----------------------------------------------------------------------------

module NightCityRoguelite

// --- Progression reset (runs inside PlayerDevelopmentData to reach its privates)

@addMethod(PlayerDevelopmentData)
public final func RL_ResetProgression(attributePoints: Int32, perkPoints: Int32) {
  // New perks (2.0 trees, Relic): sell every level and lock.
  this.ResetNewPerks();

  // Legacy perks, in case an old save carried any.
  let i = 0;
  while i < 228 {
    let perkType = IntEnum<gamedataPerkType>(i);
    if this.HasPerk(perkType) {
      this.RemovePerk(perkType);
    }
    i += 1;
  }

  // Core attributes back to the baseline value.
  let base = RLConfig.BaseAttributeValue();
  this.SetAttribute(gamedataStatType.Strength, base);
  this.SetAttribute(gamedataStatType.Reflexes, base);
  this.SetAttribute(gamedataStatType.TechnicalAbility, base);
  this.SetAttribute(gamedataStatType.Intelligence, base);
  this.SetAttribute(gamedataStatType.Cool, base);

  // Skills to their starting level, character level to 1.
  this.ResetAllProficienciesLevel();
  this.SetLevel(gamedataProficiencyType.Level, 1, telemetryLevelGainReason.Ignore);

  // Development points: wipe, then grant the baseline.
  this.ClearAllDevPoints();
  this.SetDevelopmentsPoint(gamedataDevelopmentPointType.Attribute, attributePoints);
  this.SetDevelopmentsPoint(gamedataDevelopmentPointType.Primary, perkPoints);

  this.UpdateUIBB();
}

@addMethod(PlayerDevelopmentData)
public final func RL_GrantLevels(levels: Int32) {
  let i = 0;
  while i < levels {
    if this.IsProficiencyMaxLvl(gamedataProficiencyType.Level) {
      return;
    }
    this.AddExperience(
      this.GetRemainingExpForLevelUp(gamedataProficiencyType.Level),
      gamedataProficiencyType.Level,
      telemetryLevelGainReason.Gameplay
    );
    i += 1;
  }
}

// --- Inventory reset ------------------------------------------------------------

public abstract class RLCharacterReset {
  // Phase 1. Returns immediately; call RemoveGear() ~0.5 s later.
  public static func ResetProgressionAndUnequip(player: ref<PlayerPuppet>, attributePoints: Int32, perkPoints: Int32) {
    if !IsDefined(player) {
      return;
    }
    let devData = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(devData) {
      devData.RL_ResetProgression(attributePoints, perkPoints);
    }

    let game = player.GetGame();
    let equipmentSystem = EquipmentSystem.GetInstance(player);
    let equipmentData = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(game).GetItemList(player, items);
    for item in items {
      let itemID = item.GetID();
      if !RLCharacterReset.ShouldRemove(item) {
        continue;
      }
      if IsDefined(equipmentData) && equipmentData.IsEquipped(itemID) {
        let request = new UnequipRequest();
        request.owner = player;
        request.areaType = EquipmentSystem.GetEquipAreaType(itemID);
        request.slotIndex = equipmentData.GetSlotIndex(itemID);
        request.force = true;
        equipmentSystem.QueueRequest(request);
      }
    }
  }

  // Phase 2.
  public static func RemoveGear(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    let removed = 0;
    for item in items {
      if RLCharacterReset.ShouldRemove(item) {
        transactionSystem.RemoveItem(player, item.GetID(), item.GetQuantity());
        removed += 1;
      }
    }
    RLDebug(s"Reset removed \(removed) item stacks.");
  }

  // Keep clothing, quest items and anything the game marks as unremovable.
  public static func ShouldRemove(item: wref<gameItemData>) -> Bool {
    if !IsDefined(item) {
      return false;
    }
    if item.HasTag(n"Quest") || item.HasTag(n"UnequipBlocked") {
      return false;
    }
    let itemID = item.GetID();
    if EquipmentSystem.IsClothing(itemID) {
      return false;
    }
    let area = EquipmentSystem.GetEquipAreaType(itemID);
    switch area {
      case gamedataEquipmentArea.Face:
      case gamedataEquipmentArea.Feet:
      case gamedataEquipmentArea.Head:
      case gamedataEquipmentArea.InnerChest:
      case gamedataEquipmentArea.Legs:
      case gamedataEquipmentArea.OuterChest:
      case gamedataEquipmentArea.Outfit:
      case gamedataEquipmentArea.UnderwearBottom:
      case gamedataEquipmentArea.UnderwearTop:
      case gamedataEquipmentArea.PlayerTattoo:
      case gamedataEquipmentArea.BaseFists:
      case gamedataEquipmentArea.VDefaultHandgun:
      case gamedataEquipmentArea.PersonalLink:
      case gamedataEquipmentArea.Quest:
        return false;
    }
    return true;
  }

  public static func HealFull(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    GameInstance.GetStatPoolsSystem(player.GetGame()).RequestSettingStatPoolValue(
      Cast<StatsObjectID>(player.GetEntityID()),
      gamedataStatPoolType.Health,
      100.0,
      null,
      true
    );
  }
}

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
      if RLCharacterReset.ShouldRemove(item) && IsDefined(equipmentData) && equipmentData.IsEquipped(itemID) {
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

  // Only removes what the mod hands out or replaces: weapons, combat cyberware,
  // consumables, grenades, ammo, mods, crafting parts and junk. Everything
  // else stays, in particular V's own body items (arms, heads, holstered
  // fists - removing those leaves V with invisible limbs), clothing, quest
  // items, the personal link and anything the game hides from the UI.
  public static func ShouldRemove(item: wref<gameItemData>) -> Bool {
    if !IsDefined(item) {
      return false;
    }
    if item.HasTag(n"Quest") || item.HasTag(n"UnequipBlocked") || item.HasTag(n"HideInUI") || item.HasTag(n"TppHead") {
      return false;
    }
    let itemID = item.GetID();
    if RLCharacterReset.IsBodyItem(ItemID.GetTDBID(itemID)) || EquipmentSystem.IsClothing(itemID) {
      return false;
    }
    switch RPGManager.GetItemCategory(itemID) {
      case gamedataItemCategory.Weapon:
        let area = EquipmentSystem.GetEquipAreaType(itemID);
        return NotEquals(area, gamedataEquipmentArea.BaseFists) && NotEquals(area, gamedataEquipmentArea.VDefaultHandgun);
      case gamedataItemCategory.Cyberware:
        return RLCharacterReset.IsRemovableCyberware(EquipmentSystem.GetEquipAreaType(itemID));
      case gamedataItemCategory.Consumable:
      case gamedataItemCategory.Gadget:
      case gamedataItemCategory.Part:
      case gamedataItemCategory.WeaponMod:
        return true;
      case gamedataItemCategory.General:
        // Junk, crafting materials, ammo, money, shards.
        return true;
    }
    return false;
  }

  // Combat cyberware slots. Eyes/face (optics, scanner), hands and arm styles
  // (V's visible hands) and the personal link are left alone.
  public static func IsRemovableCyberware(area: gamedataEquipmentArea) -> Bool {
    switch area {
      case gamedataEquipmentArea.AbilityCW:
      case gamedataEquipmentArea.ArmsCW:
      case gamedataEquipmentArea.CardiovascularSystemCW:
      case gamedataEquipmentArea.FrontalCortexCW:
      case gamedataEquipmentArea.ImmuneSystemCW:
      case gamedataEquipmentArea.IntegumentarySystemCW:
      case gamedataEquipmentArea.LegsCW:
      case gamedataEquipmentArea.MusculoskeletalSystemCW:
      case gamedataEquipmentArea.NervousSystemCW:
      case gamedataEquipmentArea.SystemReplacementCW:
        return true;
    }
    return false;
  }

  public static func BodyItems() -> array<TweakDBID> {
    return [
      t"Items.CharacterCustomizationArms",
      t"Items.CharacterCustomizationMaHead",
      t"Items.CharacterCustomizationWaHead",
      t"Items.PlayerFppHead",
      t"Items.PlayerMaTppHead",
      t"Items.PlayerWaTppHead",
      t"Items.PlayerMaPhotomodeHead",
      t"Items.PlayerWaPhotomodeHead",
      t"Items.BaseHolsteredArms",
      t"Items.HolsteredFists",
      t"Items.Player_Fists",
      t"Items.PlayerTattoo"
    ];
  }

  public static func IsBodyItem(id: TweakDBID) -> Bool {
    let items = RLCharacterReset.BodyItems();
    return ArrayContains(items, id);
  }

  // Repairs characters reset by older versions of the mod, which removed V's
  // arm and head items. Gives back what is missing and puts the arms and
  // third-person head back in their slots (as the game's own menus do).
  public static func RestoreBody(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let male = Equals(player.GetResolvedGenderName(), n"Male");
    let tppHead = male ? t"Items.PlayerMaTppHead" : t"Items.PlayerWaTppHead";
    let wanted: array<TweakDBID> = [t"Items.CharacterCustomizationArms", tppHead, t"Items.PlayerFppHead", t"Items.BaseHolsteredArms", t"Items.HolsteredFists"];
    let restored = 0;
    for id in wanted {
      if IsDefined(TweakDBInterface.GetItemRecord(id)) {
        let itemID = ItemID.FromTDBID(id);
        if !transactionSystem.HasItem(player, itemID) {
          transactionSystem.GiveItem(player, itemID, 1);
          restored += 1;
          // Arms and the third-person head live in fixed slots.
          if id == t"Items.CharacterCustomizationArms" || id == tppHead {
            let slot = EquipmentSystem.GetPlacementSlot(itemID);
            if TDBID.IsValid(slot) && transactionSystem.IsSlotEmpty(player, slot) {
              transactionSystem.AddItemToSlot(player, slot, itemID);
            }
          }
        }
      }
    }
    if restored > 0 {
      RLLog(s"Restored \(restored) missing body item(s).");
    }
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

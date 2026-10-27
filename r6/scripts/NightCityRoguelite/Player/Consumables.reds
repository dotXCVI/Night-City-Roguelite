// -----------------------------------------------------------------------------
// Night City Roguelite - health items and grenades
// -----------------------------------------------------------------------------
// Both are gear, not loot:
//   - Health: V carries one MaxDoc. Its quality never falls behind the run
//     (a floor that rises with depth, like Returnal's weapon proficiency): at
//     home between fights it is upgraded automatically when the floor rises.
//   - Grenades: a reward card (Armory doors) - one grenade type at a time,
//     equipped on the spot; later cards upgrade or replace it.
//
// Quality steps: 0 Common, 1 Common+, 2 Uncommon, 3 Uncommon+, 4 Rare,
// 5 Rare+, 6 Epic, 7 Epic+, 8 Legendary, 9 Legendary+, 10 Legendary++.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLQuality {
  public static func MaxStep() -> Int32 = 10

  public static func StepOf(quality: gamedataQuality) -> Int32 {
    switch quality {
      case gamedataQuality.Common: return 0;
      case gamedataQuality.CommonPlus: return 1;
      case gamedataQuality.Uncommon: return 2;
      case gamedataQuality.UncommonPlus: return 3;
      case gamedataQuality.Rare: return 4;
      case gamedataQuality.RarePlus: return 5;
      case gamedataQuality.Epic: return 6;
      case gamedataQuality.EpicPlus: return 7;
      case gamedataQuality.Legendary: return 8;
      case gamedataQuality.Iconic: return 8;
      case gamedataQuality.LegendaryPlus: return 9;
      case gamedataQuality.LegendaryPlusPlus: return 10;
    }
    return 0;
  }

  public static func StepOfRecord(record: TweakDBID) -> Int32 {
    let item = TweakDBInterface.GetItemRecord(record);
    return IsDefined(item) && IsDefined(item.Quality()) ? RLQuality.StepOf(item.Quality().Type()) : 0;
  }

  // Tier name for RPGManager.ForceItemTier.
  public static func TierName(step: Int32) -> CName {
    switch Clamp(step, 0, RLQuality.MaxStep()) {
      case 0: return n"Common";
      case 1: return n"CommonPlus";
      case 2: return n"Uncommon";
      case 3: return n"UncommonPlus";
      case 4: return n"Rare";
      case 5: return n"RarePlus";
      case 6: return n"Epic";
      case 7: return n"EpicPlus";
      case 8: return n"Legendary";
      case 9: return n"LegendaryPlus";
    }
    return n"LegendaryPlusPlus";
  }

  public static func DisplayName(step: Int32) -> String {
    switch Clamp(step, 0, RLQuality.MaxStep()) {
      case 0: return "Common";
      case 1: return "Common+";
      case 2: return "Uncommon";
      case 3: return "Uncommon+";
      case 4: return "Rare";
      case 5: return "Rare+";
      case 6: return "Epic";
      case 7: return "Epic+";
      case 8: return "Legendary";
      case 9: return "Legendary+";
    }
    return "Legendary++";
  }

  // The quality a reward is expected to have on this floor: Common on floor 1,
  // Legendary+ on the last floor.
  public static func ExpectedStep(depth: Int32, totalFloors: Int32) -> Int32 {
    return Clamp((depth - 1) * 9 / Max(1, totalFloors - 1), 0, RLQuality.MaxStep());
  }
}

public abstract class RLConsumables {
  // --- Health items ------------------------------------------------------------------

  // MaxDoc records, lowest quality first.
  public static func HealthLadder() -> array<TweakDBID> {
    let names = ["V0", "VCommonPlus", "VUncommon", "VUncommonPlus", "V1", "VRarePlus", "V2", "VEpic", "VEpicPlus", "VLegendaryPlus"];
    let ladder: array<TweakDBID>;
    for name in names {
      let id = TDBID.Create("Items.FirstAidWhiff" + name);
      if IsDefined(TweakDBInterface.GetItemRecord(id)) {
        RLConsumables.InsertByQuality(ladder, id);
      }
    }
    return ladder;
  }

  // The health item quality V is guaranteed on a floor (about two steps behind
  // weapons, so better healing still shows up as a reward-worthy upgrade).
  public static func HealthFloorStep(depth: Int32, totalFloors: Int32) -> Int32 {
    return Clamp((depth - 1) * 8 / Max(1, totalFloors - 1), 0, RLQuality.MaxStep());
  }

  // Ladder index of the best MaxDoc V carries, or -1.
  public static func CurrentHealthIndex(player: ref<PlayerPuppet>, ladder: array<TweakDBID>) -> Int32 {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let i = ArraySize(ladder) - 1;
    while i >= 0 {
      if transactionSystem.HasItem(player, ItemID.FromTDBID(ladder[i])) {
        return i;
      }
      i -= 1;
    }
    return -1;
  }

  // Gives V the base MaxDoc (run start).
  public static func GiveStarterHealth(player: ref<PlayerPuppet>, step: Int32) {
    let ladder = RLConsumables.HealthLadder();
    if ArraySize(ladder) > 0 {
      RLConsumables.SwapHealth(player, ladder, RLConsumables.IndexForStep(ladder, step));
    }
  }

  // Raises V's MaxDoc to the floor's guaranteed quality. Returns the new item's
  // quality name, or "" when nothing changed.
  public static func ApplyHealthFloor(player: ref<PlayerPuppet>, depth: Int32, totalFloors: Int32) -> String {
    let ladder = RLConsumables.HealthLadder();
    if ArraySize(ladder) == 0 {
      return "";
    }
    let wanted = RLConsumables.IndexForStep(ladder, RLConsumables.HealthFloorStep(depth, totalFloors));
    let current = RLConsumables.CurrentHealthIndex(player, ladder);
    if wanted <= current {
      return "";
    }
    RLConsumables.SwapHealth(player, ladder, wanted);
    return RLQuality.DisplayName(RLQuality.StepOfRecord(ladder[wanted]));
  }

  // One ladder step up, but never past `maxStep` (drops from elites and bosses).
  // Returns the new item's quality name, or "" when nothing changed.
  public static func UpgradeHealthOnce(player: ref<PlayerPuppet>, maxStep: Int32) -> String {
    let ladder = RLConsumables.HealthLadder();
    let next = RLConsumables.CurrentHealthIndex(player, ladder) + 1;
    if next <= 0 || next >= ArraySize(ladder) || RLQuality.StepOfRecord(ladder[next]) > maxStep {
      return "";
    }
    let system = RogueliteSystem.Get(player.GetGame());
    if IsDefined(system) {
      system.ExpectGrant(ladder[next]);
    }
    RLConsumables.SwapHealth(player, ladder, next);
    return RLQuality.DisplayName(RLQuality.StepOfRecord(ladder[next]));
  }

  private static func SwapHealth(player: ref<PlayerPuppet>, ladder: array<TweakDBID>, index: Int32) {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    for id in ladder {
      let itemID = ItemID.FromTDBID(id);
      let quantity = transactionSystem.GetItemQuantity(player, itemID);
      if quantity > 0 {
        transactionSystem.RemoveItem(player, itemID, quantity);
      }
    }
    RLGear.GiveAndEquip(player, ladder[index]);
  }

  // Highest ladder entry at or below the step (the lowest one if none is).
  private static func IndexForStep(ladder: array<TweakDBID>, step: Int32) -> Int32 {
    let best = 0;
    let i = 0;
    while i < ArraySize(ladder) {
      if RLQuality.StepOfRecord(ladder[i]) <= step {
        best = i;
      }
      i += 1;
    }
    return best;
  }

  // --- Grenades ------------------------------------------------------------------------

  // Every grenade record, or one family's ("Frag", "EMP", "Incendiary"...).
  public static func GrenadeRecords(opt family: String) -> array<TweakDBID> {
    let names = [
      "FragRegular", "FragCommonPlus", "FragUncommon", "FragUncommonPlus", "FragRarePlus", "FragEpic", "FragEpicPlus", "FragLegendary", "FragLegendaryPlus", "FragSticky",
      "EMPRegular", "EMPCommonPlus", "EMPUncommon", "EMPUncommonPlus", "EMPRare", "EMPRarePlus", "EMPEpicPlus", "EMPLegendary", "EMPLegendaryPlus", "EMPSticky",
      "IncendiaryRegular", "IncendiaryUncommonPlus", "IncendiaryRare", "IncendiaryRarePlus", "IncendiaryEpicPlus", "IncendiaryLegendary", "IncendiaryLegendaryPlus", "IncendiarySticky",
      "BiohazardRegular", "BiohazardRarePlus", "BiohazardEpicPlus", "BiohazardLegendary", "BiohazardLegendaryPlus", "BiohazardHoming",
      "FlashRegular", "FlashCommonPlus", "FlashUncommon", "FlashUncommonPlus", "FlashRarePlus", "FlashEpic", "FlashEpicPlus", "FlashLegendary", "FlashLegendaryPlus", "FlashHoming"
    ];
    let result: array<TweakDBID>;
    for name in names {
      let id = TDBID.Create("Items.Grenade" + name);
      if (StrLen(family) == 0 || StrBeginsWith(name, family)) && IsDefined(TweakDBInterface.GetItemRecord(id)) {
        ArrayPush(result, id);
      }
    }
    return result;
  }

  // A grenade of about the wanted quality (closest available), any type.
  public static func PickGrenade(step: Int32, exclude: array<TweakDBID>) -> TweakDBID {
    let all = RLConsumables.GrenadeRecords();
    let distance = 0;
    while distance <= RLQuality.MaxStep() {
      let matches: array<TweakDBID>;
      for id in all {
        if !ArrayContains(exclude, id) && Abs(RLQuality.StepOfRecord(id) - step) == distance {
          ArrayPush(matches, id);
        }
      }
      if ArraySize(matches) > 0 {
        return matches[RandRange(0, ArraySize(matches))];
      }
      distance += 1;
    }
    return TDBID.None();
  }

  // A grenade of one family ("Frag", "EMP"...) close to the wanted quality.
  public static func PickGrenadeOfFamily(const family: String, step: Int32) -> TweakDBID {
    let best = TDBID.None();
    let bestDistance = 99;
    for id in RLConsumables.GrenadeRecords(family) {
      let distance = Abs(RLQuality.StepOfRecord(id) - step);
      if distance < bestDistance {
        best = id;
        bestDistance = distance;
      }
    }
    return best;
  }

  // The grenade V carries, or none.
  public static func CurrentGrenade(player: ref<PlayerPuppet>) -> TweakDBID {
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && Equals(RPGManager.GetItemType(item.GetID()), gamedataItemType.Gad_Grenade) {
        return ItemID.GetTDBID(item.GetID());
      }
    }
    return TDBID.None();
  }

  // One grenade type at a time: the new one replaces whatever V carried.
  public static func SetGrenade(player: ref<PlayerPuppet>, record: TweakDBID) {
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    for item in items {
      if IsDefined(item) && Equals(RPGManager.GetItemType(item.GetID()), gamedataItemType.Gad_Grenade) {
        transactionSystem.RemoveItem(player, item.GetID(), item.GetQuantity());
      }
    }
    RLGear.GiveAndEquip(player, record);
    ConsumablesChargesHelper.RefreshAllCharges(player.GetGame(), gamedataStatPoolType.GrenadesCharges);
  }

  // --- Helpers -------------------------------------------------------------------------

  private static func InsertByQuality(out list: array<TweakDBID>, id: TweakDBID) {
    let step = RLQuality.StepOfRecord(id);
    let i = 0;
    while i < ArraySize(list) && RLQuality.StepOfRecord(list[i]) <= step {
      i += 1;
    }
    ArrayInsert(list, i, id);
  }
}

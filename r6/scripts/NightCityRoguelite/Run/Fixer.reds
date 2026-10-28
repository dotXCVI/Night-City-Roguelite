// -----------------------------------------------------------------------------
// Night City Roguelite - the Fixer
// -----------------------------------------------------------------------------
// A shop stop after every elite floor, before the boss door (Hades' Charon,
// Gunfire Reborn's peddler): eddies earned in the run buy one of each stock
// item. Eddies come from every cleared arena (more for heavy fights and
// bosses, half again for hot doors); they are wiped with the rest of the gear
// when the run ends.
//
//   MaxDoc upgrade, a better grenade, an effect from one of the run's
//   patrons, a perk card, a Tune-Up and a weapon effect for the main weapon,
//   and a fixer contact (two free rerolls).
//
// The Fixer also buys back gear V carries but doesn't use (weapons and
// cyberware that aren't equipped) - Cyberpunk's card removal.
//
// Prices scale with the floor; Street Smart (the terminal) takes 15% or 30%
// off.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLFixerItem {
  public let offer: ref<RLOffer>;
  public let contact: Bool;
  public let price: Int32;
  public let sold: Bool;
  // Buy-back: the item V sells (the price is what the Fixer pays).
  public let sell: Bool;
  public let sellItem: ItemID;
  public let sellName: String;
}

public abstract class RLFixer {
  public static func MoneyID() -> ItemID = ItemID.FromTDBID(t"Items.money")

  // Eddies for a cleared arena.
  public static func ArenaEddies(run: ref<RLRunState>) -> Int32 {
    let base = Cast<Float>(100 + 40 * run.Depth());
    // Half again on a hot door; Skim (the terminal) skims 20% on top.
    let scale = (run.IsHotFight() ? 1.5 : 1.0) * (RLTerminal.Has(n"Skim", 1) ? 1.2 : 1.0);
    return RoundF(base * scale) + (run.IsBossFloor() ? 400 : 0);
  }

  public static func Balance(player: ref<PlayerPuppet>) -> Int32 {
    return GameInstance.GetTransactionSystem(player.GetGame()).GetItemQuantity(player, RLFixer.MoneyID());
  }

  public static func Stock(player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> array<ref<RLFixerItem>> {
    let stock: array<ref<RLFixerItem>>;
    let depth = run.Depth();
    let profile = RLBuildProfile.Read(player);
    RLFixer.AddItem(stock, run, RLRewards.HealthUpgradeOffer(player), 250 + 50 * depth);
    let grenade = RLRewards.GrenadeUpgradeOffer(player);
    if !IsDefined(grenade) {
      grenade = RLRewards.BuildOffer(player, pools, run, RLOfferKind.Grenade, profile, false);
    }
    RLFixer.AddItem(stock, run, grenade, 300 + 60 * depth);
    let effect = RLRewards.AnyBoonOffer(player, run);
    RLFixer.AddItem(stock, run, effect, 350 + 50 * depth);
    // Made Man (the terminal): a second effect on the shelf.
    if RLTerminal.Has(n"StreetSmart", 2) && IsDefined(effect) {
      let tries = 0;
      while tries < 4 {
        let second = RLRewards.AnyBoonOffer(player, run);
        if IsDefined(second) && NotEquals(second.boon, effect.boon) {
          RLFixer.AddItem(stock, run, second, 350 + 50 * depth);
          tries = 4;
        }
        tries += 1;
      }
    }
    let none: array<gamedataNewPerkType>;
    let perks = RLPerkCatalog.Pick(player, run, profile, 1, 0, none);
    if ArraySize(perks) > 0 {
      RLFixer.AddItem(stock, run, RLRewards.PerkOffer(run, perks[0]), 500 + 80 * depth);
    }
    RLFixer.AddItem(stock, run, RLRewards.TuneUpOffer(player, run, 2), 450 + 70 * depth);
    // One weapon effect on the shelf at most: the main weapon may have room
    // for only one.
    let effectDef = IsDefined(effect) ? RLBoons.Get(effect.boon) : null;
    if !IsDefined(effectDef) || NotEquals(effectDef.kind, RLBoonKind.Weapon) {
      RLFixer.AddItem(stock, run, RLFixer.WeaponEffectOffer(player, run), 400 + 60 * depth);
    }
    let contact = new RLFixerItem();
    contact.contact = true;
    contact.price = RLFixer.Discounted(run, 400 + 40 * depth);
    ArrayPush(stock, contact);
    RLFixer.AddBuyBacks(stock, player);
    return stock;
  }

  // A weapon effect for the main weapon from one of the run's patrons, or none.
  private static func WeaponEffectOffer(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> ref<RLOffer> {
    let candidates: array<ref<RLBoonDef>>;
    for def in RLBoons.All() {
      if Equals(def.kind, RLBoonKind.Weapon) && ArrayContains(run.patrons, def.patron) && RLBoons.IsOfferable(run, def) && ItemID.IsValid(run.mainWeapon) {
        ArrayPush(candidates, def);
      }
    }
    return ArraySize(candidates) > 0 ? RLRewards.BoonOffer(run, candidates[RandRange(0, ArraySize(candidates))]) : null;
  }

  // Weapons and cyberware V carries without using them, up to three.
  private static func AddBuyBacks(out stock: array<ref<RLFixerItem>>, player: ref<PlayerPuppet>) {
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    let count = 0;
    for item in items {
      if IsDefined(item) && IsDefined(equipment) && count < 3 && !equipment.IsEquipped(item.GetID()) {
        let itemID = item.GetID();
        let isGear = RLWeapons.IsRealWeapon(itemID) || (Equals(RPGManager.GetItemCategory(itemID), gamedataItemCategory.Cyberware) && RLTweakPools.IsCyberwareArea(EquipmentSystem.GetEquipAreaType(itemID)));
        if isGear {
          let entry = new RLFixerItem();
          entry.sell = true;
          entry.sellItem = itemID;
          entry.sellName = RLRewards.ItemName(ItemID.GetTDBID(itemID));
          entry.price = 80 + 40 * RLRewards.ItemStep(item);
          ArrayPush(stock, entry);
          count += 1;
        }
      }
    }
  }

  // Buys an item: pays, grants, marks it sold. False when it can't be bought.
  public static func Buy(player: ref<PlayerPuppet>, run: ref<RLRunState>, item: ref<RLFixerItem>) -> Bool {
    if item.sell {
      // The Fixer's list was made when the screen opened: the item must
      // still be there, and still unused.
      let transactions = GameInstance.GetTransactionSystem(player.GetGame());
      let equipment = EquipmentSystem.GetData(player);
      if item.sold || !transactions.HasItem(player, item.sellItem) || (IsDefined(equipment) && equipment.IsEquipped(item.sellItem))
        || !transactions.RemoveItem(player, item.sellItem, 1) {
        return false;
      }
      RLGear.GiveEddies(player, item.price);
      item.sold = true;
      RLLog(s"Fixer: bought back \(item.sellName) for \(item.price).");
      return true;
    }
    if item.sold || RLFixer.Balance(player) < item.price || !item.contact && !RLRewards.StillGrantable(run, item.offer) {
      return false;
    }
    GameInstance.GetTransactionSystem(player.GetGame()).RemoveItem(player, RLFixer.MoneyID(), item.price);
    if item.contact {
      run.rerolls += 2;
      RLLog("Fixer: contact bought (+2 rerolls).");
    } else {
      RLRewards.Grant(player, run, item.offer);
    }
    item.sold = true;
    return true;
  }

  public static func ItemTitle(item: ref<RLFixerItem>) -> String {
    if item.sell {
      return item.sellName;
    }
    return item.contact ? "Fixer Contact" : item.offer.title;
  }

  public static func ItemSubtitle(item: ref<RLFixerItem>) -> String {
    if item.sell {
      return "SELL BACK";
    }
    return item.contact ? "SERVICE" : item.offer.subtitle;
  }

  public static func ItemDescription(item: ref<RLFixerItem>) -> String {
    if item.sell {
      return "You carry it but don't use it.";
    }
    return item.contact ? "Two free rerolls." : item.offer.description;
  }

  private static func AddItem(out stock: array<ref<RLFixerItem>>, run: ref<RLRunState>, offer: ref<RLOffer>, price: Int32) {
    if !IsDefined(offer) {
      return;
    }
    let item = new RLFixerItem();
    item.offer = offer;
    item.price = RLFixer.Discounted(run, price);
    ArrayPush(stock, item);
  }

  // Street Smart: 15% off (Haggler), 30% (Made Man).
  public static func Discounted(run: ref<RLRunState>, price: Int32) -> Int32 {
    let scale = RLTerminal.Has(n"StreetSmart", 2) ? 0.7 : (RLTerminal.Has(n"StreetSmart", 1) ? 0.85 : 1.0);
    return RoundF(Cast<Float>(price) * scale);
  }
}

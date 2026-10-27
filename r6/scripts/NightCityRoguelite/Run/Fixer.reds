// -----------------------------------------------------------------------------
// Night City Roguelite - the Fixer
// -----------------------------------------------------------------------------
// A shop stop after every elite floor, before the boss door (Hades' Charon,
// Gunfire Reborn's peddler): eddies earned in the run buy one of each stock
// item. Eddies come from every cleared arena (more for heavy fights and
// bosses) and the Bounty Hunter boon; they are wiped with the rest of the
// gear when the run ends.
//
//   MaxDoc upgrade, a better grenade, a boon, a perk card, an upgrade for the
//   equipped weapon, and a fixer contact (two free rerolls).
//
// Prices scale with the floor; the Street Smart unlock takes 20% off, and the
// Fixer's Cut boon more.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLFixerItem {
  public let offer: ref<RLOffer>;
  public let contact: Bool;
  public let price: Int32;
  public let sold: Bool;
}

public abstract class RLFixer {
  public static func MoneyID() -> ItemID = ItemID.FromTDBID(t"Items.money")

  // Eddies for a cleared arena.
  public static func ArenaEddies(run: ref<RLRunState>) -> Int32 {
    let base = Cast<Float>(100 + 40 * run.Depth());
    let threat = run.Threat();
    let scale = threat <= 1 ? 0.75 : (threat >= 3 ? 1.4 : 1.0);
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
      grenade = RLRewards.BuildOffer(player, pools, run, RLOfferKind.Grenade, 2, profile, false);
    }
    RLFixer.AddItem(stock, run, grenade, 300 + 60 * depth);
    RLFixer.AddItem(stock, run, RLRewards.BuildOffer(player, pools, run, RLOfferKind.Boon, 2, profile, false), 350 + 50 * depth);
    let none: array<gamedataNewPerkType>;
    let perks = RLPerkCatalog.Pick(player, run, profile, 1, false, none);
    if ArraySize(perks) > 0 {
      RLFixer.AddItem(stock, run, RLRewards.PerkOffer(run, perks[0]), 500 + 80 * depth);
    }
    let weapons = RLRewards.WeaponUpgradeOffers(player, 1);
    if ArraySize(weapons) > 0 {
      RLFixer.AddItem(stock, run, weapons[0], 450 + 70 * depth);
    }
    let contact = new RLFixerItem();
    contact.contact = true;
    contact.price = RLFixer.Discounted(run, 400 + 40 * depth);
    ArrayPush(stock, contact);
    return stock;
  }

  // Buys an item: pays, grants, marks it sold. False when it can't be bought.
  public static func Buy(player: ref<PlayerPuppet>, run: ref<RLRunState>, item: ref<RLFixerItem>) -> Bool {
    if item.sold || RLFixer.Balance(player) < item.price {
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
    return item.contact ? "Fixer Contact" : item.offer.title;
  }

  public static func ItemSubtitle(item: ref<RLFixerItem>) -> String {
    return item.contact ? "SERVICE" : item.offer.subtitle;
  }

  public static func ItemDescription(item: ref<RLFixerItem>) -> String {
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

  public static func Discounted(run: ref<RLRunState>, price: Int32) -> Int32 {
    let scale = 1.0 - RLBoons.Value(run, n"FixersCut") / 100.0;
    if RLMeta.PerkActive(RogueliteService.Get(), n"perk.StreetSmart") {
      scale *= 0.8;
    }
    return RoundF(Cast<Float>(price) * scale);
  }
}

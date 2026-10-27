// -----------------------------------------------------------------------------
// Night City Roguelite - events
// -----------------------------------------------------------------------------
// A "?" door is a stop without a fight (Hades' chaos gates and wells, Slay the
// Spire's ? rooms): one screen, one choice, then the next doors. It counts as
// a floor and is followed by a level-up.
//
//   RIPPERDOC   a back-alley clinic: a free MaxDoc patch-up, or paid chrome
//   BOOKIE      double or nothing with eddies, or trade a boon for an Epic one
//   TAROT       Misty reads three cards - each a blessing with a price
//   STRANGER    an iconic weapon that makes V a target, or sell a boon
//               (Act 2 on)
//
// Prices and trade-offs are fixed when the screen opens (RLEventChoice), so
// what the card says is what happens.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLEventChoice {
  public let id: CName;
  public let title: String;
  public let kicker: String;
  public let text: String;
  public let price: Int32;
  public let disabled: Bool;
  public let accent: CName;
  // What the choice hands out, fixed up front (an offer, a boon to lose).
  public let offer: ref<RLOffer>;
  public let boon: CName;
}

public class RLEvent {
  public let id: CName;
  public let title: String;
  public let flavor: String;
  public let choices: array<ref<RLEventChoice>>;
}

public abstract class RLEvents {
  // The stranger's iconic is the one iconic that isn't earned by evolving a
  // weapon, so he only shows up from Act 2.
  public static func Pick(run: ref<RLRunState>) -> CName {
    let events = [n"Ripperdoc", n"Bookie", n"Tarot"];
    if run.act >= 2 {
      ArrayPush(events, n"Stranger");
    }
    return events[RandRange(0, ArraySize(events))];
  }

  public static func Title(id: CName) -> String {
    switch id {
      case n"Ripperdoc": return "BACK-ALLEY RIPPERDOC";
      case n"Bookie": return "THE BOOKIE";
      case n"Tarot": return "MISTY'S READING";
      case n"Stranger": return "A STRANGER'S OFFER";
    }
    return "?";
  }

  // --- Building ----------------------------------------------------------------------------

  public static func Build(id: CName, player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> ref<RLEvent> {
    let event = new RLEvent();
    event.id = id;
    event.title = RLEvents.Title(id);
    let depth = run.Depth();
    let eddies = RLFixer.Balance(player);
    switch id {
      case n"Ripperdoc":
        event.flavor = "Cash only. No questions.";
        let patch = RLEvents.Choice(n"Patch", "Patch Job", "FREE", "Upgrade your MaxDoc.", 0, n"MainColors.Green");
        patch.offer = RLRewards.HealthUpgradeOffer(player);
        if !IsDefined(patch.offer) {
          patch.text = "Patch you up. Your MaxDoc is as good as it gets.";
        }
        ArrayPush(event.choices, patch);
        let chrome = RLEvents.Choice(n"Chrome", "Street Chrome", "", "", RLFixer.Discounted(run, 300 + 40 * depth), n"MainColors.Blue");
        chrome.offer = RLRewards.BuildOffer(player, pools, run, RLOfferKind.Cyberware, 3, null, true);
        if IsDefined(chrome.offer) {
          chrome.title = chrome.offer.title;
          chrome.text = chrome.offer.subtitle + ". " + chrome.offer.description + ".";
          chrome.disabled = chrome.offer.disabled;
        } else {
          chrome.text = "Nothing in stock that fits you.";
          chrome.disabled = true;
        }
        ArrayPush(event.choices, chrome);
        ArrayPush(event.choices, RLEvents.Choice(n"Lacing", "Bone Lacing", "", "+10% max health for the rest of the run.", RLFixer.Discounted(run, 200 + 30 * depth), n"MainColors.Gold"));
        break;
      case n"Bookie":
        event.flavor = "Double or nothing, choom.";
        let stake = eddies / 2;
        let bet = RLEvents.Choice(n"Bet", "Bet Half", s"STAKE \(stake)", "Even odds to double your stake.", 0, n"MainColors.Gold");
        bet.price = stake;
        bet.disabled = stake < 50;
        ArrayPush(event.choices, bet);
        let swap = RLEvents.Choice(n"Swap", "Bet a Boon", "", "Lose a random boon. Win an Epic one.", 0, n"MainColors.Purple");
        swap.boon = RLBoons.RandomOwned(run, false);
        swap.disabled = !IsNameValid(swap.boon);
        if swap.disabled {
          swap.text = "You have no boons to bet.";
        } else {
          swap.kicker = "STAKE " + RLBoons.Get(swap.boon).name;
        }
        ArrayPush(event.choices, swap);
        break;
      case n"Tarot":
        event.flavor = "The cards don't lie. They just don't say everything.";
        let cards = [n"Devil", n"Tower", n"Chariot", n"Magician", n"Death", n"Star", n"Hermit"];
        let i = 0;
        while i < 3 && ArraySize(cards) > 0 {
          let index = RandRange(0, ArraySize(cards));
          let card = RLEvents.TarotCard(cards[index], run);
          if IsDefined(card) {
            ArrayPush(event.choices, card);
            i += 1;
          }
          ArrayErase(cards, index);
        }
        break;
      case n"Stranger":
        event.flavor = "Says it fell off an Arasaka truck.";
        let deal = RLEvents.Choice(n"Iconic", "", "ICONIC", "", 0, n"MainColors.Gold");
        deal.offer = RLRewards.BuildOffer(player, pools, run, RLOfferKind.Iconic, 3, null, true);
        if IsDefined(deal.offer) {
          deal.title = deal.offer.title;
          deal.text = "Yours. But someone wants it back: take 15% more damage for the rest of the run.";
        } else {
          deal.title = "Empty Case";
          deal.text = "He's got nothing for you.";
          deal.disabled = true;
        }
        ArrayPush(event.choices, deal);
        let sell = RLEvents.Choice(n"Sell", "Sell a Boon", "", "", 0, n"MainColors.Purple");
        sell.boon = RLBoons.RandomOwned(run, false);
        if IsNameValid(sell.boon) {
          let owned = RLBoons.Owned(run, sell.boon);
          sell.price = -(300 + 200 * owned.rarity + 20 * depth);
          sell.kicker = s"+\(-sell.price) EDDIES";
          sell.text = "He takes " + RLBoons.Get(sell.boon).name + ".";
        } else {
          sell.text = "You have no boons to sell.";
          sell.disabled = true;
        }
        ArrayPush(event.choices, sell);
        break;
    }
    ArrayPush(event.choices, RLEvents.Choice(n"Leave", "Walk Away", "", "", 0, n"MainColors.Grey"));
    // Prices V can't pay grey the card out.
    for choice in event.choices {
      if choice.price > 0 && choice.price > eddies && NotEquals(choice.id, n"Bet") {
        choice.disabled = true;
      }
      if choice.price > 0 && StrLen(choice.kicker) == 0 {
        choice.kicker = s"\(choice.price) EDDIES";
      }
    }
    return event;
  }

  private static func TarotCard(id: CName, run: ref<RLRunState>) -> ref<RLEventChoice> {
    switch id {
      case n"Devil":
        return RLEvents.Choice(id, "The Devil", "", s"+\(800 + 60 * run.Depth()) eddies. Take 10% more damage for the rest of the run.", 0, n"MainColors.Red");
      case n"Tower":
        if !IsNameValid(RLBoons.RandomOwned(run, true)) {
          return null;
        }
        return RLEvents.Choice(id, "The Tower", "", "Two of your boons rise a rarity. -15% max health.", 0, n"MainColors.Purple");
      case n"Chariot":
        return RLEvents.Choice(id, "The Chariot", "", "+12% movement speed. Take 10% more damage.", 0, n"MainColors.Yellow");
      case n"Magician":
        return RLEvents.Choice(id, "The Magician", "", "+4 max RAM. -15% max health.", 0, n"MainColors.Green");
      case n"Death":
        if run.offerCount >= 5 || ArraySize(run.boons) == 0 {
          return null;
        }
        let death = RLEvents.Choice(id, "Death", "", "", 0, n"MainColors.Red");
        death.boon = RLBoons.RandomOwned(run, false);
        death.text = "Lose " + RLBoons.Get(death.boon).name + ". Every reward screen shows one more option.";
        return death;
      case n"Star":
        return RLEvents.Choice(id, "The Star", "", "+2 free rerolls.", 0, n"MainColors.Blue");
      case n"Hermit":
        return RLEvents.Choice(id, "The Hermit", "", "+2 levels.", 0, n"MainColors.ActiveWhite");
    }
    return null;
  }

  private static func Choice(id: CName, const title: String, const kicker: String, const text: String, price: Int32, accent: CName) -> ref<RLEventChoice> {
    let choice = new RLEventChoice();
    choice.id = id;
    choice.title = title;
    choice.kicker = kicker;
    choice.text = text;
    choice.price = price;
    choice.accent = accent;
    return choice;
  }

  // --- Resolving ---------------------------------------------------------------------------

  // Carries out a choice; returns the line shown afterwards.
  public static func Resolve(choice: ref<RLEventChoice>, player: ref<PlayerPuppet>, pools: ref<RLTweakPools>, run: ref<RLRunState>) -> String {
    let transactions = GameInstance.GetTransactionSystem(player.GetGame());
    if choice.price > 0 {
      transactions.RemoveItem(player, RLFixer.MoneyID(), choice.price);
    }
    switch choice.id {
      case n"Patch":
        RLCharacterReset.HealFull(player);
        if IsDefined(choice.offer) {
          RLRewards.Grant(player, run, choice.offer);
          return choice.offer.title + " installed.";
        }
        return "Patched up.";
      case n"Chrome":
        RLRewards.Grant(player, run, choice.offer);
        return choice.offer.title + " installed.";
      case n"Lacing":
        RLEvents.AddRunMod(player, run, gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, 0.10);
        return "Bone lacing set. +10% max health.";
      case n"Bet":
        if RandF() < 0.5 {
          RLGear.GiveEddies(player, choice.price * 2);
          return s"You win! +\(choice.price) eddies.";
        }
        return s"House wins. -\(choice.price) eddies.";
      case n"Swap":
        let lost = RLBoons.Get(choice.boon).name;
        RLBoons.Remove(player, run, choice.boon);
        let prize = RLRewards.BoonOffers(run, RLPatrons.PickForDoor(run), 3, 1, false);
        if ArraySize(prize) == 0 {
          return lost + " is gone.";
        }
        RLBoons.Apply(player, run, prize[0].boon, Max(prize[0].rarity, 2));
        return lost + " for " + prize[0].title + ".";
      case n"Devil":
        RLGear.GiveEddies(player, 800 + 60 * run.Depth());
        run.damageTakenBonus += 0.10;
        return "The Devil pays.";
      case n"Tower":
        RLBoons.UpgradeRandom(player, run, 2);
        RLEvents.AddRunMod(player, run, gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, -0.15);
        return "The Tower falls. Your boons rise.";
      case n"Chariot":
        RLEvents.AddRunMod(player, run, gamedataStatType.MaxSpeed, gameStatModifierType.AdditiveMultiplier, 0.12);
        run.damageTakenBonus += 0.10;
        return "The Chariot rides.";
      case n"Magician":
        RLEvents.AddRunMod(player, run, gamedataStatType.Memory, gameStatModifierType.Additive, 4.0);
        RLEvents.AddRunMod(player, run, gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, -0.15);
        return "The Magician's trick.";
      case n"Death":
        RLBoons.Remove(player, run, choice.boon);
        run.offerCount = Min(5, run.offerCount + 1);
        return "Death takes, and gives.";
      case n"Star":
        run.rerolls += 2;
        return "The Star shines. +2 rerolls.";
      case n"Hermit":
        PlayerDevelopmentSystem.GetData(player).RL_GrantLevels(2);
        return "The Hermit's wisdom. +2 levels.";
      case n"Iconic":
        RLRewards.Grant(player, run, choice.offer);
        run.damageTakenBonus += 0.15;
        return choice.offer.title + " is yours. Watch your back.";
      case n"Sell":
        RLBoons.Remove(player, run, choice.boon);
        RLGear.GiveEddies(player, -choice.price);
        return s"+\(-choice.price) eddies.";
    }
    return "";
  }

  // A stat change that lasts the rest of the run.
  public static func AddRunMod(player: ref<PlayerPuppet>, run: ref<RLRunState>, stat: gamedataStatType, type: gameStatModifierType, value: Float) {
    let mod = RPGManager.CreateStatModifier(stat, type, value);
    GameInstance.GetStatsSystem(player.GetGame()).AddModifier(Cast<StatsObjectID>(player.GetEntityID()), mod);
    ArrayPush(run.appliedMods, mod);
  }

  public static func RemoveRunMods(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    if IsDefined(player) {
      let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
      for mod in run.appliedMods {
        statsSystem.RemoveModifier(Cast<StatsObjectID>(player.GetEntityID()), mod);
      }
    }
    ArrayClear(run.appliedMods);
  }
}

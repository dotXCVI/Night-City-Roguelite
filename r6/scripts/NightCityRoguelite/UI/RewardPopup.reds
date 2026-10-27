// -----------------------------------------------------------------------------
// Night City Roguelite - reward popup
// -----------------------------------------------------------------------------
// The cleared fight's offers as cards (UI/Card.reds), centred, with the item's
// own icon (or the boon's buff icon, or the perk's tree icon) and a bar in the
// item's quality colour. Weapon cards add their DPS against V's best weapon;
// every card names the styles it feeds (gold when V already has a rank in
// one). Below them: reroll (free while charges last, then eddies), banish
// (one per act: click it, then a card) and, on a door's reward, skip for
// eddies. The footer shows V's styles. Closing (C / ESC) keeps the offers:
// F7 brings them back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLRewardPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_offers: array<ref<RLOffer>>;
  private let m_title: String;
  private let m_fluff: String;
  private let m_content: ref<InGamePopupContent>;
  // Banish mode: the next card clicked is banished instead of taken.
  private let m_banishing: Bool;
  private let m_banishCard: wref<RLCard>;

  // `fluff`: the header's right-hand line (a patron's tagline); "CHOOSE ONE"
  // when empty.
  public static func Open(system: ref<RogueliteSystem>, offers: array<ref<RLOffer>>, const title: String, opt fluff: String) -> ref<RLRewardPopup> {
    let popup = new RLRewardPopup();
    popup.m_system = system;
    popup.m_offers = offers;
    popup.m_title = title;
    popup.m_fluff = fluff;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  // No slow motion behind the menu: a menu that fails to show can never
  // leave the game crawling.
  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnShown() {
    RLLog("Menu shown.");
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1000.0));

    let header = InGamePopupHeader.Create();
    header.SetTitle(this.m_title);
    header.SetFluffRight(StrLen(this.m_fluff) > 0 ? this.m_fluff : "CHOOSE ONE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    let styles = RLStyles.Summary(run, 4);
    footer.SetFluffText(StrLen(styles) > 0 ? "STYLES  " + styles : "STYLES RANK UP AT 3, 6 AND 9 POINTS");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    RLLog(s"Reward menu: building \(ArraySize(this.m_offers)) card(s).");
    this.Build();
  }

  private func Build() {
    let column = RLUI.VPanel(12.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.Reparent(this.m_content.GetRootCompoundWidget());

    let cards = RLUI.HPanel(18.0);
    cards.SetHAlign(inkEHorizontalAlign.Center);
    cards.SetMargin(inkMargin(0.0, 16.0, 0.0, 0.0));
    cards.Reparent(column);

    let count = ArraySize(this.m_offers);
    let cardWidth = count > 4 ? 400.0 : (count > 3 ? 470.0 : 540.0);
    let i = 0;
    while i < count {
      this.BuildCard(cards, this.m_offers[i], i, cardWidth);
      i += 1;
    }

    if IsDefined(this.m_system) {
      let actions = RLUI.HPanel(18.0);
      actions.SetHAlign(inkEHorizontalAlign.Center);
      actions.SetMargin(inkMargin(0.0, 28.0, 0.0, 0.0));
      actions.Reparent(column);
      let reroll = RLRewardPopup.RerollCard(this.m_system);
      reroll.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
      reroll.Reparent(actions);
      reroll.PlayIntro(0.08 * Cast<Float>(count));
      if this.HasBanishable() {
        let banishes = this.m_system.GetBanishes();
        let banish = RLCard.Create(n"banish", 420.0, 120.0, banishes > 0 ? n"MainColors.Red" : n"MainColors.Grey");
        banish.SetCompact();
        banish.SetKicker(s"\(banishes) LEFT THIS ACT");
        banish.SetTitle("BANISH");
        banish.SetTitleSize(36);
        banish.SetDisabled(banishes <= 0);
        banish.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
        banish.Reparent(actions);
        banish.PlayIntro(0.08 * Cast<Float>(count + 1));
        this.m_banishCard = banish;
      }
      if this.m_system.CanSkipReward() {
        let skip = RLCard.Create(n"skip", 420.0, 120.0, n"MainColors.Gold");
        skip.SetCompact();
        skip.SetKicker(s"+\(this.m_system.GetSkipEddies()) EDDIES");
        skip.SetTitle("SKIP");
        skip.SetTitleSize(36);
        skip.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
        skip.Reparent(actions);
        skip.PlayIntro(0.08 * Cast<Float>(count + 2));
      }
    }
  }

  private func HasBanishable() -> Bool {
    for offer in this.m_offers {
      if RLRewards.CanBanish(offer) {
        return true;
      }
    }
    return false;
  }

  // The reroll button used by the reward screen and the door picker.
  public static func RerollCard(system: ref<RogueliteSystem>) -> ref<RLCard> {
    let charges = system.GetRerollCharges();
    let price = system.GetRerollPrice();
    let affordable = charges > 0 || system.GetEddies() >= price;
    let card = RLCard.Create(n"reroll", 420.0, 120.0, charges > 0 ? n"MainColors.Blue" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
    card.SetCompact();
    card.SetKicker(charges > 0 ? s"FREE - \(charges) LEFT" : s"\(price) EDDIES");
    card.SetTitle("REROLL");
    card.SetTitleSize(36);
    card.SetDisabled(!affordable);
    return card;
  }

  private func BuildCard(parent: ref<inkCompoundWidget>, offer: ref<RLOffer>, index: Int32, width: Float) {
    let accent = Equals(offer.kind, RLOfferKind.Boon) && IsNameValid(offer.patron) ? RLPatrons.Accent(offer.patron) : RLRewardPopup.KindAccent(offer.kind);
    let card = RLCard.Create(StringToName("offer_" + IntToString(index)), width, 620.0, accent);
    RLRewardPopup.SetOfferIcon(card, offer, width);
    if RLRewardPopup.HasQuality(offer.kind) {
      card.SetQuality(offer.step);
    }
    card.SetKicker(RLRewardPopup.KindLabel(offer));
    card.SetTitle(offer.title);
    card.SetTitleSize(40);
    if StrLen(offer.dpsLine) > 0 {
      card.AddLine(offer.dpsLine, n"MainColors.Yellow", 28);
    }
    if StrLen(offer.description) > 0 {
      let warning = offer.disabled || (Equals(offer.kind, RLOfferKind.Cyberware) && offer.amount > 0);
      card.AddLine(offer.description, warning ? n"MainColors.Red" : n"MainColors.Grey", 26);
    }
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    let styles = RLStyles.OfferLine(run, offer.tags);
    if StrLen(styles) > 0 {
      card.AddLine(styles, RLStyles.IsSynergy(run, offer.tags) ? n"MainColors.Gold" : n"MainColors.Blue", 24);
    }
    card.SetDisabled(offer.disabled);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
    card.PlayIntro(0.08 * Cast<Float>(index));
  }

  private static func HasQuality(kind: RLOfferKind) -> Bool {
    return NotEquals(kind, RLOfferKind.Perk);
  }

  // The card's kicker: what it is, and its quality (or upgrade step).
  private static func KindLabel(offer: ref<RLOffer>) -> String {
    switch offer.kind {
      case RLOfferKind.WeaponUpgrade:
      case RLOfferKind.HealthUpgrade:
      case RLOfferKind.BoonUpgrade:
        return "UPGRADE - " + offer.subtitle;
    }
    return offer.subtitle;
  }

  // Item icons for gear (weapons are wide), the buff icon for boons, the
  // perk's tree icon for perks, a menu icon for the rest.
  private static func SetOfferIcon(card: ref<RLCard>, offer: ref<RLOffer>, width: Float) {
    switch offer.kind {
      case RLOfferKind.Weapon:
      case RLOfferKind.Iconic:
      case RLOfferKind.WeaponUpgrade:
      case RLOfferKind.WeaponMod:
      case RLOfferKind.Evolve:
        let iconWidth = MinF(width - 56.0, 400.0);
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), iconWidth, iconWidth / 2.0) {
          return;
        }
        break;
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
      case RLOfferKind.HealthUpgrade:
      case RLOfferKind.OperatingSystem:
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), 190.0, 190.0) {
          return;
        }
        break;
      case RLOfferKind.Boon:
      case RLOfferKind.BoonUpgrade:
        if card.SetRecordIcon(RLIcons.BoonIcon(offer.boon), 150.0, 150.0) {
          return;
        }
        RLIcons.SetPatronIcon(card, offer.patron, 120.0);
        return;
      case RLOfferKind.Perk:
        if card.SetRecordIcon(RLPerkCatalog.Icon(offer.perk), 150.0, 150.0) {
          return;
        }
        break;
      default:
        break;
    }
    card.SetAtlasIcon(RLIcons.HubAtlas(), RLRewardPopup.KindPart(offer.kind), 120.0);
  }

  public static func KindAccent(kind: RLOfferKind) -> CName {
    switch kind {
      case RLOfferKind.Weapon: return n"MainColors.Red";
      case RLOfferKind.Iconic: return n"MainColors.Gold";
      case RLOfferKind.Cyberware: return n"MainColors.Blue";
      case RLOfferKind.Quickhack: return n"MainColors.Green";
      case RLOfferKind.Boon: return n"MainColors.Purple";
      case RLOfferKind.Grenade: return n"MainColors.Yellow";
      case RLOfferKind.Perk: return n"MainColors.ActiveWhite";
      case RLOfferKind.WeaponUpgrade:
      case RLOfferKind.HealthUpgrade:
      case RLOfferKind.BoonUpgrade: return n"MainColors.Gold";
      case RLOfferKind.WeaponMod: return n"MainColors.Yellow";
      case RLOfferKind.Evolve: return n"MainColors.Gold";
      case RLOfferKind.Attribute: return n"MainColors.ActiveWhite";
      case RLOfferKind.Capacity: return n"MainColors.Blue";
      case RLOfferKind.OperatingSystem: return n"MainColors.Blue";
      case RLOfferKind.Gig: return n"MainColors.Gold";
    }
    return n"MainColors.ActiveWhite";
  }

  public static func KindPart(kind: RLOfferKind) -> CName {
    switch kind {
      case RLOfferKind.Weapon: return n"ico_inventory";
      case RLOfferKind.Iconic: return n"ico_inventory";
      case RLOfferKind.Cyberware: return n"ico_cyberware";
      case RLOfferKind.Quickhack: return n"ico_deck";
      case RLOfferKind.Boon: return n"ico_tarot";
      case RLOfferKind.Perk: return n"ico_stats";
      case RLOfferKind.WeaponUpgrade: return n"ico_cafting_upgrading";
      case RLOfferKind.HealthUpgrade: return n"ico_cafting_upgrading";
      case RLOfferKind.Grenade: return n"ico_backpack";
      case RLOfferKind.WeaponMod: return n"ico_cafting_upgrading";
      case RLOfferKind.Evolve: return n"ico_cafting_upgrading";
      case RLOfferKind.Attribute: return n"ico_stats";
      case RLOfferKind.Capacity: return n"ico_cyberware";
      case RLOfferKind.OperatingSystem: return n"ico_cyberware";
      case RLOfferKind.Gig: return n"ico_journal";
    }
    return n"ico_map";
  }

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() || !IsDefined(this.m_system) {
      return false;
    }
    let name = NameToString(button.GetName());
    if Equals(name, "reroll") {
      this.Close();
      this.m_system.OnRewardReroll();
      return true;
    }
    if Equals(name, "skip") {
      this.Close();
      this.m_system.OnRewardSkip();
      return true;
    }
    if Equals(name, "banish") {
      this.m_banishing = !this.m_banishing;
      if IsDefined(this.m_banishCard) {
        this.m_banishCard.SetSelected(this.m_banishing);
        this.m_banishCard.SetKicker(this.m_banishing ? "NOW PICK A CARD" : s"\(this.m_system.GetBanishes()) LEFT THIS ACT");
      }
      return true;
    }
    if StrBeginsWith(name, "offer_") {
      let index = StringToInt(StrAfterFirst(name, "_"));
      if this.m_banishing {
        if index >= 0 && index < ArraySize(this.m_offers) && RLRewards.CanBanish(this.m_offers[index]) {
          this.Close();
          this.m_system.OnRewardBanish(index);
        }
        return true;
      }
      this.Close();
      this.m_system.OnRewardChosen(index);
      return true;
    }
    return false;
  }

  protected cb func OnHide() {
    super.OnHide();
    if IsDefined(this.m_system) {
      this.m_system.OnPopupClosed();
    }
  }
}

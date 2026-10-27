// -----------------------------------------------------------------------------
// Night City Roguelite - reward popup
// -----------------------------------------------------------------------------
// The cleared fight's offers as cards (UI/Card.reds), centred, with the item's
// own icon (or the boon's buff icon, or the perk's tree icon) and a bar in the
// item's quality colour. Below them a reroll: free while charges last, then
// eddies. Closing (C / ESC) keeps the offers: F7 brings them back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLRewardPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_offers: array<ref<RLOffer>>;
  private let m_title: String;
  private let m_content: ref<InGamePopupContent>;

  public static func Open(system: ref<RogueliteSystem>, offers: array<ref<RLOffer>>, const title: String) -> ref<RLRewardPopup> {
    let popup = new RLRewardPopup();
    popup.m_system = system;
    popup.m_offers = offers;
    popup.m_title = title;
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
    header.SetFluffRight("CHOOSE ONE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("EVERY PICK ALSO GRANTS +1 LEVEL");
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
    }
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
    let card = RLCard.Create(StringToName("offer_" + IntToString(index)), width, 560.0, accent);
    RLRewardPopup.SetOfferIcon(card, offer, width);
    if RLRewardPopup.HasQuality(offer.kind) {
      card.SetQuality(offer.step);
    }
    card.SetKicker(RLRewardPopup.KindLabel(offer));
    card.SetTitle(offer.title);
    card.SetTitleSize(40);
    if StrLen(offer.description) > 0 {
      card.AddLine(offer.description, offer.disabled ? n"MainColors.Red" : n"MainColors.Grey", 26);
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
        let iconWidth = MinF(width - 56.0, 400.0);
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), iconWidth, iconWidth / 2.0) {
          return;
        }
        break;
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
      case RLOfferKind.HealthUpgrade:
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), 190.0, 190.0) {
          return;
        }
        break;
      case RLOfferKind.Boon:
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
      case RLOfferKind.HealthUpgrade: return n"MainColors.Gold";
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
    if StrBeginsWith(name, "offer_") {
      let index = StringToInt(StrAfterFirst(name, "_"));
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

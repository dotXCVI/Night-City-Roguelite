// -----------------------------------------------------------------------------
// Night City Roguelite - reward popup
// -----------------------------------------------------------------------------
// Shows the floor's offers as cards (UI/Card.reds) with the item's own icon,
// the boon's buff icon, or a menu icon. ESC does not discard the reward:
// "Later" (or ESC) just closes the popup, and the computer or F7 reopens it.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLRewardPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_offers: array<ref<RLOffer>>;
  private let m_title: String;
  private let m_rerollsLeft: Int32;
  private let m_content: ref<InGamePopupContent>;

  public static func Open(system: ref<RogueliteSystem>, offers: array<ref<RLOffer>>, const title: String, rerollsLeft: Int32) -> ref<RLRewardPopup> {
    let popup = new RLRewardPopup();
    popup.m_system = system;
    popup.m_offers = offers;
    popup.m_title = title;
    popup.m_rerollsLeft = rerollsLeft;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  // No slow motion behind the menu: nothing is going on at home, and a menu
  // that fails to show can never leave the game crawling.
  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnShown() {
    RLLog("Menu shown.");
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1200.0));

    let header = InGamePopupHeader.Create();
    header.SetTitle(this.m_title);
    header.SetFluffRight("NIGHT CITY ROGUELITE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("PICK ONE - EVERY PICK ALSO GRANTS +1 LEVEL - F7 REOPENS THIS SCREEN");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    RLLog(s"Reward menu: building \(ArraySize(this.m_offers)) card(s).");
    this.Build();
    RLLog("Reward menu: built.");
  }

  private func Build() {
    let root = this.m_content.GetRootCompoundWidget();

    let column = RLUI.VPanel(10.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.Reparent(root);

    let cards = RLUI.HPanel(14.0);
    cards.Reparent(column);

    let count = ArraySize(this.m_offers);
    let cardWidth = count > 0 ? MinF(560.0, 2040.0 / Cast<Float>(count) - 28.0) : 560.0;
    let i = 0;
    while i < count {
      this.BuildCard(cards, this.m_offers[i], i, cardWidth);
      i += 1;
    }

    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 24.0, 0.0, 0.0));
    actions.Reparent(column);

    if this.m_rerollsLeft > 0 {
      this.AddAction(actions, n"reroll", "REROLL", s"\(this.m_rerollsLeft) left this floor", n"MainColors.Gold");
    }
    this.AddAction(actions, n"later", "LATER", "Keep the reward for now", n"MainColors.Blue");
  }

  private func AddAction(parent: ref<inkCompoundWidget>, name: CName, const title: String, const kicker: String, accent: CName) {
    let card = RLCard.Create(name, 520.0, 140.0, accent);
    card.SetCompact();
    card.SetKicker(kicker);
    card.SetTitle(title);
    card.SetTitleSize(40);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
  }

  private func BuildCard(parent: ref<inkCompoundWidget>, offer: ref<RLOffer>, index: Int32, width: Float) {
    let accent = RLRewardPopup.KindAccent(offer.kind);
    let card = RLCard.Create(StringToName("offer_" + IntToString(index)), width, 640.0, accent);
    RLRewardPopup.SetOfferIcon(card, offer, width);
    card.SetKicker(offer.subtitle);
    card.SetTitle(offer.title);
    card.SetTitleSize(40);
    card.AddLine(offer.description, n"MainColors.Grey", 26);
    card.SetFooter(offer.disabled ? "Unavailable" : "Take");
    card.SetDisabled(offer.disabled);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
  }

  // Item icons for gear (weapons are wide), the buff icon for boons, a menu
  // icon for the rest.
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
        break;
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
    if !IsDefined(button) || button.IsDisabled() {
      return false;
    }
    let name = NameToString(button.GetName());
    if Equals(name, "later") {
      this.Close();
      return true;
    }
    if Equals(name, "reroll") {
      this.Close();
      if IsDefined(this.m_system) {
        this.m_system.OnRewardReroll();
      }
      return true;
    }
    if StrBeginsWith(name, "offer_") {
      let index = StringToInt(StrAfterFirst(name, "_"));
      this.Close();
      if IsDefined(this.m_system) {
        this.m_system.OnRewardChosen(index);
      }
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

// -----------------------------------------------------------------------------
// Night City Roguelite - reward popup
// -----------------------------------------------------------------------------
// Shows the floor's offers as cards. ESC does not discard the reward: "Later"
// (or ESC) just closes the popup and F7 reopens it.
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

  protected cb func OnCreate() {
    super.OnCreate();

    let header = InGamePopupHeader.Create();
    header.SetTitle(this.m_title);
    header.SetFluffRight("NIGHT CITY ROGUELITE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("PICK ONE - F7 REOPENS THIS SCREEN");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Build();
  }

  private func Build() {
    let root = this.m_content.GetRootCompoundWidget();
    let size = this.m_content.GetSize();

    let column = RLUI.VPanel(14.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.Reparent(root);

    let cards = RLUI.HPanel(18.0);
    cards.Reparent(column);

    let count = ArraySize(this.m_offers);
    let cardWidth = count > 0 ? MinF(440.0, (size.X - 60.0) / Cast<Float>(count) - 36.0) : 440.0;
    let i = 0;
    while i < count {
      this.BuildCard(cards, this.m_offers[i], i, cardWidth);
      i += 1;
    }

    let actions = RLUI.HPanel(18.0);
    actions.SetMargin(inkMargin(0.0, 30.0, 0.0, 0.0));
    actions.Reparent(column);

    if this.m_rerollsLeft > 0 {
      let reroll = RLUI.Button(n"reroll", s"REROLL (\(this.m_rerollsLeft))", 320.0, false);
      reroll.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
      reroll.Reparent(actions);
    }
    let later = RLUI.Button(n"later", "LATER", 320.0, false);
    later.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    later.Reparent(actions);
  }

  private func BuildCard(parent: ref<inkCompoundWidget>, offer: ref<RLOffer>, index: Int32, width: Float) {
    let card = RLUI.VPanel(8.0);
    card.SetWidth(width);
    card.Reparent(parent);

    let subtitle = RLUI.Text(offer.subtitle, 26, Equals(offer.kind, RLOfferKind.Iconic) ? n"MainColors.ActiveYellow" : n"MainColors.Blue");
    subtitle.SetLetterCase(textLetterCase.UpperCase);
    subtitle.Reparent(card);

    let title = RLUI.WrappedText(offer.title, 40, n"MainColors.Red", width);
    title.SetFontStyle(n"Semi-Bold");
    title.Reparent(card);

    let description = RLUI.WrappedText(offer.description, 28, n"MainColors.Grey", width);
    description.Reparent(card);

    let button = RLUI.Button(StringToName("offer_" + IntToString(index)), offer.disabled ? "UNAVAILABLE" : "TAKE", width, offer.disabled);
    button.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    button.Reparent(card);
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

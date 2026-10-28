// -----------------------------------------------------------------------------
// Night City Roguelite - event popup
// -----------------------------------------------------------------------------
// An event door's screen (Run/Events.reds): the event's name, one line of
// flavour, and a card per choice with its price or payout. Closing (C / ESC)
// keeps the event waiting: F7 brings it back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLEventPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_event: ref<RLEvent>;
  private let m_content: ref<InGamePopupContent>;

  public static func Open(system: ref<RogueliteSystem>, event: ref<RLEvent>) -> ref<RLEventPopup> {
    let popup = new RLEventPopup();
    popup.m_system = system;
    popup.m_event = event;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, Equals(this.m_event.id, n"Tarot") ? 1280.0 : 1140.0));

    let header = InGamePopupHeader.Create();
    header.SetFluffLeft("");
    header.SetTitle(this.m_event.title);
    header.SetFluffRight("NO FIGHT");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("COUNTS AS A FLOOR");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);
    this.Build();
  }

  private func Build() {
    let column = RLUI.VPanel(12.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.SetMargin(RLUI.ContentMargin());
    column.Reparent(this.m_content.GetRootCompoundWidget());

    // Who's talking, and what they say.
    let intro = RLUI.HPanel(0.0);
    intro.SetHAlign(inkEHorizontalAlign.Center);
    intro.SetChildMargin(inkMargin(0.0, 0.0, 30.0, 0.0));
    intro.Reparent(column);
    let portrait = RLArts.Image(RLArts.Event(this.m_event.id), 320.0);
    portrait.SetVAlign(inkEVerticalAlign.Center);
    portrait.Reparent(intro);
    let flavor = RLUI.Text("\"" + this.m_event.flavor + "\"", 38, n"MainColors.Blue");
    flavor.SetVAlign(inkEVerticalAlign.Center);
    flavor.Reparent(intro);

    let cards = RLUI.HPanel(18.0);
    cards.SetHAlign(inkEHorizontalAlign.Center);
    cards.SetMargin(inkMargin(0.0, 20.0, 0.0, 0.0));
    cards.Reparent(column);

    let count = ArraySize(this.m_event.choices);
    let width = count > 3 ? 470.0 : 540.0;
    let i = 0;
    while i < count {
      this.BuildCard(cards, this.m_event.choices[i], i, width);
      i += 1;
    }
  }

  private func BuildCard(parent: ref<inkCompoundWidget>, choice: ref<RLEventChoice>, index: Int32, width: Float) {
    let leave = Equals(choice.id, n"Leave");
    let tarot = Equals(this.m_event.id, n"Tarot");
    let card = RLCard.Create(StringToName("choice_" + IntToString(index)), width, leave ? 300.0 : (tarot ? 640.0 : 500.0), choice.accent);
    if tarot && !leave {
      // Misty's own deck.
      card.SetRecordIcon(TDBID.Create("UIIcon.TarotCard_" + NameToString(choice.id) + "_BIG"), 190.0, 320.0);
    } else if !leave && !this.SetOfferIcon(card, choice, width) {
      card.SetAtlasIcon(RLIcons.HubAtlas(), RLEventPopup.EventPart(this.m_event.id), 110.0);
    }
    card.SetKicker(choice.kicker);
    card.SetTitle(choice.title);
    card.SetTitleSize(40);
    if StrLen(choice.text) > 0 {
      card.AddLine(choice.text, n"MainColors.Grey", 28);
    }
    if IsDefined(choice.offer) && RLItemText.Wants(choice.offer.kind) {
      RLItemText.AddTo(card, choice.offer.record, n"MainColors.ActiveWhite", 24, 2);
    }
    let affordable = !IsDefined(this.m_system) || this.m_system.GetEventChoiceAffordable(choice);
    if !affordable && !choice.disabled && choice.price > 0 {
      card.AddLine(s"Need \(choice.price) eddies", n"MainColors.Red", 26);
    }
    card.SetDisabled(!affordable);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
    card.PlayIntro(0.08 * Cast<Float>(index));
  }

  // Item choices show the item.
  private func SetOfferIcon(card: ref<RLCard>, choice: ref<RLEventChoice>, width: Float) -> Bool {
    if !IsDefined(choice.offer) || !TDBID.IsValid(choice.offer.record) {
      return false;
    }
    if Equals(choice.offer.kind, RLOfferKind.Iconic) || Equals(choice.offer.kind, RLOfferKind.Trade) {
      let iconWidth = MinF(width - 56.0, 400.0);
      return card.SetRecordIcon(RLIcons.ItemIcon(choice.offer.record), iconWidth, iconWidth / 2.0);
    }
    return card.SetRecordIcon(RLIcons.ItemIcon(choice.offer.record), 170.0, 170.0);
  }

  public static func EventPart(id: CName) -> CName {
    switch id {
      case n"Ripperdoc": return n"ico_cyberware";
      case n"Bookie": return n"ico_money";
      case n"Tarot": return n"ico_tarot";
      case n"Stranger": return n"ico_backpack";
    }
    return n"ico_journal";
  }

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() || !IsDefined(this.m_system) {
      return false;
    }
    let name = NameToString(button.GetName());
    if StrBeginsWith(name, "choice_") {
      let index = StringToInt(StrAfterFirst(name, "_"));
      this.Close();
      this.m_system.OnEventChoice(index);
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

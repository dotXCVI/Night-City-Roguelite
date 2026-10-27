// -----------------------------------------------------------------------------
// Night City Roguelite - Fixer popup
// -----------------------------------------------------------------------------
// The Fixer's stock as cards (UI/Card.reds) with their prices; buying keeps
// the shop open, LEAVE moves on to the boss door. ESC closes it without
// leaving: the computer or F7 brings it back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLFixerPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_content: ref<InGamePopupContent>;
  private let m_header: ref<InGamePopupHeader>;

  public static func Open(system: ref<RogueliteSystem>) -> ref<RLFixerPopup> {
    let popup = new RLFixerPopup();
    popup.m_system = system;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1300.0));

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetFluffRight("NIGHT CITY ROGUELITE");
    this.m_header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("ONE OF EACH - EDDIES ARE EARNED IN ARENAS AND WIPED WHEN THE RUN ENDS");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);
    this.Rebuild();
  }

  private func Rebuild() {
    let player = GetPlayer(GetGameInstance());
    let balance = IsDefined(player) ? RLFixer.Balance(player) : 0;
    this.m_header.SetTitle(s"FIXER - \(balance) EDDIES");

    let root = this.m_content.GetRootCompoundWidget();
    root.RemoveAllChildren();
    let column = RLUI.VPanel(10.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.Reparent(root);
    RLUI.WrappedText("The boss is next. Spend what you earned - the eddies don't survive the run.", 28, n"MainColors.Grey", 2000.0).Reparent(column);

    let stock: array<ref<RLFixerItem>>;
    if IsDefined(this.m_system) {
      stock = this.m_system.GetFixerStock();
    }
    let row: ref<inkHorizontalPanel>;
    let i = 0;
    for item in stock {
      if i % 3 == 0 {
        row = RLUI.HPanel(14.0);
        row.Reparent(column);
      }
      this.AddItemCard(row, item, i, balance);
      i += 1;
    }

    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 18.0, 0.0, 0.0));
    actions.Reparent(column);
    let leave = RLCard.Create(n"leave", 560.0, 140.0, n"MainColors.Red");
    leave.SetCompact();
    leave.SetKicker("On to the boss door");
    leave.SetTitle("LEAVE");
    leave.SetTitleSize(40);
    leave.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    leave.Reparent(actions);
  }

  private func AddItemCard(parent: ref<inkCompoundWidget>, item: ref<RLFixerItem>, index: Int32, balance: Int32) {
    let affordable = !item.sold && balance >= item.price;
    let accent = item.sold ? n"MainColors.Green" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey");
    let card = RLCard.Create(StringToName("item_" + IntToString(index)), 670.0, 330.0, accent);
    card.SetCompact();
    card.SetKicker(item.sold ? "SOLD" : s"\(item.price) EDDIES - " + RLFixer.ItemSubtitle(item));
    card.SetTitle(RLFixer.ItemTitle(item));
    card.SetTitleSize(36);
    card.AddLine(RLFixer.ItemDescription(item), n"MainColors.Grey", 24);
    card.SetDisabled(!affordable);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
  }

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() || !IsDefined(this.m_system) {
      return false;
    }
    let name = NameToString(button.GetName());
    if Equals(name, "leave") {
      this.Close();
      this.m_system.OnFixerLeft();
      return true;
    }
    if StrBeginsWith(name, "item_") {
      if this.m_system.BuyFromFixer(StringToInt(StrAfterFirst(name, "_"))) {
        this.PlaySound(n"Item", n"OnBuy");
      }
      this.Rebuild();
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

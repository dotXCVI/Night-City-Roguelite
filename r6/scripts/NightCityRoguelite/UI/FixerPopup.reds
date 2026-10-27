// -----------------------------------------------------------------------------
// Night City Roguelite - Fixer popup
// -----------------------------------------------------------------------------
// The Fixer's stock as cards (UI/Card.reds). The eddie balance sits on top and
// every card says what it costs: affordable in gold, out of reach in grey with
// how much is missing, bought ones marked SOLD; gear V can sell back is in
// blue with what the Fixer pays. Once nothing else is
// affordable, LEAVE lights up. Closing (C / ESC) doesn't leave: F7 brings the
// Fixer back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLFixerPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_content: ref<InGamePopupContent>;
  private let m_introPlayed: Bool;

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
    this.m_container.SetSize(Vector2(2200.0, 1240.0));

    let header = InGamePopupHeader.Create();
    header.SetTitle("THE FIXER");
    header.SetFluffRight("BOSS NEXT");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("EDDIES DON'T SURVIVE THE RUN");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);
    this.Rebuild();
    this.m_introPlayed = true;
  }

  private func Rebuild() {
    let balance = IsDefined(this.m_system) ? this.m_system.GetEddies() : 0;
    let stock: array<ref<RLFixerItem>>;
    if IsDefined(this.m_system) {
      stock = this.m_system.GetFixerStock();
    }
    let anyAffordable = false;
    for item in stock {
      if !item.sold && !item.sell && balance >= item.price {
        anyAffordable = true;
      }
    }

    let root = this.m_content.GetRootCompoundWidget();
    root.RemoveAllChildren();
    let column = RLUI.VPanel(10.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.Reparent(root);

    let top = RLUI.HPanel(10.0);
    top.SetHAlign(inkEHorizontalAlign.Center);
    top.Reparent(column);
    RLUI.StatTile("EDDIES", IntToString(balance), anyAffordable ? n"MainColors.Gold" : n"MainColors.Red").Reparent(top);

    let rows = RLUI.VPanel(9.0);
    rows.SetHAlign(inkEHorizontalAlign.Center);
    rows.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    rows.Reparent(column);
    let row: ref<inkHorizontalPanel>;
    let i = 0;
    for item in stock {
      if i % 4 == 0 {
        row = RLUI.HPanel(18.0);
        row.SetHAlign(inkEHorizontalAlign.Center);
        row.Reparent(rows);
      }
      this.AddItemCard(row, item, i, balance);
      i += 1;
    }

    let actions = RLUI.HPanel(18.0);
    actions.SetHAlign(inkEHorizontalAlign.Center);
    actions.SetMargin(inkMargin(0.0, 20.0, 0.0, 0.0));
    actions.Reparent(column);
    let leave = RLCard.Create(n"leave", 420.0, 120.0, anyAffordable ? n"MainColors.Blue" : n"MainColors.ActiveYellow");
    leave.SetCompact();
    leave.SetKicker(anyAffordable ? "" : "NOTHING ELSE YOU CAN AFFORD");
    leave.SetTitle("LEAVE");
    leave.SetTitleSize(36);
    leave.SetSelected(!anyAffordable);
    leave.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    leave.Reparent(actions);
    if !this.m_introPlayed {
      leave.PlayIntro(0.06 * Cast<Float>(ArraySize(stock)));
    }
  }

  private func AddItemCard(parent: ref<inkCompoundWidget>, item: ref<RLFixerItem>, index: Int32, balance: Int32) {
    let affordable = !item.sold && (item.sell || balance >= item.price);
    let accent = item.sold ? n"MainColors.Green" : (item.sell ? n"MainColors.Blue" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
    let card = RLCard.Create(StringToName("item_" + IntToString(index)), 500.0, 250.0, accent);
    card.SetCompact();
    if item.sold {
      card.SetKicker("SOLD");
    } else if item.sell {
      card.SetKicker(s"+\(item.price) EDDIES");
    } else if affordable {
      card.SetKicker(s"\(item.price) EDDIES");
    } else {
      card.SetKicker(s"\(item.price) EDDIES - NEED \(item.price - balance) MORE");
    }
    card.SetTitle(RLFixer.ItemTitle(item));
    card.SetTitleSize(34);
    card.AddLine(RLFixer.ItemSubtitle(item), n"MainColors.Blue", 24);
    let description = RLFixer.ItemDescription(item);
    if StrLen(description) > 0 {
      card.AddLine(description, n"MainColors.Grey", 22);
    }
    if !item.contact && !item.sell && IsDefined(item.offer) && item.offer.step > 0 {
      card.SetQuality(item.offer.step);
    }
    card.SetDisabled(!affordable);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
    if !this.m_introPlayed {
      card.PlayIntro(0.06 * Cast<Float>(index));
    }
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

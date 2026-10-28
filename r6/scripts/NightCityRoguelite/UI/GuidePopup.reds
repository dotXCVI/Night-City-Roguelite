// -----------------------------------------------------------------------------
// Night City Roguelite - the guide
// -----------------------------------------------------------------------------
// Six pictures and a line each: everything a new player needs before the
// first run. Shown once, the first time V comes home on a roguelite
// character; the terminal's HOW IT WORKS card brings it back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLGuidePopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_content: ref<InGamePopupContent>;

  public static func Open(system: ref<RogueliteSystem>) -> ref<RLGuidePopup> {
    let popup = new RLGuidePopup();
    popup.m_system = system;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1660.0));

    let header = InGamePopupHeader.Create();
    header.SetFluffLeft("");
    header.SetTitle("NIGHT CITY ROGUELITE");
    header.SetFluffRight("HOW IT WORKS");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("CLOSED A SCREEN? F7 BRINGS IT BACK");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    let column = RLUI.VPanel(9.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.SetMargin(inkMargin(0.0, 6.0, RLUI.ContentInset(), 0.0));
    column.Reparent(this.m_content.GetRootCompoundWidget());

    let top = RLUI.HPanel(9.0);
    top.SetHAlign(inkEHorizontalAlign.Center);
    top.Reparent(column);
    this.AddPage(top, 0, RLArts.Home(), "HOME",
      "Megabuilding H10. The front door stays sealed - runs take you where you need to go. Save in here.");
    this.AddPage(top, 1, RLArts.Terminal(), "TERMINAL",
      "Your desk computer. Start a run, spend Cred on upgrades, check your record.");
    this.AddPage(top, 2, RLArts.Armory(), "ARMORY",
      "The weapon room in the back. Open the stash, pick the kit you walk out with. New kits cost favors - one for every boss you put down.");

    let bottom = RLUI.HPanel(9.0);
    bottom.SetHAlign(inkEHorizontalAlign.Center);
    bottom.Reparent(column);
    this.AddPage(bottom, 3, RLArts.City(), "THE RUN",
      "Three acts, six fights each, a boss to close every act. Pick a door by what it pays, win, take a card. HOT doors pay double.");
    this.AddPage(bottom, 4, RLArts.Patrons(), "PATRONS",
      "Four of six work the city each run. Their effects feed each other: SHOCK, BURN, MARK, BLAST. Three from one earns their favour.");
    this.AddPage(bottom, 5, RLArts.Flatline(), "FLATLINE",
      "Trauma Team picks you up once a run. Go down again and you wake up here with nothing but your Cred and favors.");

    let actions = RLUI.HPanel(0.0);
    actions.SetHAlign(inkEHorizontalAlign.Center);
    actions.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
    actions.Reparent(column);
    let done = RLCard.Create(n"done", 420.0, 120.0, n"MainColors.Red");
    done.SetCompact();
    done.SetKicker("NOW GO");
    done.SetTitle("GOT IT");
    done.SetTitleSize(40);
    done.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    done.Reparent(actions);
    done.PlayIntro(0.42);
  }

  private func AddPage(parent: ref<inkCompoundWidget>, index: Int32, art: RLArt, const title: String, const text: String) {
    let card = RLCard.Create(StringToName(s"page_\(index)"), 640.0, 600.0, n"MainColors.Red");
    card.SetCompact();
    card.SetBanner(art);
    card.SetKicker(s"0\(index + 1)");
    card.SetTitle(title);
    card.SetTitleSize(40);
    card.AddLine(text, n"MainColors.Grey", 26);
    card.SetStatic();
    card.Reparent(parent);
    card.PlayIntro(0.06 * Cast<Float>(index));
  }

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if IsDefined(button) && Equals(button.GetName(), n"done") {
      this.Close();
      return true;
    }
    return false;
  }

  protected cb func OnHide() {
    super.OnHide();
    RogueliteService.Get().MarkGuideSeen();
    if IsDefined(this.m_system) {
      this.m_system.OnPopupClosed();
    }
  }
}

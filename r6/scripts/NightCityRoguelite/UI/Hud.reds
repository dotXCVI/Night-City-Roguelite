// -----------------------------------------------------------------------------
// Night City Roguelite - run HUD
// -----------------------------------------------------------------------------
// Two lines at the top center of the HUD during a run, and a boss bar under
// them while a boss lives:
//   ACT 1 - FLOOR 2
//   WAVE 2/3   HOSTILES 5   KILLS 14
//   ROYCE ======-----
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLHud extends IScriptable {
  private let m_root: wref<inkCanvas>;
  private let m_title: wref<inkText>;
  private let m_status: wref<inkText>;
  private let m_boss: wref<inkVerticalPanel>;
  private let m_bossName: wref<inkText>;
  private let m_bossFill: wref<inkRectangle>;

  public func Show() {
    if this.IsAlive() {
      this.m_root.SetVisible(true);
      return;
    }
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer");
    if !IsDefined(layer) {
      return;
    }
    let window = layer.GetVirtualWindow();
    if !IsDefined(window) {
      return;
    }
    let root = new inkCanvas();
    root.SetName(n"NightCityRogueliteHud");
    root.SetAnchor(inkEAnchor.TopCenter);
    root.SetAnchorPoint(Vector2(0.5, 0.0));
    root.SetMargin(inkMargin(0.0, 40.0, 0.0, 0.0));
    root.SetSize(Vector2(1200.0, 190.0));
    root.Reparent(window);

    let panel = RLUI.VPanel(2.0);
    panel.SetAnchor(inkEAnchor.TopCenter);
    panel.SetAnchorPoint(Vector2(0.5, 0.0));
    panel.Reparent(root);

    let title = RLUI.Text("", 38, n"MainColors.Red", true);
    title.SetHAlign(inkEHorizontalAlign.Center);
    title.SetLetterCase(textLetterCase.UpperCase);
    title.Reparent(panel);

    let status = RLUI.Text("", 30, n"MainColors.Blue");
    status.SetHAlign(inkEHorizontalAlign.Center);
    status.SetLetterCase(textLetterCase.UpperCase);
    status.Reparent(panel);

    let boss = RLUI.VPanel(4.0);
    boss.SetHAlign(inkEHorizontalAlign.Center);
    boss.SetMargin(inkMargin(0.0, 10.0, 0.0, 0.0));
    boss.SetVisible(false);
    boss.Reparent(panel);
    let bossName = RLUI.Text("", 30, n"MainColors.Red", true);
    bossName.SetHAlign(inkEHorizontalAlign.Center);
    bossName.SetLetterCase(textLetterCase.UpperCase);
    bossName.Reparent(boss);
    let track = new inkCanvas();
    track.SetSize(Vector2(RLHud.BarWidth(), 12.0));
    track.SetHAlign(inkEHorizontalAlign.Center);
    track.Reparent(boss);
    let back = new inkRectangle();
    back.SetSize(Vector2(RLHud.BarWidth(), 12.0));
    back.SetTintColor(HDRColor(0.2, 0.05, 0.05, 1.0));
    back.SetOpacity(0.8);
    back.Reparent(track);
    let fill = new inkRectangle();
    fill.SetSize(Vector2(RLHud.BarWidth(), 12.0));
    fill.SetStyle(RLUI.Style());
    fill.BindProperty(n"tintColor", n"MainColors.Red");
    fill.Reparent(track);

    this.m_root = root;
    this.m_title = title;
    this.m_status = status;
    this.m_boss = boss;
    this.m_bossName = bossName;
    this.m_bossFill = fill;
  }

  public static func BarWidth() -> Float = 640.0

  // The boss bar: name and health (percent).
  public func SetBoss(const name: String, health: Float) {
    this.Show();
    if !IsDefined(this.m_boss) {
      return;
    }
    this.m_boss.SetVisible(true);
    this.m_bossName.SetText(name);
    this.m_bossFill.SetSize(Vector2(RLHud.BarWidth() * ClampF(health, 0.0, 100.0) / 100.0, 12.0));
  }

  public func ClearBoss() {
    if IsDefined(this.m_boss) {
      this.m_boss.SetVisible(false);
    }
  }

  public func Hide() {
    if this.IsAlive() {
      this.m_root.SetVisible(false);
    }
  }

  public func Update(const title: String, const status: String) {
    this.Show();
    if IsDefined(this.m_title) {
      this.m_title.SetText(title);
    }
    if IsDefined(this.m_status) {
      this.m_status.SetText(status);
    }
  }

  // Drops widget references at session end; the HUD layer is rebuilt by the game.
  public func Release() {
    if this.IsAlive() {
      let parent = this.m_root.GetParentWidget() as inkCompoundWidget;
      if IsDefined(parent) {
        parent.RemoveChild(this.m_root);
      }
    }
    this.m_root = null;
    this.m_title = null;
    this.m_status = null;
    this.m_boss = null;
    this.m_bossName = null;
    this.m_bossFill = null;
  }

  private func IsAlive() -> Bool {
    return IsDefined(this.m_root) && IsDefined(this.m_root.GetParentWidget());
  }
}

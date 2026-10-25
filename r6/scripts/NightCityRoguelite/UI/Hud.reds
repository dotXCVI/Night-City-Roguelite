// -----------------------------------------------------------------------------
// Night City Roguelite - run HUD
// -----------------------------------------------------------------------------
// One status line at the top center of the HUD during a run:
//   ACT 1 - FLOOR 2   WAVE 2/3   HOSTILES 5   KILLS 14
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLHud extends IScriptable {
  private let m_root: wref<inkCanvas>;
  private let m_title: wref<inkText>;
  private let m_status: wref<inkText>;

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
    root.SetSize(Vector2(1200.0, 110.0));
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

    this.m_root = root;
    this.m_title = title;
    this.m_status = status;
  }

  public func Hide() {
    if this.IsAlive() {
      this.m_root.SetVisible(false);
    }
  }

  public func Update(const title: String, const status: String) {
    if !this.IsAlive() {
      this.Show();
    }
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
  }

  private func IsAlive() -> Bool {
    return IsDefined(this.m_root) && IsDefined(this.m_root.GetParentWidget());
  }
}

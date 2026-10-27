// -----------------------------------------------------------------------------
// Night City Roguelite - transitions
// -----------------------------------------------------------------------------
// A full-screen fade to black with a line of text ("PETROCHEM OFF-LIMITS /
// ACT 1 - FLOOR 3 - VS MILITECH"), used for every trip between home and an
// arena and for V's death. The system teleports V only while the screen is
// black and fades back in once the destination has streamed in, so nothing
// pops in on screen.
//
// The overlay lives on the game-notifications layer (above the HUD, below
// menus) and is built on demand. Durations are owned by the caller, which
// schedules its next step with RLDelay; nothing here calls back.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLTransition extends IScriptable {
  private let m_root: wref<inkCanvas>;
  private let m_title: wref<inkText>;
  private let m_subtitle: wref<inkText>;
  private let m_proxy: ref<inkAnimProxy>;
  private let m_black: Bool;

  // True from the start of a fade-out until the next fade-in.
  public func IsBlack() -> Bool = this.m_black

  public func FadeOut(const title: String, const subtitle: String, seconds: Float) {
    this.m_black = true;
    if !this.Ensure() {
      return;
    }
    this.SetText(title, subtitle);
    this.Animate(1.0, seconds);
  }

  public func FadeIn(seconds: Float) {
    this.m_black = false;
    if this.IsAlive() {
      this.Animate(0.0, seconds);
    }
  }

  public func SetText(const title: String, const subtitle: String) {
    if IsDefined(this.m_title) {
      this.m_title.SetText(title);
    }
    if IsDefined(this.m_subtitle) {
      this.m_subtitle.SetText(subtitle);
    }
  }

  // Session end: the layer is rebuilt by the game.
  public func Release() {
    if this.IsAlive() {
      let parent = this.m_root.GetParentWidget() as inkCompoundWidget;
      if IsDefined(parent) {
        parent.RemoveChild(this.m_root);
      }
    }
    this.m_root = null;
    this.m_title = null;
    this.m_subtitle = null;
    this.m_proxy = null;
    this.m_black = false;
  }

  private func Animate(target: Float, seconds: Float) {
    if IsDefined(this.m_proxy) && this.m_proxy.IsPlaying() {
      this.m_proxy.Stop(true);
    }
    let fade = new inkAnimTransparency();
    fade.SetStartTransparency(this.m_root.GetOpacity());
    fade.SetEndTransparency(target);
    fade.SetDuration(MaxF(seconds, 0.01));
    let animation = new inkAnimDef();
    animation.AddInterpolator(fade);
    this.m_proxy = this.m_root.PlayAnimation(animation);
  }

  private func IsAlive() -> Bool {
    return IsDefined(this.m_root) && IsDefined(this.m_root.GetParentWidget());
  }

  private func Ensure() -> Bool {
    if this.IsAlive() {
      return true;
    }
    let ink = GameInstance.GetInkSystem();
    let layer = ink.GetLayer(n"inkGameNotificationsLayer");
    if !IsDefined(layer) {
      layer = ink.GetLayer(n"inkHUDLayer");
    }
    if !IsDefined(layer) || !IsDefined(layer.GetVirtualWindow()) {
      return false;
    }

    // Larger than any screen, centred, so every aspect ratio is covered.
    let root = new inkCanvas();
    root.SetName(n"NightCityRogueliteTransition");
    root.SetAnchor(inkEAnchor.Centered);
    root.SetAnchorPoint(Vector2(0.5, 0.5));
    root.SetSize(Vector2(10000.0, 6000.0));
    root.SetInteractive(false);
    root.SetOpacity(0.0);
    root.Reparent(layer.GetVirtualWindow());

    let black = new inkRectangle();
    black.SetAnchor(inkEAnchor.Fill);
    black.SetTintColor(HDRColor(0.0, 0.0, 0.0, 1.0));
    black.Reparent(root);

    let panel = RLUI.VPanel(6.0);
    panel.SetAnchor(inkEAnchor.Centered);
    panel.SetAnchorPoint(Vector2(0.5, 0.5));
    panel.Reparent(root);

    let rule = new inkRectangle();
    rule.SetSize(Vector2(120.0, 4.0));
    rule.SetHAlign(inkEHorizontalAlign.Center);
    rule.SetStyle(RLUI.Style());
    rule.BindProperty(n"tintColor", n"MainColors.Red");
    rule.Reparent(panel);

    let title = RLUI.Text("", 72, n"MainColors.Red", true);
    title.SetHAlign(inkEHorizontalAlign.Center);
    title.SetLetterCase(textLetterCase.UpperCase);
    title.Reparent(panel);

    let subtitle = RLUI.Text("", 32, n"MainColors.Blue");
    subtitle.SetHAlign(inkEHorizontalAlign.Center);
    subtitle.SetLetterCase(textLetterCase.UpperCase);
    subtitle.Reparent(panel);

    this.m_root = root;
    this.m_title = title;
    this.m_subtitle = subtitle;
    return true;
  }
}

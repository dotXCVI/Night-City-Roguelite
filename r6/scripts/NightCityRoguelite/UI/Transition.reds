// -----------------------------------------------------------------------------
// Night City Roguelite - transitions
// -----------------------------------------------------------------------------
// A full-screen fade to black with a line of text ("PETROCHEM OFF-LIMITS /
// ACT 1 - FLOOR 3 - VS MILITECH"), used for every trip between home and an
// arena and for V's death. The system teleports V only while the screen is
// black and fades back in once the destination has streamed in, so nothing
// pops in on screen.
//
// The black glitches as it comes and goes: the title tears into red and
// blue ghosts and the text flickers, the way a signal drops. The world's own
// glitch plays under it (RogueliteSystem.StartGlitch) before the black comes
// down and as it lifts.
//
// The overlay lives on the game-notifications layer (above the HUD, below
// menus) and is built on demand. Durations are owned by the caller, which
// schedules its next step with RLDelay; nothing here calls back.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLTransition extends IScriptable {
  private let m_root: wref<inkCanvas>;
  private let m_text: wref<inkVerticalPanel>;
  private let m_title: wref<inkText>;
  private let m_ghostRed: wref<inkText>;
  private let m_ghostBlue: wref<inkText>;
  private let m_glitchProxies: array<ref<inkAnimProxy>>;
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
    this.Glitch(seconds + 0.4);
  }

  public func FadeIn(seconds: Float) {
    this.m_black = false;
    if this.IsAlive() {
      this.Animate(0.0, seconds);
      this.Glitch(seconds);
    }
  }

  public func SetText(const title: String, const subtitle: String) {
    if IsDefined(this.m_title) {
      this.m_title.SetText(title);
      this.m_ghostRed.SetText(title);
      this.m_ghostBlue.SetText(title);
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
    this.m_text = null;
    this.m_title = null;
    this.m_ghostRed = null;
    this.m_ghostBlue = null;
    ArrayClear(this.m_glitchProxies);
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

  // The title tears: red and blue ghosts jitter either side of it and fade,
  // and the text flickers, for `seconds`.
  private func Glitch(seconds: Float) {
    for proxy in this.m_glitchProxies {
      if IsDefined(proxy) && proxy.IsPlaying() {
        proxy.Stop(true);
      }
    }
    ArrayClear(this.m_glitchProxies);
    let beats = Cast<Uint32>(Max(2, RoundF(seconds / 0.12)));
    this.Jitter(this.m_ghostRed, Vector2(-16.0, 3.0), Vector2(11.0, -2.0), beats, seconds);
    this.Jitter(this.m_ghostBlue, Vector2(14.0, -3.0), Vector2(-9.0, 2.0), beats, seconds);
    // Dips and back, one per beat: it always ends fully lit.
    let anim = new inkAnimDef();
    let i = 0;
    while i < Cast<Int32>(beats) {
      let start = 0.12 * Cast<Float>(i);
      anim.AddInterpolator(RLTransition.Opacity(1.0, 0.35, start, 0.03));
      anim.AddInterpolator(RLTransition.Opacity(0.35, 1.0, start + 0.03, 0.03));
      i += 1;
    }
    ArrayPush(this.m_glitchProxies, this.m_text.PlayAnimation(anim));
  }

  private static func Opacity(from: Float, to: Float, delay: Float, seconds: Float) -> ref<inkAnimTransparency> {
    let step = new inkAnimTransparency();
    step.SetStartTransparency(from);
    step.SetEndTransparency(to);
    step.SetStartDelay(delay);
    step.SetDuration(seconds);
    return step;
  }

  // A ghost of the title: shakes between two offsets, then fades out.
  private func Jitter(ghost: wref<inkText>, from: Vector2, to: Vector2, beats: Uint32, seconds: Float) {
    let shake = new inkAnimTranslation();
    shake.SetStartTranslation(from);
    shake.SetEndTranslation(to);
    shake.SetDuration(0.06);
    let shakeAnim = new inkAnimDef();
    shakeAnim.AddInterpolator(shake);
    let options: inkAnimOptions;
    options.loopType = inkanimLoopType.PingPong;
    options.loopCounter = beats;
    ArrayPush(this.m_glitchProxies, ghost.PlayAnimationWithOptions(shakeAnim, options));
    let fade = new inkAnimTransparency();
    fade.SetStartTransparency(0.8);
    fade.SetEndTransparency(0.0);
    fade.SetDuration(MaxF(seconds, 0.1));
    let fadeAnim = new inkAnimDef();
    fadeAnim.AddInterpolator(fade);
    ArrayPush(this.m_glitchProxies, ghost.PlayAnimation(fadeAnim));
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

    // The title and its two ghosts, stacked in one box the width of the
    // screen so they centre together.
    let titleBox = new inkCanvas();
    titleBox.SetSize(Vector2(3000.0, 96.0));
    titleBox.SetHAlign(inkEHorizontalAlign.Center);
    titleBox.Reparent(panel);
    let ghostRed = RLTransition.TitleText(n"MainColors.Red");
    ghostRed.SetOpacity(0.0);
    ghostRed.Reparent(titleBox);
    let ghostBlue = RLTransition.TitleText(n"MainColors.Blue");
    ghostBlue.SetOpacity(0.0);
    ghostBlue.Reparent(titleBox);
    let title = RLTransition.TitleText(n"MainColors.Red");
    title.Reparent(titleBox);

    let subtitle = RLUI.Text("", 32, n"MainColors.Blue");
    subtitle.SetHAlign(inkEHorizontalAlign.Center);
    subtitle.SetLetterCase(textLetterCase.UpperCase);
    subtitle.Reparent(panel);

    this.m_root = root;
    this.m_text = panel;
    this.m_title = title;
    this.m_ghostRed = ghostRed;
    this.m_ghostBlue = ghostBlue;
    this.m_subtitle = subtitle;
    return true;
  }

  private static func TitleText(color: CName) -> ref<inkText> {
    let text = RLUI.Text("", 72, color, true);
    text.SetAnchor(inkEAnchor.Centered);
    text.SetAnchorPoint(Vector2(0.5, 0.5));
    text.SetHAlign(inkEHorizontalAlign.Center);
    text.SetLetterCase(textLetterCase.UpperCase);
    return text;
  }
}

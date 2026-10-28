// -----------------------------------------------------------------------------
// Night City Roguelite - run HUD
// -----------------------------------------------------------------------------
// The top center of the HUD during a run:
//   ACT 1 - FLOOR 2
//   WAVE 2/3   HOSTILES 5   KILLS 14
//   VOODOO 3+   MAELSTROM 1   COVER 1   SHIELD   MOMENTUM 4     <- the build
//   ROYCE ======-----                                             <- a boss
//   ARC  ·  PYRE                                                  <- tags
// The build row shows the patrons V leans on (+ once their favour is in),
// Trauma Team cover and the keywords on V. Tags flash when an effect fires
// or a keyword lands, so every pick is something V sees happen.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLHud extends IScriptable {
  private let m_root: wref<inkCanvas>;
  private let m_title: wref<inkText>;
  private let m_status: wref<inkText>;
  private let m_boss: wref<inkVerticalPanel>;
  private let m_bossName: wref<inkText>;
  private let m_bossFill: wref<inkRectangle>;
  private let m_build: wref<inkHorizontalPanel>;
  private let m_tag: wref<inkText>;
  private let m_tagProxy: ref<inkAnimProxy>;
  private let m_tagAt: Float;
  private let m_lastTag: String;

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
    root.SetSize(Vector2(1600.0, 300.0));
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

    let build = RLUI.HPanel(14.0);
    build.SetHAlign(inkEHorizontalAlign.Center);
    build.SetMargin(inkMargin(0.0, 4.0, 0.0, 0.0));
    build.Reparent(panel);

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

    let tag = RLUI.Text("", 36, n"MainColors.ActiveWhite", true);
    tag.SetHAlign(inkEHorizontalAlign.Center);
    tag.SetLetterCase(textLetterCase.UpperCase);
    tag.SetMargin(inkMargin(0.0, 10.0, 0.0, 0.0));
    tag.SetOpacity(0.0);
    tag.SetRenderTransformPivot(Vector2(0.5, 0.5));
    tag.Reparent(panel);

    this.m_root = root;
    this.m_build = build;
    this.m_tag = tag;
    this.m_title = title;
    this.m_status = status;
    this.m_boss = boss;
    this.m_bossName = bossName;
    this.m_bossFill = fill;
  }

  public static func BarWidth() -> Float = 640.0

  // The build row: patrons (with their favour), cover, SHIELD, MOMENTUM.
  public func SetBuild(run: ref<RLRunState>, combat: ref<RLCombatState>) {
    this.Show();
    if !IsDefined(this.m_build) || !IsDefined(run) {
      return;
    }
    this.m_build.RemoveAllChildren();
    for patron in run.patrons {
      let count = RLBoons.CountForPatron(run, patron);
      if count > 0 {
        let favour = RLBoons.Has(run, StringToName("Favour_" + NameToString(patron)));
        this.AddBuildItem(RLPatrons.ShortName(patron) + s" \(count)" + (favour ? "+" : ""), RLPatrons.Accent(patron));
      }
    }
    if run.coverMax > 0 {
      this.AddBuildItem(s"COVER \(run.cover)", run.cover > 0 ? n"MainColors.Green" : n"MainColors.Red");
    }
    if IsDefined(combat) && combat.shield {
      this.AddBuildItem("SHIELD", n"MainColors.Gold");
    }
    if IsDefined(combat) && combat.momentum > 0 {
      this.AddBuildItem(s"MOMENTUM \(combat.momentum)", n"MainColors.Gold");
    }
  }

  private func AddBuildItem(const text: String, color: CName) {
    let item = RLUI.Text(text, 26, color, true);
    item.SetLetterCase(textLetterCase.UpperCase);
    item.Reparent(this.m_build);
  }

  // A one-word tag that flashes and fades. Tags landing together share the
  // line ("ARC  ·  PYRE"); the same tag again right away is dropped.
  public func Tag(const label: String, color: CName) {
    this.Show();
    if !IsDefined(this.m_tag) {
      return;
    }
    let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(GetGameInstance()).GetSimTime());
    let recent = now - this.m_tagAt < 0.6;
    if recent && StrContains(this.m_lastTag, label) {
      return;
    }
    this.m_lastTag = recent && StrLen(this.m_lastTag) + StrLen(label) < 40 ? this.m_lastTag + "  ·  " + label : label;
    this.m_tagAt = now;
    this.m_tag.SetText(this.m_lastTag);
    this.m_tag.BindProperty(n"tintColor", color);
    if IsDefined(this.m_tagProxy) {
      this.m_tagProxy.Stop();
    }
    this.m_tag.SetOpacity(1.0);
    let fade = new inkAnimTransparency();
    fade.SetStartTransparency(1.0);
    fade.SetEndTransparency(0.0);
    fade.SetStartDelay(0.7);
    fade.SetDuration(0.6);
    let pop = new inkAnimScale();
    pop.SetStartScale(Vector2(1.25, 1.25));
    pop.SetEndScale(Vector2(1.0, 1.0));
    pop.SetDuration(0.15);
    pop.SetMode(inkanimInterpolationMode.EasyOut);
    pop.SetType(inkanimInterpolationType.Quadratic);
    let anim = new inkAnimDef();
    anim.AddInterpolator(fade);
    anim.AddInterpolator(pop);
    this.m_tagProxy = this.m_tag.PlayAnimation(anim);
  }

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
      this.m_build.RemoveAllChildren();
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
    this.m_build = null;
    this.m_tag = null;
    this.m_tagProxy = null;
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

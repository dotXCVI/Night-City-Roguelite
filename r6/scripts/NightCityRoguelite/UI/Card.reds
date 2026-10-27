// -----------------------------------------------------------------------------
// Night City Roguelite - cards
// -----------------------------------------------------------------------------
// The selectable card used by the terminal, the door picker and the reward
// screen. Built from the game's own UI pieces (the cell frames from
// atlas_shapes_sync, the hub menu and common icon atlases, item and buff icons
// from TweakDB) so it reads like the game's menus:
//
//   +--------------------------------+
//   | [banner art]           (opt.)  |
//   | ====  accent bar               |
//   | [icon]                         |
//   | KICKER                  pips   |
//   | Title                          |
//   | lines...                       |
//   |                                |
//   | FOOTER                         |
//   +--------------------------------+
//
// Hover lifts the card a little and lights its frame and art in the accent
// colour - the text never sits on a tint, so it reads the same either way.
// A selected card keeps a thick frame; disabled cards are dimmed.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLCard extends CustomButton {
  protected let m_width: Float;
  protected let m_height: Float;
  protected let m_accent: CName;
  protected let m_bg: wref<inkImage>;
  protected let m_frame: wref<inkImage>;
  protected let m_hoverFrame: wref<inkImage>;
  protected let m_selectedFrame: wref<inkImage>;
  protected let m_bar: wref<inkRectangle>;
  protected let m_bannerBox: wref<inkCanvas>;
  protected let m_banner: wref<inkImage>;
  protected let m_badge: wref<inkCanvas>;
  protected let m_badgeIcon: wref<inkImage>;
  protected let m_bannerHeight: Float;
  protected let m_compact: Bool;
  // The card is (being) lifted by a hover.
  protected let m_lifted: Bool;
  protected let m_body: wref<inkVerticalPanel>;
  protected let m_iconBox: wref<inkCanvas>;
  protected let m_icon: wref<inkImage>;
  protected let m_kicker: wref<inkText>;
  protected let m_pips: wref<inkHorizontalPanel>;
  protected let m_lines: wref<inkVerticalPanel>;
  protected let m_footer: wref<inkText>;
  protected let m_disabledAnimDef: ref<inkAnimDef>;
  protected let m_disabledAnimProxy: ref<inkAnimProxy>;
  protected let m_hoverAnimDef: ref<inkAnimDef>;
  protected let m_liftAnimDef: ref<inkAnimDef>;
  protected let m_bannerAnimDef: ref<inkAnimDef>;
  protected let m_hoverFrameProxy: ref<inkAnimProxy>;
  protected let m_liftProxy: ref<inkAnimProxy>;
  protected let m_bannerProxy: ref<inkAnimProxy>;

  public static func Create(name: CName, width: Float, height: Float, accent: CName) -> ref<RLCard> {
    let card = new RLCard();
    card.m_width = width;
    card.m_height = height;
    card.m_accent = accent;
    card.CreateInstance();
    card.SetName(name);
    card.ToggleAnimations(true);
    card.ToggleSounds(true);
    return card;
  }

  protected func CreateWidgets() {
    let root = new inkCanvas();
    root.SetName(n"card");
    root.SetSize(Vector2(this.m_width, this.m_height));
    root.SetInteractive(true);
    root.SetRenderTransformPivot(Vector2(0.5, 0.5));

    let bg = RLCard.Shape(n"cell_bg", n"MainColors.Fullscreen_PrimaryBackgroundDarkest");
    bg.SetOpacity(0.94);
    bg.Reparent(root);

    // Art across the top of the card (SetBanner), with an icon badge in its
    // lower left corner (SetBadge).
    let bannerBox = new inkCanvas();
    bannerBox.SetName(n"bannerBox");
    bannerBox.SetAnchor(inkEAnchor.TopLeft);
    bannerBox.SetMargin(inkMargin(6.0, 6.0, 0.0, 0.0));
    bannerBox.SetVisible(false);
    bannerBox.Reparent(root);

    let banner = new inkImage();
    banner.SetName(n"banner");
    banner.SetAnchor(inkEAnchor.Fill);
    banner.SetOpacity(0.78);
    banner.Reparent(bannerBox);

    let badge = new inkCanvas();
    badge.SetName(n"badge");
    badge.SetSize(Vector2(92.0, 92.0));
    badge.SetAnchor(inkEAnchor.BottomLeft);
    badge.SetAnchorPoint(Vector2(0.0, 1.0));
    badge.SetMargin(inkMargin(16.0, 0.0, 0.0, 14.0));
    badge.SetVisible(false);
    badge.Reparent(bannerBox);

    let plate = RLCard.Shape(n"cell_bg", n"MainColors.Fullscreen_PrimaryBackgroundDarkest");
    plate.SetOpacity(0.88);
    plate.Reparent(badge);

    let plateFrame = RLCard.Shape(n"cell_fg", this.m_accent);
    plateFrame.SetOpacity(0.6);
    plateFrame.Reparent(badge);

    let badgeIcon = new inkImage();
    badgeIcon.SetName(n"badgeIcon");
    badgeIcon.SetAnchor(inkEAnchor.Fill);
    badgeIcon.SetMargin(inkMargin(12.0, 12.0, 12.0, 12.0));
    badgeIcon.SetStyle(RLUI.Style());
    badgeIcon.BindProperty(n"tintColor", this.m_accent);
    badgeIcon.Reparent(badge);

    let frame = RLCard.Shape(n"cell_fg", n"MainColors.Red");
    frame.SetOpacity(0.45);
    frame.Reparent(root);

    let hoverFrame = RLCard.Shape(n"cell_fg", this.m_accent);
    hoverFrame.SetOpacity(0.0);
    hoverFrame.Reparent(root);

    let selectedFrame = RLCard.Shape(n"cell_fg_thick", n"MainColors.ActiveYellow");
    selectedFrame.SetVisible(false);
    selectedFrame.Reparent(root);

    let bar = new inkRectangle();
    bar.SetName(n"accentBar");
    bar.SetAnchor(inkEAnchor.TopFillHorizontaly);
    bar.SetMargin(inkMargin(24.0, 14.0, 60.0, 0.0));
    bar.SetSize(Vector2(100.0, 5.0));
    bar.SetStyle(RLUI.Style());
    bar.BindProperty(n"tintColor", this.m_accent);
    bar.Reparent(root);

    let body = new inkVerticalPanel();
    body.SetName(n"body");
    body.SetAnchor(inkEAnchor.Fill);
    body.SetMargin(inkMargin(28.0, 34.0, 28.0, 24.0));
    body.SetChildMargin(inkMargin(0.0, 4.0, 0.0, 4.0));
    body.Reparent(root);

    let iconBox = new inkCanvas();
    iconBox.SetName(n"iconBox");
    iconBox.SetSize(Vector2(110.0, 110.0));
    iconBox.SetHAlign(inkEHorizontalAlign.Left);
    iconBox.SetVisible(false);
    iconBox.SetAffectsLayoutWhenHidden(false);
    iconBox.SetMargin(inkMargin(0.0, 0.0, 0.0, 10.0));
    iconBox.Reparent(body);

    let icon = new inkImage();
    icon.SetName(n"icon");
    icon.SetAnchor(inkEAnchor.Fill);
    icon.SetStyle(RLUI.Style());
    icon.BindProperty(n"tintColor", this.m_accent);
    icon.Reparent(iconBox);

    let header = new inkHorizontalPanel();
    header.SetName(n"header");
    header.SetFitToContent(true);
    header.Reparent(body);

    let kicker = RLUI.Text("", 24, this.m_accent, true);
    kicker.SetLetterCase(textLetterCase.UpperCase);
    kicker.SetVAlign(inkEVerticalAlign.Center);
    kicker.Reparent(header);

    let pips = new inkHorizontalPanel();
    pips.SetName(n"pips");
    pips.SetFitToContent(true);
    pips.SetVAlign(inkEVerticalAlign.Center);
    pips.SetMargin(inkMargin(16.0, 0.0, 0.0, 0.0));
    pips.SetChildMargin(inkMargin(3.0, 0.0, 3.0, 0.0));
    pips.Reparent(header);

    let title = RLUI.WrappedText("", 42, n"MainColors.Red", this.m_width - 56.0);
    title.SetFontStyle(n"Semi-Bold");
    title.Reparent(body);

    let lines = new inkVerticalPanel();
    lines.SetName(n"lines");
    lines.SetFitToContent(true);
    lines.SetChildMargin(inkMargin(0.0, 3.0, 0.0, 3.0));
    lines.Reparent(body);

    let footer = RLUI.Text("", 26, this.m_accent, true);
    footer.SetLetterCase(textLetterCase.UpperCase);
    footer.SetAnchor(inkEAnchor.BottomLeft);
    footer.SetAnchorPoint(Vector2(0.0, 1.0));
    footer.SetMargin(inkMargin(28.0, 0.0, 0.0, 22.0));
    footer.Reparent(root);

    this.m_root = root;
    this.m_label = title;
    this.m_bg = bg;
    this.m_bannerBox = bannerBox;
    this.m_banner = banner;
    this.m_badge = badge;
    this.m_badgeIcon = badgeIcon;
    this.m_frame = frame;
    this.m_hoverFrame = hoverFrame;
    this.m_selectedFrame = selectedFrame;
    this.m_bar = bar;
    this.m_body = body;
    this.m_iconBox = iconBox;
    this.m_icon = icon;
    this.m_kicker = kicker;
    this.m_pips = pips;
    this.m_lines = lines;
    this.m_footer = footer;
    this.SetRootWidget(root);
  }

  protected func CreateAnimations() {
    let dim = new inkAnimTransparency();
    dim.SetStartTransparency(1.0);
    dim.SetEndTransparency(0.35);
    dim.SetDuration(this.m_useAnimations ? 0.08 : 0.0001);
    this.m_disabledAnimDef = new inkAnimDef();
    this.m_disabledAnimDef.AddInterpolator(dim);

    let hover = new inkAnimTransparency();
    hover.SetStartTransparency(0.0);
    hover.SetEndTransparency(1.0);
    hover.SetDuration(this.m_useAnimations ? 0.15 : 0.0001);
    this.m_hoverAnimDef = new inkAnimDef();
    this.m_hoverAnimDef.AddInterpolator(hover);

    // The card rises a few pixels and grows a hair.
    let lift = new inkAnimTranslation();
    lift.SetStartTranslation(Vector2(0.0, 0.0));
    lift.SetEndTranslation(Vector2(0.0, -10.0));
    lift.SetDuration(this.m_useAnimations ? 0.16 : 0.0001);
    lift.SetMode(inkanimInterpolationMode.EasyOut);
    lift.SetType(inkanimInterpolationType.Quadratic);
    let grow = new inkAnimScale();
    grow.SetStartScale(Vector2(1.0, 1.0));
    grow.SetEndScale(Vector2(1.025, 1.025));
    grow.SetDuration(this.m_useAnimations ? 0.16 : 0.0001);
    grow.SetMode(inkanimInterpolationMode.EasyOut);
    grow.SetType(inkanimInterpolationType.Quadratic);
    this.m_liftAnimDef = new inkAnimDef();
    this.m_liftAnimDef.AddInterpolator(lift);
    this.m_liftAnimDef.AddInterpolator(grow);

    // The art comes up to full brightness.
    let light = new inkAnimTransparency();
    light.SetStartTransparency(0.78);
    light.SetEndTransparency(1.0);
    light.SetDuration(this.m_useAnimations ? 0.16 : 0.0001);
    this.m_bannerAnimDef = new inkAnimDef();
    this.m_bannerAnimDef.AddInterpolator(light);
  }

  protected func ApplyDisabledState() {
    let options: inkAnimOptions;
    options.playReversed = !this.m_isDisabled;
    if IsDefined(this.m_disabledAnimProxy) {
      this.m_disabledAnimProxy.Stop();
    }
    this.m_disabledAnimProxy = this.m_root.PlayAnimationWithOptions(this.m_disabledAnimDef, options);
  }

  protected func ApplyHoveredState() {
    let on = this.m_isHovered && !this.m_isDisabled;
    if Equals(on, this.m_lifted) {
      return;
    }
    this.m_lifted = on;
    let options: inkAnimOptions;
    options.playReversed = !on;
    if IsDefined(this.m_hoverFrameProxy) {
      this.m_hoverFrameProxy.Stop();
    }
    this.m_hoverFrameProxy = this.m_hoverFrame.PlayAnimationWithOptions(this.m_hoverAnimDef, options);
    if IsDefined(this.m_liftProxy) {
      this.m_liftProxy.Stop();
    }
    this.m_liftProxy = this.m_root.PlayAnimationWithOptions(this.m_liftAnimDef, options);
    if this.m_bannerHeight > 0.0 {
      if IsDefined(this.m_bannerProxy) {
        this.m_bannerProxy.Stop();
      }
      this.m_bannerProxy = this.m_banner.PlayAnimationWithOptions(this.m_bannerAnimDef, options);
    }
  }

  // A press settles the card back down for a moment.
  protected func ApplyPressedState() {
    if this.m_isDisabled {
      return;
    }
    let scale = this.m_isPressed ? 0.99 : (this.m_lifted ? 1.025 : 1.0);
    this.m_root.SetScale(Vector2(scale, scale));
  }

  // --- Content ---------------------------------------------------------------------------

  public func SetKicker(const text: String) {
    this.m_kicker.SetText(text);
  }

  public func SetTitle(const text: String) {
    this.m_label.SetText(text);
  }

  // For short cards without a footer: tighter padding.
  public func SetCompact() {
    this.m_compact = true;
    this.m_body.SetChildMargin(inkMargin(0.0, 1.0, 0.0, 1.0));
    this.m_iconBox.SetMargin(inkMargin(0.0, 0.0, 0.0, 4.0));
    this.Layout();
  }

  // Codex art across the top of the card, at the art's own 16:9.
  public func SetBanner(art: RLArt) {
    if !RLArts.IsValid(art) {
      return;
    }
    let width = this.m_width - 12.0;
    this.m_bannerHeight = width * RLArts.Ratio();
    this.m_banner.SetAtlasResource(RLArts.Atlas(art.sheet));
    this.m_banner.SetTexturePart(art.part);
    this.m_bannerBox.SetSize(Vector2(width, this.m_bannerHeight));
    this.m_bannerBox.SetVisible(true);
    this.Layout();
  }

  // An icon on a small plate in the banner's corner (the reward type, a
  // faction logo).
  public func SetBadge(atlas: ResRef, part: CName) {
    this.m_badgeIcon.SetAtlasResource(atlas);
    this.m_badgeIcon.SetTexturePart(part);
    this.m_badge.SetVisible(true);
  }

  // Body and accent bar sit under the banner when there is one.
  private func Layout() {
    let top = this.m_bannerHeight > 0.0 ? this.m_bannerHeight + 6.0 : 0.0;
    if this.m_compact {
      this.m_body.SetMargin(inkMargin(24.0, top + 22.0, 24.0, 10.0));
      this.m_bar.SetMargin(inkMargin(24.0, top + 10.0, 60.0, 0.0));
    } else {
      this.m_body.SetMargin(inkMargin(28.0, top + 34.0, 28.0, 24.0));
      this.m_bar.SetMargin(inkMargin(24.0, top + 14.0, 60.0, 0.0));
    }
  }

  public func SetTitleSize(size: Int32) {
    this.m_label.SetFontSize(size);
  }

  public func SetFooter(const text: String) {
    this.m_footer.SetText(text);
  }

  public func AddLine(const text: String, color: CName, size: Int32) -> ref<inkText> {
    let line = RLUI.WrappedText(text, size, color, this.m_width - 56.0);
    line.Reparent(this.m_lines);
    return line;
  }

  // A line led by a small icon from an atlas (a faction logo).
  public func AddIconLine(atlas: ResRef, part: CName, const text: String, color: CName, size: Int32) {
    let row = RLUI.HPanel(0.0);
    row.SetChildMargin(inkMargin(0.0, 0.0, 10.0, 0.0));
    row.Reparent(this.m_lines);
    let icon = new inkImage();
    icon.SetAtlasResource(atlas);
    icon.SetTexturePart(part);
    icon.SetSize(Vector2(Cast<Float>(size) + 10.0, Cast<Float>(size) + 10.0));
    icon.SetFitToContent(false);
    icon.SetVAlign(inkEVerticalAlign.Center);
    icon.SetStyle(RLUI.Style());
    icon.BindProperty(n"tintColor", color);
    icon.Reparent(row);
    let label = RLUI.Text(text, size, color);
    label.SetVAlign(inkEVerticalAlign.Center);
    label.Reparent(row);
  }

  public func AddSpacer(height: Float) {
    let spacer = new inkRectangle();
    spacer.SetOpacity(0.0);
    spacer.SetSize(Vector2(10.0, height));
    spacer.Reparent(this.m_lines);
  }

  // A thin divider line in the accent colour.
  public func AddDivider() {
    let line = new inkRectangle();
    line.SetSize(Vector2(this.m_width - 56.0, 2.0));
    line.SetOpacity(0.35);
    line.SetStyle(RLUI.Style());
    line.BindProperty(n"tintColor", this.m_accent);
    line.SetMargin(inkMargin(0.0, 6.0, 0.0, 6.0));
    line.Reparent(this.m_lines);
  }

  // `filled` of `total` small bars next to the kicker (threat, stacks...).
  public func SetPips(filled: Int32, total: Int32, color: CName) {
    this.m_pips.RemoveAllChildren();
    let i = 0;
    while i < total {
      let pip = new inkRectangle();
      pip.SetSize(Vector2(26.0, 9.0));
      pip.SetVAlign(inkEVerticalAlign.Center);
      pip.SetStyle(RLUI.Style());
      pip.BindProperty(n"tintColor", i < filled ? color : n"MainColors.Grey");
      pip.SetOpacity(i < filled ? 1.0 : 0.3);
      pip.Reparent(this.m_pips);
      i += 1;
    }
  }

  // Information only: no hover, no clicks.
  public func SetStatic() {
    this.m_root.SetInteractive(false);
    this.m_banner.SetOpacity(1.0);
  }

  public func SetSelected(selected: Bool) {
    this.m_selectedFrame.SetVisible(selected);
  }

  // The accent bar in the item's quality colour (Common grey .. Legendary
  // orange), like the game's own item cards.
  public func SetQuality(step: Int32) {
    this.m_bar.UnbindProperty(n"tintColor");
    this.m_bar.SetTintColor(RLCard.QualityColor(step));
    this.m_bar.SetSize(Vector2(100.0, 7.0));
  }

  public static func QualityColor(step: Int32) -> HDRColor {
    switch Clamp(step / 2, 0, 4) {
      case 1: return HDRColor(0.30, 0.86, 0.48, 1.0);
      case 2: return HDRColor(0.27, 0.62, 1.00, 1.0);
      case 3: return HDRColor(0.76, 0.40, 1.00, 1.0);
      case 4: return HDRColor(1.00, 0.62, 0.16, 1.0);
    }
    return HDRColor(0.62, 0.64, 0.66, 1.0);
  }

  // Cards slide up and fade in one after another when a screen opens.
  public func PlayIntro(delay: Float) {
    let target = this.m_isDisabled ? 0.35 : 1.0;
    if IsDefined(this.m_disabledAnimProxy) {
      this.m_disabledAnimProxy.Stop(true);
    }
    this.m_root.SetOpacity(0.0);
    let fade = new inkAnimTransparency();
    fade.SetStartTransparency(0.0);
    fade.SetEndTransparency(target);
    fade.SetDuration(0.22);
    fade.SetStartDelay(delay);
    let slide = new inkAnimTranslation();
    slide.SetStartTranslation(Vector2(0.0, 40.0));
    slide.SetEndTranslation(Vector2(0.0, 0.0));
    slide.SetDuration(0.3);
    slide.SetStartDelay(delay);
    slide.SetMode(inkanimInterpolationMode.EasyOut);
    slide.SetType(inkanimInterpolationType.Quadratic);
    let intro = new inkAnimDef();
    intro.AddInterpolator(fade);
    intro.AddInterpolator(slide);
    this.m_root.PlayAnimation(intro);
  }

  // Icon from an atlas part (hub menu / common icons), tinted with the accent.
  public func SetAtlasIcon(atlas: ResRef, part: CName, size: Float) {
    this.m_icon.SetAtlasResource(atlas);
    this.m_icon.SetTexturePart(part);
    this.m_iconBox.SetSize(Vector2(size, size));
    this.m_iconBox.SetVisible(true);
  }

  // Icon from a TweakDB UIIcon record (item and buff icons), untinted.
  public func SetRecordIcon(iconID: TweakDBID, width: Float, height: Float) -> Bool {
    let record = TweakDBInterface.GetUIIconRecord(iconID);
    if !IsDefined(record) {
      return false;
    }
    this.m_icon.UnbindProperty(n"tintColor");
    this.m_icon.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    // Loaded in the background like the game's own item icons.
    let reference = new UIIconReference();
    reference.iconID = iconID;
    this.m_icon.RequestSetImage(reference);
    this.m_iconBox.SetSize(Vector2(width, height));
    this.m_iconBox.SetVisible(true);
    return true;
  }

  // --- Helpers ---------------------------------------------------------------------------

  private static func Shape(part: CName, color: CName) -> ref<inkImage> {
    let image = new inkImage();
    image.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    image.SetTexturePart(part);
    image.SetNineSliceScale(true);
    image.SetAnchor(inkEAnchor.Fill);
    image.SetStyle(RLUI.Style());
    image.BindProperty(n"tintColor", color);
    return image;
  }
}

// Icons used by the menus (all from the game's own atlases).
public abstract class RLIcons {
  public static func HubAtlas() -> ResRef = r"base\\gameplay\\gui\\fullscreen\\hub_menu\\hub_atlas.inkatlas"
  public static func CommonAtlas() -> ResRef = r"base\\gameplay\\gui\\common\\icons\\atlas_common.inkatlas"

  // UIIcon record for an item's icon (weapons, cyberware, quickhacks).
  public static func ItemIcon(item: TweakDBID) -> TweakDBID {
    let record = TweakDBInterface.GetItemRecord(item);
    if !IsDefined(record) {
      return TDBID.None();
    }
    let path = record.IconPath();
    if StrLen(path) == 0 {
      return TDBID.None();
    }
    return StrBeginsWith(path, "UIIcon.") ? TDBID.Create(path) : TDBID.Create("UIIcon." + path);
  }

  // UIIcon record for a boon's HUD buff icon.
  public static func BoonIcon(boon: CName) -> TweakDBID {
    let effect = TweakDBInterface.GetStatusEffectRecord(RLBoons.BuffID(boon));
    if !IsDefined(effect) || !IsDefined(effect.UiData()) {
      return TDBID.None();
    }
    return TDBID.Create("UIIcon." + effect.UiData().IconPath());
  }

  public static func LogoAtlas() -> ResRef = r"base\\gameplay\\gui\\common\\icons\\gang_logos.inkatlas"

  // A faction's logo in the gang logo atlas.
  public static func FactionLogo(faction: gamedataAffiliation) -> CName {
    switch faction {
      case gamedataAffiliation.Animals: return n"logo_animals";
      case gamedataAffiliation.Arasaka: return n"logo_arasaka";
      case gamedataAffiliation.Barghest: return n"logo_barghest";
      case gamedataAffiliation.KangTao: return n"logo_kangtao";
      case gamedataAffiliation.Maelstrom: return n"logo_maelstrom";
      case gamedataAffiliation.Militech: return n"logo_militech";
      case gamedataAffiliation.Scavengers: return n"logo_scavengers";
      case gamedataAffiliation.SixthStreet: return n"logo_6thstreet";
      case gamedataAffiliation.TygerClaws: return n"logo_tygerclaws";
      case gamedataAffiliation.Valentinos: return n"logo_valentinos";
      case gamedataAffiliation.VoodooBoys: return n"logo_voodooboys";
      case gamedataAffiliation.Wraiths: return n"logo_wraiths";
    }
    return n"logo_ncpd";
  }

  // A patron's logo on a card.
  public static func SetPatronIcon(card: ref<RLCard>, patronID: CName, size: Float) {
    let patron = RLPatrons.Get(patronID);
    if !IsDefined(patron) {
      card.SetAtlasIcon(RLIcons.HubAtlas(), n"ico_tarot", size);
      return;
    }
    card.SetAtlasIcon(patron.isLogo ? RLIcons.LogoAtlas() : RLIcons.HubAtlas(), patron.iconPart, size);
  }

  public static func CategoryPart(category: RLRewardCategory) -> CName {
    switch category {
      case RLRewardCategory.Armory: return n"ico_inventory";
      case RLRewardCategory.Chrome: return n"ico_cyberware";
      case RLRewardCategory.Daemons: return n"ico_deck";
      case RLRewardCategory.Boons: return n"ico_tarot";
      case RLRewardCategory.Training: return n"ico_stats";
      case RLRewardCategory.Iconic: return n"ico_inventory";
      case RLRewardCategory.Workshop: return n"ico_cafting_upgrading";
      case RLRewardCategory.Event: return n"ico_journal";
      case RLRewardCategory.Bounty: return n"ico_money";
      case RLRewardCategory.System: return n"ico_cyberware";
    }
    return n"ico_map";
  }

  public static func CategoryAccent(category: RLRewardCategory) -> CName {
    switch category {
      case RLRewardCategory.Armory: return n"MainColors.Red";
      case RLRewardCategory.Chrome: return n"MainColors.Blue";
      case RLRewardCategory.Daemons: return n"MainColors.Green";
      case RLRewardCategory.Boons: return n"MainColors.Purple";
      case RLRewardCategory.Training: return n"MainColors.ActiveWhite";
      case RLRewardCategory.Iconic: return n"MainColors.Gold";
      case RLRewardCategory.Workshop: return n"MainColors.Yellow";
      case RLRewardCategory.Event: return n"MainColors.Blue";
      case RLRewardCategory.Bounty: return n"MainColors.Red";
      case RLRewardCategory.System: return n"MainColors.Blue";
    }
    return n"MainColors.Red";
  }

  public static func KitPart(kit: CName) -> CName {
    switch kit {
      case n"Solo": return n"weapon_rifle";
      case n"Blade": return n"weapon_blades";
      case n"Netrunner": return n"ico_int";
      case n"Marksman": return n"weapon_sniper";
      case n"Brawler": return n"weapon_shotgun";
      case n"Gunslinger": return n"weapon_revolver";
      case n"Demolitions": return n"grenade_regular";
      case n"Juggernaut": return n"weapon_lmg";
      case n"Wireman": return n"ico_int";
    }
    return n"ico_body";
  }

  public static func ThreatAccent(threat: Int32) -> CName {
    if threat <= 1 {
      return n"MainColors.Green";
    }
    if threat >= 3 {
      return n"MainColors.Red";
    }
    return n"MainColors.Yellow";
  }
}

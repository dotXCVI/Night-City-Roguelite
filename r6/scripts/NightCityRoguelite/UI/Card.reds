// -----------------------------------------------------------------------------
// Night City Roguelite - cards
// -----------------------------------------------------------------------------
// The selectable card used by the terminal, the door picker and the reward
// screen. Built from the game's own UI pieces (the cell frames from
// atlas_shapes_sync, the hub menu and common icon atlases, item and buff icons
// from TweakDB) so it reads like the game's menus:
//
//   +--------------------------------+
//   | ====  accent bar               |
//   | [icon]                         |
//   | KICKER                  pips   |
//   | Title                          |
//   | lines...                       |
//   |                                |
//   | FOOTER                         |
//   +--------------------------------+
//
// Hover brightens the frame and fills the card with its accent colour; a
// selected card keeps a thick frame; disabled cards are dimmed.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLCard extends CustomButton {
  protected let m_width: Float;
  protected let m_height: Float;
  protected let m_accent: CName;
  protected let m_bg: wref<inkImage>;
  protected let m_fill: wref<inkImage>;
  protected let m_frame: wref<inkImage>;
  protected let m_hoverFrame: wref<inkImage>;
  protected let m_selectedFrame: wref<inkImage>;
  protected let m_bar: wref<inkRectangle>;
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
  protected let m_hoverFillProxy: ref<inkAnimProxy>;
  protected let m_hoverFrameProxy: ref<inkAnimProxy>;

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

    let bg = RLCard.Shape(n"cell_bg", n"MainColors.Fullscreen_PrimaryBackgroundDarkest");
    bg.SetOpacity(0.92);
    bg.Reparent(root);

    let fill = RLCard.Shape(n"cell_bg", this.m_accent);
    fill.SetOpacity(0.0);
    fill.Reparent(root);

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
    body.SetMargin(inkMargin(28.0, 34.0, 28.0, 64.0));
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
    this.m_fill = fill;
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
    let options: inkAnimOptions;
    options.playReversed = !on;
    if IsDefined(this.m_hoverFrameProxy) {
      this.m_hoverFrameProxy.Stop();
    }
    this.m_hoverFrameProxy = this.m_hoverFrame.PlayAnimationWithOptions(this.m_hoverAnimDef, options);
    // The fill only goes to a faint tint.
    this.m_fill.SetOpacity(on ? 0.12 : 0.0);
  }

  protected func ApplyPressedState() {
    this.m_fill.SetOpacity(this.m_isPressed && !this.m_isDisabled ? 0.22 : (this.m_isHovered && !this.m_isDisabled ? 0.12 : 0.0));
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
    this.m_body.SetMargin(inkMargin(24.0, 22.0, 24.0, 10.0));
    this.m_body.SetChildMargin(inkMargin(0.0, 1.0, 0.0, 1.0));
    this.m_bar.SetMargin(inkMargin(24.0, 10.0, 60.0, 0.0));
    this.m_iconBox.SetMargin(inkMargin(0.0, 0.0, 0.0, 4.0));
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

  public func SetSelected(selected: Bool) {
    this.m_selectedFrame.SetVisible(selected);
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
    this.m_icon.SetAtlasResource(record.AtlasResourcePath());
    this.m_icon.SetTexturePart(record.AtlasPartName());
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

  public static func CategoryPart(category: RLRewardCategory) -> CName {
    switch category {
      case RLRewardCategory.Armory: return n"ico_inventory";
      case RLRewardCategory.Chrome: return n"ico_cyberware";
      case RLRewardCategory.Daemons: return n"ico_deck";
      case RLRewardCategory.Boons: return n"ico_tarot";
      case RLRewardCategory.Training: return n"ico_stats";
      case RLRewardCategory.Iconic: return n"ico_inventory";
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

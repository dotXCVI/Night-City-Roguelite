// -----------------------------------------------------------------------------
// Night City Roguelite - widget helpers
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public abstract class RLUI {
  public static func FontFamily() -> String = "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"
  public static func Style() -> ResRef = r"base\\gameplay\\gui\\common\\main_colors.inkstyle"

  public static func Text(const content: String, size: Int32, color: CName, opt bold: Bool) -> ref<inkText> {
    let text = new inkText();
    text.SetFontFamily(RLUI.FontFamily());
    text.SetFontStyle(bold ? n"Semi-Bold" : n"Medium");
    text.SetFontSize(size);
    text.SetStyle(RLUI.Style());
    text.BindProperty(n"tintColor", color);
    text.SetText(content);
    text.SetFitToContent(true);
    return text;
  }

  public static func WrappedText(const content: String, size: Int32, color: CName, width: Float) -> ref<inkText> {
    let text = RLUI.Text(content, size, color);
    text.SetWrapping(true, width);
    return text;
  }

  // Codeware's popup content starts 76 px in on the left and runs to the
  // container's edge; the same margin on the right centres things in the
  // frame.
  public static func ContentInset() -> Float = 76.0

  public static func ContentMargin() -> inkMargin = inkMargin(0.0, 0.0, RLUI.ContentInset(), 0.0)

  public static func VPanel(childSpacing: Float) -> ref<inkVerticalPanel> {
    let panel = new inkVerticalPanel();
    panel.SetFitToContent(true);
    panel.SetChildMargin(inkMargin(0.0, childSpacing, 0.0, childSpacing));
    return panel;
  }

  public static func HPanel(childSpacing: Float) -> ref<inkHorizontalPanel> {
    let panel = new inkHorizontalPanel();
    panel.SetFitToContent(true);
    panel.SetChildMargin(inkMargin(childSpacing, 0.0, childSpacing, 0.0));
    return panel;
  }

  // Small grey section heading with a faint rule under it.
  public static func SectionLabel(const label: String) -> ref<inkWidget> {
    let panel = new inkVerticalPanel();
    panel.SetFitToContent(true);
    panel.SetMargin(inkMargin(0.0, 8.0, 0.0, 2.0));
    let text = RLUI.Text(label, 26, n"MainColors.Grey", true);
    text.SetLetterCase(textLetterCase.UpperCase);
    text.Reparent(panel);
    let rule = new inkRectangle();
    rule.SetSize(Vector2(2000.0, 2.0));
    rule.SetOpacity(0.15);
    rule.SetStyle(RLUI.Style());
    rule.BindProperty(n"tintColor", n"MainColors.Red");
    rule.Reparent(panel);
    return panel;
  }

  // A small panel with a caption and a big value (terminal stats row).
  public static func StatTile(const caption: String, const value: String, color: CName) -> ref<inkWidget> {
    let tile = new inkCanvas();
    tile.SetSize(Vector2(388.0, 108.0));
    let bg = new inkImage();
    bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    bg.SetTexturePart(n"cell_bg");
    bg.SetNineSliceScale(true);
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetStyle(RLUI.Style());
    bg.BindProperty(n"tintColor", n"MainColors.Fullscreen_PrimaryBackgroundDarkest");
    bg.SetOpacity(0.8);
    bg.Reparent(tile);
    let frame = new inkImage();
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetStyle(RLUI.Style());
    frame.BindProperty(n"tintColor", n"MainColors.Red");
    frame.SetOpacity(0.25);
    frame.Reparent(tile);
    let panel = new inkVerticalPanel();
    panel.SetAnchor(inkEAnchor.Fill);
    panel.SetMargin(inkMargin(24.0, 12.0, 16.0, 8.0));
    panel.Reparent(tile);
    let label = RLUI.Text(caption, 22, n"MainColors.Grey");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.Reparent(panel);
    let number = RLUI.Text(value, 50, color, true);
    number.Reparent(panel);
    return tile;
  }

  public static func Show(popup: ref<CustomPopup>) {
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(ShowCustomPopupEvent.Create(popup));
  }
}

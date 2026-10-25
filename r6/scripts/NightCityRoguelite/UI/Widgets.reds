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

  public static func Button(name: CName, const label: String, width: Float, disabled: Bool, opt height: Float, opt fontSize: Int32) -> ref<SimpleButton> {
    let button = SimpleButton.Create();
    button.SetName(name);
    button.SetText(label);
    button.SetWidth(width);
    if height > 0.0 {
      button.GetRootWidget().SetHeight(height);
    }
    if fontSize > 0 {
      let text = button.GetRootCompoundWidget().GetWidgetByPathName(n"label") as inkText;
      if IsDefined(text) {
        text.SetFontSize(fontSize);
      }
    }
    button.SetDisabled(disabled);
    button.ToggleAnimations(true);
    button.ToggleSounds(true);
    return button;
  }

  public static func Show(popup: ref<CustomPopup>) {
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(ShowCustomPopupEvent.Create(popup));
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - armory
// -----------------------------------------------------------------------------
// The back room of V's apartment: where the starting kit is picked (and
// locked kits are bought with Cred). Opened from the stash wall there, or F7
// while standing in the room (Hub/HomeDevices.reds); from the terminal only
// when the apartment isn't available.
//
// Two rows of kit cards, each with the kit's weapon on it, the attitude, the
// loadout and the two attributes it starts with.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLArmoryPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_content: ref<InGamePopupContent>;
  private let m_header: ref<InGamePopupHeader>;
  private let m_introPlayed: Bool;

  public static func Open(system: ref<RogueliteSystem>) -> ref<RLArmoryPopup> {
    let popup = new RLArmoryPopup();
    popup.m_system = system;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1320.0));

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetTitle("ARMORY");
    this.m_header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("YOUR KIT IS WHAT YOU WALK OUT WITH. EVERYTHING ELSE, YOU EARN.");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Rebuild();
    this.m_introPlayed = true;
    RLLog("Armory: built.");
  }

  private func Rebuild() {
    let service = RogueliteService.Get();
    this.m_header.SetFluffRight(s"\(service.GetCred()) CRED");
    let root = this.m_content.GetRootCompoundWidget();
    root.RemoveAllChildren();
    let rows = RLUI.VPanel(9.0);
    rows.SetAnchor(inkEAnchor.Fill);
    rows.SetMargin(inkMargin(0.0, 10.0, RLUI.ContentInset(), 0.0));
    rows.Reparent(root);
    let row: ref<inkHorizontalPanel>;
    let i = 0;
    for kit in RLMeta.Kits() {
      if i % 5 == 0 {
        row = RLUI.HPanel(9.0);
        row.SetHAlign(inkEHorizontalAlign.Center);
        row.Reparent(rows);
      }
      this.AddKitCard(row, service, kit, i);
      i += 1;
    }
  }

  private func AddKitCard(parent: ref<inkCompoundWidget>, service: ref<RogueliteService>, kit: CName, index: Int32) {
    let available = RLMeta.IsKitAvailable(service, kit);
    let selected = Equals(service.GetSelectedKit(), kit);
    let unlock = RLMeta.Get(StringToName("kit." + NameToString(kit)));
    let affordable = IsDefined(unlock) && RLMeta.CanBuy(service, unlock);
    let accent = selected ? n"MainColors.ActiveYellow" : (available ? n"MainColors.Blue" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
    let card = RLCard.Create(StringToName("kit_" + NameToString(kit)), 390.0, 500.0, accent);
    card.SetCompact();
    card.SetBanner(RLArts.Kit(kit));
    card.SetBadge(RLIcons.CommonAtlas(), RLIcons.KitPart(kit));
    if selected {
      card.SetKicker("EQUIPPED");
    } else if available {
      card.SetKicker("READY");
    } else if IsDefined(unlock) {
      card.SetKicker(affordable ? s"BUY - \(unlock.cost) CRED" : s"\(unlock.cost) CRED");
    } else {
      card.SetKicker("LOCKED");
    }
    card.SetTitle(RLMeta.KitName(kit));
    card.SetTitleSize(36);
    card.AddLine(RLMeta.KitTagline(kit), n"MainColors.ActiveWhite", 24);
    card.AddLine(RLMeta.KitDescription(kit), n"MainColors.Grey", 22);
    card.AddLine(RLLevelUp.AttributeName(RLKits.MainAttribute(kit)) + "  /  " + RLLevelUp.AttributeName(RLKits.SecondAttribute(kit)), n"MainColors.Blue", 20);
    card.SetSelected(selected);
    card.SetDisabled(!available && !affordable);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
    if !this.m_introPlayed {
      card.PlayIntro(0.05 * Cast<Float>(index));
    }
  }

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() {
      return false;
    }
    let name = NameToString(button.GetName());
    if !StrBeginsWith(name, "kit_") {
      return false;
    }
    let service = RogueliteService.Get();
    let kit = StringToName(StrAfterFirst(name, "_"));
    if !RLMeta.IsKitAvailable(service, kit) {
      if !RLMeta.TryBuy(service, StringToName("kit." + NameToString(kit))) {
        return false;
      }
      this.PlaySound(n"Item", n"OnBuy");
      RLLog("Kit bought: " + NameToString(kit) + ".");
    }
    service.SetSelectedKit(kit);
    this.Rebuild();
    return true;
  }

  protected cb func OnHide() {
    super.OnHide();
    if IsDefined(this.m_system) {
      this.m_system.OnPopupClosed();
    }
  }
}

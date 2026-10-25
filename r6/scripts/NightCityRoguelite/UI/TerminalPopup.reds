// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, three views:
//   Hub         (home, no run): stats, kit, mode, unlocks, START RUN.
//   ArenaPicker (home, run active): pick the next arena, or abandon.
//   InArena     (in an arena): run status, abandon.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public enum RLTerminalView {
  Hub = 0,
  ArenaPicker = 1,
  InArena = 2,
}

public class RLTerminalPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_view: RLTerminalView;
  private let m_summary: String;
  private let m_lastArena: CName;
  private let m_content: ref<InGamePopupContent>;
  private let m_confirmAbandon: Bool;

  public static func OpenHub(system: ref<RogueliteSystem>) -> ref<RLTerminalPopup> {
    return RLTerminalPopup.Open(system, RLTerminalView.Hub, "", n"");
  }

  public static func OpenArenaPicker(system: ref<RogueliteSystem>, const summary: String, lastArena: CName) -> ref<RLTerminalPopup> {
    return RLTerminalPopup.Open(system, RLTerminalView.ArenaPicker, summary, lastArena);
  }

  public static func OpenInArena(system: ref<RogueliteSystem>, const summary: String) -> ref<RLTerminalPopup> {
    return RLTerminalPopup.Open(system, RLTerminalView.InArena, summary, n"");
  }

  private static func Open(system: ref<RogueliteSystem>, view: RLTerminalView, const summary: String, lastArena: CName) -> ref<RLTerminalPopup> {
    let popup = new RLTerminalPopup();
    popup.m_system = system;
    popup.m_view = view;
    popup.m_summary = summary;
    popup.m_lastArena = lastArena;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(1800.0, 1180.0));

    let header = InGamePopupHeader.Create();
    switch this.m_view {
      case RLTerminalView.ArenaPicker:
        header.SetTitle("CHOOSE AN ARENA");
        break;
      case RLTerminalView.InArena:
        header.SetTitle("RUN IN PROGRESS");
        break;
      default:
        header.SetTitle("ROGUELITE TERMINAL");
    }
    header.SetFluffRight("NIGHT CITY ROGUELITE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.SetFluffText("F7 OPENS THIS TERMINAL");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Rebuild();
  }

  private func Rebuild() {
    let root = this.m_content.GetRootCompoundWidget();
    root.RemoveAllChildren();
    let body = RLUI.VPanel(6.0);
    body.SetAnchor(inkEAnchor.Fill);
    body.Reparent(root);
    switch this.m_view {
      case RLTerminalView.ArenaPicker:
        this.BuildArenaPicker(body);
        break;
      case RLTerminalView.InArena:
        this.BuildInArena(body);
        break;
      default:
        this.BuildHub(body);
    }
  }

  // --- In-arena view --------------------------------------------------------------------

  private func BuildInArena(body: ref<inkCompoundWidget>) {
    RLUI.WrappedText(this.m_summary, 32, n"MainColors.Blue", 1300.0).Reparent(body);
    let actions = RLUI.HPanel(18.0);
    actions.SetMargin(inkMargin(0.0, 40.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddButton(actions, n"resume", "RESUME", 360.0, false, 90.0, 44);
    this.AddAbandonButton(actions);
  }

  // --- Arena picker ------------------------------------------------------------------------

  private func BuildArenaPicker(body: ref<inkCompoundWidget>) {
    RLUI.Text(this.m_summary, 30, n"MainColors.Red", true).Reparent(body);

    let columns = RLUI.HPanel(16.0);
    columns.SetMargin(inkMargin(0.0, 16.0, 0.0, 16.0));
    columns.Reparent(body);
    let left = RLUI.VPanel(4.0);
    left.Reparent(columns);
    let right = RLUI.VPanel(4.0);
    right.Reparent(columns);

    let i = 0;
    for arena in RLArenas.Enabled() {
      let column = i % 2 == 0 ? left : right;
      let row = RLUI.HPanel(10.0);
      row.Reparent(column);
      let label = arena.name + (Equals(arena.id, this.m_lastArena) ? " (last)" : "");
      this.AddButton(row, StringToName("arena_" + NameToString(arena.id)), label, 460.0, false, 72.0, 34);
      let info = RLUI.Text(arena.area + " - " + RLTerminalPopup.FactionList(arena.factions), 24, n"MainColors.Grey");
      info.SetVAlign(inkEVerticalAlign.Center);
      info.Reparent(row);
      i += 1;
    }

    let actions = RLUI.HPanel(18.0);
    actions.SetMargin(inkMargin(0.0, 24.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddButton(actions, n"resume", "NOT YET", 360.0, false, 80.0, 40);
    this.AddAbandonButton(actions);
  }

  public static func FactionList(factions: array<gamedataAffiliation>) -> String {
    let text = "";
    for faction in factions {
      if StrLen(text) > 0 {
        text += ", ";
      }
      text += RogueliteSystem.FactionName(faction);
    }
    return text;
  }

  private func AddAbandonButton(parent: ref<inkCompoundWidget>) {
    this.AddButton(parent, n"abandon", this.m_confirmAbandon ? "CONFIRM: ABANDON RUN" : "ABANDON RUN", 620.0, false, 80.0, 40);
  }

  // --- Hub view --------------------------------------------------------------------------------

  private func BuildHub(body: ref<inkCompoundWidget>) {
    let service = RogueliteService.Get();
    let mode = service.IsRoguelikeMode() ? "ROGUELIKE (no unlock perks, +50% Cred)" : "ROGUELITE (unlock perks active)";
    RLUI.Text(s"CRED \(service.GetCred())    RUNS \(service.GetRunsStarted())    WINS \(service.GetVictories())    BEST FLOOR \(service.GetBestDepth())", 32, n"MainColors.Red", true).Reparent(body);
    RLUI.Text("MODE: " + mode, 28, n"MainColors.Blue").Reparent(body);

    // Kits
    RLUI.Text("STARTING KIT", 26, n"MainColors.Grey").Reparent(body);
    let kits = RLUI.HPanel(8.0);
    kits.Reparent(body);
    for kit in RLMeta.Kits() {
      let available = RLMeta.IsKitAvailable(service, kit);
      let selected = Equals(service.GetSelectedKit(), kit);
      let label = (selected ? "> " : "") + RLMeta.KitName(kit) + (available ? "" : " (locked)");
      this.AddButton(kits, StringToName("kit_" + NameToString(kit)), label, 300.0, !available, 64.0, 32);
    }
    RLUI.Text(RLMeta.KitDescription(service.GetSelectedKit()), 26, n"MainColors.Blue").Reparent(body);

    // Main actions
    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 12.0, 0.0, 12.0));
    actions.Reparent(body);
    this.AddButton(actions, n"start", "START RUN", 420.0, false, 90.0, 50);
    this.AddButton(actions, n"mode", service.IsRoguelikeMode() ? "SWITCH TO ROGUELITE" : "SWITCH TO ROGUELIKE", 520.0, false, 90.0, 36);

    // Unlocks: two columns of [button][description]
    RLUI.Text("UNLOCKS", 26, n"MainColors.Grey").Reparent(body);
    let columns = RLUI.HPanel(16.0);
    columns.Reparent(body);
    let left = RLUI.VPanel(3.0);
    left.Reparent(columns);
    let right = RLUI.VPanel(3.0);
    right.Reparent(columns);
    let i = 0;
    for def in RLMeta.Unlocks() {
      let column = i % 2 == 0 ? left : right;
      let row = RLUI.HPanel(8.0);
      row.Reparent(column);
      let owned = service.HasUnlock(def.id);
      let label = owned ? def.name + " - owned" : s"\(def.name) - \(def.cost)";
      this.AddButton(row, StringToName("buy_" + NameToString(def.id)), label, 400.0, owned || !RLMeta.CanBuy(service, def), 56.0, 28);
      let description = RLUI.WrappedText(def.description, 22, n"MainColors.Grey", 380.0);
      description.SetVAlign(inkEVerticalAlign.Center);
      description.Reparent(row);
      i += 1;
    }
  }

  private func AddButton(parent: ref<inkCompoundWidget>, name: CName, const label: String, width: Float, disabled: Bool, opt height: Float, opt fontSize: Int32) {
    let button = RLUI.Button(name, label, width, disabled, height > 0.0 ? height : 70.0, fontSize > 0 ? fontSize : 36);
    button.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    button.Reparent(parent);
  }

  // --- Input -----------------------------------------------------------------------------------

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() || !IsDefined(this.m_system) {
      return false;
    }
    let service = RogueliteService.Get();
    let name = NameToString(button.GetName());

    if Equals(name, "resume") {
      this.Close();
    } else if Equals(name, "abandon") {
      if this.m_confirmAbandon {
        this.Close();
        this.m_system.AbandonRun();
      } else {
        this.m_confirmAbandon = true;
        this.Rebuild();
      }
    } else if StrBeginsWith(name, "arena_") {
      this.Close();
      this.m_system.DeployTo(StringToName(StrAfterFirst(name, "_")));
    } else if Equals(name, "start") {
      this.Close();
      this.m_system.StartRun(service.GetSelectedKit());
    } else if Equals(name, "mode") {
      service.SetRoguelikeMode(!service.IsRoguelikeMode());
      this.Rebuild();
    } else if StrBeginsWith(name, "kit_") {
      service.SetSelectedKit(StringToName(StrAfterFirst(name, "_")));
      this.Rebuild();
    } else if StrBeginsWith(name, "buy_") {
      if RLMeta.TryBuy(service, StringToName(StrAfterFirst(name, "_"))) {
        this.PlaySound(n"Item", n"OnBuy");
      }
      this.Rebuild();
    } else {
      return false;
    }
    return true;
  }

  protected cb func OnHide() {
    super.OnHide();
    if IsDefined(this.m_system) {
      this.m_system.OnPopupClosed();
    }
  }
}

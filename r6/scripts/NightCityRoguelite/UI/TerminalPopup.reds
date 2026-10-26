// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, three views:
//   Hub         (home, no run): stats, kit, mode, unlocks, START RUN.
//   DoorPicker  (home, run active): pick the next fight by its reward, or abandon.
//   InArena     (in an arena): run status, abandon.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public enum RLTerminalView {
  Hub = 0,
  DoorPicker = 1,
  InArena = 2,
}

public class RLTerminalPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_view: RLTerminalView;
  private let m_summary: String;
  private let m_doors: array<ref<RLDoor>>;
  private let m_content: ref<InGamePopupContent>;
  private let m_confirmAbandon: Bool;

  public static func OpenHub(system: ref<RogueliteSystem>) -> ref<RLTerminalPopup> {
    let none: array<ref<RLDoor>>;
    return RLTerminalPopup.Open(system, RLTerminalView.Hub, "", none);
  }

  public static func OpenDoorPicker(system: ref<RogueliteSystem>, const summary: String, doors: array<ref<RLDoor>>) -> ref<RLTerminalPopup> {
    return RLTerminalPopup.Open(system, RLTerminalView.DoorPicker, summary, doors);
  }

  public static func OpenInArena(system: ref<RogueliteSystem>, const summary: String) -> ref<RLTerminalPopup> {
    let none: array<ref<RLDoor>>;
    return RLTerminalPopup.Open(system, RLTerminalView.InArena, summary, none);
  }

  private static func Open(system: ref<RogueliteSystem>, view: RLTerminalView, const summary: String, doors: array<ref<RLDoor>>) -> ref<RLTerminalPopup> {
    let popup = new RLTerminalPopup();
    popup.m_system = system;
    popup.m_view = view;
    popup.m_summary = summary;
    popup.m_doors = doors;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(1800.0, 1180.0));

    let header = InGamePopupHeader.Create();
    switch this.m_view {
      case RLTerminalView.DoorPicker:
        header.SetTitle(ArraySize(this.m_doors) == 1 ? "YOUR NEXT FIGHT" : "CHOOSE YOUR NEXT FIGHT");
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
      case RLTerminalView.DoorPicker:
        this.BuildDoorPicker(body);
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

  // --- Door picker -------------------------------------------------------------------------
  // One row per door: [REWARD - THREAT] then what it pays, where it is and how
  // hard it is.

  private func BuildDoorPicker(body: ref<inkCompoundWidget>) {
    RLUI.Text(this.m_summary, 30, n"MainColors.Red", true).Reparent(body);
    let hint = ArraySize(this.m_doors) == 1
      ? "The first fight is picked for you. From here on you choose the reward - bigger rewards mean harder fights."
      : "Pick the reward you want. The reward sets the fight: training is light, chrome and iconics are heavy.";
    RLUI.WrappedText(hint, 24, n"MainColors.Grey", 1500.0).Reparent(body);

    let list = RLUI.VPanel(14.0);
    list.SetMargin(inkMargin(0.0, 16.0, 0.0, 16.0));
    list.Reparent(body);
    let i = 0;
    for door in this.m_doors {
      let row = RLUI.HPanel(18.0);
      row.Reparent(list);
      let label = (door.boss ? "BOSS - " : "") + RLRewards.CategoryName(door.category) + "   " + RLTerminalPopup.Stars(door.threat);
      this.AddButton(row, StringToName(s"door_\(i)"), label, 560.0, false, 96.0, 38);
      let info = RLUI.VPanel(2.0);
      info.SetVAlign(inkEVerticalAlign.Center);
      info.Reparent(row);
      RLUI.Text(RLRewards.CategoryDescription(door.category), 28, n"MainColors.Blue").Reparent(info);
      let arena = RLArenas.Get(door.arena);
      if IsDefined(arena) {
        RLUI.Text(arena.name + " (" + arena.area + ") - " + RLTerminalPopup.FactionList(arena.factions), 24, n"MainColors.Grey").Reparent(info);
      }
      RLUI.Text(RLRewards.ThreatName(door.threat) + ": " + RLRewards.ThreatDescription(door.threat), 24, door.threat >= 3 ? n"MainColors.Red" : n"MainColors.Grey").Reparent(info);
      i += 1;
    }

    let actions = RLUI.HPanel(18.0);
    actions.SetMargin(inkMargin(0.0, 24.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddButton(actions, n"resume", "NOT YET", 360.0, false, 80.0, 40);
    this.AddAbandonButton(actions);
  }

  public static func Stars(threat: Int32) -> String {
    if threat <= 1 {
      return "[#--]";
    }
    if threat >= 3 {
      return "[###]";
    }
    return "[##-]";
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
    } else if StrBeginsWith(name, "door_") {
      this.Close();
      this.m_system.DeployToDoor(StringToInt(StrAfterFirst(name, "_")));
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

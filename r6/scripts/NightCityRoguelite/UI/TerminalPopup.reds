// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, three views:
//   Hub         (home, no run): stats, kit cards, START RUN, mode, unlocks.
//   DoorPicker  (home, run active): one card per door - pick the next fight
//               by its reward, or abandon.
//   InArena     (in an arena): run status, abandon.
// Everything clickable is an RLCard (UI/Card.reds).
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

  // No slow motion behind the menu: nothing is going on at home, and a menu
  // that fails to show can never leave the game crawling.
  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnShown() {
    RLLog("Menu shown.");
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1420.0));

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
    footer.SetFluffText("YOUR COMPUTER OR F7 OPENS THIS TERMINAL");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Rebuild();
    RLLog("Terminal menu: built.");
  }

  private func Rebuild() {
    let root = this.m_content.GetRootCompoundWidget();
    root.RemoveAllChildren();
    let body = RLUI.VPanel(8.0);
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
    RLUI.SectionLabel("STATUS").Reparent(body);
    RLUI.WrappedText(this.m_summary, 34, n"MainColors.Blue", 1900.0).Reparent(body);
    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 40.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddActionCard(actions, n"resume", "RESUME", "Back to the fight", n"MainColors.Blue");
    this.AddAbandonCard(actions);
  }

  // --- Door picker -------------------------------------------------------------------------
  // One card per door: the reward, the threat, where and against whom.

  private func BuildDoorPicker(body: ref<inkCompoundWidget>) {
    RLUI.Text(this.m_summary, 32, n"MainColors.Red", true).Reparent(body);
    let hint = ArraySize(this.m_doors) == 1
      ? "The first fight is picked for you. From here on you choose the reward - bigger rewards mean harder fights."
      : "Pick the reward you want. The reward sets the fight: training is light, chrome and iconics are heavy.";
    RLUI.WrappedText(hint, 26, n"MainColors.Grey", 2000.0).Reparent(body);

    let row = RLUI.HPanel(14.0);
    row.SetMargin(inkMargin(0.0, 20.0, 0.0, 10.0));
    row.Reparent(body);
    let count = Max(1, ArraySize(this.m_doors));
    let width = MinF(660.0, (2040.0 / Cast<Float>(count)) - 28.0);
    let i = 0;
    for door in this.m_doors {
      this.AddDoorCard(row, door, i, width);
      i += 1;
    }

    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 16.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddActionCard(actions, n"resume", "NOT YET", "Close the terminal", n"MainColors.Blue");
    this.AddAbandonCard(actions);
  }

  private func AddDoorCard(parent: ref<inkCompoundWidget>, door: ref<RLDoor>, index: Int32, width: Float) {
    let accent = door.boss ? n"MainColors.Red" : RLIcons.CategoryAccent(door.category);
    let card = RLCard.Create(StringToName(s"door_\(index)"), width, 660.0, accent);
    card.SetAtlasIcon(RLIcons.HubAtlas(), RLIcons.CategoryPart(door.category), 104.0);
    card.SetKicker(door.boss ? "BOSS FIGHT" : RLRewards.ThreatName(door.threat));
    card.SetPips(door.threat, 3, RLIcons.ThreatAccent(door.threat));
    card.SetTitle(RLRewards.CategoryName(door.category));
    card.AddLine(RLRewards.CategoryDescription(door.category), n"MainColors.Blue", 28);
    card.AddDivider();
    let arena = RLArenas.Get(door.arena);
    if IsDefined(arena) {
      card.AddLine(arena.name, n"MainColors.Red", 30);
      card.AddLine(arena.area + " - " + RLTerminalPopup.FactionList(arena.factions), n"MainColors.Grey", 24);
    }
    card.AddSpacer(6.0);
    card.AddLine(RLRewards.ThreatDescription(door.threat), n"MainColors.Grey", 24);
    card.SetFooter("Deploy");
    this.Hook(card, parent);
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

  private func AddAbandonCard(parent: ref<inkCompoundWidget>) {
    if this.m_confirmAbandon {
      this.AddActionCard(parent, n"abandon", "CONFIRM ABANDON", "Ends the run as a flatline", n"MainColors.Red");
    } else {
      this.AddActionCard(parent, n"abandon", "ABANDON RUN", "Asks for confirmation", n"MainColors.Red");
    }
  }

  // A wide, short card used for plain actions.
  private func AddActionCard(parent: ref<inkCompoundWidget>, name: CName, const title: String, const kicker: String, accent: CName) -> ref<RLCard> {
    let card = RLCard.Create(name, 560.0, 140.0, accent);
    card.SetCompact();
    card.SetKicker(kicker);
    card.SetTitle(title);
    card.SetTitleSize(40);
    this.Hook(card, parent);
    return card;
  }

  // --- Hub view --------------------------------------------------------------------------------

  private func BuildHub(body: ref<inkCompoundWidget>) {
    let service = RogueliteService.Get();

    // Stats
    let stats = RLUI.HPanel(10.0);
    stats.Reparent(body);
    RLUI.StatTile("CRED", IntToString(service.GetCred()), n"MainColors.Gold").Reparent(stats);
    RLUI.StatTile("RUNS", IntToString(service.GetRunsStarted()), n"MainColors.Blue").Reparent(stats);
    RLUI.StatTile("WINS", IntToString(service.GetVictories()), n"MainColors.Blue").Reparent(stats);
    RLUI.StatTile("BEST FLOOR", IntToString(service.GetBestDepth()), n"MainColors.Blue").Reparent(stats);
    RLUI.StatTile("MODE", service.IsRoguelikeMode() ? "ROGUELIKE" : "ROGUELITE", n"MainColors.Red").Reparent(stats);

    // Kits
    RLUI.SectionLabel("STARTING KIT").Reparent(body);
    let kits = RLUI.HPanel(10.0);
    kits.Reparent(body);
    for kit in RLMeta.Kits() {
      let available = RLMeta.IsKitAvailable(service, kit);
      let selected = Equals(service.GetSelectedKit(), kit);
      let card = RLCard.Create(StringToName("kit_" + NameToString(kit)), 392.0, 256.0, selected ? n"MainColors.ActiveYellow" : n"MainColors.Blue");
      card.SetCompact();
      card.SetAtlasIcon(RLIcons.CommonAtlas(), RLIcons.KitPart(kit), 64.0);
      card.SetKicker(selected ? "SELECTED" : (available ? "KIT" : "LOCKED"));
      card.SetTitle(RLMeta.KitName(kit));
      card.SetTitleSize(36);
      card.AddLine(RLMeta.KitDescription(kit), n"MainColors.Grey", 24);
      card.SetSelected(selected);
      card.SetDisabled(!available);
      this.Hook(card, kits);
    }

    // Main actions
    let actions = RLUI.HPanel(10.0);
    actions.SetMargin(inkMargin(0.0, 14.0, 0.0, 4.0));
    actions.Reparent(body);
    let start = this.AddActionCard(actions, n"start", "START RUN", "Kit: " + RLMeta.KitName(service.GetSelectedKit()), n"MainColors.Red");
    start.SetTitleSize(48);
    this.AddActionCard(actions, n"mode", service.IsRoguelikeMode() ? "SWITCH TO ROGUELITE" : "SWITCH TO ROGUELIKE",
      service.IsRoguelikeMode() ? "Now: no unlock perks, +50% Cred" : "Now: unlock perks active", n"MainColors.Blue");

    // Unlocks: a grid of compact cards
    RLUI.SectionLabel("UNLOCKS").Reparent(body);
    let grid = RLUI.VPanel(5.0);
    grid.Reparent(body);
    let row: ref<inkHorizontalPanel>;
    let i = 0;
    for def in RLMeta.Unlocks() {
      if i % 3 == 0 {
        row = RLUI.HPanel(10.0);
        row.Reparent(grid);
      }
      let owned = service.HasUnlock(def.id);
      let affordable = RLMeta.CanBuy(service, def);
      let card = RLCard.Create(StringToName("buy_" + NameToString(def.id)), 660.0, 140.0, owned ? n"MainColors.Green" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
      card.SetCompact();
      card.SetKicker(owned ? "OWNED" : s"\(def.cost) CRED");
      card.SetTitle(def.name);
      card.SetTitleSize(32);
      card.AddLine(def.description, n"MainColors.Grey", 22);
      card.SetDisabled(owned || !affordable);
      this.Hook(card, row);
      i += 1;
    }
  }

  private func Hook(card: ref<RLCard>, parent: ref<inkCompoundWidget>) {
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.Reparent(parent);
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

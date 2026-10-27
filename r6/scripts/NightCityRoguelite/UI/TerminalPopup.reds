// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, three views:
//   Hub         (home, no run): stats, kit cards (locked ones are bought by
//               clicking them), START RUN, unlocks.
//   DoorPicker  (between fights): one card per door - pick the next fight
//               by its reward; reroll the doors, or abandon.
//   InArena     (during a fight): run status, abandon.
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
  private let m_introPlayed: Bool;
  private let m_content: ref<InGamePopupContent>;
  private let m_confirmAbandon: Bool;

  public static func OpenHub(system: ref<RogueliteSystem>) -> ref<RLTerminalPopup> {
    let none: array<ref<RLDoor>>;
    return RLTerminalPopup.Open(system, RLTerminalView.Hub, "", none);
  }

  public static func OpenDoorPicker(system: ref<RogueliteSystem>, doors: array<ref<RLDoor>>) -> ref<RLTerminalPopup> {
    let run = system.GetRun();
    return RLTerminalPopup.Open(system, RLTerminalView.DoorPicker, IsDefined(run) ? run.FloorLabel() : "", doors);
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
    let header = InGamePopupHeader.Create();
    switch this.m_view {
      case RLTerminalView.DoorPicker:
        this.m_container.SetSize(Vector2(2200.0, 1000.0));
        header.SetTitle(ArraySize(this.m_doors) == 1 ? "YOUR NEXT FIGHT" : "CHOOSE YOUR NEXT FIGHT");
        header.SetFluffRight(this.m_summary);
        break;
      case RLTerminalView.InArena:
        this.m_container.SetSize(Vector2(1800.0, 960.0));
        header.SetTitle("RUN IN PROGRESS");
        header.SetFluffRight("NIGHT CITY ROGUELITE");
        break;
      default:
        this.m_container.SetSize(Vector2(2200.0, 1640.0));
        header.SetTitle("ROGUELITE TERMINAL");
        header.SetFluffRight("NIGHT CITY ROGUELITE");
    }
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Rebuild();
    this.m_introPlayed = true;
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
    RLUI.WrappedText(this.m_summary, 34, n"MainColors.Blue", 1600.0).Reparent(body);
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    if IsDefined(run) && ArraySize(run.boons) > 0 {
      RLUI.SectionLabel("BOONS").Reparent(body);
      for patron in RLPatrons.All() {
        let line = RLTerminalPopup.PatronBoons(run, patron.id);
        if StrLen(line) > 0 {
          RLUI.WrappedText(patron.name + "  " + line, 28, patron.accent, 1600.0).Reparent(body);
        }
      }
    }
    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 40.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddActionCard(actions, n"resume", "RESUME", "", n"MainColors.Blue");
    this.AddActionCard(actions, n"markbug", "MARK BUG", "F8 WORKS TOO", n"MainColors.Grey");
    this.AddAbandonCard(actions);
  }

  // --- Door picker -------------------------------------------------------------------------
  // One card per door: the reward, the threat, where and against whom.

  private func BuildDoorPicker(body: ref<inkCompoundWidget>) {
    let row = RLUI.HPanel(18.0);
    row.SetHAlign(inkEHorizontalAlign.Center);
    row.SetMargin(inkMargin(0.0, 16.0, 0.0, 0.0));
    row.Reparent(body);
    let count = ArraySize(this.m_doors);
    let width = count > 3 ? 470.0 : 540.0;
    let i = 0;
    for door in this.m_doors {
      this.AddDoorCard(row, door, i, width);
      i += 1;
    }

    let actions = RLUI.HPanel(18.0);
    actions.SetHAlign(inkEHorizontalAlign.Center);
    actions.SetMargin(inkMargin(0.0, 28.0, 0.0, 0.0));
    actions.Reparent(body);
    if count > 1 && IsDefined(this.m_system) {
      let reroll = RLRewardPopup.RerollCard(this.m_system);
      this.Hook(reroll, actions);
      this.Intro(reroll, count);
    }
    this.Intro(this.AddAbandonCard(actions), count + 1);
  }

  private func AddDoorCard(parent: ref<inkCompoundWidget>, door: ref<RLDoor>, index: Int32, width: Float) {
    let isPatron = Equals(door.category, RLRewardCategory.Boons) && IsNameValid(door.patron);
    let accent = door.boss ? n"MainColors.Red" : (isPatron ? RLPatrons.Accent(door.patron) : RLIcons.CategoryAccent(door.category));
    let card = RLCard.Create(StringToName(s"door_\(index)"), width, 520.0, accent);
    if isPatron {
      RLIcons.SetPatronIcon(card, door.patron, 104.0);
    } else {
      card.SetAtlasIcon(RLIcons.HubAtlas(), RLIcons.CategoryPart(door.category), 104.0);
    }
    card.SetKicker(door.boss ? "BOSS" : RLRewards.ThreatName(door.threat));
    card.SetPips(door.threat, 3, RLIcons.ThreatAccent(door.threat));
    card.SetTitle(RLRewards.DoorTitle(door));
    if isPatron {
      let patron = RLPatrons.Get(door.patron);
      card.AddLine(IsDefined(patron) ? patron.tagline : "", n"MainColors.Blue", 28);
    } else {
      card.AddLine(RLRewards.CategoryDescription(door.category), n"MainColors.Blue", 28);
    }
    if Equals(door.category, RLRewardCategory.Bounty) {
      card.AddLine("Pays in " + RLPatrons.Name(door.patron) + " boons", n"MainColors.Grey", 26);
    }
    if NotEquals(door.objective, RLObjectiveKind.None) {
      card.AddLine(RLObjectives.Name(door.objective), n"MainColors.Yellow", 28);
    }
    let arena = RLArenas.Get(door.arena);
    if IsDefined(arena) {
      card.AddDivider();
      card.AddLine(arena.name, n"MainColors.Red", 30);
      if Equals(door.category, RLRewardCategory.Bounty) {
        card.AddLine("vs a cyberpsycho", n"MainColors.Grey", 26);
      } else if IsDefined(door.faction) {
        card.AddIconLine(RLIcons.LogoAtlas(), RLIcons.FactionLogo(door.faction.faction), "vs " + RLEncounters.FactionName(door.faction.faction), n"MainColors.Grey", 26);
      } else {
        card.AddLine("vs " + RLTerminalPopup.FactionList(arena.factions), n"MainColors.Grey", 26);
      }
    }
    this.Hook(card, parent);
    this.Intro(card, index);
  }

  private func Intro(card: ref<RLCard>, index: Int32) {
    if !this.m_introPlayed {
      card.PlayIntro(0.08 * Cast<Float>(index));
    }
  }

  public static func FactionList(factions: array<gamedataAffiliation>) -> String {
    let text = "";
    for faction in factions {
      if StrLen(text) > 0 {
        text += ", ";
      }
      text += RLEncounters.FactionName(faction);
    }
    return text;
  }

  // "Kenshin Protocol (RARE), Bushido (COMMON)" - the patron's boons V holds
  // (duos under their first patron).
  public static func PatronBoons(run: ref<RLRunState>, patron: CName) -> String {
    let line = "";
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && Equals(def.patron, patron) {
        let tag = Equals(def.kind, RLBoonKind.Core) ? RLBoons.RarityName(state.rarity) : (Equals(def.kind, RLBoonKind.Duo) ? "DUO" : "LEGENDARY");
        let shown = Equals(def.kind, RLBoonKind.Core) && RLBoons.HighestRarity(def) == 0 ? def.name : def.name + " (" + tag + ")";
        line += (StrLen(line) > 0 ? ", " : "") + shown;
      }
    }
    return line;
  }

  private func AddAbandonCard(parent: ref<inkCompoundWidget>) -> ref<RLCard> {
    return this.m_confirmAbandon
      ? this.AddActionCard(parent, n"abandon", "CONFIRM ABANDON", "COUNTS AS A FLATLINE", n"MainColors.Red")
      : this.AddActionCard(parent, n"abandon", "ABANDON RUN", "", n"MainColors.Red");
  }

  // A wide, short card used for plain actions.
  private func AddActionCard(parent: ref<inkCompoundWidget>, name: CName, const title: String, const kicker: String, accent: CName) -> ref<RLCard> {
    let card = RLCard.Create(name, 420.0, 120.0, accent);
    card.SetCompact();
    card.SetKicker(kicker);
    card.SetTitle(title);
    card.SetTitleSize(36);
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
    RLUI.StatTile("TOTAL KILLS", IntToString(service.GetTotalKills()), n"MainColors.Red").Reparent(stats);

    // Kits (two rows of four): locked kits are bought right here.
    RLUI.SectionLabel("STARTING KIT").Reparent(body);
    let kitRows = RLUI.VPanel(5.0);
    kitRows.Reparent(body);
    let kits: ref<inkHorizontalPanel>;
    let k = 0;
    for kit in RLMeta.Kits() {
      if k % 4 == 0 {
        kits = RLUI.HPanel(10.0);
        kits.Reparent(kitRows);
      }
      k += 1;
      let available = RLMeta.IsKitAvailable(service, kit);
      let selected = Equals(service.GetSelectedKit(), kit);
      let unlock = RLMeta.Get(StringToName("kit." + NameToString(kit)));
      let affordable = IsDefined(unlock) && RLMeta.CanBuy(service, unlock);
      let accent = selected ? n"MainColors.ActiveYellow" : (available ? n"MainColors.Blue" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
      let card = RLCard.Create(StringToName("kit_" + NameToString(kit)), 495.0, 196.0, accent);
      card.SetCompact();
      card.SetAtlasIcon(RLIcons.CommonAtlas(), RLIcons.KitPart(kit), 48.0);
      if selected {
        card.SetKicker("SELECTED");
      } else if available {
        card.SetKicker("KIT");
      } else if IsDefined(unlock) {
        card.SetKicker(affordable ? s"BUY - \(unlock.cost) CRED" : s"LOCKED - \(unlock.cost) CRED");
      } else {
        card.SetKicker("LOCKED");
      }
      card.SetTitle(RLMeta.KitName(kit));
      card.SetTitleSize(32);
      card.AddLine(RLMeta.KitDescription(kit), n"MainColors.Grey", 22);
      card.SetSelected(selected);
      card.SetDisabled(!available && !affordable);
      this.Hook(card, kits);
    }

    // Start
    let actions = RLUI.HPanel(10.0);
    actions.SetMargin(inkMargin(0.0, 14.0, 0.0, 4.0));
    actions.Reparent(body);
    let start = this.AddActionCard(actions, n"start", "START RUN", "KIT: " + RLMeta.KitName(service.GetSelectedKit()), n"MainColors.Red");
    start.SetTitleSize(48);
    // Assist mode (Hades' God Mode): less damage taken, a little more with
    // every run lost while it is on.
    let reduction = RoundF(service.AssistReduction() * 100.0);
    let assist = this.AddActionCard(actions, n"assist",
      service.IsAssistOn() ? "ASSIST: ON" : "ASSIST: OFF",
      s"\(reduction)% LESS DAMAGE TAKEN",
      service.IsAssistOn() ? n"MainColors.Green" : n"MainColors.Grey");
    assist.SetSelected(service.IsAssistOn());
    // Test runs: start on any floor to try a boss, an act or the new door
    // types without playing up to it. No Cred, no stats.
    this.AddActionCard(actions, n"test_floor", s"FLOOR \(service.GetTestFloor())", "TEST RUN FROM", n"MainColors.Grey");
    this.AddActionCard(actions, n"test_start", "TEST RUN", "NO CRED, NO STATS", n"MainColors.Grey");

    // Unlocks (kits are bought from the kit rows): a 5-column grid.
    RLUI.SectionLabel("UNLOCKS").Reparent(body);
    let grid = RLUI.VPanel(5.0);
    grid.Reparent(body);
    let row: ref<inkHorizontalPanel>;
    let i = 0;
    for def in RLMeta.Unlocks() {
      if !StrBeginsWith(NameToString(def.id), "kit.") {
        if i % 5 == 0 {
          row = RLUI.HPanel(8.0);
          row.Reparent(grid);
        }
        let owned = service.HasUnlock(def.id);
        let affordable = RLMeta.CanBuy(service, def);
        let card = RLCard.Create(StringToName("buy_" + NameToString(def.id)), 398.0, 124.0, owned ? n"MainColors.Green" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
        card.SetCompact();
        card.SetKicker(owned ? "OWNED" : s"\(def.cost) CRED");
        card.SetTitle(def.name);
        card.SetTitleSize(28);
        card.AddLine(def.description, n"MainColors.Grey", 20);
        card.SetDisabled(owned || !affordable);
        this.Hook(card, row);
        i += 1;
      }
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
    } else if Equals(name, "markbug") {
      this.Close();
      this.m_system.MarkBug();
    } else if Equals(name, "abandon") {
      if this.m_confirmAbandon {
        this.Close();
        this.m_system.AbandonRun();
      } else {
        this.m_confirmAbandon = true;
        this.Rebuild();
      }
    } else if Equals(name, "reroll") {
      this.Close();
      this.m_system.OnDoorReroll();
    } else if StrBeginsWith(name, "door_") {
      this.Close();
      this.m_system.DeployToDoor(StringToInt(StrAfterFirst(name, "_")));
    } else if Equals(name, "start") {
      this.Close();
      this.m_system.StartRun(service.GetSelectedKit());
    } else if Equals(name, "test_floor") {
      service.CycleTestFloor();
      this.Rebuild();
    } else if Equals(name, "test_start") {
      this.Close();
      this.m_system.StartRun(service.GetSelectedKit(), service.GetTestFloor());
    } else if Equals(name, "assist") {
      service.SetAssist(!service.IsAssistOn());
      this.Rebuild();
    } else if StrBeginsWith(name, "kit_") {
      let kit = StringToName(StrAfterFirst(name, "_"));
      if !RLMeta.IsKitAvailable(service, kit) {
        if !RLMeta.TryBuy(service, StringToName("kit." + NameToString(kit))) {
          return false;
        }
        this.PlaySound(n"Item", n"OnBuy");
      }
      service.SetSelectedKit(kit);
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

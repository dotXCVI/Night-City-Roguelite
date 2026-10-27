// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, three views:
//   Hub         (home, no run): stats, START RUN, the kit (picked in the
//               armory, UI/ArmoryPopup.reds), assist, test runs, the guide,
//               upgrades.
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
        this.m_container.SetSize(Vector2(2200.0, 1180.0));
        header.SetTitle(ArraySize(this.m_doors) == 1 ? "NEXT FIGHT" : "PICK YOUR FIGHT");
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
    body.SetMargin(RLUI.ContentMargin());
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
    let styles = RLStyles.Summary(run, 5);
    if StrLen(styles) > 0 {
      RLUI.SectionLabel("STYLES").Reparent(body);
      RLUI.WrappedText(styles, 28, n"MainColors.Gold", 1600.0).Reparent(body);
    }
    if IsDefined(run) && run.overdriveUnlocked {
      RLUI.SectionLabel("OVERDRIVE").Reparent(body);
      RLUI.WrappedText(RLOverdrive.Status(run) + " - " + RLOverdrive.Description(run.os), 28, n"MainColors.Blue", 1600.0).Reparent(body);
    }
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
    let card = RLCard.Create(StringToName(s"door_\(index)"), width, 700.0, accent);
    // The art is where the fight is; the badge is what it pays.
    card.SetCompact();
    card.SetBanner(IsDefined(RLArenas.Get(door.arena)) && NotEquals(door.category, RLRewardCategory.Event) ? RLArts.Arena(door.arena) : RLArts.Category(door.category));
    if isPatron {
      let patron = RLPatrons.Get(door.patron);
      card.SetBadge(IsDefined(patron) && patron.isLogo ? RLIcons.LogoAtlas() : RLIcons.HubAtlas(), IsDefined(patron) ? patron.iconPart : n"ico_tarot");
    } else {
      card.SetBadge(RLIcons.HubAtlas(), RLIcons.CategoryPart(door.category));
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
      if StrLen(arena.terrain) > 0 {
        card.AddLine(arena.terrain, n"MainColors.Blue", 24);
      }
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
    RLUI.StatTile("BODY COUNT", IntToString(service.GetTotalKills()), n"MainColors.Red").Reparent(stats);

    // The run, the kit it starts with, and the small switches.
    let main = RLUI.HPanel(9.0);
    main.SetMargin(inkMargin(0.0, 14.0, 0.0, 4.0));
    main.Reparent(body);

    let kit = service.GetSelectedKit();
    let start = RLCard.Create(n"start", 760.0, 600.0, n"MainColors.Red");
    start.SetCompact();
    start.SetBanner(RLArts.City());
    start.SetKicker("THREE ACTS - EIGHTEEN FIGHTS");
    start.SetTitle("START RUN");
    start.SetTitleSize(60);
    this.Hook(start, main);
    this.Intro(start, 0);

    // Kits are picked at the armory stash; the card opens the same screen.
    let reachable = IsDefined(this.m_system) && this.m_system.IsArmoryReachable();
    let kitCard = RLCard.Create(n"kit", 520.0, 600.0, n"MainColors.ActiveYellow");
    kitCard.SetCompact();
    kitCard.SetBanner(RLArts.Kit(kit));
    kitCard.SetBadge(RLIcons.CommonAtlas(), RLIcons.KitPart(kit));
    kitCard.SetKicker("YOUR KIT");
    kitCard.SetTitle(RLMeta.KitName(kit));
    kitCard.SetTitleSize(40);
    kitCard.AddLine(RLMeta.KitTagline(kit), n"MainColors.ActiveWhite", 24);
    kitCard.AddLine(RLMeta.KitDescription(kit), n"MainColors.Grey", 22);
    kitCard.AddLine(reachable ? "Swap it at the armory stash, in the back." : "Click to swap.", n"MainColors.Blue", 22);
    this.Hook(kitCard, main);
    this.Intro(kitCard, 1);

    let side = RLUI.VPanel(5.0);
    side.Reparent(main);
    // Assist mode (Hades' God Mode): less damage taken, a little more with
    // every run lost while it is on.
    let reduction = RoundF(service.AssistReduction() * 100.0);
    let assist = this.AddActionCard(side, n"assist",
      service.IsAssistOn() ? "ASSIST: ON" : "ASSIST: OFF",
      s"TAKE \(reduction)% LESS DAMAGE",
      service.IsAssistOn() ? n"MainColors.Green" : n"MainColors.Grey");
    assist.SetSelected(service.IsAssistOn());
    // Test runs: start on any floor to try a boss, an act or the new door
    // types without playing up to it. No Cred, no stats.
    this.AddActionCard(side, n"test_floor", s"FLOOR \(service.GetTestFloor())", "TEST RUN STARTS ON", n"MainColors.Grey");
    this.AddActionCard(side, n"test_start", "TEST RUN", "NO CRED, NO STATS", n"MainColors.Grey");
    this.AddActionCard(side, n"guide", "HOW IT WORKS", "THE BASICS", n"MainColors.Blue");

    // Unlocks (kits are bought in the armory): a 5-column grid.
    RLUI.SectionLabel("UPGRADES - PAID IN CRED, KEPT FOREVER").Reparent(body);
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
        let card = RLCard.Create(StringToName("buy_" + NameToString(def.id)), 392.0, 124.0, owned ? n"MainColors.Green" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
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
    } else if Equals(name, "kit") {
      this.Close();
      this.m_system.OpenArmoryLater();
    } else if Equals(name, "guide") {
      this.Close();
      this.m_system.OpenGuideLater();
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

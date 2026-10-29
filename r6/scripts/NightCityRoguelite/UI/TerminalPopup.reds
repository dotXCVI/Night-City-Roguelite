// -----------------------------------------------------------------------------
// Night City Roguelite - terminal
// -----------------------------------------------------------------------------
// One popup, five views:
//   Hub         (home, no run): stats, START RUN, the kit (picked in the
//               armory, UI/ArmoryPopup.reds), assist, the database, the
//               guide, the way into the upgrades. Test runs show up only
//               with RLConfig.DevTools.
//   Upgrades    (home): the ten rows of Meta/Terminal.reds, one strip each -
//               the row and its rank, its two takes (the one on is lit; the
//               other switches on for free), and the next rank's price. A
//               rank out of reach shakes instead of greying out.
//   DoorPicker  (between fights): one card per door - pick the next fight
//               by what it pays (the reward leads, the arena is a strip at
//               the bottom); HOT doors are marked and pulse. Reroll the
//               doors, or abandon.
//   InArena     (during a fight): run status, the database, abandon.
//   Database    (from the hub, the door picker or a fight): every keyword,
//               term, effect, mod and quickhack (UI/Database.reds), a tab
//               column on the left; BACK returns to the view it came from.
// Everything clickable is an RLCard (UI/Card.reds).
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public enum RLTerminalView {
  Hub = 0,
  DoorPicker = 1,
  InArena = 2,
  Upgrades = 3,
  Database = 4,
}

public class RLTerminalPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_view: RLTerminalView;
  private let m_summary: String;
  private let m_doors: array<ref<RLDoor>>;
  private let m_introPlayed: Bool;
  private let m_content: ref<InGamePopupContent>;
  private let m_header: ref<InGamePopupHeader>;
  private let m_confirmAbandon: Bool;
  // The database: the open tab, and the view BACK returns to.
  private let m_dbTab: CName;
  private let m_dbReturn: RLTerminalView;
  // The open tab's entries, their rows in the list, the one clicked (shown
  // when the cursor isn't on a row) and the panel the entry is read in.
  private let m_dbEntries: array<ref<RLDbEntry>>;
  private let m_dbRows: array<wref<RLCard>>;
  private let m_dbPinned: Int32;
  private let m_dbHover: Int32;
  private let m_dbDetail: wref<inkCanvas>;

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
    if IsDefined(this.m_system) {
      this.m_system.OnScreenShown();
    }
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetFluffLeft("");
    this.m_header.Reparent(this);
    this.FitView();

    let footer = InGamePopupFooter.Create();
    if Equals(this.m_view, RLTerminalView.DoorPicker) {
      footer.SetFluffText("EVERY WIN ALSO PAYS EDDIES");
    } else if Equals(this.m_view, RLTerminalView.InArena) {
      footer.SetFluffText("F8 MARKS A BUG FOR THE LOG");
    }
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.Rebuild();
    this.m_introPlayed = true;
    RLLog("Terminal menu: built.");
  }

  // The container and the header for the current view.
  private func FitView() {
    switch this.m_view {
      case RLTerminalView.DoorPicker:
        this.m_container.SetSize(Vector2(2200.0, 1200.0));
        this.m_header.SetTitle(ArraySize(this.m_doors) == 1 ? "NEXT FIGHT" : "PICK YOUR FIGHT");
        this.m_header.SetFluffRight(this.m_summary);
        break;
      case RLTerminalView.InArena:
        this.m_container.SetSize(Vector2(1800.0, 960.0));
        this.m_header.SetTitle("RUN IN PROGRESS");
        this.m_header.SetFluffRight("NIGHT CITY ROGUELITE");
        break;
      case RLTerminalView.Upgrades:
        this.m_container.SetSize(Vector2(2200.0, 1680.0));
        this.m_header.SetTitle("UPGRADES");
        this.m_header.SetFluffRight(s"\(RogueliteService.Get().GetCred()) CRED");
        break;
      case RLTerminalView.Database:
        this.m_container.SetSize(Vector2(2200.0, 1700.0));
        this.m_header.SetTitle("DATABASE");
        let tab = RLDatabase.GetTab(this.m_dbTab);
        this.m_header.SetFluffRight(IsDefined(tab) ? tab.label : "");
        break;
      default:
        this.m_container.SetSize(Vector2(2200.0, 1120.0));
        this.m_header.SetTitle("ROGUELITE TERMINAL");
        this.m_header.SetFluffRight("NIGHT CITY ROGUELITE");
    }
  }

  // Hub and Upgrades swap in place; the new view plays its intro.
  private func SwitchView(view: RLTerminalView) {
    this.m_view = view;
    this.m_introPlayed = false;
    this.FitView();
    this.Rebuild();
    this.m_introPlayed = true;
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
      case RLTerminalView.Upgrades:
        this.BuildUpgrades(body);
        break;
      case RLTerminalView.Database:
        this.BuildDatabase(body);
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
    if IsDefined(run) {
      RLUI.SectionLabel("YOUR RUN").Reparent(body);
      RLUI.WrappedText(s"MAIN: \(RLRewards.ItemName(RLWeapons.MainRecord(run))) (\(RLQuality.DisplayName(run.mainStep)))   COVER: \(run.cover)/\(run.coverMax)", 28, n"MainColors.Blue", 1600.0).Reparent(body);
      let mods = RLArmMods.Summary(run);
      if StrLen(mods) > 0 || StrLen(run.mainElement) > 0 {
        RLUI.WrappedText((StrLen(run.mainElement) > 0 ? RLArms.ElementName(run.mainElement) + "   " : "") + mods, 28, n"MainColors.ActiveYellow", 1600.0).Reparent(body);
      }
      if run.mainSignature && RLArms.IsMainChrome(run) {
        RLUI.WrappedText(RLSignatures.Line(RLArmMods.MainFamily(run)), 28, n"MainColors.Gold", 1600.0).Reparent(body);
      }
      if RLArms.IsMainDeck(run) {
        let hacks = RLHacks.Summary(GetPlayer(GetGameInstance()));
        if StrLen(hacks) > 0 {
          RLUI.WrappedText("QUICKHACKS: " + hacks, 28, n"MainColors.Green", 1600.0).Reparent(body);
        }
      }
    }
    if IsDefined(run) && ArraySize(run.boons) > 0 {
      RLUI.SectionLabel("EFFECTS").Reparent(body);
      for patron in run.patrons {
        let line = RLTerminalPopup.PatronEffects(run, patron);
        if StrLen(line) > 0 {
          RLUI.WrappedText(RLPatrons.Name(patron) + "  " + line, 28, RLPatrons.Accent(patron), 1600.0).Reparent(body);
        }
      }
    }
    let actions = RLUI.HPanel(14.0);
    actions.SetMargin(inkMargin(0.0, 40.0, 0.0, 0.0));
    actions.Reparent(body);
    this.AddActionCard(actions, n"resume", "RESUME", "", n"MainColors.Blue");
    this.AddActionCard(actions, n"database", "DATABASE", "WHAT EVERYTHING DOES", n"MainColors.ActiveWhite");
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
      let reroll = RLRewardPopup.RerollCard(this.m_system, false);
      this.Hook(reroll, actions);
      this.Intro(reroll, count);
    }
    this.Intro(this.AddActionCard(actions, n"database", "DATABASE", "WHAT EVERYTHING DOES", n"MainColors.ActiveWhite"), count + 1);
    this.Intro(this.AddAbandonCard(actions), count + 2);
  }

  // The reward leads: its picture and badge, what it pays in plain words.
  // Where and against whom sits at the bottom.
  private func AddDoorCard(parent: ref<inkCompoundWidget>, door: ref<RLDoor>, index: Int32, width: Float) {
    let isPatron = Equals(door.category, RLRewardCategory.Boons) && IsNameValid(door.patron);
    let accent = door.boss || door.hot ? n"MainColors.Red" : (isPatron ? RLPatrons.Accent(door.patron) : RLIcons.CategoryAccent(door.category));
    let card = RLCard.Create(StringToName(s"door_\(index)"), width, 760.0, accent);
    card.SetCompact();
    card.SetBanner(isPatron ? RLArts.Patron(door.patron) : RLArts.Category(door.category));
    if isPatron {
      let patron = RLPatrons.Get(door.patron);
      card.SetBadge(IsDefined(patron) && patron.isLogo ? RLIcons.LogoAtlas() : RLIcons.HubAtlas(), IsDefined(patron) ? patron.iconPart : n"ico_tarot");
    } else {
      card.SetBadge(RLIcons.HubAtlas(), RLIcons.CategoryPart(door.category));
    }
    if door.hot {
      card.SetHot();
    }
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    card.SetKicker(door.boss ? "BOSS" : (isPatron ? RLTerminalPopup.KeywordLine(door.patron) : RLRewards.CategoryDescription(door.category)));
    card.SetTitle(RLRewards.DoorTitle(door));
    card.SetTitleSize(44);
    card.AddLine(RLRewards.DoorPromise(run, door, IsDefined(run) ? RLRewards.DoorCardCount(run, door) : 3), n"MainColors.ActiveWhite", 30);
    if door.hot {
      card.AddLine("Double the trouble, double the take: an elite pack and a lieutenant, cards two steps up, +50% eddies.", n"MainColors.Red", 26);
    }
    if isPatron && IsDefined(run) {
      let held = RLBoons.CountForPatron(run, door.patron);
      if held > 0 {
        card.AddLine(held >= 3 ? s"You hold \(held). Their favour is yours." : s"You hold \(held). Three earns their favour.", n"MainColors.Gold", 24);
      }
    }
    if NotEquals(door.objective, RLObjectiveKind.None) {
      card.AddLine(RLObjectives.Name(door.objective) + " - " + RLObjectives.Description(door.objective), n"MainColors.Yellow", 24);
    }
    let nemesis = RLNemeses.Get(door.nemesis);
    if IsDefined(nemesis) {
      card.AddLine(nemesis.RankTitle() + ": " + nemesis.FullName() + ". " + nemesis.Threat(), n"MainColors.Red", 24);
    }
    // An act's first doors: where the act goes, and where it ends.
    let route = RLRoutes.Get(door.route);
    if IsDefined(route) {
      let landmark = RLArenas.Get(door.routeBoss);
      card.AddLine("ROUTE: " + route.name + (IsDefined(landmark) ? ". The boss waits at " + landmark.name + "." : "."), n"MainColors.Blue", 24);
    }
    let arena = RLArenas.Get(door.arena);
    if IsDefined(arena) {
      card.AddDivider();
      card.AddLine(arena.name, n"MainColors.Grey", 26);
      if Equals(door.category, RLRewardCategory.Bounty) {
        card.AddLine("vs a cyberpsycho", n"MainColors.Grey", 24);
      } else if IsDefined(door.faction) {
        card.AddIconLine(RLIcons.LogoAtlas(), RLIcons.FactionLogo(door.faction.faction), "vs " + RLEncounters.FactionName(door.faction.faction), n"MainColors.Grey", 24);
      } else {
        card.AddLine("vs " + RLTerminalPopup.FactionList(arena.factions), n"MainColors.Grey", 24);
      }
    }
    this.Hook(card, parent);
    this.Intro(card, index);
  }

  // "MARK - FOCUS": a patron's two keywords.
  public static func KeywordLine(patron: CName) -> String {
    let text = "";
    for keyword in RLPatrons.Keywords(patron) {
      text += (StrLen(text) > 0 ? " - " : "") + NameToString(keyword);
    }
    return text;
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

  // "Arc Flash+, Feedback Loop, Ghost Shot (DUO)" - the effects V holds from
  // a patron (duos under their first patron).
  public static func PatronEffects(run: ref<RLRunState>, patron: CName) -> String {
    let line = "";
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && Equals(def.patron, patron) {
        let kind = RLBoons.CountsForPatron(def) ? "" : " (" + RLBoons.KindName(def.kind) + ")";
        line += (StrLen(line) > 0 ? ", " : "") + RLBoons.HeldName(state) + kind;
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
  private func AddActionCard(parent: ref<inkCompoundWidget>, name: CName, const title: String, const kicker: String, accent: CName, opt height: Float, opt width: Float) -> ref<RLCard> {
    let card = RLCard.Create(name, width > 0.0 ? width : 420.0, height > 0.0 ? height : 120.0, accent);
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

    // Stats: six tiles across the content's width (2124 = 2200 less the
    // inset; each tile carries 10 either side).
    let stats = RLUI.HPanel(10.0);
    stats.Reparent(body);
    let tile = 334.0;
    RLUI.StatTile("CRED", IntToString(service.GetCred()), n"MainColors.Gold", tile).Reparent(stats);
    RLUI.StatTile("FAVORS", IntToString(service.GetFavors()), n"MainColors.ActiveYellow", tile).Reparent(stats);
    RLUI.StatTile("RUNS", IntToString(service.GetRunsStarted()), n"MainColors.Blue", tile).Reparent(stats);
    RLUI.StatTile("WINS", IntToString(service.GetVictories()), n"MainColors.Blue", tile).Reparent(stats);
    RLUI.StatTile("BEST FLOOR", IntToString(service.GetBestDepth()), n"MainColors.Blue", tile).Reparent(stats);
    RLUI.StatTile("BODY COUNT", IntToString(service.GetTotalKills()), n"MainColors.Red", tile).Reparent(stats);

    // The run, the kit it starts with, and the small switches, filling the
    // same width; the developer's cards take a column of their own.
    let main = RLUI.HPanel(9.0);
    main.SetMargin(inkMargin(0.0, 14.0, 0.0, 4.0));
    main.Reparent(body);
    let dev = RLConfig.DevTools();
    let tall = 660.0;

    let kit = service.GetSelectedKit();
    // The banner art is 16:9 at the card's width, so the card's width sets
    // how much room is left under it: the line-up goes two to a row.
    let start = RLCard.Create(n"start", 700.0, tall, n"MainColors.Red");
    start.SetCompact();
    start.SetBanner(RLArts.City());
    start.SetKicker("THREE ACTS - EIGHTEEN FIGHTS");
    start.SetTitle("START RUN");
    start.SetTitleSize(54);
    if IsDefined(this.m_system) {
      start.AddLine("IN TOWN THIS RUN", n"MainColors.Grey", 20);
      let atlases: array<ResRef>;
      let parts: array<CName>;
      let texts: array<String>;
      let colors: array<CName>;
      for id in this.m_system.GetLineup() {
        let patron = RLPatrons.Get(id);
        if IsDefined(patron) {
          ArrayPush(atlases, patron.isLogo ? RLIcons.LogoAtlas() : RLIcons.HubAtlas());
          ArrayPush(parts, patron.iconPart);
          ArrayPush(texts, patron.name + "  " + RLTerminalPopup.KeywordLine(id));
          ArrayPush(colors, patron.accent);
        }
      }
      start.AddIconGrid(atlases, parts, texts, colors, 20, 2);
    }
    this.Hook(start, main);
    this.Intro(start, 0);

    // Kits are picked at the armory stash; the card opens the same screen.
    let reachable = IsDefined(this.m_system) && this.m_system.IsArmoryReachable();
    let kitCard = RLCard.Create(n"kit", dev ? 540.0 : 700.0, tall, n"MainColors.ActiveYellow");
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

    // The column beside them fills the same height with four cards.
    let gap = 12.0;
    let height = (tall - gap * 3.0) / 4.0;
    let width = dev ? 400.0 : 668.0;
    let side = RLUI.VPanel(gap);
    side.Reparent(main);
    // Assist mode (Hades' God Mode): less damage taken, a little more with
    // every run lost while it is on.
    let reduction = RoundF(service.AssistReduction() * 100.0);
    let assist = this.AddActionCard(side, n"assist",
      service.IsAssistOn() ? "ASSIST: ON" : "ASSIST: OFF",
      s"TAKE \(reduction)% LESS DAMAGE",
      service.IsAssistOn() ? n"MainColors.Green" : n"MainColors.Grey", height, width);
    assist.SetSelected(service.IsAssistOn());
    this.Intro(assist, 2);
    this.Intro(this.AddActionCard(side, n"database", "DATABASE", "WHAT EVERYTHING DOES", n"MainColors.ActiveWhite", height, width), 3);
    this.Intro(this.AddActionCard(side, n"guide", "HOW IT WORKS", "THE BASICS", n"MainColors.Blue", height, width), 4);
    RLTerminal.Migrate(service);
    this.Intro(this.AddActionCard(side, n"upgrades", "UPGRADES", s"\(service.GetCred()) CRED TO SPEND", n"MainColors.Gold", height, width), 5);
    // Test runs and the arena scout (developers): start on any floor to try
    // a boss, an act or the new door types without playing up to it.
    if dev {
      let devHeight = (tall - gap * 3.0) / 4.0;
      let tools = RLUI.VPanel(gap);
      tools.Reparent(main);
      this.AddActionCard(tools, n"test_floor", s"FLOOR \(service.GetTestFloor())", "TEST RUN STARTS ON", n"MainColors.Grey", devHeight, width);
      this.AddActionCard(tools, n"test_start", "TEST RUN", "NO CRED, NO STATS", n"MainColors.Grey", devHeight, width);
      let landmarks = RLArenaScout.List(true);
      this.AddActionCard(tools, n"scout_landmarks", "SCOUT LANDMARKS", s"\(ArraySize(landmarks)) STORY SITES", n"MainColors.Grey", devHeight, width);
      let surveyed = service.IsSurveyDone() ? "ALL" : IntToString(service.GetSurveyNext());
      this.AddActionCard(tools, n"survey", "SURVEY CITY", s"\(surveyed) OF \(RLCitySurvey.Total()) DONE", n"MainColors.Grey", devHeight, width);
    }
  }

  // --- Database view ---------------------------------------------------------------------------

  // Opens the database from the current view; BACK comes back to it.
  private func OpenDatabase() {
    this.m_dbReturn = this.m_view;
    if !IsNameValid(this.m_dbTab) {
      this.m_dbTab = n"keywords";
    }
    this.SwitchView(RLTerminalView.Database);
  }

  // Like Hades' Codex: the tabs on the left, the open tab's entries as a
  // list of names in the middle, and the one under the cursor (or the one
  // clicked) in full on the right.
  private func BuildDatabase(body: ref<inkCompoundWidget>) {
    let height = 1360.0;
    let split = RLUI.HPanel(12.0);
    split.Reparent(body);

    let column = RLUI.VPanel(4.0);
    column.Reparent(split);
    let back = this.AddActionCard(column, n"back", "BACK", "", n"MainColors.Blue", 76.0, 300.0);
    back.HideKicker();
    let group = "";
    let i = 1;
    for tab in RLDatabase.Tabs() {
      if NotEquals(tab.group, group) {
        group = tab.group;
        RLTerminalPopup.DbGroupLabel(group, 300.0).Reparent(column);
      }
      let on = Equals(tab.id, this.m_dbTab);
      let card = RLCard.Create(StringToName("db_" + NameToString(tab.id)), 300.0, 56.0, on ? tab.accent : n"MainColors.Grey");
      card.SetCompact();
      card.HideKicker();
      card.SetTitle(tab.label);
      card.SetTitleSize(24);
      card.SetSelected(on);
      this.Hook(card, column);
      this.Intro(card, i);
      i += 1;
    }

    let tab = RLDatabase.GetTab(this.m_dbTab);
    if !IsDefined(tab) {
      return;
    }
    this.m_dbEntries = RLDatabase.Entries(tab.id);
    ArrayClear(this.m_dbRows);
    this.m_dbPinned = Clamp(this.m_dbPinned, 0, Max(ArraySize(this.m_dbEntries) - 1, 0));

    // The list: the tab's name and what's in it, then the entries by group.
    let listWidth = 560.0;
    let list = RLUI.VPanel(3.0);
    list.Reparent(split);
    RLUI.Text(tab.label, 40, tab.accent, true).Reparent(list);
    RLUI.WrappedText(tab.intro, 22, n"MainColors.Grey", listWidth).Reparent(list);
    let groups = 0;
    group = "";
    for entry in this.m_dbEntries {
      if NotEquals(entry.group, group) {
        group = entry.group;
        groups += 1;
      }
    }
    // Rows share what's left of the height with the group headings.
    let count = Max(ArraySize(this.m_dbEntries), 1);
    let rowHeight = ClampF((height - 130.0 - 40.0 * Cast<Float>(groups)) / Cast<Float>(count) - 6.0, 46.0, 64.0);
    this.m_dbHover = -1;
    group = "";
    let n = 0;
    for entry in this.m_dbEntries {
      if NotEquals(entry.group, group) {
        group = entry.group;
        RLTerminalPopup.DbGroupLabel(group, listWidth).Reparent(list);
      }
      let row = RLCard.Create(StringToName("dbrow_" + IntToString(n)), listWidth, rowHeight, entry.accent);
      row.SetTight();
      row.HideKicker();
      row.SetTitle(entry.title);
      row.SetTitleSize(rowHeight < 52.0 ? 22 : (rowHeight < 58.0 ? 24 : 26));
      row.SetSelected(n == this.m_dbPinned);
      row.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
      row.RegisterToCallback(n"OnCardHoverOn", this, n"OnDbRowHoverOn");
      row.RegisterToCallback(n"OnCardHoverOff", this, n"OnDbRowHoverOff");
      row.Reparent(list);
      if !this.m_introPlayed {
        row.PlayIntro(0.03 * Cast<Float>(n));
      }
      ArrayPush(this.m_dbRows, row);
      n += 1;
    }

    // The entry, read in full.
    let detail = new inkCanvas();
    detail.SetSize(Vector2(2124.0 - 300.0 - listWidth - 72.0, height));
    detail.Reparent(split);
    this.m_dbDetail = detail;
    this.ShowDbEntry(this.m_dbPinned);
  }

  private static func DbGroupLabel(const label: String, width: Float) -> ref<inkWidget> {
    let panel = new inkVerticalPanel();
    panel.SetFitToContent(true);
    panel.SetMargin(inkMargin(4.0, 12.0, 0.0, 2.0));
    let text = RLUI.Text(label, 20, n"MainColors.Grey", true);
    text.SetLetterCase(textLetterCase.UpperCase);
    text.Reparent(panel);
    let rule = new inkRectangle();
    rule.SetSize(Vector2(width - 4.0, 2.0));
    rule.SetOpacity(0.2);
    rule.SetStyle(RLUI.Style());
    rule.BindProperty(n"tintColor", n"MainColors.Grey");
    rule.SetMargin(inkMargin(0.0, 2.0, 0.0, 0.0));
    rule.Reparent(panel);
    return panel;
  }

  // Rebuilds the reading panel for entry `index`.
  private func ShowDbEntry(index: Int32) {
    let detail = this.m_dbDetail;
    if !IsDefined(detail) || index < 0 || index >= ArraySize(this.m_dbEntries) {
      return;
    }
    detail.RemoveAllChildren();
    let entry = this.m_dbEntries[index];
    let size = detail.GetSize();
    let card = RLCard.Create(n"db_detail", size.X, size.Y, entry.accent);
    card.SetKicker(entry.kicker);
    card.SetTitle(entry.title);
    card.SetTitleSize(56);
    card.AddSpacer(10.0);
    card.AddLine(entry.text, n"MainColors.ActiveWhite", 32);
    let i = 0;
    while i < ArraySize(entry.sectionLabels) {
      card.AddSpacer(22.0);
      let label = card.AddLine(entry.sectionLabels[i], n"MainColors.Grey", 22);
      label.SetFontStyle(n"Semi-Bold");
      label.SetLetterCase(textLetterCase.UpperCase);
      card.AddLine(entry.sectionTexts[i], entry.sectionColors[i], 28);
      i += 1;
    }
    if ArraySize(entry.chips) > 0 {
      card.AddSpacer(22.0);
      card.AddChips(entry.chips, entry.chipColors);
    }
    card.SetStatic();
    card.Reparent(detail);
  }

  private func DbRowIndex(widget: wref<inkWidget>) -> Int32 {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) {
      return -1;
    }
    let name = NameToString(button.GetName());
    if !StrBeginsWith(name, "dbrow_") {
      return -1;
    }
    return StringToInt(StrAfterFirst(name, "_"));
  }

  protected cb func OnDbRowHoverOn(widget: wref<inkWidget>) -> Bool {
    let index = this.DbRowIndex(widget);
    if index >= 0 {
      this.m_dbHover = index;
      this.ShowDbEntry(index);
    }
    return true;
  }

  // Back to the clicked entry - unless the cursor has already moved on to
  // another row (its hover can arrive first).
  protected cb func OnDbRowHoverOff(widget: wref<inkWidget>) -> Bool {
    if this.m_dbHover == this.DbRowIndex(widget) {
      this.m_dbHover = -1;
      this.ShowDbEntry(this.m_dbPinned);
    }
    return true;
  }

  // A click keeps an entry up when the cursor leaves the list.
  private func PinDbEntry(index: Int32) {
    this.m_dbPinned = index;
    let i = 0;
    while i < ArraySize(this.m_dbRows) {
      if IsDefined(this.m_dbRows[i]) {
        this.m_dbRows[i].SetSelected(i == index);
      }
      i += 1;
    }
    this.ShowDbEntry(index);
  }

  // --- Upgrades view ---------------------------------------------------------------------------

  private func BuildUpgrades(body: ref<inkCompoundWidget>) {
    let service = RogueliteService.Get();
    let top = RLUI.HPanel(10.0);
    top.Reparent(body);
    this.AddActionCard(top, n"back", "BACK", "TO THE TERMINAL", n"MainColors.Blue", 100.0);
    let note = RLUI.Text("Ranks are bought once per row and serve either take. The lit take is on; switching is free.", 24, n"MainColors.Grey");
    note.SetVAlign(inkEVerticalAlign.Center);
    note.SetMargin(inkMargin(20.0, 0.0, 0.0, 0.0));
    note.Reparent(top);
    let list = RLUI.VPanel(5.0);
    list.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
    list.Reparent(body);
    let i = 0;
    for row in RLTerminal.Rows() {
      this.AddUpgradeRow(list, service, row, i);
      i += 1;
    }
  }

  // Ten rows and the BACK bar fit the screen with the header showing.
  public static func UpgradeRowHeight() -> Float = 126.0

  // One strip: the row and its rank, both takes, the next rank.
  private func AddUpgradeRow(parent: ref<inkCompoundWidget>, service: ref<RogueliteService>, row: ref<RLRow>, index: Int32) {
    let strip = RLUI.HPanel(10.0);
    strip.Reparent(parent);
    let rank = RLTerminal.Rank(service, row.id);
    let max = ArraySize(row.costs);

    let label = RLCard.Create(StringToName("rowlabel_" + NameToString(row.id)), 250.0, RLTerminalPopup.UpgradeRowHeight(), n"MainColors.Grey");
    label.SetCompact();
    label.SetKicker(s"RANK \(rank)/\(max)");
    label.SetPips(rank, max, n"MainColors.Gold");
    label.SetTitle(row.label);
    label.SetTitleSize(30);
    label.SetStatic();
    label.Reparent(strip);
    this.Intro(label, index);

    let second = RLTerminal.SecondTakeOn(service, row.id);
    let t = 0;
    while t < ArraySize(row.takes) {
      let take = row.takes[t];
      let on = Equals(second, t == 1);
      // Name and both rank lines need the whole card: no kicker. The take
      // that's on is the lit card.
      let card = RLCard.Create(StringToName(s"take_\(t)_" + NameToString(row.id)), 750.0, RLTerminalPopup.UpgradeRowHeight(), on ? n"MainColors.Blue" : n"MainColors.Grey");
      card.SetCompact();
      card.HideKicker();
      card.SetTitle(take.name);
      card.SetTitleSize(26);
      let r = 0;
      while r < ArraySize(take.rankNames) {
        let owned = r < rank;
        let line = RLTerminal.Numeral(r + 1) + "   " + take.rankNames[r] + ". " + take.rankLines[r];
        card.AddLine(line, owned && on ? n"MainColors.ActiveWhite" : n"MainColors.Grey", 20);
        r += 1;
      }
      card.SetSelected(on);
      this.Hook(card, strip);
      this.Intro(card, index);
      t += 1;
    }

    let cost = RLTerminal.NextCost(service, row);
    let affordable = cost > 0 && service.GetCred() >= cost;
    let buy = RLCard.Create(StringToName("rank_" + NameToString(row.id)), 270.0, RLTerminalPopup.UpgradeRowHeight(), cost <= 0 ? n"MainColors.Green" : (affordable ? n"MainColors.Gold" : n"MainColors.Grey"));
    buy.SetCompact();
    if cost <= 0 {
      buy.SetKicker("ALL RANKS");
      buy.SetTitle("MAXED");
      buy.SetStatic();
    } else {
      buy.SetKicker("RANK " + RLTerminal.Numeral(rank + 1));
      buy.SetTitle(s"\(cost) CRED");
    }
    buy.SetTitleSize(30);
    this.Hook(buy, strip);
    this.Intro(buy, index);

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
    } else if Equals(name, "scout_landmarks") {
      this.Close();
      this.m_system.StartScout(true);
    } else if Equals(name, "survey") {
      this.Close();
      this.m_system.StartSurvey();
    } else if Equals(name, "assist") {
      service.SetAssist(!service.IsAssistOn());
      this.Rebuild();
    } else if Equals(name, "kit") {
      this.Close();
      this.m_system.OpenArmoryLater();
    } else if Equals(name, "guide") {
      this.Close();
      this.m_system.OpenGuideLater();
    } else if Equals(name, "upgrades") {
      this.SwitchView(RLTerminalView.Upgrades);
    } else if Equals(name, "database") {
      this.OpenDatabase();
    } else if StrBeginsWith(name, "dbrow_") {
      this.PlaySound(n"Button", n"OnPress");
      this.PinDbEntry(StringToInt(StrAfterFirst(name, "_")));
    } else if StrBeginsWith(name, "db_") {
      let tab = StringToName(StrAfterFirst(name, "_"));
      if NotEquals(tab, this.m_dbTab) {
        this.m_dbTab = tab;
        this.m_dbPinned = 0;
        this.PlaySound(n"Button", n"OnPress");
        this.SwitchView(RLTerminalView.Database);
      }
    } else if Equals(name, "back") {
      this.SwitchView(Equals(this.m_view, RLTerminalView.Database) ? this.m_dbReturn : RLTerminalView.Hub);
    } else if StrBeginsWith(name, "rank_") {
      if RLTerminal.TryBuy(service, StringToName(StrAfterFirst(name, "_"))) {
        this.PlaySound(n"Item", n"OnBuy");
        this.m_header.SetFluffRight(s"\(service.GetCred()) CRED");
        this.Rebuild();
      } else {
        let card = button as RLCard;
        if IsDefined(card) {
          card.Shake();
        }
      }
    } else if StrBeginsWith(name, "take_") {
      let rest = StrAfterFirst(name, "_");
      let row = StringToName(StrAfterFirst(rest, "_"));
      let wantSecond = StrBeginsWith(rest, "1");
      if NotEquals(RLTerminal.SecondTakeOn(service, row), wantSecond) {
        RLTerminal.SwitchTake(service, row);
        this.PlaySound(n"Button", n"OnPress");
        this.Rebuild();
      }
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

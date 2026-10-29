// -----------------------------------------------------------------------------
// Night City Roguelite - the database
// -----------------------------------------------------------------------------
// Everything a run talks about, in one place (the terminal's DATABASE view,
// UI/TerminalPopup.reds): the keywords, the run's terms, every patron's
// effects, the duos, each main-weapon chrome's evolution and mods, and the
// quickhacks. Entries are read from the same catalogues the cards are dealt
// from, so the database never says something a card doesn't.
//
// The view reads like Hades' Codex: tabs on the left, the open tab's entries
// as a list of names (in groups), and the entry under the cursor in full on
// the right - one thing at a time, in large type.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLDbTab {
  public let id: CName;
  public let label: String;
  // BASICS, PATRONS or CHROME: the tab column's sections.
  public let group: String;
  public let accent: CName;
  // A line under the tab's name: what's in it.
  public let intro: String;
}

public class RLDbEntry {
  // The list's group heading (EFFECTS, LEGENDARY, ARASAKA...).
  public let group: String;
  public let kicker: String;
  public let title: String;
  public let accent: CName;
  public let text: String;
  // Labelled paragraphs under the text (OVERCLOCK, ON A LAUNCHER, MADE BY...).
  public let sectionLabels: array<String>;
  public let sectionTexts: array<String>;
  public let sectionColors: array<CName>;
  public let chips: array<String>;
  public let chipColors: array<CName>;

  public static func Make(const group: String, const kicker: String, const title: String, accent: CName, const text: String) -> ref<RLDbEntry> {
    let entry = new RLDbEntry();
    entry.group = group;
    entry.kicker = kicker;
    entry.title = title;
    entry.accent = accent;
    entry.text = text;
    return entry;
  }

  public func Section(const label: String, const text: String, color: CName) {
    if StrLen(text) > 0 {
      ArrayPush(this.sectionLabels, label);
      ArrayPush(this.sectionTexts, text);
      ArrayPush(this.sectionColors, color);
    }
  }

  public func Chip(const label: String, keyword: CName) {
    ArrayPush(this.chips, label);
    ArrayPush(this.chipColors, RLKeywords.Color(keyword));
  }

  // MAKES / USES chips, the way the cards show them.
  public func Speaks(makes: array<CName>, uses: array<CName>) {
    for keyword in makes {
      this.Chip("MAKES " + NameToString(keyword), keyword);
    }
    for keyword in uses {
      if !ArrayContains(makes, keyword) {
        this.Chip("USES " + NameToString(keyword), keyword);
      }
    }
  }
}

public abstract class RLDatabase {
  // --- Tabs -----------------------------------------------------------------------------

  public static func Tabs() -> array<ref<RLDbTab>> {
    let tabs: array<ref<RLDbTab>>;
    RLDatabase.Tab(tabs, n"keywords", "KEYWORDS", "BASICS", n"MainColors.ActiveWhite",
      "The words effects speak. One effect's keyword sets off another's - that's a combo.");
    RLDatabase.Tab(tabs, n"terms", "THE RUN", "BASICS", n"MainColors.ActiveWhite",
      "What the doors, cards and screens mean.");
    RLDatabase.Tab(tabs, n"nemeses", "NEMESES", "BASICS", n"MainColors.Red",
      "Everyone who flatlined you. They remember, they learn, and they're out there.");
    for patron in RLPatrons.All() {
      RLDatabase.Tab(tabs, patron.id, patron.name, "PATRONS", patron.accent,
        patron.tagline + " Speaks " + RLDatabase.KeywordList(RLPatrons.Keywords(patron.id)) + ".");
    }
    RLDatabase.Tab(tabs, n"duos", "DUOS", "PATRONS", n"MainColors.Purple",
      "Two patrons in one card. Offered once you hold an effect from each.");
    for family in ["StrongArms", "MantisBlades", "NanoWires", "ProjectileLauncher", "Deck"] {
      RLDatabase.Tab(tabs, StringToName(family), RLArmMods.FamilyName(family), "CHROME", n"MainColors.ActiveYellow",
        "What it learns when it evolves, and its mods. Mods come from Tune-Up doors.");
    }
    RLDatabase.Tab(tabs, n"hacks", "QUICKHACKS", "CHROME", n"MainColors.Green",
      "Every hack a deck can be dealt, and the keyword it makes.");
    return tabs;
  }

  private static func Tab(out tabs: array<ref<RLDbTab>>, id: CName, const label: String, const group: String, accent: CName, const intro: String) {
    let tab = new RLDbTab();
    tab.id = id;
    tab.label = label;
    tab.group = group;
    tab.accent = accent;
    tab.intro = intro;
    ArrayPush(tabs, tab);
  }

  public static func GetTab(id: CName) -> ref<RLDbTab> {
    for tab in RLDatabase.Tabs() {
      if Equals(tab.id, id) {
        return tab;
      }
    }
    return null;
  }

  public static func Entries(id: CName) -> array<ref<RLDbEntry>> {
    switch id {
      case n"keywords": return RLDatabase.Keywords();
      case n"terms": return RLDatabase.Terms();
      case n"nemeses": return RLDatabase.Nemeses();
      case n"duos": return RLDatabase.Duos();
      case n"hacks": return RLDatabase.Quickhacks();
    }
    if IsDefined(RLPatrons.Get(id)) {
      return RLDatabase.Patron(id);
    }
    return RLDatabase.Chrome(NameToString(id));
  }

  // "MARK and FOCUS"
  private static func KeywordList(keywords: array<CName>) -> String {
    let text = "";
    let i = 0;
    while i < ArraySize(keywords) {
      if i > 0 {
        text += i == ArraySize(keywords) - 1 ? " and " : ", ";
      }
      text += NameToString(keywords[i]);
      i += 1;
    }
    return text;
  }

  // --- Keywords -------------------------------------------------------------------------

  // Grouped by the patron who speaks them.
  private static func Keywords() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    RLDatabase.Keyword(list, n"MARK", "The game's ping outline on an enemy. MARK effects pay off on it: more damage, executions, missiles that find it.");
    RLDatabase.Keyword(list, n"FOCUS", "Time slows for a moment. You don't.");
    RLDatabase.Keyword(list, n"BLAST", "An explosion. Grenades and launcher shells count.");
    if RLConfig.DroneEscort() {
      RLDatabase.Keyword(list, n"DRONE", "A Militech drone fighting on your side.");
    }
    RLDatabase.Keyword(list, n"SHOCK", "Electrocuted: sparks, damage and a stagger.");
    RLDatabase.Keyword(list, n"GLITCH", "Their chrome shuts down for 6 s: no dodging, no Sandevistan, no healing.");
    RLDatabase.Keyword(list, n"BURN", "On fire, burning down over time.");
    RLDatabase.Keyword(list, n"BLEED", "Bleeding: a slice of health every second, more with every stack. Poison counts.");
    RLDatabase.Keyword(list, n"MOMENTUM", "Stacks on you from sprinting, sliding and dashing. Each one: more speed, more damage. A hit taken costs one.");
    RLDatabase.Keyword(list, n"SHIELD", "One hit absorbed.");
    RLDatabase.Keyword(list, n"LUCK", "Chance effects, rolling your way.");
    RLDatabase.Keyword(list, n"DEAL", "A price now for a payoff later.");
    return list;
  }

  private static func Keyword(out list: array<ref<RLDbEntry>>, keyword: CName, const text: String) {
    let patron = RLDatabase.SpokenBy(keyword);
    let entry = RLDbEntry.Make(patron, patron + " KEYWORD", NameToString(keyword), RLKeywords.Color(keyword), text);
    entry.Section("MADE BY", RLDatabase.Speakers(keyword, true), n"MainColors.ActiveWhite");
    entry.Section("PAID OFF BY", RLDatabase.Speakers(keyword, false), n"MainColors.ActiveWhite");
    entry.Chip(NameToString(keyword), keyword);
    ArrayPush(list, entry);
  }

  // "ARASAKA" - the patron who speaks a keyword.
  private static func SpokenBy(keyword: CName) -> String {
    for patron in RLPatrons.All() {
      let keywords = RLPatrons.Keywords(patron.id);
      if ArrayContains(keywords, keyword) {
        return patron.name;
      }
    }
    return "KEYWORD";
  }

  // Every effect, mod and quickhack that makes a keyword (or pays off on
  // it), by name - where to look for it in a run.
  private static func Speakers(keyword: CName, makes: Bool) -> String {
    let names: array<String>;
    for def in RLBoons.All() {
      let said = makes ? def.makes : def.uses;
      if ArrayContains(said, keyword) && !ArrayContains(names, def.name) {
        ArrayPush(names, def.name);
      }
    }
    for mod in RLArmMods.All() {
      let said = makes ? mod.makes : mod.uses;
      if ArrayContains(said, keyword) && !ArrayContains(names, mod.name) {
        ArrayPush(names, mod.name);
      }
    }
    if makes {
      for family in RLHacks.Families() {
        if Equals(family.keyword, keyword) && !ArrayContains(names, family.name) {
          ArrayPush(names, family.name);
        }
      }
    }
    let text = "";
    for name in names {
      text += (StrLen(text) > 0 ? ", " : "") + name;
    }
    return text;
  }

  // --- The run --------------------------------------------------------------------------

  private static func Terms() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    let white = n"MainColors.ActiveWhite";
    RLDatabase.Term(list, "PATRONS", "PATRON", n"MainColors.Purple", "Four of Night City's powers back each run. A patron door pays a pick of their effects.");
    RLDatabase.Term(list, "PATRONS", "OVERCLOCK", n"MainColors.Purple", "A stronger version of an effect or mod you hold, offered once you have it. Shown with a +.");
    RLDatabase.Term(list, "PATRONS", "DUO", n"MainColors.Purple", "Two patrons' effect in one. Offered once you hold an effect from each.");
    RLDatabase.Term(list, "PATRONS", "LEGENDARY", n"MainColors.Gold", "The card a build chases. Offered once you hold two of a patron's effects.");
    RLDatabase.Term(list, "PATRONS", "FAVOUR", n"MainColors.Gold", "Not a card: hold three effects from one patron and theirs is yours.");
    RLDatabase.Term(list, "WEAPONS", "WEAPON EFFECT", n"MainColors.Red", "Lives on your main weapon's slot and stays through a trade. Two slots, three once it evolves. Reads hits, shells or uploads.");
    RLDatabase.Term(list, "WEAPONS", "TUNE-UP", n"MainColors.Gold", "Your main weapon, a quality step up. Tune-Up doors on floors 4, 10 and 16 also deal chrome mods.");
    RLDatabase.Term(list, "WEAPONS", "TRADE", n"MainColors.Red", "A new gun at your slot's quality, effects kept. Arms REWIRE to a new element; a deck gets a new quickhack.");
    RLDatabase.Term(list, "WEAPONS", "EVOLVE", n"MainColors.Gold", "Legendary with two weapon effects: a gun becomes an iconic, chrome learns its signature. A third effect slot either way.");
    RLDatabase.Term(list, "WEAPONS", "STYLES", n"MainColors.Gold", "Points for how you fight. Ranks at 3, 6 and 9 add damage; rank III adds a signature.");
    RLDatabase.Term(list, "DOORS", "HOT DOOR", n"MainColors.Red", "Elites every wave and a lieutenant at the end. The reward comes two steps up, with a card more and +50% eddies.");
    RLDatabase.Term(list, "DOORS", "ROUTE", n"MainColors.Blue", "An act's first doors each lead somewhere in the city. The one you take is where the act's fights are, who you fight, and the landmark where its boss waits.");
    RLDatabase.Term(list, "DOORS", "NEMESIS", n"MainColors.Red", "Whoever flatlines you remembers. They come back on doors against their gang, rank up when they kill you again, and learn to shrug off your favourite keyword.");
    RLDatabase.Term(list, "DOORS", "BANISH", white, "Takes a card out of the run for good. One an act.");
    RLDatabase.Term(list, "DOORS", "REROLL", n"MainColors.Blue", "Deals a screen or the doors again. Charges refill every act.");
    RLDatabase.Term(list, "SURVIVAL", "COVER", n"MainColors.Green", "Trauma Team. A lethal hit with cover left gets you back up, once per cover.");
    RLDatabase.Term(list, "SURVIVAL", "OVERDRIVE", n"MainColors.Blue", "Your ultimate, from the Act 1 boss's operating system. Kills and hits taken fill it; fire your OS when it's full.");
    RLDatabase.Term(list, "SURVIVAL", "CAPACITY OVERCLOCK", n"MainColors.Red", "Chrome over capacity goes in anyway. Every point raises the odds of a cyberpsychosis episode.");
    RLDatabase.Term(list, "BETWEEN RUNS", "CRED", n"MainColors.Gold", "Banked from every arena. Buys terminal upgrades.");
    RLDatabase.Term(list, "BETWEEN RUNS", "FAVORS", n"MainColors.ActiveYellow", "A fixer owes you one for every boss you put down. Call in kits at the armory.");
    return list;
  }

  private static func Term(out list: array<ref<RLDbEntry>>, const group: String, const title: String, accent: CName, const text: String) {
    ArrayPush(list, RLDbEntry.Make(group, group, title, accent, text));
  }

  // --- Nemeses --------------------------------------------------------------------------

  // At large first, then the fallen; their story under each.
  private static func Nemeses() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    let all = RogueliteService.Get().GetNemeses();
    for alive in [true, false] {
      let i = ArraySize(all) - 1;
      while i >= 0 {
        let nemesis = all[i];
        if Equals(nemesis.alive, alive) {
          ArrayPush(list, RLDatabase.Nemesis(nemesis));
        }
        i -= 1;
      }
    }
    if ArraySize(list) == 0 {
      ArrayPush(list, RLDbEntry.Make("AT LARGE", "NOBODY YET", "No one", n"MainColors.Grey",
        "Nobody's flatlined you yet. The first one who does will remember."));
    }
    return list;
  }

  private static func Nemesis(nemesis: ref<RLNemesis>) -> ref<RLDbEntry> {
    let faction = RLEncounters.FactionName(nemesis.Affiliation());
    let entry = RLDbEntry.Make(nemesis.alive ? "AT LARGE" : "TAKEN DOWN", nemesis.RankTitle() + " - " + faction, nemesis.FullName(),
      nemesis.alive ? n"MainColors.Red" : n"MainColors.Grey",
      nemesis.Threat() + (nemesis.meetings > 1 ? s" Met \(nemesis.meetings) times." : ""));
    entry.Section("TRICKS", RLAffixes.Names(nemesis.affixes), n"MainColors.ActiveWhite");
    let story = "";
    for line in nemesis.story {
      story += (StrLen(story) > 0 ? " " : "") + NameToString(line);
    }
    entry.Section("THE STORY SO FAR", story, n"MainColors.ActiveWhite");
    if IsNameValid(nemesis.immune) {
      entry.Chip("RESISTS " + NameToString(nemesis.immune), nemesis.immune);
    }
    return entry;
  }

  // --- Patrons --------------------------------------------------------------------------

  // A patron's effects, weapon effect, legendaries and favour (duos have
  // their own tab).
  private static func Patron(id: CName) -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    let accent = RLPatrons.Accent(id);
    for kind in [RLBoonKind.Effect, RLBoonKind.Weapon, RLBoonKind.Legendary, RLBoonKind.Favour] {
      for def in RLBoons.All() {
        if Equals(def.patron, id) && Equals(def.kind, kind) {
          ArrayPush(list, RLDatabase.Effect(def, accent));
        }
      }
    }
    return list;
  }

  private static func Duos() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    for def in RLBoons.All() {
      if Equals(def.kind, RLBoonKind.Duo) {
        ArrayPush(list, RLDatabase.Effect(def, RLPatrons.Accent(def.patron)));
      }
    }
    return list;
  }

  private static func Effect(def: ref<RLBoonDef>, accent: CName) -> ref<RLDbEntry> {
    let kind = RLBoons.KindName(def.kind);
    let duo = Equals(def.kind, RLBoonKind.Duo);
    // Duos are grouped by their first patron; the rest by kind ("EFFECTS").
    let group = duo ? RLPatrons.Name(def.patron) : (Equals(def.kind, RLBoonKind.Effect) ? "EFFECTS" : kind);
    let kicker = duo ? "DUO - " + RLPatrons.Name(def.patron) + " + " + RLPatrons.Name(def.partner) : RLPatrons.Name(def.patron) + " - " + kind;
    let entry: ref<RLDbEntry>;
    if Equals(def.kind, RLBoonKind.Weapon) {
      // Every reading, so a launcher or a deck build can plan too.
      entry = RLDbEntry.Make(group, kicker, def.name, accent, def.text);
      entry.Section("ON A LAUNCHER", RLWeaponActions.ShellText(def.id, false), n"MainColors.ActiveWhite");
      entry.Section("ON A CYBERDECK", RLWeaponActions.UploadText(def.id, false), n"MainColors.ActiveWhite");
    } else {
      entry = RLDbEntry.Make(group, kicker, def.name, accent, def.text);
    }
    entry.Section("OVERCLOCK", def.overclock, n"MainColors.Purple");
    entry.Speaks(def.makes, def.uses);
    return entry;
  }

  // --- Chrome ---------------------------------------------------------------------------

  // A main-weapon chrome: what it learns when it evolves, then its mods by
  // slot.
  private static func Chrome(const family: String) -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    let what = RLSignatures.What(family);
    let signature = RLDbEntry.Make("EVOLUTION", "EVOLUTION - " + RLArmMods.FamilyName(family), RLSignatures.Name(family), n"MainColors.Gold",
      StrUpper(StrLeft(what, 1)) + StrMid(what, 1));
    signature.Section("ALSO", "Legendary++ and a third weapon effect slot.", n"MainColors.Grey");
    ArrayPush(list, signature);
    let slots: array<String>;
    for def in RLArmMods.All() {
      if Equals(def.family, family) && !ArrayContains(slots, def.slot) {
        ArrayPush(slots, def.slot);
      }
    }
    for slot in slots {
      RLDatabase.Mods(list, family, slot);
    }
    return list;
  }

  private static func Mods(out list: array<ref<RLDbEntry>>, const family: String, const slot: String) {
    for def in RLArmMods.All() {
      if Equals(def.family, family) && Equals(def.slot, slot) {
        let entry = RLDbEntry.Make(def.slot + " MODS", def.slot + " MOD - " + RLArmMods.FamilyName(family), def.name, n"MainColors.ActiveYellow", def.text);
        entry.Section("OVERCLOCK", def.overclock, n"MainColors.Purple");
        entry.Speaks(def.makes, def.uses);
        ArrayPush(list, entry);
      }
    }
  }

  private static func Quickhacks() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    for family in RLHacks.Families() {
      let record = RLHacks.RecordAt(family, 0);
      let role = RLHacks.RoleName(family.role);
      let entry = RLDbEntry.Make(role, role + " QUICKHACK", TDBID.IsValid(record) ? RLRewards.ItemName(record) : family.name,
        IsNameValid(family.keyword) ? RLKeywords.Color(family.keyword) : n"MainColors.Green", family.line);
      if IsNameValid(family.keyword) {
        entry.Chip("MAKES " + NameToString(family.keyword), family.keyword);
      }
      ArrayPush(list, entry);
    }
    return list;
  }
}

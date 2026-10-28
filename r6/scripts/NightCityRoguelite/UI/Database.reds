// -----------------------------------------------------------------------------
// Night City Roguelite - the database
// -----------------------------------------------------------------------------
// Everything a run talks about, in one place (the terminal's DATABASE view,
// UI/TerminalPopup.reds): the keywords, the run's terms, every patron's
// effects, the duos, each main-weapon chrome's evolution and mods, and the
// quickhacks. Entries are read from the same catalogues the cards are dealt
// from, so the database never says something a card doesn't - and it looks
// like the cards: the same accents, keyword chips and overclock lines.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLDbTab {
  public let id: CName;
  public let label: String;
  // BASICS, PATRONS or CHROME: the tab column's sections.
  public let group: String;
  public let accent: CName;
  public let columns: Int32;
}

public class RLDbEntry {
  public let kicker: String;
  public let title: String;
  public let accent: CName;
  public let lines: array<String>;
  public let lineColors: array<CName>;
  public let chips: array<String>;
  public let chipColors: array<CName>;

  public func Line(const text: String, color: CName) {
    if StrLen(text) > 0 {
      ArrayPush(this.lines, text);
      ArrayPush(this.lineColors, color);
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
    RLDatabase.Tab(tabs, n"keywords", "KEYWORDS", "BASICS", n"MainColors.ActiveWhite", 3);
    RLDatabase.Tab(tabs, n"terms", "THE RUN", "BASICS", n"MainColors.ActiveWhite", 3);
    for patron in RLPatrons.All() {
      RLDatabase.Tab(tabs, patron.id, patron.name, "PATRONS", patron.accent, 2);
    }
    RLDatabase.Tab(tabs, n"duos", "DUOS", "PATRONS", n"MainColors.Purple", 3);
    for family in ["StrongArms", "MantisBlades", "NanoWires", "ProjectileLauncher", "Deck"] {
      RLDatabase.Tab(tabs, StringToName(family), RLArmMods.FamilyName(family), "CHROME", n"MainColors.ActiveYellow", 2);
    }
    RLDatabase.Tab(tabs, n"hacks", "QUICKHACKS", "CHROME", n"MainColors.Green", 3);
    return tabs;
  }

  private static func Tab(out tabs: array<ref<RLDbTab>>, id: CName, const label: String, const group: String, accent: CName, columns: Int32) {
    let tab = new RLDbTab();
    tab.id = id;
    tab.label = label;
    tab.group = group;
    tab.accent = accent;
    tab.columns = columns;
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
      case n"duos": return RLDatabase.Duos();
      case n"hacks": return RLDatabase.Quickhacks();
    }
    if IsDefined(RLPatrons.Get(id)) {
      return RLDatabase.Patron(id);
    }
    return RLDatabase.Chrome(NameToString(id));
  }

  // --- Keywords -------------------------------------------------------------------------

  private static func Keywords() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    RLDatabase.Keyword(list, n"MARK", "The game's ping outline on an enemy. MARK effects pay off on it: more damage, executions, missiles that find it.");
    RLDatabase.Keyword(list, n"FOCUS", "Time slows for a moment. You don't.");
    RLDatabase.Keyword(list, n"BLAST", "An explosion. Grenades and launcher shells count.");
    RLDatabase.Keyword(list, n"SHOCK", "Electrocuted: sparks, damage and a stagger.");
    RLDatabase.Keyword(list, n"GLITCH", "Their chrome shuts down for 6 s: no dodging, no Sandevistan, no healing.");
    RLDatabase.Keyword(list, n"BURN", "On fire, burning down over time.");
    RLDatabase.Keyword(list, n"BLEED", "Bleeding: a slice of health every second, more with every stack. Poison counts.");
    RLDatabase.Keyword(list, n"MOMENTUM", "Stacks on you from sprinting, sliding and dashing. Each one: more speed, more damage. A hit taken costs one.");
    RLDatabase.Keyword(list, n"SHIELD", "One hit absorbed.");
    RLDatabase.Keyword(list, n"LUCK", "Chance effects, rolling your way.");
    RLDatabase.Keyword(list, n"DEAL", "A price now for a payoff later.");
    if RLConfig.DroneEscort() {
      RLDatabase.Keyword(list, n"DRONE", "A Militech drone fighting on your side.");
    }
    return list;
  }

  private static func Keyword(out list: array<ref<RLDbEntry>>, keyword: CName, const text: String) {
    let entry = new RLDbEntry();
    entry.kicker = RLDatabase.MadeBy(keyword);
    entry.title = NameToString(keyword);
    entry.accent = RLKeywords.Color(keyword);
    entry.Line(text, n"MainColors.ActiveWhite");
    entry.Chip(NameToString(keyword), keyword);
    ArrayPush(list, entry);
  }

  // "ARASAKA" - the patron who speaks a keyword.
  private static func MadeBy(keyword: CName) -> String {
    for patron in RLPatrons.All() {
      let keywords = RLPatrons.Keywords(patron.id);
      if ArrayContains(keywords, keyword) {
        return patron.name;
      }
    }
    return "KEYWORD";
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
    RLDatabase.Term(list, "DOORS", "BANISH", white, "Takes a card out of the run for good. One an act.");
    RLDatabase.Term(list, "DOORS", "REROLL", n"MainColors.Blue", "Deals a screen or the doors again. Charges refill every act.");
    RLDatabase.Term(list, "SURVIVAL", "COVER", n"MainColors.Green", "Trauma Team. A lethal hit with cover left gets you back up, once per cover.");
    RLDatabase.Term(list, "SURVIVAL", "OVERDRIVE", n"MainColors.Blue", "Your ultimate, from the Act 1 boss's operating system. Kills and hits taken fill it; fire your OS when it's full.");
    RLDatabase.Term(list, "SURVIVAL", "CAPACITY OVERCLOCK", n"MainColors.Red", "Chrome over capacity goes in anyway. Every point raises the odds of a cyberpsychosis episode.");
    RLDatabase.Term(list, "BETWEEN RUNS", "CRED", n"MainColors.Gold", "Banked from every arena. Buys terminal upgrades.");
    RLDatabase.Term(list, "BETWEEN RUNS", "FAVORS", n"MainColors.ActiveYellow", "A fixer owes you one for every boss you put down. Call in kits at the armory.");
    return list;
  }

  private static func Term(out list: array<ref<RLDbEntry>>, const kicker: String, const title: String, accent: CName, const text: String) {
    let entry = new RLDbEntry();
    entry.kicker = kicker;
    entry.title = title;
    entry.accent = accent;
    entry.Line(text, n"MainColors.ActiveWhite");
    ArrayPush(list, entry);
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
    let entry = new RLDbEntry();
    entry.title = def.name;
    entry.accent = accent;
    entry.kicker = Equals(def.kind, RLBoonKind.Duo)
      ? "DUO - " + RLPatrons.Name(def.patron) + " + " + RLPatrons.Name(def.partner)
      : RLBoons.KindName(def.kind);
    if Equals(def.kind, RLBoonKind.Weapon) {
      // Every reading, so a launcher or a deck build can plan too.
      entry.Line("HITS   " + def.text, n"MainColors.ActiveWhite");
      entry.Line("SHELLS   " + RLWeaponActions.ShellText(def.id, false), n"MainColors.ActiveWhite");
      entry.Line("UPLOADS   " + RLWeaponActions.UploadText(def.id, false), n"MainColors.ActiveWhite");
    } else {
      entry.Line(def.text, n"MainColors.ActiveWhite");
      if StrLen(def.overclock) > 0 {
        entry.Line("OVERCLOCK   " + def.overclock, n"MainColors.Purple");
      }
    }
    entry.Speaks(def.makes, def.uses);
    return entry;
  }

  // --- Chrome ---------------------------------------------------------------------------

  // A main-weapon chrome: what it learns when it evolves, then its mods.
  private static func Chrome(const family: String) -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    let signature = new RLDbEntry();
    signature.kicker = "EVOLUTION";
    signature.title = RLSignatures.Name(family);
    signature.accent = n"MainColors.Gold";
    let what = RLSignatures.What(family);
    signature.Line(StrUpper(StrLeft(what, 1)) + StrMid(what, 1), n"MainColors.ActiveWhite");
    signature.Line("With Legendary++ and a third weapon effect slot.", n"MainColors.Grey");
    ArrayPush(list, signature);
    for def in RLArmMods.All() {
      if Equals(def.family, family) {
        let entry = new RLDbEntry();
        entry.kicker = def.slot + " MOD";
        entry.title = def.name;
        entry.accent = n"MainColors.ActiveYellow";
        entry.Line(def.text, n"MainColors.ActiveWhite");
        entry.Line("OVERCLOCK   " + def.overclock, n"MainColors.Purple");
        entry.Speaks(def.makes, def.uses);
        ArrayPush(list, entry);
      }
    }
    return list;
  }

  private static func Quickhacks() -> array<ref<RLDbEntry>> {
    let list: array<ref<RLDbEntry>>;
    for family in RLHacks.Families() {
      let entry = new RLDbEntry();
      let record = RLHacks.RecordAt(family, 0);
      entry.kicker = RLHacks.RoleName(family.role) + " QUICKHACK";
      entry.title = TDBID.IsValid(record) ? RLRewards.ItemName(record) : family.name;
      entry.accent = IsNameValid(family.keyword) ? RLKeywords.Color(family.keyword) : n"MainColors.Green";
      entry.Line(family.line, n"MainColors.ActiveWhite");
      if IsNameValid(family.keyword) {
        entry.Chip("MAKES " + NameToString(family.keyword), family.keyword);
      }
      ArrayPush(list, entry);
    }
    return list;
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - the terminal's upgrades
// -----------------------------------------------------------------------------
// Cred buys ranks in ten rows (Hades' Mirror of Night). A row is one idea
// with two takes on it: its ranks are bought once and serve whichever take is
// switched on, and switching is free at home. Every rank has its own name and
// its own line - none of them is "+1 more".
//
//   COVER      Trauma Team         Back-Alley Doc
//   CHOICE     Wide Net            Street Map
//   REROLLS    Fixer Contacts      Burn Notice
//   HEAD START Quartermaster       Patron's Ear
//   EDDIES     Street Smart        Skim
//   BODY       Edge                Tolerance
//   OVERDRIVE  Primed              Meltdown
//   HEAT       Hot Streak          Bounty Board
//   STYLE      Specialist          Gig Economy
//   FORTUNE    Lucky Star          Inside Man
//
// Kits aren't here: they cost favors (Meta/MetaProgression.reds).
//
// Stored with the other unlocks (RogueliteService): "row.<row>.<rank>" for
// each rank bought, "take.<row>.B" while a row's second take is on. The old
// one-off unlocks are carried over once (Migrate).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLTake {
  public let id: CName;
  public let name: String;
  public let rankNames: array<String>;
  public let rankLines: array<String>;
}

public class RLRow {
  public let id: CName;
  public let label: String;
  public let takes: array<ref<RLTake>>;
  public let costs: array<Int32>;
}

public abstract class RLTerminal {
  // --- The rows ---------------------------------------------------------------------------

  public static func Rows() -> array<ref<RLRow>> {
    let rows: array<ref<RLRow>>;
    let two: array<Int32> = [250, 600];
    let one: array<Int32> = [400];
    ArrayPush(rows, RLTerminal.Row(n"Cover", "COVER", two,
      RLTerminal.Take(n"TraumaTeam", "TRAUMA TEAM",
        ["Gold Plan", "Platinum Plan"],
        ["Your cover gets you up at 75% health, not 50%.", "Two covers a run."]),
      RLTerminal.Take(n"BackAlleyDoc", "BACK-ALLEY DOC",
        ["House Call", "Repeat Customer"],
        ["Runs start with an Uncommon MaxDoc.", "Your MaxDoc holds one more charge."])));
    ArrayPush(rows, RLTerminal.Row(n"Choice", "CHOICE", one,
      RLTerminal.Take(n"WideNet", "WIDE NET", ["Wide Net"], ["Four cards on every reward screen."]),
      RLTerminal.Take(n"StreetMap", "STREET MAP", ["Street Map"], ["Four doors to pick from."])));
    ArrayPush(rows, RLTerminal.Row(n"Rerolls", "REROLLS", two,
      RLTerminal.Take(n"FixerContacts", "FIXER CONTACTS",
        ["Know a Guy", "Inner Circle"],
        ["One more reroll every act.", "Your first door reroll on each floor is free."]),
      RLTerminal.Take(n"BurnNotice", "BURN NOTICE",
        ["Burn Notice", "Blacklist"],
        ["Two banishes an act.", "A banished card comes back as a standout."])));
    ArrayPush(rows, RLTerminal.Row(n"HeadStart", "HEAD START", two,
      RLTerminal.Take(n"Quartermaster", "QUARTERMASTER",
        ["Requisition", "Priority Requisition"],
        ["A free Armory pick before the first door.", "That pick comes two steps up."]),
      RLTerminal.Take(n"PatronsEar", "PATRON'S EAR",
        ["Open Line", "Standing Offer"],
        ["Your first patron screen deals a card more.", "Your most-backed patron always works the run."])));
    ArrayPush(rows, RLTerminal.Row(n"Eddies", "EDDIES", two,
      RLTerminal.Take(n"StreetSmart", "STREET SMART",
        ["Haggler", "Made Man"],
        ["The Fixer knocks 15% off.", "30% off, and a second effect on the shelf."]),
      RLTerminal.Take(n"Skim", "SKIM",
        ["Skim", "Off the Books"],
        ["Arenas pay 20% more eddies.", "Skipping a reward pays double."])));
    ArrayPush(rows, RLTerminal.Row(n"Body", "BODY", two,
      RLTerminal.Take(n"Edge", "EDGE",
        ["Edge", "Honed"],
        ["+1 to your kit's main attribute.", "+1 to its second attribute too."]),
      RLTerminal.Take(n"Tolerance", "TOLERANCE",
        ["Tolerance", "Neural Dampers"],
        ["+10 cyberware capacity.", "Overclock episodes come half as often."])));
    ArrayPush(rows, RLTerminal.Row(n"Overdrive", "OVERDRIVE", two,
      RLTerminal.Take(n"Primed", "PRIMED",
        ["Primed", "Hair Trigger"],
        ["Overdrive comes online full.", "The meter fills 25% faster."]),
      RLTerminal.Take(n"Meltdown", "MELTDOWN",
        ["Afterburn", "Meltdown"],
        ["Overdrive refills your MaxDoc.", "Overdrive goes off with a BLAST around you."])));
    ArrayPush(rows, RLTerminal.Row(n"Heat", "HEAT", two,
      RLTerminal.Take(n"HotStreak", "HOT STREAK",
        ["Hot Streak", "Marked Man"],
        ["Hot doors deal a card more.", "A second hot door in Act 1."]),
      RLTerminal.Take(n"BountyBoard", "BOUNTY BOARD",
        ["Bounty Board", "Wanted"],
        ["Bounties show up from Act 1.", "Bounties pay double eddies."])));
    ArrayPush(rows, RLTerminal.Row(n"Style", "STYLE", two,
      RLTerminal.Take(n"Specialist", "SPECIALIST",
        ["Specialist", "Signature"],
        ["Your main weapon's style starts at 2 points.", "Rank III at 8 points, not 9."]),
      RLTerminal.Take(n"GigEconomy", "GIG ECONOMY",
        ["Repeat Client", "Long Contract"],
        ["Gigs pay 1,500 eddies.", "Gigs run until the Act 3 boss."])));
    ArrayPush(rows, RLTerminal.Row(n"Fortune", "FORTUNE", two,
      RLTerminal.Take(n"LuckyStar", "LUCKY STAR",
        ["Lucky Star", "Sure Thing"],
        ["Runs start with the Director's pity built up.", "Each act's first reward screen deals a standout."]),
      RLTerminal.Take(n"InsideMan", "INSIDE MAN",
        ["Tip-Off", "Inside Man"],
        ["? doors turn up twice as often.", "Acts 2 and 3 open with a door from your lead patron."])));
    return rows;
  }

  private static func Row(id: CName, const label: String, costs: array<Int32>, a: ref<RLTake>, b: ref<RLTake>) -> ref<RLRow> {
    let row = new RLRow();
    row.id = id;
    row.label = label;
    row.costs = costs;
    ArrayPush(row.takes, a);
    ArrayPush(row.takes, b);
    return row;
  }

  private static func Take(id: CName, const name: String, rankNames: array<String>, rankLines: array<String>) -> ref<RLTake> {
    let take = new RLTake();
    take.id = id;
    take.name = name;
    take.rankNames = rankNames;
    take.rankLines = rankLines;
    return take;
  }

  public static func GetRow(id: CName) -> ref<RLRow> {
    for row in RLTerminal.Rows() {
      if Equals(row.id, id) {
        return row;
      }
    }
    return null;
  }

  // Which row a take sits in, and whether it's the row's second take.
  private static func RowOf(take: CName) -> CName {
    switch take {
      case n"TraumaTeam":
      case n"BackAlleyDoc": return n"Cover";
      case n"WideNet":
      case n"StreetMap": return n"Choice";
      case n"FixerContacts":
      case n"BurnNotice": return n"Rerolls";
      case n"Quartermaster":
      case n"PatronsEar": return n"HeadStart";
      case n"StreetSmart":
      case n"Skim": return n"Eddies";
      case n"Edge":
      case n"Tolerance": return n"Body";
      case n"Primed":
      case n"Meltdown": return n"Overdrive";
      case n"HotStreak":
      case n"BountyBoard": return n"Heat";
      case n"Specialist":
      case n"GigEconomy": return n"Style";
      case n"LuckyStar":
      case n"InsideMan": return n"Fortune";
    }
    return n"";
  }

  private static func IsSecondTake(take: CName) -> Bool {
    switch take {
      case n"BackAlleyDoc":
      case n"StreetMap":
      case n"BurnNotice":
      case n"PatronsEar":
      case n"Skim":
      case n"Tolerance":
      case n"Meltdown":
      case n"BountyBoard":
      case n"GigEconomy":
      case n"InsideMan":
        return true;
    }
    return false;
  }

  // --- Ownership ----------------------------------------------------------------------------

  private static func RankID(row: CName, rank: Int32) -> CName = StringToName("row." + NameToString(row) + "." + IntToString(rank))

  private static func TakeID(row: CName) -> CName = StringToName("take." + NameToString(row) + ".B")

  // Ranks bought in a row.
  public static func Rank(service: ref<RogueliteService>, row: CName) -> Int32 {
    let rank = 0;
    while service.HasUnlock(RLTerminal.RankID(row, rank + 1)) {
      rank += 1;
    }
    return rank;
  }

  public static func SecondTakeOn(service: ref<RogueliteService>, row: CName) -> Bool = service.HasUnlock(RLTerminal.TakeID(row))

  // A take is switched on and has at least `rank` ranks behind it.
  public static func Has(take: CName, rank: Int32) -> Bool {
    let service = RogueliteService.Get();
    if !IsDefined(service) {
      return false;
    }
    let row = RLTerminal.RowOf(take);
    if !IsNameValid(row) || NotEquals(RLTerminal.SecondTakeOn(service, row), RLTerminal.IsSecondTake(take)) {
      return false;
    }
    return service.HasUnlock(RLTerminal.RankID(row, rank));
  }

  // The next rank's price; 0 once the row is maxed.
  public static func NextCost(service: ref<RogueliteService>, row: ref<RLRow>) -> Int32 {
    let rank = RLTerminal.Rank(service, row.id);
    return rank < ArraySize(row.costs) ? row.costs[rank] : 0;
  }

  public static func TryBuy(service: ref<RogueliteService>, id: CName) -> Bool {
    let row = RLTerminal.GetRow(id);
    if !IsDefined(row) {
      return false;
    }
    let cost = RLTerminal.NextCost(service, row);
    if cost <= 0 || !service.TrySpendCred(cost) {
      return false;
    }
    let rank = RLTerminal.Rank(service, id) + 1;
    service.AddUnlock(RLTerminal.RankID(id, rank));
    RLLog(s"Terminal: \(row.label) rank \(rank) for \(cost) Cred.");
    RLTelemetry.RecordFor(0, "META", RLTelemetry.Field("did", "upgrade") + RLTelemetry.Field("row", NameToString(id))
      + RLTelemetry.IntField("rank", rank) + RLTelemetry.IntField("cost", cost) + RLTelemetry.IntField("left", service.GetCred()));
    return true;
  }

  // Switches a row to the other take (free, at home).
  public static func SwitchTake(service: ref<RogueliteService>, id: CName) {
    let flag = RLTerminal.TakeID(id);
    if service.HasUnlock(flag) {
      service.RemoveUnlock(flag);
    } else {
      service.AddUnlock(flag);
    }
    RLTelemetry.RecordFor(0, "META", RLTelemetry.Field("did", "switch") + RLTelemetry.Field("row", NameToString(id))
      + RLTelemetry.Field("take", RLTerminal.TakeOn(service, id)));
  }

  // The take switched on in a row ("TraumaTeam").
  public static func TakeOn(service: ref<RogueliteService>, row: CName) -> String {
    let def = RLTerminal.GetRow(row);
    if !IsDefined(def) || ArraySize(def.takes) == 0 {
      return "";
    }
    let second = RLTerminal.SecondTakeOn(service, row) && ArraySize(def.takes) > 1;
    return NameToString(def.takes[second ? 1 : 0].id);
  }

  // What the terminal gives a run: every row with a rank, as its live take
  // and rank ("TraumaTeam2,WideNet1").
  public static func Loadout(service: ref<RogueliteService>) -> String {
    let text = "";
    for row in RLTerminal.Rows() {
      let rank = RLTerminal.Rank(service, row.id);
      if rank > 0 {
        text += (StrLen(text) > 0 ? "," : "") + RLTerminal.TakeOn(service, row.id) + IntToString(rank);
      }
    }
    return text;
  }

  // "I", "II"
  public static func Numeral(rank: Int32) -> String {
    switch rank {
      case 1: return "I";
      case 2: return "II";
      case 3: return "III";
    }
    return "";
  }

  // --- Carrying the old unlocks over ---------------------------------------------------------

  // Once per profile: what the old one-off unlocks bought becomes the nearest
  // rank, and anything without an equal is refunded.
  public static func Migrate(service: ref<RogueliteService>) {
    let done = n"migrated.terminal";
    if service.HasUnlock(done) {
      return;
    }
    service.AddUnlock(done);
    let refund = 0;
    if service.HasUnlock(n"perk.Reroll") { service.AddUnlock(RLTerminal.RankID(n"Rerolls", 1)); }
    if service.HasUnlock(n"perk.Reroll2") { service.AddUnlock(RLTerminal.RankID(n"Rerolls", 2)); }
    let wideNet = service.HasUnlock(n"perk.FourthChoice");
    let streetMap = service.HasUnlock(n"perk.FourthDoor");
    if wideNet || streetMap {
      service.AddUnlock(RLTerminal.RankID(n"Choice", 1));
    }
    if streetMap && !wideNet {
      service.AddUnlock(RLTerminal.TakeID(n"Choice"));
    } else if streetMap && wideNet {
      refund += 350;
    }
    if service.HasUnlock(n"perk.StarterPick") { service.AddUnlock(RLTerminal.RankID(n"HeadStart", 1)); }
    let platinum = service.HasUnlock(n"perk.Platinum");
    let medKit = service.HasUnlock(n"perk.MedKit");
    if platinum || medKit {
      service.AddUnlock(RLTerminal.RankID(n"Cover", 1));
    }
    if platinum {
      service.AddUnlock(RLTerminal.RankID(n"Cover", 2));
      // Both ranks already went to Platinum: the Med Kit comes back as Cred.
      if medKit {
        refund += 150;
      }
    } else if medKit {
      service.AddUnlock(RLTerminal.TakeID(n"Cover"));
    }
    if service.HasUnlock(n"perk.StreetSmart") { service.AddUnlock(RLTerminal.RankID(n"Eddies", 1)); }
    if service.HasUnlock(n"perk.Attribute1") { service.AddUnlock(RLTerminal.RankID(n"Body", 1)); }
    if service.HasUnlock(n"perk.Attribute2") { service.AddUnlock(RLTerminal.RankID(n"Body", 2)); }
    if service.HasUnlock(n"perk.Attribute3") { refund += 350; }
    if refund > 0 {
      service.AddCred(refund);
    }
    RLLog(s"Terminal: old unlocks carried over" + (refund > 0 ? s", \(refund) Cred refunded." : "."));
  }
}

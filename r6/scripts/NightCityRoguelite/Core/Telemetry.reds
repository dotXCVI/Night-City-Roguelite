// -----------------------------------------------------------------------------
// Night City Roguelite - run telemetry
// -----------------------------------------------------------------------------
// Compact, machine-readable records of every run, kept apart from the text log
// so balance questions get numbers: how long floors take, what was offered and
// what was picked, what the build looked like, what killed V. The last ~50
// runs are kept (RogueliteService, saved outside the save files like Cred).
// tools/runreport.py turns them into run reports, a summary across runs and
// players (text or a page), and CSV.
//
// One record per line:  T1|<seq>|<run id>|<kind>|key=value;key=value;...
// (seq counts every record ever written, so order survives the store.)
//
//   RUN      the run started: kit, test run, starting floor, assist, the
//            build (ver, RLConfig.ModVersion), the terminal upgrades and
//            the patron line-up
//   FLOOR    a fight ended: door (hot or not), arena, enemies, time and each
//            wave's seconds, damage dealt and taken, what hurt V most (by
//            enemy archetype), main weapon hits, outcome, the effects held,
//            and the effect ledger: how often each effect fired and the
//            damage it added - its multipliers, and its blasts and statuses
//            as they landed (fx=ArcFlash:12:340,...)
//   OFFER    a reward screen was rolled: every card (kind:title:quality step)
//   PICK     what was taken (or rerolled, bought, chosen at an event), and
//            how long the screen was up (think)
//   BUILD    after each pick: level, attributes, build tags, styles, OS,
//            main weapon and tier, cover, overclock, gig, patrons, effects
//   COVER    a Trauma Team cover was spent: where, and what hit V
//   ULT      Overdrive fired: the OS and the wave
//   DEATH    what landed the last hit before V went down
//   END      the run ended: won, lost, abandoned, quit (the session ended
//            mid-run: where) or crashed (seen at the next load - only when
//            the store was written mid-run; a crash usually loses it all)
//   MARK     the player pressed MARK BUG: where V was, the arena, the wave
//            and the objective's markers (see RogueliteSystem.MarkBug)
//
// Not about a run (run id 0):
//   SESSION  a roguelite save loaded: build, Cred, favors, runs, upgrades
//   META     the terminal and armory: an upgrade bought, a take switched, a
//            kit unlocked
//
// A record longer than a saved name holds goes in pieces (T1+|<seq>|...,
// RogueliteService.Pieces); tools/runreport.py joins them.
//
// Values never contain '|' or ';' (Clean strips them).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLTelemetry {
  // Script enums have no names at runtime (EnumValueToString returns "").
  public static func StateName(state: RLState) -> String {
    switch state {
      case RLState.Inactive: return "Inactive";
      case RLState.AwaitingTakeover: return "AwaitingTakeover";
      case RLState.Hub: return "Hub";
      case RLState.Preparing: return "Preparing";
      case RLState.RunHome: return "RunHome";
      case RLState.Traveling: return "Traveling";
      case RLState.Deploying: return "Deploying";
      case RLState.InEncounter: return "InEncounter";
      case RLState.Cleared: return "Cleared";
      case RLState.Flatlined: return "Flatlined";
      case RLState.Ending: return "Ending";
    }
    return IntToString(EnumInt(state));
  }

  // Script enums have no names at runtime (EnumValueToString returns "").
  public static func KindName(kind: RLOfferKind) -> String {
    switch kind {
      case RLOfferKind.Trade: return "Trade";
      case RLOfferKind.Iconic: return "Iconic";
      case RLOfferKind.Cyberware: return "Cyberware";
      case RLOfferKind.Quickhack: return "Quickhack";
      case RLOfferKind.Boon: return "Effect";
      case RLOfferKind.Perk: return "Perk";
      case RLOfferKind.Grenade: return "Grenade";
      case RLOfferKind.TuneUp: return "TuneUp";
      case RLOfferKind.HealthUpgrade: return "HealthUpgrade";
      case RLOfferKind.Evolve: return "Evolve";
      case RLOfferKind.Capacity: return "Capacity";
      case RLOfferKind.OperatingSystem: return "OperatingSystem";
      case RLOfferKind.Gig: return "Gig";
      case RLOfferKind.Rewire: return "Rewire";
      case RLOfferKind.ArmMod: return "ArmMod";
    }
    return IntToString(EnumInt(kind));
  }

  public static func Version() -> String = "T1"

  public static func Record(run: ref<RLRunState>, const kind: String, const fields: String) {
    RLTelemetry.RecordFor(IsDefined(run) ? run.id : 0, kind, fields);
  }

  // A record for a run by its id (0: not about a run - META, SESSION).
  public static func RecordFor(id: Int32, const kind: String, const fields: String) {
    let service = RogueliteService.Get();
    if IsDefined(service) {
      service.AppendTelemetry(RLTelemetry.Version(), IntToString(id) + "|" + kind + "|" + fields);
    }
  }

  public static func Clean(const value: String) -> String {
    return StrReplace(StrReplace(StrReplace(value, "|", "/"), ";", ","), "=", "-");
  }

  public static func Field(const key: String, const value: String) -> String {
    return key + "=" + RLTelemetry.Clean(value) + ";";
  }

  public static func IntField(const key: String, value: Int32) -> String = key + "=" + IntToString(value) + ";"

  // One card: kind:title:quality step.
  public static func OfferText(offer: ref<RLOffer>) -> String {
    if !IsDefined(offer) {
      return "";
    }
    let kind = RLTelemetry.KindName(offer.kind);
    return RLTelemetry.Clean(kind + ":" + offer.title + ":" + IntToString(offer.step));
  }

  public static func OffersText(offers: array<ref<RLOffer>>) -> String {
    let text = "";
    for offer in offers {
      text += (StrLen(text) > 0 ? "," : "") + RLTelemetry.OfferText(offer);
    }
    return text;
  }

  // Level, the five attributes, the build profile's tags and the boons held.
  public static func BuildText(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> String {
    if !IsDefined(player) {
      return "";
    }
    let stats = GameInstance.GetStatsSystem(player.GetGame());
    let id = Cast<StatsObjectID>(player.GetEntityID());
    let attrs = s"B\(RoundF(stats.GetStatValue(id, gamedataStatType.Strength)))"
      + s",R\(RoundF(stats.GetStatValue(id, gamedataStatType.Reflexes)))"
      + s",T\(RoundF(stats.GetStatValue(id, gamedataStatType.TechnicalAbility)))"
      + s",I\(RoundF(stats.GetStatValue(id, gamedataStatType.Intelligence)))"
      + s",C\(RoundF(stats.GetStatValue(id, gamedataStatType.Cool)))";
    let effects = "";
    for state in run.boons {
      effects += (StrLen(effects) > 0 ? "," : "") + NameToString(state.id) + (state.overclocked ? "+" : "");
    }
    return RLTelemetry.IntField("lvl", RoundF(stats.GetStatValue(id, gamedataStatType.Level)))
      + RLTelemetry.Field("attr", attrs)
      + RLTelemetry.Field("tags", RLBuildProfile.Read(player).Describe())
      + RLTelemetry.Field("styles", RLStyles.Telemetry(run))
      + RLTelemetry.Field("os", NameToString(run.os))
      + RLTelemetry.Field("main", RLRewards.ItemName(RLWeapons.MainRecord(run)) + ":" + IntToString(run.mainStep) + (StrLen(run.mainElement) > 0 ? ":" + run.mainElement : ""))
      + RLTelemetry.Field("mods", RLArmMods.Summary(run))
      + RLTelemetry.Field("hacks", RLHacks.Summary(player))
      + RLTelemetry.IntField("evolved", RLWeapons.IsEvolved(run) ? 1 : 0)
      + RLTelemetry.IntField("cover", run.cover)
      + RLTelemetry.IntField("overclock", run.overclock)
      + RLTelemetry.Field("gig", run.gigStyle >= 0 ? RLStyle.Name(run.gigStyle) + s" \(run.gigProgress)/\(run.gigTarget)" : "")
      + RLTelemetry.Field("patrons", RLPatrons.LineupText(run.patrons))
      + RLTelemetry.Field("effects", effects);
  }
}

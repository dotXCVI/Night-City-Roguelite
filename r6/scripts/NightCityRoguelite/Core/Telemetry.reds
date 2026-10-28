// -----------------------------------------------------------------------------
// Night City Roguelite - run telemetry
// -----------------------------------------------------------------------------
// Compact, machine-readable records of every run, kept apart from the text log
// so balance questions get numbers: how long floors take, what was offered and
// what was picked, what the build looked like, what killed V. The last ~50
// runs are kept (RogueliteService, saved outside the save files like Cred).
// tools/runreport.py turns them into a floor-by-floor report and CSV.
//
// One record per line:  T1|<seq>|<run id>|<kind>|key=value;key=value;...
// (seq counts every record ever written, so order survives the store.)
//
//   RUN      the run started: kit, test run, starting floor, assist
//   FLOOR    a fight ended: door, arena, enemies, time, damage, outcome
//   OFFER    a reward screen was rolled: every card (kind:title:quality step)
//   PICK     what was taken (or rerolled, bought, chosen at an event)
//   BUILD    after each pick: level, attributes, build tags, styles, OS,
//            weapon mods, overclock, gig progress, boons
//   ULT      Overdrive fired: the OS and the wave
//   DEATH    what landed the last hit before V went down
//   END      the run ended: result, floors, kills, minutes
//   MARK     the player pressed MARK BUG (see RogueliteSystem.MarkBug)
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
      case RLOfferKind.Weapon: return "Weapon";
      case RLOfferKind.Iconic: return "Iconic";
      case RLOfferKind.Cyberware: return "Cyberware";
      case RLOfferKind.Quickhack: return "Quickhack";
      case RLOfferKind.Boon: return "Boon";
      case RLOfferKind.Perk: return "Perk";
      case RLOfferKind.Grenade: return "Grenade";
      case RLOfferKind.WeaponUpgrade: return "WeaponUpgrade";
      case RLOfferKind.HealthUpgrade: return "HealthUpgrade";
      case RLOfferKind.WeaponMod: return "WeaponMod";
      case RLOfferKind.Evolve: return "Evolve";
      case RLOfferKind.Attribute: return "Attribute";
      case RLOfferKind.Capacity: return "Capacity";
      case RLOfferKind.BoonUpgrade: return "BoonUpgrade";
      case RLOfferKind.OperatingSystem: return "OperatingSystem";
      case RLOfferKind.Gig: return "Gig";
    }
    return IntToString(EnumInt(kind));
  }

  public static func Version() -> String = "T1"

  public static func Record(run: ref<RLRunState>, const kind: String, const fields: String) {
    let service = RogueliteService.Get();
    if !IsDefined(service) {
      return;
    }
    let id = IsDefined(run) ? run.id : 0;
    service.AppendTelemetry(RLTelemetry.Version(), IntToString(id) + "|" + kind + "|" + fields);
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
    let boons = "";
    for state in run.boons {
      boons += (StrLen(boons) > 0 ? "," : "") + NameToString(state.id) + ":" + IntToString(state.rarity);
    }
    let mods = "";
    for weapon in run.weapons {
      for mod in weapon.mods {
        mods += (StrLen(mods) > 0 ? "," : "") + NameToString(mod);
      }
    }
    return RLTelemetry.IntField("lvl", RoundF(stats.GetStatValue(id, gamedataStatType.Level)))
      + RLTelemetry.Field("attr", attrs)
      + RLTelemetry.Field("tags", RLBuildProfile.Read(player).Describe())
      + RLTelemetry.Field("styles", RLStyles.Telemetry(run))
      + RLTelemetry.Field("os", NameToString(run.os))
      + RLTelemetry.Field("mods", mods)
      + RLTelemetry.IntField("overclock", run.overclock)
      + RLTelemetry.Field("gig", run.gigStyle >= 0 ? RLStyle.Name(run.gigStyle) + s" \(run.gigProgress)/\(run.gigTarget)" : "")
      + RLTelemetry.Field("boons", boons);
  }
}

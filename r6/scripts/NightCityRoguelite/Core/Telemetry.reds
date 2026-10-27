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
//   BUILD    after each pick: level, attributes, build tags, boons
//   DEATH    what landed the last hit before V went down
//   END      the run ended: result, floors, kills, minutes
//   MARK     the player pressed MARK BUG (see RogueliteSystem.MarkBug)
//
// Values never contain '|' or ';' (Clean strips them).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLTelemetry {
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
    let kind = EnumValueToString("RLOfferKind", Cast<Int64>(EnumInt(offer.kind)));
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
    return RLTelemetry.IntField("lvl", RoundF(stats.GetStatValue(id, gamedataStatType.Level)))
      + RLTelemetry.Field("attr", attrs)
      + RLTelemetry.Field("tags", RLBuildProfile.Read(player).Describe())
      + RLTelemetry.Field("boons", boons);
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - gigs
// -----------------------------------------------------------------------------
// A run opens with three gigs from Night City's fixers; V takes one. Each is
// a kill count in one style (Rewards/Styles.reds) to make before the Act 2
// boss falls - Hades' prophecies folded into a single run. It steers the
// build early and pays out mid-run: eddies, and two points in its style for
// the rest of the run.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLGigs {
  // The gig must be done by the end of this floor (the Act 2 boss).
  public static func Deadline() -> Int32 = 2 * RLConfig.FloorsPerAct()

  public static func Payout() -> Int32 = 1000

  public static func Target(style: Int32) -> Int32 {
    switch style {
      case 7: return 25;
      case 10: return 25;
      case 11: return 15;
      case 2: return 30;
    }
    return 40;
  }

  public static func KillWords(style: Int32) -> String {
    switch style {
      case 0: return "blade kills";
      case 1: return "blunt or fist kills";
      case 2: return "monowire kills";
      case 3: return "pistol kills";
      case 4: return "shotgun or LMG kills";
      case 5: return "rifle kills";
      case 6: return "precision rifle kills";
      case 7: return "quickhack kills";
      case 8: return "smart weapon kills";
      case 9: return "tech weapon kills";
      case 10: return "explosion kills";
      case 11: return "throwing kills";
    }
    return "kills";
  }

  public static func Fixer(style: Int32) -> String {
    switch style % 6 {
      case 0: return "WAKAKO";
      case 1: return "PADRE";
      case 2: return "REGINA";
      case 3: return "DAKOTA";
      case 4: return "MR. HANDS";
      case 5: return "ROGUE";
    }
    return "A FIXER";
  }

  // Three gigs: one in the build's leading style, two others.
  public static func Offers(run: ref<RLRunState>) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    if run.Depth() > RLGigs.Deadline() - 3 {
      return offers;
    }
    let styles: array<Int32>;
    let lead = -1;
    let i = 0;
    while i < ArraySize(run.stylePoints) {
      if lead < 0 || run.stylePoints[i] > run.stylePoints[lead] {
        lead = i;
      }
      i += 1;
    }
    if lead >= 0 {
      ArrayPush(styles, lead);
    }
    let tries = 0;
    while ArraySize(styles) < 3 && tries < 40 {
      RLStyle.AddUnique(styles, RandRange(0, RLStyle.Count()));
      tries += 1;
    }
    for style in styles {
      let offer = new RLOffer();
      offer.kind = RLOfferKind.Gig;
      offer.amount = style;
      offer.title = RLStyle.Name(style) + " GIG";
      offer.subtitle = "GIG FROM " + RLGigs.Fixer(style);
      offer.description = s"\(RLGigs.Target(style)) \(RLGigs.KillWords(style)) before the Act 2 boss falls. Pays \(RLGigs.Payout()) eddies and +2 \(RLStyle.Name(style)).";
      offer.step = 4;
      ArrayPush(offers, offer);
    }
    return offers;
  }

  public static func Take(run: ref<RLRunState>, style: Int32) {
    run.gigStyle = style;
    run.gigTarget = RLGigs.Target(style);
    run.gigProgress = 0;
    run.gigDone = false;
    run.gigFailed = false;
    RLLog(s"Gig taken: \(RLStyle.Name(style)), \(run.gigTarget) kills.");
  }

  public static func IsActive(run: ref<RLRunState>) -> Bool = IsDefined(run) && run.gigStyle >= 0 && !run.gigDone && !run.gigFailed

  public static func OnKill(run: ref<RLRunState>, player: ref<PlayerPuppet>, styles: array<Int32>) {
    if !RLGigs.IsActive(run) || !ArrayContains(styles, run.gigStyle) {
      return;
    }
    run.gigProgress += 1;
    if run.gigProgress >= run.gigTarget {
      run.gigDone = true;
      RLGear.GiveEddies(player, RLGigs.Payout());
      RLStyles.Refresh(player, run, true);
      RLNotify(player.GetGame(), s"GIG COMPLETE - +\(RLGigs.Payout()) eddies, +2 \(RLStyle.Name(run.gigStyle))", 6.0);
      RLLog("Gig complete.");
    }
  }

  // A floor was cleared: past the deadline, an unfinished gig fails.
  public static func OnFloorCleared(run: ref<RLRunState>, game: GameInstance) {
    if RLGigs.IsActive(run) && run.Depth() >= RLGigs.Deadline() {
      run.gigFailed = true;
      RLNotify(game, "GIG FAILED - the client went elsewhere.", 5.0);
      RLLog("Gig failed.");
    }
  }

  // The HUD's piece of the status line.
  public static func Status(run: ref<RLRunState>) -> String {
    if !RLGigs.IsActive(run) {
      return "";
    }
    return s"GIG \(run.gigProgress)/\(run.gigTarget)";
  }
}

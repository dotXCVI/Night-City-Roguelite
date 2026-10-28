// -----------------------------------------------------------------------------
// Night City Roguelite - the Director
// -----------------------------------------------------------------------------
// Bends the run towards a better one, mostly without the player seeing it:
//
//   Quality   every item card rolls around the floor's expected quality step:
//             -1 / 0 / +1 / +2 at 25 / 55 / 16 / 4%, 10 / 50 / 30 / 10 on
//             elite floors; boss rewards and hot doors are always +2 (Enter
//             the Gungeon's floor tables, Slay the Spire's elite odds).
//   Pity      every flat reward screen (nothing above expectation) moves 6
//             points from -1 to +1, up to 30; a +2 card resets it (Slay the
//             Spire's rarity offset).
//   Spike     two flat screens in a row and the next one is guaranteed a
//             standout card.
//   Magnificence  every +2 card taken makes the next +2 roll less likely
//             (x0.4 each), so one lucky run doesn't snowball.
//
//   HOT doors the one thing V does see: a door with an elite pack and a
//             lieutenant that pays two quality steps up, a card more and a
//             big card. One in Act 1, two in Acts 2 and 3 (five a run),
//             placed when V needs a spike most - the
//             main weapon behind the floor, a drought of flat screens, a
//             Trauma Team cover spent - never on the first floor of a run,
//             never two floors running, never on the elite floor or before a
//             boss. An act that runs short of floors gets its two anyway.
//
// The Director never touches enemy stats mid-fight: players notice that, and
// hate it.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLRewardDirector {
  public static func PityStep() -> Int32 = 6
  public static func PityMax() -> Int32 = 30

  public static func SpikeDue(run: ref<RLRunState>) -> Bool = run.flatStreak >= 2

  // A card's quality step for this floor. `spike` forces +2.
  public static func RollStep(run: ref<RLRunState>, spike: Bool) -> Int32 {
    let expected = RLQuality.ExpectedStep(run.Depth(), run.TotalFloors());
    if spike || run.IsBossFloor() {
      return Min(RLQuality.MaxStep(), expected + 2);
    }
    // Odds for -1, 0, +1, +2 steps.
    let odds: array<Float> = [25.0, 55.0, 16.0, 4.0];
    if run.IsEliteFloor() {
      odds = [10.0, 50.0, 30.0, 10.0];
    }
    let pity = MinF(Cast<Float>(run.pityOffset), odds[0]);
    odds[0] -= pity;
    odds[2] += pity;
    let damped = odds[3] * PowF(0.4, Cast<Float>(run.magnificence));
    odds[2] += odds[3] - damped;
    odds[3] = damped;

    let roll = RandRangeF(0.0, odds[0] + odds[1] + odds[2] + odds[3]);
    let i = 0;
    while i < 3 && roll >= odds[i] {
      roll -= odds[i];
      i += 1;
    }
    return Clamp(expected + i - 1, 0, RLQuality.MaxStep());
  }

  // After a reward screen is rolled: track flat screens, pity and spikes.
  public static func AfterRoll(run: ref<RLRunState>, offers: array<ref<RLOffer>>, profile: ref<RLBuildProfile>) {
    let best = -9;
    for offer in offers {
      best = Max(best, offer.excitement);
    }
    if best <= 0 {
      run.flatStreak += 1;
      run.pityOffset = Min(RLRewardDirector.PityMax(), run.pityOffset + RLRewardDirector.PityStep());
    } else {
      run.flatStreak = 0;
    }
    if best >= 2 {
      run.pityOffset = 0;
    }
    RLDebug(s"Director: best card \(best), flat streak \(run.flatStreak), pity \(run.pityOffset), magnificence \(run.magnificence). Build: \(IsDefined(profile) ? profile.Describe() : "-").");
  }

  public static func OnPicked(run: ref<RLRunState>, offer: ref<RLOffer>) {
    if offer.excitement >= 2 {
      run.magnificence += 1;
    }
  }

  // --- Hot doors ---------------------------------------------------------------------------

  // One in Act 1 (its window is floors 2-4, and two would always land on 2
  // and 4), two in Acts 2 and 3.
  public static func HotDoorsPerAct(act: Int32) -> Int32 {
    if act <= 1 {
      // Marked Man (the terminal) puts a second one in Act 1.
      return RLTerminal.Has(n"HotStreak", 2) ? 2 : 1;
    }
    return 2;
  }

  // The highest floor of an act that can have a hot door (the elite floor
  // and the boss come after it).
  public static func LastHotFloor() -> Int32 = RLConfig.EliteFloor() - 1

  // Should this floor's doors include a hot one? Decided once a floor, so a
  // reroll of the doors keeps the Director's call.
  public static func WantsHotDoor(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> Bool {
    let depth = run.Depth();
    if run.hotDecidedDepth != depth {
      run.hotDecidedDepth = depth;
      run.hotDecision = RLRewardDirector.DecideHot(run);
    }
    return run.hotDecision;
  }

  private static func DecideHot(run: ref<RLRunState>) -> Bool {
    let depth = run.Depth();
    let floor = run.floor;
    if run.hotLeft <= 0 || depth <= 1 || floor > RLRewardDirector.LastHotFloor() || run.lastHotDepth == depth - 1 {
      return false;
    }
    // Every act gets its hot doors: when skipping this floor would leave too
    // few floors for the rest, this one is hot.
    if run.hotLeft > RLRewardDirector.FloorsThatFit(floor + 1) {
      RLLog(s"Director: hot door on floor \(depth) (the act needs it).");
      return true;
    }
    let need = RLRewardDirector.Need(run);
    RLDebug(s"Director: need \(need) on floor \(depth), \(run.hotLeft) hot door(s) left this act.");
    if need >= 55 {
      RLLog(s"Director: hot door on floor \(depth) (need \(need)).");
      return true;
    }
    return false;
  }

  // How much V needs a spike right now (55 and up places a hot door).
  public static func Need(run: ref<RLRunState>) -> Int32 {
    let gap = RLQuality.ExpectedStep(run.Depth(), run.TotalFloors()) - run.mainStep;
    let need = 20 + RandRange(0, 30);
    need += 18 * Max(0, gap);
    need += 15 * run.flatStreak;
    if run.coverSpent > 0 && run.cover < run.coverMax {
      need += 20;
    }
    return need;
  }

  // Hot doors that still fit from `floor` to the act's last hot floor, never
  // two floors running.
  public static func FloorsThatFit(floor: Int32) -> Int32 {
    let last = RLRewardDirector.LastHotFloor();
    return floor > last ? 0 : (last - floor) / 2 + 1;
  }

  public static func OnHotPlaced(run: ref<RLRunState>) {
    if run.lastHotDepth != run.Depth() {
      run.hotLeft -= 1;
      run.lastHotDepth = run.Depth();
    }
  }
}

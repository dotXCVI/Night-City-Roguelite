// -----------------------------------------------------------------------------
// Night City Roguelite - reward director
// -----------------------------------------------------------------------------
// Bends reward luck towards a better run, without the player seeing it:
//
//   Quality   every card rolls around the floor's expected quality step:
//             -1 / 0 / +1 / +2 at 25 / 55 / 16 / 4%, elite floors and heavy
//             fights 10 / 50 / 30 / 10, light fights 35 / 55 / 10 / 0; boss
//             rewards are always +2 (Enter the Gungeon's floor tables, Slay the
//             Spire's elite and boss odds).
//   Pity      every flat reward screen (nothing above expectation) moves 6
//             points from -1 to +1, up to 30; a +2 card resets it (Slay the
//             Spire's rarity offset).
//   Spike     two flat screens in a row and the next one is guaranteed a
//             standout card: +2 quality, or a perk above the floor's power.
//   Magnificence  every +2 card taken makes the next +2 roll less likely
//             (x0.4 each), so one lucky run doesn't snowball (Enter the
//             Gungeon).
//   Build     offers matching the build get up to +40% weight
//             (Rewards/BuildProfile.reds), but every screen keeps at least one
//             card that doesn't match.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLRewardDirector {
  public static func PityStep() -> Int32 = 6
  public static func PityMax() -> Int32 = 30

  public static func SpikeDue(run: ref<RLRunState>) -> Bool = run.flatStreak >= 2

  // A card's quality step for this floor. `spike` forces +2.
  public static func RollStep(run: ref<RLRunState>, threat: Int32, spike: Bool) -> Int32 {
    let expected = RLQuality.ExpectedStep(run.Depth(), run.TotalFloors());
    if spike || run.IsBossFloor() {
      return Min(RLQuality.MaxStep(), expected + 2);
    }
    // Odds for -1, 0, +1, +2 steps.
    let odds: array<Float> = [25.0, 55.0, 16.0, 4.0];
    if run.IsEliteFloor() || threat >= 3 {
      odds = [10.0, 50.0, 30.0, 10.0];
    } else if threat <= 1 {
      odds = [35.0, 55.0, 10.0, 0.0];
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
    RLDebug(s"Reward director: best card \(best), flat streak \(run.flatStreak), pity \(run.pityOffset), magnificence \(run.magnificence). Build: \(IsDefined(profile) ? profile.Describe() : "-").");
  }

  public static func OnPicked(run: ref<RLRunState>, offer: ref<RLOffer>) {
    if offer.excitement >= 2 {
      run.magnificence += 1;
    }
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - encounter builder
// -----------------------------------------------------------------------------
// Turns a floor into waves of enemies.
//
//   Size     3 + floor/3 enemies per wave, +-1 for heavy / light doors, the
//            last wave one bigger. Act 1 fights have 2 waves, later acts 3;
//            heavy fights add a wave in Act 3.
//   Mix      grunt / tough / elite odds by act (Act 1 opens with grunts only);
//            heavy fights trade grunts for elites, light fights the reverse.
//   Elite    the elite floor puts one elite in every wave.
//   Boss     two regular waves, then the boss wave (faction elites in Act 1,
//            MaxTac after that) with a few adds.
//   Levels   from the run's curve (Run/Difficulty.reds): elites +1, bosses +2,
//            heavy doors +1, light doors -1.
//   Pacing   the pacing director's pressure (-1..1) scales wave size by up to
//            15% and shifts a little of the mix towards / away from elites
//            (Run/Pacing.reds). Boss units are never scaled.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLEncounters {
  public static func Build(run: ref<RLRunState>, faction: ref<RLFactionPool>, pressure: Float) -> ref<RLEncounterPlan> {
    let threat = run.Threat();
    let plan = new RLEncounterPlan();
    plan.factionName = RLEncounters.FactionName(faction.faction);

    let baseLevel = RLDifficulty.EnemyBaseLevel(run);
    let threatLevel = threat - 2;
    let weights = RLEncounters.TierWeights(run, threat, pressure);
    let perWave = 3 + run.Depth() / 3 + (threat - 2);
    perWave = Max(2, RoundF(Cast<Float>(perWave) * (1.0 + 0.15 * pressure)));

    let waves = run.act >= 2 ? 3 : 2;
    if threat >= 3 && run.act >= 3 {
      waves += 1;
    }
    if run.IsEliteFloor() {
      waves = 3;
    }
    if run.IsBossFloor() {
      waves = 2;
    }

    let w = 0;
    while w < waves {
      plan.BeginWave();
      let size = w == waves - 1 ? perWave + 1 : perWave;
      let k = 0;
      if run.IsEliteFloor() {
        plan.Add(faction.Pick(2), false, baseLevel + 1 + threatLevel, true);
        k = 1;
      }
      while k < size {
        let tier = RLEncounters.RollTier(weights);
        plan.Add(faction.Pick(tier), false, baseLevel + (tier >= 2 ? 1 : 0) + threatLevel, tier >= 2);
        k += 1;
      }
      w += 1;
    }

    if run.IsBossFloor() {
      plan.BeginWave();
      let bosses = RLEncounters.BossRecords(run.act);
      if ArraySize(bosses) == 0 {
        // Act 1, or no MaxTac records: faction elites lead the boss wave.
        plan.Add(faction.Pick(2), true, baseLevel + 2, true);
        plan.Add(faction.Pick(2), true, baseLevel + 2, true);
      } else {
        for boss in bosses {
          plan.Add(boss, true, baseLevel + 2, true);
        }
      }
      let adds = run.act + 1;
      while adds > 0 {
        plan.Add(faction.Pick(1), false, baseLevel, false);
        adds -= 1;
      }
    }
    return plan;
  }

  // Grunt / tough / elite odds.
  public static func TierWeights(run: ref<RLRunState>, threat: Int32, pressure: Float) -> array<Int32> {
    let weights: array<Int32>;
    if run.act <= 1 {
      weights = run.floor <= 2 ? [85, 15, 0] : [70, 27, 3];
    } else if run.act == 2 {
      weights = [50, 42, 8];
    } else {
      weights = [30, 50, 20];
    }
    if threat >= 3 {
      let shift = Min(10, weights[0]);
      weights[0] -= shift;
      weights[2] += shift;
    } else if threat <= 1 {
      weights[1] += weights[2];
      weights[2] = 0;
      let down = Min(15, weights[1]);
      weights[1] -= down;
      weights[0] += down;
    }
    // Pacing: a little more or less elite pressure (never elites on floors
    // that have none).
    if weights[2] > 0 {
      let shift = Clamp(RoundF(5.0 * pressure), -weights[2], weights[0]);
      weights[0] -= shift;
      weights[2] += shift;
    }
    return weights;
  }

  public static func RollTier(weights: array<Int32>) -> Int32 {
    let total = weights[0] + weights[1] + weights[2];
    let roll = RandRange(0, Max(1, total));
    if roll < weights[0] {
      return 0;
    }
    if roll < weights[0] + weights[1] {
      return 1;
    }
    return 2;
  }

  // MaxTac lead the boss waves of acts 2 and 3; act 1's boss wave is led by
  // faction elites (empty result).
  public static func BossRecords(act: Int32) -> array<TweakDBID> {
    let result: array<TweakDBID>;
    if act <= 1 {
      return result;
    }
    let maxtac: array<TweakDBID>;
    for id in RLBosses.MaxTac() {
      if RLBosses.Exists(id) {
        ArrayPush(maxtac, id);
      }
    }
    let count = act >= 3 ? 3 : 2;
    let i = 0;
    while i < count && ArraySize(maxtac) > 0 {
      ArrayPush(result, maxtac[RandRange(0, ArraySize(maxtac))]);
      i += 1;
    }
    return result;
  }

  public static func FactionName(faction: gamedataAffiliation) -> String {
    switch faction {
      case gamedataAffiliation.Animals: return "Animals";
      case gamedataAffiliation.Maelstrom: return "Maelstrom";
      case gamedataAffiliation.Scavengers: return "Scavengers";
      case gamedataAffiliation.SixthStreet: return "6th Street";
      case gamedataAffiliation.TygerClaws: return "Tyger Claws";
      case gamedataAffiliation.Valentinos: return "Valentinos";
      case gamedataAffiliation.VoodooBoys: return "Voodoo Boys";
      case gamedataAffiliation.Wraiths: return "Wraiths";
      case gamedataAffiliation.Barghest: return "Barghest";
      case gamedataAffiliation.Arasaka: return "Arasaka";
      case gamedataAffiliation.Militech: return "Militech";
      case gamedataAffiliation.KangTao: return "Kang Tao";
    }
    return "Hostiles";
  }
}

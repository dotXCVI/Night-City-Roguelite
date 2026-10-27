// -----------------------------------------------------------------------------
// Night City Roguelite - difficulty curve
// -----------------------------------------------------------------------------
// The mod's own difficulty, set by how far into the run V is (the game's
// difficulty stays on Hard for AI behaviour):
//
//   - Enemy level follows the floor, never V: base level = floor number plus
//     a per-act offset (Act 1 one level below, Act 3 one above). V gains a
//     level with every reward, so every level V earns makes V stronger.
//   - Damage V takes is scaled from IncomingDamageFirstFloor (floor 1) to
//     IncomingDamageLastFloor (floor 18) - early fights forgive mistakes.
//
// Both curves live in Core/Config.reds.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLDifficulty {
  // Base enemy level for the run's current floor.
  public static func EnemyBaseLevel(run: ref<RLRunState>) -> Int32 {
    return Max(1, run.Depth() + RLConfig.EnemyLevelOffset(run.act));
  }

  // Multiplier on damage V takes at the given floor (1-based).
  public static func IncomingDamageScale(depth: Int32, totalFloors: Int32) -> Float {
    let progress = totalFloors > 1 ? Cast<Float>(depth - 1) / Cast<Float>(totalFloors - 1) : 0.0;
    progress = ClampF(progress, 0.0, 1.0);
    let first = RLConfig.IncomingDamageFirstFloor();
    return first + (RLConfig.IncomingDamageLastFloor() - first) * progress;
  }
}

// Damage V takes during a run: the curve above, the pacing director's
// pressure and assist mode (RogueliteSystem.GetIncomingDamageScale).
@wrapMethod(DamageSystem)
private final func ProcessPlayerIncomingDamageMultiplier(hitEvent: ref<gameHitEvent>) {
  wrappedMethod(hitEvent);
  let player = hitEvent.target as PlayerPuppet;
  if !IsDefined(player) {
    return;
  }
  let system = RogueliteSystem.Get(player.GetGame());
  if !IsDefined(system) || !system.IsInArenaFight() {
    return;
  }
  hitEvent.attackComputed.MultAttackValue(system.GetIncomingDamageScale());
}

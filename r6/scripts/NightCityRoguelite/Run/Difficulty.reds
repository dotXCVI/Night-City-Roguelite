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
//   - Gates: from Act 2, bosses (and in Act 3 every enemy) shrug off part
//     of V's damage, so a run without a build behind it stalls there while
//     styles, mods and Overdrive carry a real one (EnemyToughness).
//
// The curves live in Core/Config.reds.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLDifficulty {
  // Base enemy level for the run's current floor.
  public static func EnemyBaseLevel(run: ref<RLRunState>) -> Int32 {
    return Max(1, run.Depth() + RLConfig.EnemyLevelOffset(run.act));
  }

  // Multiplier on V's damage against an arena enemy (the act's gate).
  public static func EnemyToughness(run: ref<RLRunState>, isBoss: Bool) -> Float {
    return isBoss ? RLConfig.BossDamageTaken(run.act) : RLConfig.EnemyDamageTaken(run.act);
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
// pressure, assist mode, boons and event trade-offs
// (RogueliteSystem.ScaleIncomingHit).
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
  let scale = system.ScaleIncomingHit(player, hitEvent);
  if scale <= 0.0 {
    // V's own blast: no damage at all (the game's fixed-percentage
    // explosion damage would otherwise apply later in the pipeline).
    hitEvent.attackData.AddFlag(hitFlag.DealNoDamage, n"NCRogueliteSelfBlast");
    return;
  }
  hitEvent.attackComputed.MultAttackValue(scale);
}

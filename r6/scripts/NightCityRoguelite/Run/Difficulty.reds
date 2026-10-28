// -----------------------------------------------------------------------------
// Night City Roguelite - difficulty curve
// -----------------------------------------------------------------------------
// The mod's own difficulty (the game's difficulty stays on Hard for AI
// behaviour):
//
//   - Levels are set per act, for V and the enemies alike (Config.ActLevel).
//     Inside an act nothing scales, so every pick is pure gain; the boss
//     steps both, and the act step tunes V's weapons up with it.
//   - Damage V takes is set per act too (Config.ActIncomingDamage): early
//     fights forgive mistakes.
//   - No hidden taxes: the old weapon-quality penalty and the act gates
//     (enemies shrugging off part of V's damage) are gone. ARMORED is
//     plating to break (Combat/Affixes.reds); bosses get phases.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLDifficulty {
  // Base enemy level for the run's act.
  public static func EnemyBaseLevel(run: ref<RLRunState>) -> Int32 = RLConfig.ActLevel(run.act)

  // Multiplier on damage V takes in the run's act.
  public static func IncomingDamageScale(run: ref<RLRunState>) -> Float = RLConfig.ActIncomingDamage(run.act)

  // Puts V at the act's level (levels only ever go up).
  public static func SetPlayerLevel(player: ref<PlayerPuppet>, act: Int32) {
    let data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return;
    }
    let current = data.GetProficiencyLevel(gamedataProficiencyType.Level);
    let target = RLConfig.ActLevel(act);
    if target > current {
      data.RL_GrantLevels(target - current);
    }
  }
}

// Damage V takes during a run: the act's scale, the pacing director's
// pressure, assist mode, effects and event trade-offs
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
    // Absorbed (V's own blast, a SHIELD, an untouchable moment): no damage at
    // all (the game's fixed-percentage explosion damage would otherwise apply
    // later in the pipeline).
    hitEvent.attackData.AddFlag(hitFlag.DealNoDamage, n"NCRogueliteAbsorbed");
    return;
  }
  hitEvent.attackComputed.MultAttackValue(scale);
}

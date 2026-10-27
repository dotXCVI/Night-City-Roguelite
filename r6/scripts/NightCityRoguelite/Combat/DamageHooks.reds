// -----------------------------------------------------------------------------
// Night City Roguelite - combat hooks
// -----------------------------------------------------------------------------
// Where boons and elite affixes meet the game's damage pipeline:
//
//   - hits V lands on arena enemies are scaled after the game's own
//     modifiers and before the damage is dealt (DamageSystem.Process calls
//     ProcessCrowdTarget right after the global modifiers);
//   - an arena enemy's death fires kill boons and death affixes at once.
//
// Hits V takes are scaled in Run/Difficulty.reds.
// -----------------------------------------------------------------------------

module NightCityRoguelite

@wrapMethod(DamageSystem)
private final func ProcessCrowdTarget(hitEvent: ref<gameHitEvent>) {
  wrappedMethod(hitEvent);
  if hitEvent.projectionPipeline {
    return;
  }
  let target = hitEvent.target as ScriptedPuppet;
  let instigator = hitEvent.attackData.GetInstigator();
  if !IsDefined(target) || !IsDefined(instigator) || !instigator.IsPlayer() {
    return;
  }
  let system = RogueliteSystem.Get(target.GetGame());
  if IsDefined(system) {
    let factor = system.OnOutgoingHit(target, hitEvent);
    if factor != 1.0 {
      hitEvent.attackComputed.MultAttackValue(factor);
    }
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let system = RogueliteSystem.Get(this.GetGame());
  if IsDefined(system) {
    system.OnArenaEnemyDied(this);
  }
  return result;
}

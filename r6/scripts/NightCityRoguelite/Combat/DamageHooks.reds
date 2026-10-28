// -----------------------------------------------------------------------------
// Night City Roguelite - combat hooks
// -----------------------------------------------------------------------------
// Where effects and elite affixes meet the game's damage pipeline:
//
//   - hits V lands on arena enemies are scaled after the game's own
//     modifiers and before the damage is dealt (DamageSystem.Process calls
//     ProcessCrowdTarget right after the global modifiers);
//   - an arena enemy's death fires kill effects and death affixes at once;
//   - a quickhack V uploads onto one is read when the upload finishes, damage
//     or not (Rewards/BoonEffects.reds OnUpload).
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
  if !IsDefined(target) || !IsDefined(instigator) {
    return;
  }
  let system = RogueliteSystem.Get(target.GetGame());
  if !instigator.IsPlayer() {
    // Drone Escort's hits carry V's keywords once overclocked.
    if IsDefined(system) && system.IsEscortDrone(instigator.GetEntityID()) {
      system.OnDroneHit(target);
    }
    return;
  }
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

// A quickhack finished uploading. The listener is the game's own for every
// quickhack upload; only V's uploads onto arena enemies count.
@wrapMethod(QuickHackUploadListener)
protected cb func OnStatPoolMaxValueReached(value: Float) -> Bool {
  let action = this.m_action;
  let game = this.m_gameInstance;
  let result = wrappedMethod(value);
  if !IsDefined(action) || !action.IsQuickHack() {
    return result;
  }
  let executor = action.GetExecutor();
  if !IsDefined(executor) || !executor.IsPlayer() {
    return result;
  }
  let target = GameInstance.FindEntityByID(game, action.GetRequesterID()) as ScriptedPuppet;
  let system = RogueliteSystem.Get(game);
  if IsDefined(target) && IsDefined(system) {
    system.OnQuickhackUploaded(target, action.GetObjectActionID());
  }
  return result;
}

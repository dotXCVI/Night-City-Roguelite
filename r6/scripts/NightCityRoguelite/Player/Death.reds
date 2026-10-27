// -----------------------------------------------------------------------------
// Night City Roguelite - death and coming to
// -----------------------------------------------------------------------------
// When a run is lost V really dies: the game's own death plays (weapons drop
// away, the camera goes down, the death sound), and V then comes to through
// the same path the Second Heart cyberware uses - the player state machine's
// resurrection (DeathDecisionsWithResurrection -> ResurrectEvents, which
// revives V at full health).
//
//   - The game's death menu is held back with the quest fact the story uses
//     for scripted deaths (block_death_menu); its old value is restored after.
//   - Resurrection is allowed while RogueliteSystem says a flatline is being
//     handled: HasSecondHeart answers yes for that moment only.
//
// The run system fades to black while V is down and takes V home once V has
// come to (RogueliteSystem.Flatline / DeathTick). If V somehow stays down,
// the death menu is let through after a while, so the game can never hang.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLDeath {
  public static func DeathMenuFact() -> CName = n"block_death_menu"

  // Holds the death menu back and takes V's health to zero. Returns the old
  // value of the death-menu fact, for End().
  public static func Begin(player: ref<PlayerPuppet>) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }
    let game = player.GetGame();
    let quests = GameInstance.GetQuestsSystem(game);
    let previous = quests.GetFact(RLDeath.DeathMenuFact());
    quests.SetFact(RLDeath.DeathMenuFact(), 1);
    GameInstance.GetStatPoolsSystem(game).RequestSettingStatPoolValue(
      Cast<StatsObjectID>(player.GetEntityID()),
      gamedataStatPoolType.Health,
      0.0,
      null,
      true
    );
    RLLog("Flatlined: V is going down.");
    return previous;
  }

  public static func End(game: GameInstance, previousFact: Int32) {
    GameInstance.GetQuestsSystem(game).SetFact(RLDeath.DeathMenuFact(), previousFact);
  }

  // The fallback when V stays down: the game's own death menu (load a save).
  public static func ShowDeathMenu(player: ref<PlayerPuppet>) {
    let blackboard = IsDefined(player) ? player.GetPlayerStateMachineBlackboard() : null;
    if IsDefined(blackboard) {
      blackboard.SetBool(GetAllBlackboardDefs().PlayerStateMachine.DisplayDeathMenu, true);
    }
  }

  // V's health is at zero: dead, or still on the way back.
  public static func IsDown(player: ref<PlayerPuppet>) -> Bool {
    return GameInstance.GetStatPoolsSystem(player.GetGame())
      .HasStatPoolValueReachedMin(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health);
  }

  // The resurrection leaves the Second Heart effect behind; it isn't V's.
  public static func ClearAftermath(player: ref<PlayerPuppet>) {
    StatusEffectHelper.RemoveStatusEffect(player, t"BaseStatusEffect.SecondHeart");
  }
}

@wrapMethod(HighLevelTransition)
protected const final func HasSecondHeart(scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let system = RogueliteSystem.Get(scriptInterface.owner.GetGame());
  if IsDefined(system) && system.IsResurrectionPending() {
    return true;
  }
  return wrappedMethod(scriptInterface);
}

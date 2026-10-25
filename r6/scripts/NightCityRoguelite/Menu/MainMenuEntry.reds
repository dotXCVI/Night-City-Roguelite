// -----------------------------------------------------------------------------
// Night City Roguelite - main menu entry
// -----------------------------------------------------------------------------
// Adds a ROGUELITE item above New Game. Choosing it:
//   1. marks a pending roguelite start in the meta service,
//   2. runs the normal new-game flow,
//   3. auto-selects the Phantom Liberty standalone start on the expansion screen
//      (no story prologue), then continues to difficulty, lifepath and the
//      character creator as usual.
// Once the new game is ready, RogueliteSystem takes over.
// -----------------------------------------------------------------------------

module NightCityRoguelite

@wrapMethod(SingleplayerMenuGameController)
private func PopulateMenuItemList() {
  // The original adds Continue / New Game / Load / Settings / ...
  // We want ROGUELITE right before New Game, so rebuild the list order:
  // insert ours first, then let the original append the rest.
  if this.RL_IsExpansionAvailable() {
    this.AddMenuItem("ROGUELITE", n"OnRogueliteNewGame");
  }
  wrappedMethod();
}

@addMethod(SingleplayerMenuGameController)
private func RL_IsExpansionAvailable() -> Bool {
  return this.GetSystemRequestsHandler().IsAdditionalContentEnabled(n"EP1");
}

@addMethod(MenuScenario_SingleplayerMenu)
protected cb func OnRogueliteNewGame() -> Bool {
  RogueliteService.Get().RequestPendingStart();
  this.CloseSubMenu();
  this.SwitchToScenario(n"MenuScenario_ExpansionNewGame");
}

// Entering the main menu again (Back from the new-game flow, or after quitting
// a session) cancels any roguelite start that didn't make it into a game.
@wrapMethod(MenuScenario_SingleplayerMenu)
protected cb func OnEnterScenario(prevScenario: CName, userData: ref<IScriptable>) -> Bool {
  RogueliteService.Get().ClearPendingStart();
  return wrappedMethod(prevScenario, userData);
}

// Auto-pick the Phantom Liberty standalone start once the screen is ready.
@wrapMethod(ExpansionNewGame)
protected cb func OnIntroComplete(anim: ref<inkAnimProxy>) -> Bool {
  let result = wrappedMethod(anim);
  if RogueliteService.Get().TryConsumeScreenSkip() {
    this.m_characterCustomizationState.SetIsExpansionStandalone(true);
    this.PlaySound(n"Button", n"OnPress");
    this.NextMenu();
  }
  return result;
}

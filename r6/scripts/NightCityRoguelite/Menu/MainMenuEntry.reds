// -----------------------------------------------------------------------------
// Night City Roguelite - main menu entry
// -----------------------------------------------------------------------------
// Adds a ROGUELITE item above New Game. Choosing it:
//   1. marks a pending roguelite start in the meta service,
//   2. runs the normal new-game flow,
//   3. passes the campaign screen without ever showing it (Phantom Liberty
//      standalone start, no story prologue), skips the difficulty screen (the
//      mod sets its own), the life path screen (Street Kid - it changes
//      nothing here) and the attribute screen (the mod resets attributes), so
//      the flow is body type -> appearance -> summary.
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

// The campaign screen is never shown: it is hidden as it initializes (its
// intro animation would fade it back in, so visibility rather than opacity).
// The intro must be left to finish - its end is what calls OnIntroComplete
// (stopping it early left a blank screen in v0.0.14) - and there the
// standalone start, the life path and zero creation points (the mod sets
// attributes itself) are chosen. Its outro then plays hidden and hands over
// to the next screen.
@wrapMethod(ExpansionNewGame)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  if RogueliteService.Get().HasPendingStart() {
    this.GetRootWidget().SetVisible(false);
  }
  return result;
}

@wrapMethod(ExpansionNewGame)
protected cb func OnIntroComplete(anim: ref<inkAnimProxy>) -> Bool {
  let result = wrappedMethod(anim);
  if RogueliteService.Get().TryConsumeScreenSkip() {
    this.m_characterCustomizationState.SetIsExpansionStandalone(true);
    this.m_characterCustomizationState.SetLifePath(t"LifePaths.StreetKid");
    this.m_characterCustomizationState.SetAttributePointsAvailable(0u);
    this.NextMenu();
  } else {
    this.GetRootWidget().SetVisible(true);
  }
  return result;
}

// Difficulty and life path screens skipped: straight to body type.
@wrapMethod(MenuScenario_ExpansionNewGame)
protected cb func OnAccept() -> Bool {
  if RogueliteService.Get().HasPendingStart() {
    this.SwitchToScenario(n"MenuScenario_BodyTypeSelection");
    return true;
  }
  return wrappedMethod();
}

// Body type normally follows the life path screen, which opens the creator's
// background; open it here instead when coming straight from the campaign
// screen.
@wrapMethod(MenuScenario_BodyTypeSelection)
protected cb func OnEnterScenario(prevScenario: CName, userData: ref<IScriptable>) -> Bool {
  if Equals(prevScenario, n"MenuScenario_ExpansionNewGame") && RogueliteService.Get().HasPendingStart() {
    this.GetMenusState().OpenMenu(n"character_customization_background");
  }
  return wrappedMethod(prevScenario, userData);
}

// The attribute screen is skipped (attributes are reset when the run starts).
@wrapMethod(MenuScenario_CharacterCustomization)
protected cb func OnAccept() -> Bool {
  if RogueliteService.Get().HasPendingStart() {
    this.SwitchToScenario(n"MenuScenario_Summary");
    return true;
  }
  return wrappedMethod();
}

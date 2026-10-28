// -----------------------------------------------------------------------------
// Night City Roguelite - Operating System activation
// -----------------------------------------------------------------------------
// The game's own cyberware button triggers Overdrive (Run/Overdrive.reds):
// each OS puts a status effect on V when it activates, which is how the mod
// sees it - Sandevistan its player buff, Berserk its player buffs, a
// cyberdeck's Overclock anything tagged "Overclock".
//
// Air Dash also gets a real cooldown here (the game's 0.4 s let it be chained
// almost without pause on a roguelite build), and every dash and slide is
// passed on to the run's effects.
// -----------------------------------------------------------------------------

module NightCityRoguelite

@addField(PlayerPuppet)
public let rl_lastAirDash: Float;

@addField(PlayerPuppet)
public let rl_lastDash: Float;

public abstract class RLAirDash {
  public static func Cooldown() -> Float = 1.5
}

// No second air dash until the cooldown is over (roguelite characters only).
@wrapMethod(LocomotionTransition)
protected const final func WantsToDodge(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let wants = wrappedMethod(stateContext, scriptInterface);
  if !wants || scriptInterface.IsOnGround() {
    return wants;
  }
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(player) || player.rl_lastAirDash <= 0.0 {
    return wants;
  }
  let system = RogueliteSystem.Get(player.GetGame());
  if !IsDefined(system) || !system.IsRoguelitePlaythrough() {
    return wants;
  }
  let now = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
  return now - player.rl_lastAirDash >= RLAirDash.Cooldown();
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if IsDefined(evt.staticData) {
    let id = evt.staticData.GetID();
    if id == t"BaseStatusEffect.PlayerJustAirDashed" {
      this.rl_lastAirDash = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
    }
    // Every dodge, dash and air dash feeds the dash effects (Kinetic Dash,
    // Convoy, MOMENTUM...), once per move.
    if id == t"BaseStatusEffect.PlayerJustAirDashed" || id == t"BaseStatusEffect.PlayerJustDodged" || id == t"BaseStatusEffect.PlayerJustDashed" {
      let now = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
      if now - this.rl_lastDash > 0.25 {
        this.rl_lastDash = now;
        let system = RogueliteSystem.Get(this.GetGame());
        if IsDefined(system) {
          system.OnPlayerDashed();
        }
      }
    }
  }
  if evt.isNewApplication && IsDefined(evt.staticData) {
    let os = RLOSHooks.Activated(evt.staticData);
    if IsNameValid(os) {
      let system = RogueliteSystem.Get(this.GetGame());
      if IsDefined(system) {
        system.OnOperatingSystemActivated(os);
      }
    }
  }
  return result;
}

// A slide counts for the effects that ask for one (Slipstream, Kinetic
// Rounds).
@wrapMethod(SlideEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) {
  wrappedMethod(stateContext, scriptInterface);
  let player = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    let system = RogueliteSystem.Get(player.GetGame());
    if IsDefined(system) {
      system.OnPlayerSlid();
    }
  }
}

// The game's own Sandevistan clean-up turns "V ignores time dilation" off a
// second after it ends; while Zero Hour is still running V must keep moving.
@wrapMethod(PlayerPuppet)
protected cb func OnCleanUpTimeDilationEvent(evt: ref<CleanUpTimeDilationEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let time = GameInstance.GetTimeSystem(this.GetGame());
  if time.IsTimeDilationActive(n"NCRogueliteZeroHour") {
    time.SetIgnoreTimeDilationOnLocalPlayerZero(true);
  }
  return result;
}

public abstract class RLOSHooks {
  // The OS a status effect announces ("" for any other effect).
  public static func Activated(effect: ref<StatusEffect_Record>) -> CName {
    let id = effect.GetID();
    if id == t"BaseStatusEffect.SandevistanPlayerBuff" || id == t"BaseStatusEffect.CooldownedSandevistanPlayerBuff" {
      return n"Sandevistan";
    }
    if id == t"BaseStatusEffect.BerserkPlayerBuff" || id == t"BaseStatusEffect.AdvancedBerserkPlayerBuff" {
      return n"Berserk";
    }
    let tags = effect.GameplayTags();
    if ArrayContains(tags, n"Overclock") {
      return n"Cyberdeck";
    }
    return n"";
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - Operating System activation
// -----------------------------------------------------------------------------
// The game's own cyberware button triggers Overdrive (Run/Overdrive.reds):
// each OS puts a status effect on V when it activates, which is how the mod
// sees it - Sandevistan its player buff, Berserk its player buffs, a
// cyberdeck's Overclock anything tagged "Overclock".
// -----------------------------------------------------------------------------

module NightCityRoguelite

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result = wrappedMethod(evt);
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

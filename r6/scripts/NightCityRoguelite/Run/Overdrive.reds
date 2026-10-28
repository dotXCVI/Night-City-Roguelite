// -----------------------------------------------------------------------------
// Night City Roguelite - Overdrive and cyberpsychosis episodes
// -----------------------------------------------------------------------------
// Overdrive is the run's ultimate (Hades' Call). It unlocks with the
// Operating System chosen at the Act 1 boss, charges from kills (more from
// elites and bosses) and from damage V takes, and carries over between
// fights. Once it is full, activating the OS (the game's own cyberware
// button) overdrives it:
//
//   Sandevistan  ZERO HOUR  time nearly stops for 7 s, +50% damage
//   Berserk      RAMPAGE    a shockwave, then 8 s of +60% damage, 70% less
//                           damage taken and kills that heal
//   Cyberdeck    BLACKWALL  every enemy within 40 m loses half its health
//                           (bosses 15%), is electrocuted and stunned; RAM
//                           refills
//
// The OS activation is seen through the status effect it puts on V
// (Player/OSHooks.reds).
//
// Capacity overclock (chrome installed over capacity) shares the place:
// every 20 s of fighting, each point over capacity is a 6% chance of a
// cyberpsychosis episode - 6 s of +30% damage dealt and taken.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLOverdrive {
  public static func Full() -> Float = 100.0

  public static func KillCharge(isBoss: Bool, isElite: Bool) -> Float {
    if isBoss {
      return 30.0;
    }
    return isElite ? 15.0 : 5.0;
  }

  public static func Name(os: CName) -> String {
    switch os {
      case n"Sandevistan": return "ZERO HOUR";
      case n"Berserk": return "RAMPAGE";
      case n"Cyberdeck": return "BLACKWALL";
    }
    return "OVERDRIVE";
  }

  public static func Description(os: CName) -> String {
    switch os {
      case n"Sandevistan": return "Time nearly stops for 7 s. +50% damage.";
      case n"Berserk": return "A shockwave, then 8 s of +60% damage, 70% less damage taken, kills heal.";
      case n"Cyberdeck": return "Every enemy nearby loses half its health, is electrocuted and stunned. RAM refills.";
    }
    return "";
  }

  public static func IsReady(run: ref<RLRunState>) -> Bool = IsDefined(run) && run.overdriveUnlocked && run.overdrive >= RLOverdrive.Full()

  // The HUD's piece of the status line ("" before it unlocks).
  public static func Status(run: ref<RLRunState>) -> String {
    if !IsDefined(run) || !run.overdriveUnlocked {
      return "";
    }
    if RLOverdrive.IsReady(run) {
      return RLOverdrive.Name(run.os) + " READY";
    }
    return s"\(RLOverdrive.Name(run.os)) \(RoundF(run.overdrive))%";
  }

  public static func Charge(run: ref<RLRunState>, game: GameInstance, amount: Float) {
    if !IsDefined(run) || !run.overdriveUnlocked || amount <= 0.0 {
      return;
    }
    let wasReady = RLOverdrive.IsReady(run);
    // Hair Trigger (the terminal): the meter fills a quarter faster.
    let gain = RLTerminal.Has(n"Primed", 2) ? amount * 1.25 : amount;
    run.overdrive = MinF(RLOverdrive.Full(), run.overdrive + gain);
    if !wasReady && RLOverdrive.IsReady(run) {
      RLNotify(game, RLOverdrive.Name(run.os) + " READY - ACTIVATE YOUR OPERATING SYSTEM", 5.0);
    }
  }

  public static func OnKill(run: ref<RLRunState>, combat: ref<RLCombatState>, game: GameInstance, isBoss: Bool, isElite: Bool) {
    // No charge from kills made during the overdrive itself.
    if combat.rampageUntil > RLBoonEffects.Now(game) || GameInstance.GetTimeSystem(game).IsTimeDilationActive(n"NCRogueliteZeroHour") {
      return;
    }
    RLOverdrive.Charge(run, game, RLOverdrive.KillCharge(isBoss, isElite));
  }

  // Health lost (percent of max) charges a little: close calls pay.
  public static func OnDamageTaken(run: ref<RLRunState>, game: GameInstance, percent: Float) {
    RLOverdrive.Charge(run, game, 0.3 * percent);
  }

  // The OS was activated: overdrive it when the meter is full.
  public static func OnActivated(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>, os: CName) -> Bool {
    let game = player.GetGame();
    let now = RLBoonEffects.Now(game);
    // One activation puts several effects on V.
    if !RLOverdrive.IsReady(run) || now - combat.overdriveFiredAt < 2.0 {
      return false;
    }
    combat.overdriveFiredAt = now;
    run.overdrive = 0.0;
    switch os {
      case n"Sandevistan":
        let time = GameInstance.GetTimeSystem(game);
        time.SetIgnoreTimeDilationOnLocalPlayerZero(true);
        time.SetTimeDilation(n"NCRogueliteZeroHour", 0.06, 7.0, n"Linear", n"Linear");
        break;
      case n"Berserk":
        RLExplosions.Blast(player, player.GetWorldPosition(), t"Attacks.CyberwareExplosion", 8.0, null, n"Rampage");
        combat.rampageUntil = now + 8.0;
        break;
      case n"Cyberdeck":
        RLOverdrive.Blackwall(player);
        break;
      default:
        return false;
    }
    RLOverdrive.AfterActivated(player);
    RLNotify(game, RLOverdrive.Name(os), 3.0);
    RLLog("Overdrive: " + RLOverdrive.Name(os) + ".");
    return true;
  }

  // The terminal's Meltdown row: Afterburn refills the MaxDoc, Meltdown sets
  // off a BLAST around V.
  private static func AfterActivated(player: ref<PlayerPuppet>) {
    let game = player.GetGame();
    if RLTerminal.Has(n"Meltdown", 1) {
      ConsumablesChargesHelper.RefreshAllCharges(game, gamedataStatPoolType.HealingItemsCharges);
    }
    let system = RogueliteSystem.Get(game);
    if RLTerminal.Has(n"Meltdown", 2) && IsDefined(system) && system.IsFighting() {
      let fx = system.Fx(player);
      RLBoonEffects.As(fx, n"Meltdown");
      RLKeywords.Blast(fx, player.GetWorldPosition(), 6.0, null, 0);
    }
  }

  private static func Blackwall(player: ref<PlayerPuppet>) {
    let game = player.GetGame();
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) {
      return;
    }
    let pools = GameInstance.GetStatPoolsSystem(game);
    let combat = system.GetCombat();
    for enemy in system.EnemiesNear(player.GetWorldPosition(), 40.0) {
      let share = combat.IsBoss(enemy.GetEntityID()) ? 15.0 : 50.0;
      pools.RequestChangingStatPoolValue(Cast<StatsObjectID>(enemy.GetEntityID()), gamedataStatPoolType.Health, -share, player, false, true);
      StatusEffectHelper.ApplyStatusEffect(enemy, t"BaseStatusEffect.Electrocuted", player.GetEntityID());
      StatusEffectHelper.ApplyStatusEffect(enemy, t"BaseStatusEffect.Stun", player.GetEntityID());
    }
    pools.RequestSettingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, 100.0, null, true);
  }

  // The fight is over (cleared, lost, abandoned): no slow time or episode
  // glitch carries into what comes next.
  public static func Stop(game: GameInstance, player: ref<PlayerPuppet>) {
    let time = GameInstance.GetTimeSystem(game);
    if time.IsTimeDilationActive(n"NCRogueliteZeroHour") {
      time.UnsetTimeDilation(n"NCRogueliteZeroHour", n"None");
      time.SetIgnoreTimeDilationOnLocalPlayerZero(false);
    }
    time.UnsetTimeDilation(n"NCRogueliteBlades", n"None");
    time.UnsetTimeDilation(n"NCRogueliteEcho", n"None");
    if IsDefined(player) {
      GameObjectEffectHelper.StopEffectEvent(player, n"transition_glitch_loop");
    }
  }

  public static func IsRampage(combat: ref<RLCombatState>, game: GameInstance) -> Bool = combat.rampageUntil > RLBoonEffects.Now(game)

  // Multiplier on V's hits: Zero Hour, Rampage, an episode.
  public static func OutgoingFactor(combat: ref<RLCombatState>, game: GameInstance) -> Float {
    let factor = 1.0;
    if GameInstance.GetTimeSystem(game).IsTimeDilationActive(n"NCRogueliteZeroHour") {
      factor *= 1.5;
    }
    if RLOverdrive.IsRampage(combat, game) {
      factor *= 1.6;
    }
    if combat.psychoUntil > RLBoonEffects.Now(game) {
      factor *= 1.3;
    }
    return factor;
  }

  // Multiplier on hits V takes.
  public static func IncomingFactor(combat: ref<RLCombatState>, game: GameInstance) -> Float {
    let factor = 1.0;
    if RLOverdrive.IsRampage(combat, game) {
      factor *= 0.3;
    }
    if combat.psychoUntil > RLBoonEffects.Now(game) {
      factor *= 1.3;
    }
    return factor;
  }

  // Kills during Rampage heal.
  public static func RampageHeal(combat: ref<RLCombatState>, player: ref<PlayerPuppet>) {
    if RLOverdrive.IsRampage(combat, player.GetGame()) {
      GameInstance.GetStatPoolsSystem(player.GetGame()).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, 4.0, null, false, true);
    }
  }

  // Once a second in a fight: capacity overclock episodes.
  public static func OnTick(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>) {
    if run.overclock <= 0 {
      return;
    }
    let game = player.GetGame();
    let now = RLBoonEffects.Now(game);
    if combat.psychoUntil > now {
      return;
    }
    combat.psychoTimer += 1.0;
    if combat.psychoTimer < 20.0 {
      return;
    }
    combat.psychoTimer = 0.0;
    // Neural Dampers (the terminal) halve the odds.
    let odds = MinF(0.6, 0.06 * Cast<Float>(run.overclock)) * (RLTerminal.Has(n"Tolerance", 2) ? 0.5 : 1.0);
    if RandF() < odds {
      combat.psychoUntil = now + 6.0;
      GameObjectEffectHelper.StartEffectEvent(player, n"transition_glitch_loop", false);
      RLDelay(game, RLEpisodeEnd.Create(player), n"episodeEnd", 6.0);
      RLNotify(game, "CYBERPSYCHOSIS EPISODE", 3.0);
      RLLog(s"Cyberpsychosis episode (overclock \(run.overclock)).");
    }
  }
}

// Ends an episode's screen glitch.
public class RLEpisodeEnd extends RLDelayTarget {
  private let m_player: wref<PlayerPuppet>;

  public static func Create(player: ref<PlayerPuppet>) -> ref<RLEpisodeEnd> {
    let target = new RLEpisodeEnd();
    target.m_player = player;
    RLExplosions.Keep(target);
    return target;
  }

  public func OnDelayed(action: CName) {
    if IsDefined(this.m_player) {
      GameObjectEffectHelper.StopEffectEvent(this.m_player, n"transition_glitch_loop");
    }
    RLExplosions.Release(this);
  }
}

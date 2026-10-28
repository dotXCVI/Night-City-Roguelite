// -----------------------------------------------------------------------------
// Night City Roguelite - effects in fights
// -----------------------------------------------------------------------------
// The rules behind the effects (Rewards/Boons.reds), the elite affixes' damage
// side and V's FOCUS, MOMENTUM and SHIELD, driven by six hooks:
//
//   outgoing hit  every hit V lands (Combat/DamageHooks.reds): multipliers,
//                 then the procs - which put keywords on enemies
//                 (Combat/Keywords.reds) and set the reactions to them off;
//   incoming hit  every hit V takes: the SHIELD, MOMENTUM lost, favours;
//   kill          every arena enemy that dies: kill procs, which can read how
//                 the killing hit landed;
//   dash          V dodged or air-dashed (Player/OSHooks.reds);
//   tick          once a second in a fight: bleeding, MOMENTUM from moving,
//                 Red Mist, arcs, marks running out;
//   step          a reaction that was scheduled a beat later (RLEffectStep).
//
// Every effect that adds damage or fires notes it in the fight's ledger, so
// the telemetry shows which cards carry a build and which never fire.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLBoonEffects {
  public static func Now(game: GameInstance) -> Float = EngineTime.ToFloat(GameInstance.GetTimeSystem(game).GetSimTime())

  public static func HitFlags(hitEvent: ref<gameHitEvent>, run: ref<RLRunState>) -> Int32 {
    let flags = 0;
    let attackData = hitEvent.attackData;
    if attackData.HasFlag(hitFlag.Headshot) {
      flags |= RLHitFlag.Headshot();
    }
    if attackData.HasFlag(hitFlag.CriticalHit) {
      flags |= RLHitFlag.Crit();
    }
    switch attackData.GetAttackType() {
      case gamedataAttackType.Ranged:
        flags |= RLHitFlag.Ranged();
        break;
      case gamedataAttackType.Melee:
      case gamedataAttackType.QuickMelee:
      case gamedataAttackType.StrongMelee:
      case gamedataAttackType.GuardBreak:
      case gamedataAttackType.WhipAttack:
      case gamedataAttackType.ChargedWhipAttack:
      case gamedataAttackType.Thrown:
        flags |= RLHitFlag.Melee();
        break;
      case gamedataAttackType.Explosion:
      case gamedataAttackType.PressureWave:
        flags |= RLHitFlag.Explosion();
        break;
      case gamedataAttackType.Hack:
        flags |= RLHitFlag.Quickhack();
        break;
      case gamedataAttackType.Effect:
        flags |= RLHitFlag.Tick();
        break;
    }
    if attackData.HasFlag(hitFlag.QuickHack) {
      flags |= RLHitFlag.Quickhack();
    }
    let weapon = attackData.GetWeapon();
    if IsDefined(run) && IsDefined(weapon) && RLWeapons.IsMain(run, weapon.GetItemID()) {
      flags |= RLHitFlag.Main();
    }
    // A deck in the main slot: its quickhacks are its hits.
    if IsDefined(run) && RLHitFlag.Has(flags, RLHitFlag.Quickhack()) && RLArms.IsMainDeck(run) {
      flags |= RLHitFlag.Main();
    }
    return flags;
  }

  // --- Outgoing hits ---------------------------------------------------------------------

  // Multiplier on a hit V lands on an arena enemy; also notes the hit and fires
  // the on-hit procs.
  public static func OnOutgoingHit(fx: ref<RLFx>, target: ref<ScriptedPuppet>, hitEvent: ref<gameHitEvent>) -> Float {
    let run = fx.run;
    let combat = fx.combat;
    let player = fx.player;
    let targetID = target.GetEntityID();
    let foe = combat.Foe(targetID);
    // Shots into a body feed nothing (hit counters, Payload, arcs).
    if !IsDefined(foe) || foe.dead || target.IsDead() {
      return 1.0;
    }
    let styles = RLStyles.HitStyles(hitEvent);
    let flags = RLHitFlag.WithStyles(RLBoonEffects.HitFlags(hitEvent, run), styles);
    let weapon = hitEvent.attackData.GetWeapon();
    let weaponID = IsDefined(weapon) ? weapon.GetItemID() : ItemID.None();
    let pools = GameInstance.GetStatPoolsSystem(fx.game);
    let ctx = new RLHitContext();
    ctx.player = player;
    ctx.target = target;
    ctx.foe = foe;
    ctx.hitEvent = hitEvent;
    ctx.now = fx.now;
    ctx.distance = Vector4.Distance(player.GetWorldPosition(), target.GetWorldPosition());
    ctx.targetHealth = pools.GetStatPoolValue(Cast<StatsObjectID>(targetID), gamedataStatPoolType.Health, true);
    ctx.damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    ctx.firstHit = !foe.hasHit;
    ctx.recentHit = foe.hasHit && fx.now - foe.hitTime <= 1.0;
    ctx.isBoss = foe.isBoss;
    ctx.isElite = foe.isElite;
    ctx.affixes = foe.affixes;
    let tick = RLHitFlag.Has(flags, RLHitFlag.Tick());
    let main = RLHitFlag.Has(flags, RLHitFlag.Main()) && !tick;

    // Kensei: in FOCUS every hit is a crit.
    let kensei = 1.0;
    if !tick && fx.Has(n"Kensei") && RLKeywords.InFocus(fx) && !RLHitFlag.Has(flags, RLHitFlag.Crit()) {
      flags |= RLHitFlag.Crit();
      hitEvent.attackData.AddFlag(hitFlag.CriticalHit, n"NCRogueliteKensei");
      let critDamage = GameInstance.GetStatsSystem(fx.game).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.CritDamage);
      kensei = 1.0 + MaxF(0.5, critDamage / 100.0);
      RLBoonEffects.Note(fx, n"Kensei", ctx.damage * (kensei - 1.0));
    }
    ctx.flags = flags;
    if !tick {
      combat.RecordHit(foe, flags, weaponID, fx.now);
      combat.UpdateRamp(targetID);
      if RLKeywords.IsBurning(target) {
        foe.burnSeenAt = fx.now;
      }
    }

    let factor = kensei;
    factor *= RLBoonEffects.Multipliers(fx, ctx, main);
    factor *= RLArmModEffects.Multiplier(fx, ctx, main);
    // Styles and Overdrive, then the target's plating.
    factor *= 1.0 + RLStyles.DamageBonus(RLStyles.BestRank(run, styles));
    factor *= RLStyles.OnHit(run, combat, ctx, styles);
    factor *= RLOverdrive.OutgoingFactor(combat, fx.game);
    factor *= RLAffixes.DamageTakenFactor(fx, foe, target, ctx.targetHealth);
    // What the hit really does, for arcs and the ledger (before an
    // execution makes it absurd).
    let dealt = ctx.damage * factor;
    // Execution Order (after everything else: it decides the hit). One
    // execution per enemy, however many pellets land.
    if !tick && !foe.executed && fx.Has(n"ExecutionOrder") && !foe.isBoss && RLKeywords.IsMarked(fx, foe)
      && ctx.targetHealth < (fx.Overclocked(n"ExecutionOrder") ? 35.0 : 25.0) {
      foe.executed = true;
      factor *= 100.0;
      RLBoonEffects.Execute(fx, target);
    }
    if !tick && RLArmModEffects.Garrotes(fx, ctx, main) {
      factor *= 100.0;
    }
    combat.damageDealt += dealt;

    if !tick {
      RLBoonEffects.HitProcs(fx, ctx, main, dealt);
    }
    if factor != 1.0 && combat.loggedHits < 5 {
      combat.loggedHits += 1;
      RLDebug(s"Hit scaled x\(factor) (hit flags \(flags)).");
    }
    return factor;
  }

  // Every damage multiplier from the effects.
  private static func Multipliers(fx: ref<RLFx>, ctx: ref<RLHitContext>, main: Bool) -> Float {
    let run = fx.run;
    let combat = fx.combat;
    let foe = ctx.foe;
    let target = ctx.target;
    let flags = ctx.flags;
    let tick = RLHitFlag.Has(flags, RLHitFlag.Tick());
    let crit = RLHitFlag.Has(flags, RLHitFlag.Crit());
    let explosion = RLHitFlag.Has(flags, RLHitFlag.Explosion());
    let factor = 1.0;

    // Lucky Round: every 8th main weapon hit is a big one.
    if main && fx.Has(n"LuckyRound") {
      combat.luckyHits += RLBoonEffects.CounterStep(fx, crit);
      let every = fx.Overclocked(n"LuckyRound") ? 6 : 8;
      if combat.luckyHits >= every {
        combat.luckyHits -= every;
        factor *= RLBoonEffects.Boost(fx, n"LuckyRound", ctx.damage, 3.0);
        RLKeywords.Tag(fx, "LUCKY ROUND", n"MainColors.Purple");
      }
    }
    // Road Warrior: the charged hit.
    if !tick && !explosion && combat.charged && fx.Has(n"RoadWarrior") {
      combat.charged = false;
      combat.sprintSeconds = 0;
      if RLBoonEffects.FullMomentum(fx) {
        RLBoonEffects.SetMomentum(fx, combat.momentum / 2);
      }
      factor *= RLBoonEffects.Boost(fx, n"RoadWarrior", ctx.damage, 2.0);
      RLKeywords.Knockdown(fx, target);
      if fx.Overclocked(n"RoadWarrior") {
        RLKeywords.Blast(fx, target.GetWorldPosition(), 3.0, null, 0);
      }
      RLKeywords.Tag(fx, "ROAD WARRIOR", n"MainColors.Gold");
    }
    // MARK: Deadeye Tag's bonus, and the Smart style's own marks.
    if foe.markUntil > fx.now || RLKeywords.IsMarked(fx, foe) {
      let bonus = foe.markUntil > fx.now ? foe.markBonus : 0.0;
      if fx.Has(n"DeadeyeTag") {
        bonus = MaxF(bonus, 0.25);
        RLBoonEffects.Note(fx, n"DeadeyeTag", ctx.damage * 0.25);
      }
      factor *= 1.0 + bonus;
      if explosion && fx.Has(n"SmartLink") {
        factor *= RLBoonEffects.Boost(fx, n"SmartLink", ctx.damage, 1.5);
      }
    }
    if fx.Has(n"FeedbackLoop") && RLKeywords.IsShocked(fx, foe, target) {
      factor *= RLBoonEffects.Boost(fx, n"FeedbackLoop", ctx.damage, 1.3);
    }
    if fx.Overclocked(n"KineticDash") && foe.knockedUntil > fx.now {
      factor *= RLBoonEffects.Boost(fx, n"KineticDash", ctx.damage, 1.3);
    }
    if explosion && fx.Has(n"ShapedCharge") {
      factor *= RLBoonEffects.Boost(fx, n"ShapedCharge", ctx.damage, 1.4);
      RLKeywords.Knockdown(fx, target);
    }
    if combat.momentum > 0 && (fx.Has(n"Slipstream") || fx.Has(n"NomadRun")) {
      factor *= RLBoonEffects.Boost(fx, n"Slipstream", ctx.damage, 1.0 + 0.06 * Cast<Float>(combat.momentum));
    }
    if combat.redMist && fx.Overclocked(n"RedMist") {
      factor *= RLBoonEffects.Boost(fx, n"RedMist", ctx.damage, 1.15);
    }
    let trophies = fx.run.trophyKills / 10;
    if trophies > 0 && fx.Has(n"TrophyWall") {
      factor *= RLBoonEffects.Boost(fx, n"TrophyWall", ctx.damage, 1.0 + 0.05 * Cast<Float>(trophies));
    }
    if fx.Has(n"Cyberpsychosis") && RLBoonEffects.PlayerHealth(fx) < 50.0 {
      factor *= RLBoonEffects.Boost(fx, n"Cyberpsychosis", ctx.damage, 1.6);
    }
    if fx.Has(n"GlassChrome") {
      factor *= RLBoonEffects.Boost(fx, n"GlassChrome", ctx.damage, 2.0);
    }
    if fx.Has(n"LoanShark") && run.loanFights <= 0 {
      factor *= RLBoonEffects.Boost(fx, n"LoanShark", ctx.damage, 1.4);
    }
    // Kinetic Rounds: a knockdown hit right after a dash (or at full MOMENTUM).
    if main && fx.Has(n"KineticRounds") && (combat.dashUntil > fx.now || RLBoonEffects.FullMomentum(fx)) {
      RLKeywords.Knockdown(fx, target);
      RLBoonEffects.Note(fx, n"KineticRounds", 0.0);
      if fx.Overclocked(n"KineticRounds") {
        factor *= 1.3;
      }
    }
    return factor;
  }

  // The keyword procs of a hit that landed.
  private static func HitProcs(fx: ref<RLFx>, ctx: ref<RLHitContext>, main: Bool, dealt: Float) {
    let combat = fx.combat;
    let foe = ctx.foe;
    let target = ctx.target;
    let flags = ctx.flags;
    let crit = RLHitFlag.Has(flags, RLHitFlag.Crit());
    let quickhack = RLHitFlag.Has(flags, RLHitFlag.Quickhack());
    let explosion = RLHitFlag.Has(flags, RLHitFlag.Explosion());
    let melee = RLHitFlag.Has(flags, RLHitFlag.Melee());

    // MARK
    if ctx.firstHit && fx.Has(n"KiroshiUplink") {
      RLKeywords.Mark(fx, target, 6.0);
      RLBoonEffects.Note(fx, n"KiroshiUplink", 0.0);
    }
    if RLHitFlag.Has(flags, RLHitFlag.Headshot()) && fx.Has(n"DeadeyeTag") {
      RLKeywords.Mark(fx, target, 6.0);
    }
    if crit && RLKeywords.InFocus(fx) && fx.Overclocked(n"Kensei") {
      RLKeywords.Mark(fx, target, 6.0);
    }
    if main && fx.Has(n"TracerRounds") {
      foe.mainHits += RLBoonEffects.CounterStep(fx, crit);
      let every = fx.Overclocked(n"TracerRounds") ? 2 : 3;
      if foe.mainHits >= every {
        foe.mainHits = 0;
        RLKeywords.Mark(fx, target, 6.0);
        RLBoonEffects.Note(fx, n"TracerRounds", 0.0);
      }
    }
    // BLAST
    if main && fx.Has(n"Payload") {
      combat.payloadHits += RLBoonEffects.CounterStep(fx, crit);
      let every = fx.Overclocked(n"Payload") ? 4 : 6;
      if combat.payloadHits >= every {
        combat.payloadHits = 0;
        RLBoonEffects.Note(fx, n"Payload", 0.0);
        RLKeywords.Blast(fx, target.GetWorldPosition(), 3.0, null, 0);
      }
    }
    if explosion && fx.Has(n"EMPPayload") {
      RLKeywords.Shock(fx, target);
      RLKeywords.Glitch(fx, target);
      RLBoonEffects.Note(fx, n"EMPPayload", 0.0);
    }
    if explosion && fx.Has(n"Napalm") {
      RLKeywords.Burn(fx, target);
      RLBoonEffects.Note(fx, n"Napalm", 0.0);
    }
    if explosion && fx.Has(n"Shrapnel") {
      RLKeywords.Bleed(fx, target, 1);
      if fx.Overclocked(n"Shrapnel") {
        RLKeywords.Mark(fx, target, 6.0);
      }
      RLBoonEffects.Note(fx, n"Shrapnel", 0.0);
    }
    // SHOCK
    if main && fx.Has(n"ThunderRounds") && (RLHitFlag.Has(flags, RLHitFlag.Headshot()) || Equals(ctx.hitEvent.attackData.GetAttackType(), gamedataAttackType.StrongMelee)) {
      RLBoonEffects.Note(fx, n"ThunderRounds", 0.0);
      RLKeywords.Tag(fx, "THUNDER", n"MainColors.Blue");
      RLKeywords.Shock(fx, target);
      if fx.Overclocked(n"ThunderRounds") {
        for other in RLKeywords.EnemiesNear(fx, target.GetWorldPosition(), 4.0) {
          RLKeywords.Shock(fx, other);
        }
      }
    }
    if crit && !explosion && fx.Has(n"ArcFlash") {
      RLBoonEffects.ArcFlash(fx, target, dealt);
    }
    if quickhack {
      RLBoonEffects.QuickhackProcs(fx, ctx);
    }
    // GLITCH payback: main weapon hits on glitched enemies feed the deck.
    if main && fx.Overclocked(n"GhostProtocol") && fx.combat.IsGlitched(foe, fx.now) && fx.now - combat.ramRefundAt >= 1.0 {
      combat.ramRefundAt = fx.now;
      RLBoonEffects.GiveRam(fx, 1.0);
      RLBoonEffects.Note(fx, n"GhostProtocol", 0.0);
    }
    // BURN and BLEED
    if main && fx.Has(n"HotBarrel") {
      RLBoonEffects.HeatUp(fx, crit, melee);
      if combat.hotUntil > fx.now {
        RLKeywords.Burn(fx, target);
      }
    }
    if (crit || melee) && fx.Has(n"Bloodletter") {
      RLKeywords.Bleed(fx, target, 1);
      RLBoonEffects.Note(fx, n"Bloodletter", 0.0);
    }
    if fx.Has(n"Cyberpsychosis") && RLBoonEffects.PlayerHealth(fx) < 50.0 {
      RLKeywords.Burn(fx, target);
      RLKeywords.Bleed(fx, target, 1);
    }
    // Elemental arm chrome in the main slot speaks its keyword.
    if main && StrLen(fx.run.mainElement) > 0 {
      RLArms.OnMainHit(fx, target);
    }
    // Nomad Run: from 10 stacks, hits knock enemies down.
    if !explosion && fx.Has(n"NomadRun") && fx.combat.momentum >= 10 && !RLHitFlag.Has(flags, RLHitFlag.Tick()) && RLKeywords.Knockdown(fx, target) {
      RLBoonEffects.Note(fx, n"NomadRun", 0.0);
    }
    if main {
      combat.lastMainHitAt = fx.now;
      RLArmModEffects.OnMainHit(fx, ctx, dealt);
    }
  }

  private static func QuickhackProcs(fx: ref<RLFx>, ctx: ref<RLHitContext>) {
    let foe = ctx.foe;
    let target = ctx.target;
    // One upload counts once, however many hits it lands in a second.
    if fx.now - foe.quickhackTime < 1.0 {
      return;
    }
    let first = foe.quickhackTime <= 0.0;
    foe.quickhackTime = fx.now;
    RLArmModEffects.OnQuickhack(fx, ctx, first);
    if fx.Has(n"GhostProtocol") {
      RLKeywords.Glitch(fx, target);
      RLBoonEffects.Note(fx, n"GhostProtocol", 0.0);
    }
    if fx.Has(n"GhostShot") && RLKeywords.IsMarked(fx, foe) {
      RLKeywords.Shock(fx, target);
      RLBoonEffects.Note(fx, n"GhostShot", 0.0);
    }
    if fx.Overclocked(n"KiroshiUplink") {
      for other in RLKeywords.EnemiesNear(fx, target.GetWorldPosition(), 5.0) {
        RLKeywords.Mark(fx, other, 6.0);
      }
    }
    if fx.Has(n"RiggedICE") && RLLuck.Roll(fx, 0.25) {
      RLBoonEffects.Note(fx, n"RiggedICE", 0.0);
      RLKeywords.Tag(fx, "RIGGED", n"MainColors.Purple");
      let times = RLLuck.Times(fx);
      RLBoonEffects.GiveRam(fx, 4.0 * Cast<Float>(times));
      let other = RLKeywords.Nearest(fx, target.GetWorldPosition(), 15.0, target.GetEntityID(), false);
      if IsDefined(other) {
        RLKeywords.Shock(fx, other);
      }
    }
  }

  // Arc Flash: the crit arcs to the nearest enemies.
  private static func ArcFlash(fx: ref<RLFx>, source: ref<ScriptedPuppet>, damage: Float) {
    let count = fx.Overclocked(n"ArcFlash") ? 3 : 2;
    count *= RLLuck.Times(fx);
    let critChance = GameInstance.GetStatsSystem(fx.game).GetStatValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatType.CritChance) / 100.0;
    let hit = 0;
    let dealt = 0.0;
    let reached: array<EntityID>;
    ArrayPush(reached, source.GetEntityID());
    while hit < count {
      let next = RLBoonEffects.NearestExcept(fx, source.GetWorldPosition(), 8.0, reached);
      if !IsDefined(next) {
        break;
      }
      ArrayPush(reached, next.GetEntityID());
      let arc = damage * 0.4;
      if fx.Overclocked(n"ArcFlash") && RLLuck.Roll(fx, critChance) {
        arc *= 2.0;
      }
      RLKeywords.Damage(fx, next, arc);
      RLKeywords.Shock(fx, next);
      dealt += arc;
      hit += 1;
    }
    if hit > 0 {
      RLBoonEffects.Note(fx, n"ArcFlash", dealt);
      RLKeywords.Tag(fx, "ARC", n"MainColors.Blue");
    }
  }

  // Execution Order took the target: the overclock MARKS around it, and Dead
  // Man's Hand flips for another.
  private static func Execute(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    RLBoonEffects.Note(fx, n"ExecutionOrder", 0.0);
    RLKeywords.Tag(fx, "EXECUTED", n"MainColors.ActiveYellow");
    if fx.Overclocked(n"ExecutionOrder") {
      for other in RLKeywords.EnemiesNear(fx, target.GetWorldPosition(), 8.0) {
        if other.GetEntityID() != target.GetEntityID() {
          RLKeywords.Mark(fx, other, 6.0);
        }
      }
    }
    if fx.Has(n"DeadMansHand") && RLLuck.Roll(fx, 0.5) {
      let times = RLLuck.Times(fx);
      let taken: array<EntityID>;
      ArrayPush(taken, target.GetEntityID());
      let i = 0;
      while i < times {
        let next = RLBoonEffects.NearestExcept(fx, target.GetWorldPosition(), 15.0, taken);
        if IsDefined(next) && !fx.combat.IsBoss(next.GetEntityID()) {
          ArrayPush(taken, next.GetEntityID());
          RLKeywords.DamagePercent(fx, next, 1.0);
          RLBoonEffects.Note(fx, n"DeadMansHand", 0.0);
          RLKeywords.Tag(fx, "HEADS", n"MainColors.Purple");
        }
        i += 1;
      }
    }
  }

  // --- Incoming hits ---------------------------------------------------------------------

  // Multiplier on a hit V takes from the effects (the run's curve and assist
  // mode are applied by the run system). 0 = the hit is absorbed.
  public static func OnIncomingHit(fx: ref<RLFx>, hitEvent: ref<gameHitEvent>, attacker: ref<ScriptedPuppet>) -> Float {
    let combat = fx.combat;
    let attackType = hitEvent.attackData.GetAttackType();
    let tick = Equals(attackType, gamedataAttackType.Effect);
    let instigator = hitEvent.attackData.GetInstigator();
    if combat.untouchableUntil > fx.now {
      return 0.0;
    }
    if fx.Has(n"Favour_Militech") && IsDefined(instigator) && instigator.IsPlayer()
      && (Equals(attackType, gamedataAttackType.Explosion) || Equals(attackType, gamedataAttackType.PressureWave)) {
      return 0.0;
    }
    if tick && fx.Has(n"Favour_Maelstrom") {
      return 0.0;
    }
    if tick {
      return 1.0;
    }
    combat.lastDamageAt = fx.now;
    if combat.shield {
      combat.shield = false;
      RLBoonEffects.ShieldBroke(fx, attacker);
      return 0.0;
    }
    if combat.momentum > 0 {
      RLBoonEffects.SetMomentum(fx, combat.momentum - 1);
    }
    return 1.0;
  }

  // V's health went down (percent, after the hit landed).
  public static func OnHealthDropped(fx: ref<RLFx>, oldValue: Float, newValue: Float) {
    if fx.Has(n"Kensei") && !fx.combat.kenseiUsed && newValue < 30.0 && oldValue >= 30.0 {
      fx.combat.kenseiUsed = true;
      RLKeywords.Focus(fx, 2.0);
      RLBoonEffects.Note(fx, n"Kensei", 0.0);
    }
  }

  private static func ShieldBroke(fx: ref<RLFx>, attacker: ref<ScriptedPuppet>) {
    RLKeywords.Tag(fx, "SHIELD DOWN", n"MainColors.Gold");
    GameInstance.GetAudioSystem(fx.game).PlayShockwave(n"explosion", fx.player.GetWorldPosition());
    RLBoonEffects.Note(fx, n"HoloMantle", 0.0);
    if fx.Has(n"RiotPlating") {
      RLBoonEffects.Note(fx, n"RiotPlating", 0.0);
      for enemy in RLKeywords.EnemiesNear(fx, fx.player.GetWorldPosition(), 6.0) {
        RLKeywords.Shock(fx, enemy);
      }
    }
    if fx.Has(n"StaticShield") && IsDefined(attacker) && IsDefined(fx.combat.Foe(attacker.GetEntityID())) {
      RLBoonEffects.Note(fx, n"StaticShield", 0.0);
      RLKeywords.Shock(fx, attacker);
      RLKeywords.Glitch(fx, attacker);
    }
    if IsDefined(fx.system) {
      fx.system.RefreshHud();
    }
  }

  // --- Kills -------------------------------------------------------------------------------

  // An arena enemy died. `flags`: how V's last hit on it landed (0 if V
  // never hit it).
  public static func OnKill(fx: ref<RLFx>, body: ref<ScriptedPuppet>, flags: Int32, isBoss: Bool, isElite: Bool) {
    let combat = fx.combat;
    let run = fx.run;
    combat.kills += 1;
    let foe = IsDefined(body) ? combat.Foe(body.GetEntityID()) : null;
    let position = IsDefined(body) ? body.GetWorldPosition() : fx.player.GetWorldPosition();
    let bodyID = IsDefined(body) ? body.GetEntityID() : EntityID();
    let marked = IsDefined(foe) && RLKeywords.IsMarked(fx, foe);
    let burning = IsDefined(foe) && (RLKeywords.IsBurning(body) || fx.now - foe.burnSeenAt < 2.0);
    let bleeding = IsDefined(foe) && combat.IsBleeding(foe, fx.now);
    let shocked = IsDefined(foe) && RLKeywords.IsShocked(fx, foe, body);
    let explosion = RLHitFlag.Has(flags, RLHitFlag.Explosion());

    if fx.Has(n"TrophyWall") {
      let before = run.trophyKills / 10;
      let double = fx.Overclocked(n"TrophyWall") && (RLHitFlag.Has(flags, RLHitFlag.Melee()) || burning || bleeding);
      run.trophyKills += double ? 2 : 1;
      if run.trophyKills / 10 > before {
        RLKeywords.Tag(fx, s"TROPHY +\(5 * (run.trophyKills / 10))%", n"MainColors.Red");
      }
    }
    if fx.Has(n"KillSwitch") {
      let missiles = fx.Overclocked(n"KillSwitch") ? 2 : 1;
      let aimed: array<EntityID>;
      ArrayPush(aimed, bodyID);
      let i = 0;
      while i < missiles {
        let next = RLBoonEffects.NearestExceptMarked(fx, position, 25.0, aimed, fx.Has(n"SmartLink"));
        if IsDefined(next) {
          ArrayPush(aimed, next.GetEntityID());
          RLEffectStep.ScheduleOn(fx, n"missile", next, 0.35 + 0.15 * Cast<Float>(i));
          RLBoonEffects.Note(fx, n"KillSwitch", 0.0);
        }
        i += 1;
      }
    }
    if burning && fx.Has(n"Pyre") {
      RLBoonEffects.Note(fx, n"Pyre", 0.0);
      RLKeywords.Tag(fx, "PYRE", n"MainColors.Red");
      let radius = fx.Overclocked(n"Pyre") ? 6.5 : 4.5;
      RLKeywords.Blast(fx, position, radius - 1.0, body, 0);
      let lit: array<EntityID>;
      ArrayPush(lit, bodyID);
      for other in RLKeywords.EnemiesNear(fx, position, radius) {
        RLKeywords.Burn(fx, other);
        ArrayPush(lit, other.GetEntityID());
      }
      // Overclocked, the fire jumps on to the two nearest beyond the blast.
      if fx.Overclocked(n"Pyre") {
        let i = 0;
        while i < 2 {
          let next = RLBoonEffects.NearestExcept(fx, position, 20.0, lit);
          if IsDefined(next) {
            RLKeywords.Burn(fx, next);
            ArrayPush(lit, next.GetEntityID());
          }
          i += 1;
        }
      }
    }
    if shocked && fx.Overclocked(n"FeedbackLoop") {
      for other in RLKeywords.EnemiesNear(fx, position, 5.0) {
        RLKeywords.Shock(fx, other);
      }
    }
    if marked {
      if fx.Overclocked(n"DeadeyeTag") {
        let next = RLKeywords.Nearest(fx, position, 20.0, bodyID, false);
        if IsDefined(next) {
          RLKeywords.Mark(fx, next, 6.0);
        }
      }
      if fx.Has(n"DeathSentence") {
        for other in RLKeywords.EnemiesNear(fx, position, 15.0) {
          RLKeywords.Mark(fx, other, 6.0);
        }
        RLBoonEffects.Note(fx, n"DeathSentence", 0.0);
      }
    }
    RLBoonEffects.ZanshinKill(fx, marked);
    RLArmModEffects.OnKill(fx, body, foe, flags);
    if RLHitFlag.Has(flags, RLHitFlag.Quickhack()) && fx.Has(n"DaisyChain") {
      RLBoonEffects.Note(fx, n"DaisyChain", 0.0);
      let reached: array<EntityID>;
      ArrayPush(reached, bodyID);
      RLEffectStep.Chain(fx, n"daisy", position, reached, fx.Overclocked(n"DaisyChain") ? 1 : 0, 0.3);
    }
    if explosion && fx.Has(n"Ordnance") {
      combat.blastKills += 1;
      let every = fx.Overclocked(n"Ordnance") ? 2 : 4;
      if combat.blastKills % every == 0 {
        ConsumablesChargesHelper.RefreshAmountOfCharges(fx.game, gamedataStatPoolType.GrenadesCharges, 1);
        RLBoonEffects.Note(fx, n"Ordnance", 0.0);
        RLKeywords.Tag(fx, "+1 GRENADE", n"MainColors.Yellow");
      }
    }
    if (burning || bleeding) && fx.Has(n"BloodMoney") && RLLuck.Roll(fx, 0.25) {
      let times = RLLuck.Times(fx);
      let passed: array<EntityID>;
      ArrayPush(passed, bodyID);
      let i = 0;
      while i < times {
        let next = RLBoonEffects.NearestExcept(fx, position, 15.0, passed);
        if IsDefined(next) {
          ArrayPush(passed, next.GetEntityID());
          if burning { RLKeywords.Burn(fx, next); }
          if bleeding { RLKeywords.Bleed(fx, next, foe.bleedStacks); }
        }
        i += 1;
      }
      RLBoonEffects.Note(fx, n"BloodMoney", 0.0);
    }
  }

  private static func ZanshinKill(fx: ref<RLFx>, marked: Bool) {
    if !fx.Has(n"Zanshin") {
      return;
    }
    if RLKeywords.InFocus(fx) && fx.Overclocked(n"Zanshin") {
      RLKeywords.Focus(fx, MinF(RLKeywords.FocusLeft(fx) + 0.5, 4.0));
      return;
    }
    fx.combat.focusKills += 1;
    if marked || fx.combat.focusKills >= 5 {
      fx.combat.focusKills = 0;
      RLKeywords.Focus(fx, 1.5);
      RLBoonEffects.Note(fx, n"Zanshin", 0.0);
    }
  }

  // --- Dashes ------------------------------------------------------------------------------

  // V dodged, dashed or air-dashed.
  public static func OnDash(fx: ref<RLFx>) {
    let combat = fx.combat;
    let position = fx.player.GetWorldPosition();
    combat.dashUntil = fx.now + 2.0;
    let fullBefore = RLBoonEffects.FullMomentum(fx);
    if RLBoonEffects.BuildsMomentum(fx) {
      RLBoonEffects.SetMomentum(fx, combat.momentum + 1);
    }
    if fx.Has(n"KineticDash") {
      let downed = 0;
      for enemy in RLKeywords.EnemiesNear(fx, position, 3.5) {
        if RLKeywords.Knockdown(fx, enemy) {
          downed += 1;
        }
      }
      if downed > 0 {
        RLBoonEffects.Note(fx, n"KineticDash", 0.0);
        RLKeywords.Tag(fx, "KNOCKDOWN", n"MainColors.Gold");
      }
    }
    if combat.shield && fx.Has(n"RiotPlating") {
      for enemy in RLKeywords.EnemiesNear(fx, position, 3.5) {
        RLKeywords.Knockdown(fx, enemy);
        RLKeywords.DamagePercent(fx, enemy, 0.1);
        RLBoonEffects.Note(fx, n"RiotPlating", 0.0);
        if fx.Overclocked(n"RiotPlating") {
          RLKeywords.Blast(fx, enemy.GetWorldPosition(), 2.5, null, 0);
        }
      }
    }
    if fullBefore && fx.Has(n"BulletTime") && fx.now - combat.bulletTimeAt >= 4.0 {
      combat.bulletTimeAt = fx.now;
      RLKeywords.Focus(fx, 1.5);
      RLBoonEffects.Note(fx, n"BulletTime", 0.0);
    }
    if fx.Has(n"Convoy") && fx.now - combat.convoyAt >= 2.0 {
      combat.convoyAt = fx.now;
      RLEffectStep.Schedule(fx, n"charge", position, 4.0, 0, 1.0);
      RLBoonEffects.Note(fx, n"Convoy", 0.0);
    }
    if fx.Has(n"Burnout") {
      for enemy in RLKeywords.EnemiesNear(fx, position, 4.0) {
        RLKeywords.Burn(fx, enemy);
        RLBoonEffects.Note(fx, n"Burnout", 0.0);
      }
    }
    if fullBefore && fx.Has(n"Getaway") && fx.now - combat.getawayAt >= 1.0 && RLLuck.Roll(fx, 0.34) {
      combat.getawayAt = fx.now;
      combat.untouchableUntil = fx.now + 1.0 * Cast<Float>(RLLuck.Times(fx));
      StatusEffectHelper.RemoveStatusEffect(fx.player, t"BaseStatusEffect.DodgeCooldown");
      StatusEffectHelper.RemoveStatusEffect(fx.player, t"BaseStatusEffect.DodgeAirCooldown");
      fx.player.rl_lastAirDash = 0.0;
      RLBoonEffects.Note(fx, n"Getaway", 0.0);
      RLKeywords.Tag(fx, "GETAWAY", n"MainColors.Purple");
    }
  }

  // V slid: Kinetic Rounds' window, and a MOMENTUM stack.
  public static func OnSlide(fx: ref<RLFx>) {
    fx.combat.dashUntil = fx.now + 2.0;
    if RLBoonEffects.BuildsMomentum(fx) {
      RLBoonEffects.SetMomentum(fx, fx.combat.momentum + 1);
    }
  }

  // --- Fight start and end --------------------------------------------------------------------

  public static func OnFightStart(fx: ref<RLFx>) {
    let combat = fx.combat;
    if fx.Has(n"HoloMantle") || fx.Has(n"Favour_Aldecaldos") {
      combat.shield = true;
    }
    if fx.Has(n"Favour_Aldecaldos") {
      RLBoonEffects.SetMomentum(fx, RLBoonEffects.FullStacks(fx));
    }
    if fx.Has(n"DroneEscort") {
      RLDrone.Spawn(fx);
    }
  }

  // The fight is over (won, lost or left): time back to normal, the speed
  // from MOMENTUM off V, the drone gone.
  public static func EndFight(player: ref<PlayerPuppet>, combat: ref<RLCombatState>) {
    if !IsDefined(player) || !IsDefined(combat) {
      return;
    }
    GameInstance.GetTimeSystem(player.GetGame()).UnsetTimeDilation(n"NCRogueliteFocus", n"");
    if IsDefined(combat.speedMod) {
      GameInstance.GetStatsSystem(player.GetGame()).RemoveModifier(Cast<StatsObjectID>(player.GetEntityID()), combat.speedMod);
      combat.speedMod = null;
    }
    combat.momentum = 0;
    combat.shield = false;
    combat.focusUntil = 0.0;
    RLDrone.Despawn(combat);
  }

  // Arasaka's favour: the first elite, boss or (failing those) enemy V sees
  // in a wave is MARKED.
  public static func OnEnemySighted(fx: ref<RLFx>, puppet: ref<ScriptedPuppet>, isTough: Bool, wave: Int32) {
    if !fx.Has(n"Favour_Arasaka") {
      return;
    }
    if isTough || fx.combat.markedWave != wave {
      fx.combat.markedWave = wave;
      RLKeywords.Mark(fx, puppet, 12.0);
      RLBoonEffects.Note(fx, n"Favour_Arasaka", 0.0);
    }
  }

  // --- Tick --------------------------------------------------------------------------------

  // Once a second during a fight.
  public static func OnTick(fx: ref<RLFx>) {
    let combat = fx.combat;
    let player = fx.player;
    RLKeywords.ExpireMarks(fx);
    RLBoonEffects.MarksBleed(fx);
    RLBoonEffects.TickBleeding(fx);
    // MOMENTUM from moving fast; Road Warrior's charge from sprinting.
    let moving = RLBoonEffects.IsSprinting(player);
    if moving && RLBoonEffects.BuildsMomentum(fx) {
      RLBoonEffects.SetMomentum(fx, combat.momentum + 1);
    }
    combat.sprintSeconds = moving ? combat.sprintSeconds + 1 : 0;
    if fx.Has(n"RoadWarrior") && !combat.charged && (combat.sprintSeconds >= 2 || RLBoonEffects.FullMomentum(fx)) {
      combat.charged = true;
      RLKeywords.Tag(fx, "CHARGED", n"MainColors.Gold");
    }
    // Weapon heat bleeds off when the main weapon is quiet.
    if combat.heat > 0 && fx.now - combat.lastMainHitAt > 1.0 {
      combat.heat = Max(0, combat.heat - 3);
    }
    // Red Mist: fire or blood close by.
    if fx.Has(n"RedMist") {
      let on = RLBoonEffects.BloodNear(fx, 10.0);
      if on {
        GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, 2.0, null, false, true);
        RLBoonEffects.Note(fx, n"RedMist", 0.0);
        if !combat.redMist {
          RLKeywords.Tag(fx, "RED MIST", n"MainColors.Red");
        }
      }
      combat.redMist = on;
    }
    // Holo-Mantle's overclock: the SHIELD comes back.
    if !combat.shield && fx.Overclocked(n"HoloMantle") && fx.now - combat.lastDamageAt >= 20.0 {
      combat.shield = true;
      RLKeywords.Tag(fx, "SHIELD UP", n"MainColors.Gold");
    }
    // The Loa's favour: SHOCKED enemies arc to each other.
    if fx.Has(n"Favour_VoodooBoys") {
      combat.arcTimer += 1.0;
      if combat.arcTimer >= 2.0 {
        combat.arcTimer = 0.0;
        RLBoonEffects.ArcBetweenShocked(fx);
      }
    }
    // Short Circuit: the fire carries a current.
    if fx.Has(n"ShortCircuit") {
      for foe in combat.Foes() {
        let puppet = RLBoonEffects.Puppet(fx, foe);
        if IsDefined(puppet) && RLKeywords.IsBurning(puppet) {
          RLKeywords.Shock(fx, puppet);
          RLBoonEffects.Note(fx, n"ShortCircuit", 0.0);
        }
      }
    }
    // Maelstrom's favour: fire on V heals instead.
    if fx.Has(n"Favour_Maelstrom") && StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Burning) {
      StatusEffectHelper.RemoveAllStatusEffectsByType(player, gamedataStatusEffectType.Burning);
      GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, 3.0, null, false, true);
    }
  }

  // Hemorrhage: a MARK keeps its target BLEEDING for as long as it lasts.
  private static func MarksBleed(fx: ref<RLFx>) {
    if !fx.Has(n"Hemorrhage") {
      return;
    }
    for foe in fx.combat.Foes() {
      if foe.markUntil > fx.now {
        if fx.combat.IsBleeding(foe, fx.now) {
          foe.bleedUntil = MaxF(foe.bleedUntil, fx.now + 2.0);
        } else {
          let puppet = RLBoonEffects.Puppet(fx, foe);
          if IsDefined(puppet) {
            RLKeywords.Bleed(fx, puppet, 1);
          }
        }
      }
    }
  }

  // BLEED: each stack takes a slice of health every second (less off a boss).
  private static func TickBleeding(fx: ref<RLFx>) {
    for foe in fx.combat.Foes() {
      if fx.combat.IsBleeding(foe, fx.now) {
        let puppet = RLBoonEffects.Puppet(fx, foe);
        if IsDefined(puppet) {
          let share = (foe.isBoss ? 0.004 : 0.015) * Cast<Float>(foe.bleedStacks);
          RLKeywords.DamagePercent(fx, puppet, share);
        }
      } else if foe.bleedStacks > 0 {
        foe.bleedStacks = 0;
      }
    }
  }

  private static func ArcBetweenShocked(fx: ref<RLFx>) {
    for foe in fx.combat.Foes() {
      let puppet = RLBoonEffects.Puppet(fx, foe);
      if IsDefined(puppet) && RLKeywords.IsShocked(fx, foe, puppet) {
        let other = RLKeywords.Nearest(fx, puppet.GetWorldPosition(), 8.0, foe.id, false);
        if IsDefined(other) {
          RLKeywords.Shock(fx, other);
          RLKeywords.DamagePercent(fx, other, 0.05);
          RLBoonEffects.Note(fx, n"Favour_VoodooBoys", 0.0);
        }
      }
    }
  }

  // --- Steps ---------------------------------------------------------------------------------

  // A reaction scheduled a beat after what set it off (RLEffectStep).
  public static func OnStep(fx: ref<RLFx>, kind: CName, position: Vector4, radius: Float, depth: Int32, target: wref<ScriptedPuppet>, reached: array<EntityID>) {
    switch kind {
      case n"echo":
        RLKeywords.Tag(fx, "ECHO", n"MainColors.Purple");
        RLKeywords.Blast(fx, position, radius, null, depth);
        break;
      case n"missile":
        let aim = IsDefined(target) && !target.IsDead() ? target.GetWorldPosition() : position;
        RLKeywords.Blast(fx, aim, 2.5, null, 0);
        break;
      case n"charge":
        RLKeywords.Blast(fx, position, radius, null, 0);
        break;
      case n"strike":
        RLKeywords.Blast(fx, position, radius, null, 0);
        break;
      case n"cocktail":
        if IsDefined(target) {
          RLKeywords.SpreadStatuses(fx, target);
        }
        break;
      case n"arc":
        RLBoonEffects.ArcOn(fx, position, reached);
        break;
      case n"daisy":
        let next = RLBoonEffects.NearestExcept(fx, position, 15.0, reached);
        if IsDefined(next) {
          RLKeywords.Shock(fx, next);
          RLKeywords.DamagePercent(fx, next, 0.15);
          RLKeywords.Tag(fx, "JUMP", n"MainColors.Green");
          if depth > 0 {
            ArrayPush(reached, next.GetEntityID());
            RLEffectStep.Chain(fx, n"daisy", next.GetWorldPosition(), reached, depth - 1, 0.4);
          }
        }
        break;
    }
  }

  // Blackwall Gate: the chain jumps to the nearest enemy it hasn't reached,
  // then on from there a second later. A boss takes a smaller bite.
  private static func ArcOn(fx: ref<RLFx>, position: Vector4, reached: array<EntityID>) {
    let best = RLBoonEffects.NearestExcept(fx, position, 12.0, reached);
    if !IsDefined(best) {
      return;
    }
    let foe = fx.combat.Foe(best.GetEntityID());
    RLBoonEffects.Note(fx, n"BlackwallGate", 0.0);
    RLKeywords.Tag(fx, "BLACKWALL", n"MainColors.Blue");
    RLKeywords.DamagePercent(fx, best, IsDefined(foe) && foe.isBoss ? 0.015 : 0.05);
    fx.combat.arcing = true;
    RLKeywords.Shock(fx, best);
    fx.combat.arcing = false;
    ArrayPush(reached, best.GetEntityID());
    RLEffectStep.Chain(fx, n"arc", best.GetWorldPosition(), reached, 0, 1.0);
  }

  // Fire Mission: three strikes on the biggest group of enemies.
  public static func FireMission(fx: ref<RLFx>) {
    let best: Vector4;
    let bestCount = 0;
    for foe in fx.combat.Foes() {
      let puppet = RLBoonEffects.Puppet(fx, foe);
      if IsDefined(puppet) {
        let near = RLKeywords.EnemiesNear(fx, puppet.GetWorldPosition(), 6.0);
        let count = ArraySize(near);
        if count > bestCount {
          bestCount = count;
          best = puppet.GetWorldPosition();
        }
      }
    }
    if bestCount == 0 {
      return;
    }
    RLBoonEffects.Note(fx, n"FireMission", 0.0);
    RLNotify(fx.game, "FIRE MISSION INBOUND", 2.5);
    RLEffectStep.Schedule(fx, n"strike", best, 7.0, 0, 0.6);
    RLEffectStep.Schedule(fx, n"strike", best + Vector4(2.5, 1.5, 0.0, 0.0), 6.0, 0, 1.0);
    RLEffectStep.Schedule(fx, n"strike", best + Vector4(-2.0, -2.0, 0.0, 0.0), 6.0, 0, 1.4);
  }

  // --- The pieces ----------------------------------------------------------------------------

  // MOMENTUM's cap: 5, 8 with Slipstream overclocked. Nomad Run lifts it to
  // 20, and its knockdowns start at 10.
  public static func MaxMomentum(fx: ref<RLFx>) -> Int32 {
    if fx.Has(n"NomadRun") {
      return 20;
    }
    return fx.Overclocked(n"Slipstream") ? 8 : 5;
  }

  // "Full MOMENTUM", for what pays off on it (Road Warrior, Kinetic Rounds,
  // Bullet Time, Getaway, the Family's favour): the cap, or 10 under Nomad
  // Run - a run past 10 stays full.
  public static func FullStacks(fx: ref<RLFx>) -> Int32 = Min(RLBoonEffects.MaxMomentum(fx), 10)

  public static func FullMomentum(fx: ref<RLFx>) -> Bool = fx.combat.momentum >= RLBoonEffects.FullStacks(fx)

  public static func BuildsMomentum(fx: ref<RLFx>) -> Bool = fx.Has(n"Slipstream") || fx.Has(n"NomadRun")

  // Sets MOMENTUM and the speed that comes with it.
  public static func SetMomentum(fx: ref<RLFx>, stacks: Int32) {
    let combat = fx.combat;
    let value = Clamp(stacks, 0, RLBoonEffects.MaxMomentum(fx));
    if value == combat.momentum {
      return;
    }
    let stats = GameInstance.GetStatsSystem(fx.game);
    let id = Cast<StatsObjectID>(fx.player.GetEntityID());
    if IsDefined(combat.speedMod) {
      stats.RemoveModifier(id, combat.speedMod);
      combat.speedMod = null;
    }
    combat.momentum = value;
    if value > 0 {
      combat.speedMod = RPGManager.CreateStatModifier(gamedataStatType.MaxSpeed, gameStatModifierType.AdditiveMultiplier, 0.06 * Cast<Float>(Min(value, 10)));
      stats.AddModifier(id, combat.speedMod);
    }
    if fx.Has(n"NomadRun") && value >= 10 && value % 5 == 0 {
      RLKeywords.Tag(fx, s"NOMAD \(value)", n"MainColors.Gold");
    }
    if IsDefined(fx.system) {
      fx.system.RefreshHud();
    }
  }

  // Hot Barrel: heat from main weapon hits; full heat makes the barrel hot.
  private static func HeatUp(fx: ref<RLFx>, crit: Bool, melee: Bool) {
    let combat = fx.combat;
    let step = melee ? 3 : 1;
    step *= RLBoonEffects.CounterStep(fx, crit);
    if fx.Overclocked(n"HotBarrel") {
      step *= 2;
    }
    combat.heat += step;
    if combat.heat >= 12 && combat.hotUntil <= fx.now {
      combat.heat = 0;
      combat.hotUntil = fx.now + 4.0;
      RLBoonEffects.Note(fx, n"HotBarrel", 0.0);
      RLKeywords.Tag(fx, "HOT BARREL", n"MainColors.Red");
    }
  }

  // What a hit adds to a hit counter: crits count twice with Loaded Dice.
  private static func CounterStep(fx: ref<RLFx>, crit: Bool) -> Int32 = crit && fx.Has(n"LoadedDice") ? 2 : 1

  // An effect's multiplier, noted in the ledger.
  public static func Boost(fx: ref<RLFx>, id: CName, damage: Float, multiplier: Float) -> Float {
    RLBoonEffects.Note(fx, id, damage * (multiplier - 1.0));
    return multiplier;
  }

  public static func Note(fx: ref<RLFx>, id: CName, damage: Float) {
    fx.combat.Fired(id, damage);
  }

  public static func GiveRam(fx: ref<RLFx>, amount: Float) {
    GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatPoolType.Memory, amount, null, false, false);
  }

  public static func PlayerHealth(fx: ref<RLFx>) -> Float {
    return GameInstance.GetStatPoolsSystem(fx.game).GetStatPoolValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatPoolType.Health, true);
  }

  public static func IsSprinting(player: ref<PlayerPuppet>) -> Bool {
    let blackboard = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(blackboard) {
      return false;
    }
    let state = blackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion);
    return state == EnumInt(gamePSMLocomotionStates.Sprint) || state == EnumInt(gamePSMLocomotionStates.Slide) || state == EnumInt(gamePSMLocomotionStates.CrouchSprint);
  }

  // An enemy within `radius` of V is BURNING or BLEEDING.
  private static func BloodNear(fx: ref<RLFx>, radius: Float) -> Bool {
    for enemy in RLKeywords.EnemiesNear(fx, fx.player.GetWorldPosition(), radius) {
      let foe = fx.combat.Foe(enemy.GetEntityID());
      if RLKeywords.IsBurning(enemy) || (IsDefined(foe) && fx.combat.IsBleeding(foe, fx.now)) {
        return true;
      }
    }
    return false;
  }

  private static func Puppet(fx: ref<RLFx>, foe: ref<RLFoe>) -> ref<ScriptedPuppet> {
    if foe.dead {
      return null;
    }
    let puppet = GameInstance.FindEntityByID(fx.game, foe.id) as ScriptedPuppet;
    return IsDefined(puppet) && !puppet.IsDead() ? puppet : null;
  }

  public static func NearestExcept(fx: ref<RLFx>, position: Vector4, radius: Float, except: array<EntityID>) -> ref<ScriptedPuppet> {
    return RLBoonEffects.NearestExceptMarked(fx, position, radius, except, false);
  }

  // The nearest MARKED enemy within `radius`, or null.
  public static func NearestMarked(fx: ref<RLFx>, position: Vector4, radius: Float) -> ref<ScriptedPuppet> {
    let best: ref<ScriptedPuppet>;
    let bestDistance = radius;
    for enemy in RLKeywords.EnemiesNear(fx, position, radius) {
      if !enemy.IsDead() && RLKeywords.IsMarked(fx, fx.combat.Foe(enemy.GetEntityID())) {
        let distance = Vector4.Distance(position, enemy.GetWorldPosition());
        if distance <= bestDistance {
          bestDistance = distance;
          best = enemy;
        }
      }
    }
    return best;
  }

  private static func NearestExceptMarked(fx: ref<RLFx>, position: Vector4, radius: Float, except: array<EntityID>, preferMarked: Bool) -> ref<ScriptedPuppet> {
    let best: ref<ScriptedPuppet>;
    let bestScore = 99999.0;
    for enemy in RLKeywords.EnemiesNear(fx, position, radius) {
      if !ArrayContains(except, enemy.GetEntityID()) && !enemy.IsDead() {
        let score = Vector4.Distance(position, enemy.GetWorldPosition());
        if preferMarked && RLKeywords.IsMarked(fx, fx.combat.Foe(enemy.GetEntityID())) {
          score -= 1000.0;
        }
        if score < bestScore {
          bestScore = score;
          best = enemy;
        }
      }
    }
    return best;
  }
}

// Drone Escort (a prototype, off unless RLConfig.DroneEscort): a Militech
// drone on V's side for the fight (r6/tweaks: NCRoguelite.EscortDrone, in the
// player's attitude group). Its hits carry V's keywords once overclocked
// (Combat/DamageHooks.reds).
public abstract class RLDrone {
  public static func Spawn(fx: ref<RLFx>) {
    if EntityID.IsDefined(fx.combat.droneID) {
      return;
    }
    let spec = new DynamicEntitySpec();
    spec.recordID = t"NCRoguelite.EscortDrone";
    spec.position = fx.player.GetWorldPosition() + Vector4(1.5, 1.5, 1.8, 0.0);
    spec.orientation = EulerAngles.ToQuat(Vector4.ToRotation(fx.player.GetWorldForward()));
    spec.alwaysSpawned = true;
    spec.persistState = false;
    spec.persistSpawn = false;
    fx.combat.droneID = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
    RLLog(EntityID.IsDefined(fx.combat.droneID) ? "Drone Escort spawned." : "Drone Escort failed to spawn.");
  }

  public static func Despawn(combat: ref<RLCombatState>) {
    if EntityID.IsDefined(combat.droneID) {
      GameInstance.GetDynamicEntitySystem().DeleteEntity(combat.droneID);
      combat.droneID = EntityID();
    }
  }

  // A hit the drone landed on an arena enemy: the overclock carries V's
  // keywords on it.
  public static func OnHit(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    if !fx.Overclocked(n"DroneEscort") {
      return;
    }
    let made = RLBoons.Makes(fx.run);
    if ArrayContains(made, n"MARK") { RLKeywords.Mark(fx, target, 6.0); }
    if ArrayContains(made, n"SHOCK") { RLKeywords.Shock(fx, target); }
    if ArrayContains(made, n"BURN") { RLKeywords.Burn(fx, target); }
    RLBoonEffects.Note(fx, n"DroneEscort", 0.0);
  }
}

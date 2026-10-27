// -----------------------------------------------------------------------------
// Night City Roguelite - boon effects in fights
// -----------------------------------------------------------------------------
// The scripted side of the boons (Rewards/Boons.reds) and of elite affixes
// (Combat/Affixes.reds), driven by four hooks:
//
//   outgoing hit  every hit V lands (DamageSystem, Combat/DamageHooks.reds):
//                 damage multipliers, procs, and a note of how the target was
//                 hit (headshot, crit, ranged, melee, explosion, quickhack);
//   incoming hit  every hit V takes: damage reductions;
//   kill          every arena enemy that dies (RLWaveSpawner): kill procs,
//                 which can read how the killing hit landed;
//   tick          once a second during a fight: RAM recovery, timers.
//
// RLCombatState holds what one fight needs (kill counts, the hit notes,
// suppressed enemies, enemy roles and affixes) and is reset for every arena.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLHitFlag {
  public static func Headshot() -> Int32 = 1
  public static func Crit() -> Int32 = 2
  public static func Ranged() -> Int32 = 4
  public static func Melee() -> Int32 = 8
  public static func Explosion() -> Int32 = 16
  public static func Quickhack() -> Int32 = 32

  public static func Has(flags: Int32, flag: Int32) -> Bool = (flags & flag) != 0
}

public class RLCombatState {
  public let kills: Int32;
  public let psychoKills: Int32;
  public let berserkUntil: Float;
  public let slowUntil: Float;
  public let familyUsed: Bool;
  public let ramTimer: Float;
  // V's own blasts (boons, objectives) don't hurt V: hits from V until then
  // are ignored.
  public let selfBlastUntil: Float;
  // How each enemy was last hit by V (RLHitFlag bits).
  private let m_hitIDs: array<EntityID>;
  private let m_hitFlags: array<Int32>;
  // Enemies V shot recently (Suppressive Fire).
  private let m_suppressedIDs: array<EntityID>;
  private let m_suppressedUntil: array<Float>;
  // Enemy roles and elite affixes (RLAffix bits).
  private let m_enemyIDs: array<EntityID>;
  private let m_enemyBoss: array<Bool>;
  private let m_enemyElite: array<Bool>;
  private let m_enemyAffixes: array<Int32>;
  // Delay targets waiting to fire (RLDelayedBlast).
  private let m_pending: array<ref<IScriptable>>;
  // Enemies whose death procs already fired.
  private let m_deadIDs: array<EntityID>;
  // Last time each enemy healed off V (Vampiric).
  private let m_healIDs: array<EntityID>;
  private let m_healTimes: array<Float>;

  public func ResetArena() {
    this.kills = 0;
    this.psychoKills = 0;
    this.berserkUntil = 0.0;
    this.familyUsed = false;
    this.ramTimer = 0.0;
    ArrayClear(this.m_hitIDs);
    ArrayClear(this.m_hitFlags);
    ArrayClear(this.m_suppressedIDs);
    ArrayClear(this.m_suppressedUntil);
    ArrayClear(this.m_enemyIDs);
    ArrayClear(this.m_enemyBoss);
    ArrayClear(this.m_enemyElite);
    ArrayClear(this.m_enemyAffixes);
    ArrayClear(this.m_deadIDs);
    ArrayClear(this.m_healIDs);
    ArrayClear(this.m_healTimes);
  }

  // True at most once a second per enemy (and records the time).
  public func TryHeal(id: EntityID, now: Float) -> Bool {
    let i = this.IndexOf(this.m_healIDs, id);
    if i >= 0 {
      if now - this.m_healTimes[i] < 1.0 {
        return false;
      }
      this.m_healTimes[i] = now;
      return true;
    }
    ArrayPush(this.m_healIDs, id);
    ArrayPush(this.m_healTimes, now);
    return true;
  }

  public func Keep(target: ref<IScriptable>) {
    ArrayPush(this.m_pending, target);
  }

  public func Release(target: ref<IScriptable>) {
    ArrayRemove(this.m_pending, target);
  }

  public func IsArenaEnemy(id: EntityID) -> Bool = this.IndexOf(this.m_enemyIDs, id) >= 0

  // True the first time it's called for an enemy: its death procs fire once.
  public func MarkDead(id: EntityID) -> Bool {
    if ArrayContains(this.m_deadIDs, id) {
      return false;
    }
    ArrayPush(this.m_deadIDs, id);
    return true;
  }

  public func RecordHit(id: EntityID, flags: Int32) {
    let i = this.IndexOf(this.m_hitIDs, id);
    if i >= 0 {
      this.m_hitFlags[i] = flags;
      return;
    }
    ArrayPush(this.m_hitIDs, id);
    ArrayPush(this.m_hitFlags, flags);
  }

  // How the enemy was last hit (0 if V never hit it); forgets it.
  public func TakeHitFlags(id: EntityID) -> Int32 {
    let i = this.IndexOf(this.m_hitIDs, id);
    if i < 0 {
      return 0;
    }
    let flags = this.m_hitFlags[i];
    ArrayErase(this.m_hitIDs, i);
    ArrayErase(this.m_hitFlags, i);
    return flags;
  }

  public func Suppress(id: EntityID, until: Float) {
    let i = this.IndexOf(this.m_suppressedIDs, id);
    if i >= 0 {
      this.m_suppressedUntil[i] = until;
      return;
    }
    ArrayPush(this.m_suppressedIDs, id);
    ArrayPush(this.m_suppressedUntil, until);
  }

  public func IsSuppressed(id: EntityID, now: Float) -> Bool {
    let i = this.IndexOf(this.m_suppressedIDs, id);
    return i >= 0 && this.m_suppressedUntil[i] > now;
  }

  public func RegisterEnemy(id: EntityID, isBoss: Bool, isElite: Bool, affixes: Int32) {
    let i = this.IndexOf(this.m_enemyIDs, id);
    if i >= 0 {
      this.m_enemyBoss[i] = isBoss;
      this.m_enemyElite[i] = isElite;
      this.m_enemyAffixes[i] = affixes;
      return;
    }
    ArrayPush(this.m_enemyIDs, id);
    ArrayPush(this.m_enemyBoss, isBoss);
    ArrayPush(this.m_enemyElite, isElite);
    ArrayPush(this.m_enemyAffixes, affixes);
  }

  public func IsBoss(id: EntityID) -> Bool {
    let i = this.IndexOf(this.m_enemyIDs, id);
    return i >= 0 && this.m_enemyBoss[i];
  }

  public func IsElite(id: EntityID) -> Bool {
    let i = this.IndexOf(this.m_enemyIDs, id);
    return i >= 0 && this.m_enemyElite[i];
  }

  public func Affixes(id: EntityID) -> Int32 {
    let i = this.IndexOf(this.m_enemyIDs, id);
    return i >= 0 ? this.m_enemyAffixes[i] : 0;
  }

  private func IndexOf(ids: array<EntityID>, id: EntityID) -> Int32 {
    let i = 0;
    while i < ArraySize(ids) {
      if ids[i] == id {
        return i;
      }
      i += 1;
    }
    return -1;
  }
}

public abstract class RLBoonEffects {
  public static func Now(game: GameInstance) -> Float = EngineTime.ToFloat(GameInstance.GetTimeSystem(game).GetSimTime())

  public static func IsBerserk(combat: ref<RLCombatState>, game: GameInstance) -> Bool = combat.berserkUntil > RLBoonEffects.Now(game)

  public static func HitFlags(hitEvent: ref<gameHitEvent>) -> Int32 {
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
    }
    if attackData.HasFlag(hitFlag.QuickHack) {
      flags |= RLHitFlag.Quickhack();
    }
    return flags;
  }

  // --- Outgoing hits ---------------------------------------------------------------------

  // Multiplier on a hit V lands on an arena enemy; also notes the hit and fires
  // on-hit procs.
  public static func OnOutgoingHit(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>, target: ref<ScriptedPuppet>, hitEvent: ref<gameHitEvent>) -> Float {
    let game = player.GetGame();
    let now = RLBoonEffects.Now(game);
    let flags = RLBoonEffects.HitFlags(hitEvent);
    let targetID = target.GetEntityID();
    // Burn, bleed and poison ticks keep how the enemy was really hit.
    if NotEquals(hitEvent.attackData.GetAttackType(), gamedataAttackType.Effect) {
      combat.RecordHit(targetID, flags);
    }
    let pools = GameInstance.GetStatPoolsSystem(game);
    let targetHealth = pools.GetStatPoolValue(Cast<StatsObjectID>(targetID), gamedataStatPoolType.Health, true);
    let playerHealth = pools.GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, true);

    let factor = 1.0;
    if RLHitFlag.Has(flags, RLHitFlag.Headshot()) {
      factor *= 1.0 + RLBoons.Value(run, n"Hanako") / 100.0;
      if RLHitFlag.Has(flags, RLHitFlag.Ranged()) && RLBoons.Has(run, n"SmartLink") {
        factor *= 1.35;
      }
    }
    if targetHealth >= 99.0 {
      factor *= 1.0 + RLBoons.Value(run, n"Bushido") / 100.0;
    }
    if RLHitFlag.Has(flags, RLHitFlag.Ranged()) {
      factor *= 1.0 + RLBoons.Value(run, n"HardenedRounds") / 100.0;
      if RLBoons.Has(run, n"KillCount") {
        factor *= 1.0 + Cast<Float>(Min(combat.kills * 2, 40)) / 100.0;
      }
      let suppress = RLBoons.Value(run, n"Suppressive");
      if suppress > 0.0 {
        combat.Suppress(targetID, now + 3.0);
      }
    }
    if RLHitFlag.Has(flags, RLHitFlag.Explosion()) {
      factor *= 1.0 + RLBoons.Value(run, n"Ordnance") / 100.0;
    }
    if RLHitFlag.Has(flags, RLHitFlag.Quickhack()) {
      factor *= 1.0 + RLBoons.Value(run, n"BlackIce") / 100.0;
    }
    if RLHitFlag.Has(flags, RLHitFlag.Melee()) {
      factor *= 1.0 + RLBoons.Value(run, n"ChromeFist") / 100.0;
      if RLBoons.Has(run, n"ShortCircuit") && RandF() < 0.25 {
        StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Electrocuted", player.GetEntityID());
      }
    }
    if playerHealth < 40.0 {
      factor *= 1.0 + RLBoons.Value(run, n"RedMist") / 100.0;
    }
    let lucky = RLBoons.Value(run, n"LuckyShot");
    if lucky > 0.0 && RandF() < lucky / 100.0 {
      factor *= 2.0;
    }
    if RLBoonEffects.IsBerserk(combat, game) {
      factor *= 1.5;
    }
    if RLHitFlag.Has(flags, RLHitFlag.Crit()) && targetHealth < 25.0 && RLBoons.Has(run, n"ShogunsEdge") && !combat.IsBoss(targetID) {
      factor *= 10.0;
    }
    // Elite affixes on the target.
    factor *= RLAffixes.DamageTakenFactor(combat.Affixes(targetID));
    return factor;
  }

  // --- Incoming hits ---------------------------------------------------------------------

  // Multiplier on a hit V takes from boons (the run's difficulty curve and
  // assist mode are applied by the run system).
  public static func IncomingFactor(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>, hitEvent: ref<gameHitEvent>) -> Float {
    let game = player.GetGame();
    let factor = 1.0 - RLBoons.Value(run, n"ThickSkin") / 100.0;
    let health = GameInstance.GetStatPoolsSystem(game).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, true);
    if health < 40.0 && RLBoons.Has(run, n"DesertFury") {
      factor *= 0.7;
    }
    let instigator = hitEvent.attackData.GetInstigator();
    let suppress = RLBoons.Value(run, n"Suppressive");
    if suppress > 0.0 && IsDefined(instigator) && combat.IsSuppressed(instigator.GetEntityID(), RLBoonEffects.Now(game)) {
      factor *= 1.0 - suppress / 100.0;
    }
    if RLBoonEffects.IsBerserk(combat, game) {
      factor *= 0.5;
    }
    return MaxF(0.05, factor);
  }

  // --- Kills -------------------------------------------------------------------------------

  // An arena enemy died. `hitFlags`: how V's last hit on it landed (0 if V
  // never hit it).
  public static func OnKill(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>, body: ref<ScriptedPuppet>, hitFlags: Int32, isBoss: Bool, isElite: Bool) {
    let game = player.GetGame();
    let playerID = Cast<StatsObjectID>(player.GetEntityID());
    let pools = GameInstance.GetStatPoolsSystem(game);
    combat.kills += 1;

    let heal = RLBoons.Value(run, n"Bloodlust");
    if RLHitFlag.Has(hitFlags, RLHitFlag.Explosion()) && RLBoons.Has(run, n"ShrapnelFrenzy") {
      heal += 5.0;
    }
    if heal > 0.0 {
      pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Health, heal, null, false, true);
    }

    let eddies = RoundF(RLBoons.Value(run, n"BountyHunter"));
    if RLHitFlag.Has(hitFlags, RLHitFlag.Quickhack()) && RLBoons.Has(run, n"DataBroker") {
      eddies += 150;
    }
    if (isElite || isBoss) && RLBoons.Has(run, n"CorporateBounty") {
      eddies += 500;
    }
    if eddies > 0 {
      RLGear.GiveEddies(player, eddies);
    }

    let ammo = RLBoons.Value(run, n"KillChain");
    if ammo > 0.0 {
      RLLoot.RefillAmmo(player, ammo / 100.0);
    }

    let ram = RLBoons.Value(run, n"DataLeech");
    if ram > 0.0 {
      pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Memory, ram, null, false, false);
    }
    if RLHitFlag.Has(hitFlags, RLHitFlag.Quickhack()) && RLBoons.Has(run, n"LoasEmbrace") {
      pools.RequestSettingStatPoolValue(playerID, gamedataStatPoolType.Memory, 100.0, null, true);
    }

    let volatile = RLBoons.Value(run, n"VolatileKills");
    if volatile > 0.0 && IsDefined(body) && RandF() < volatile / 100.0 {
      RLExplosions.Blast(player, body.GetWorldPosition(), t"Attacks.CyberwareExplosion", 5.0, body);
    }

    let echo = RLBoons.Value(run, n"Sandevistan");
    let now = RLBoonEffects.Now(game);
    if echo > 0.0 && RLHitFlag.Has(hitFlags, RLHitFlag.Headshot()) && combat.slowUntil <= now {
      combat.slowUntil = now + echo;
      GameInstance.GetTimeSystem(game).SetTimeDilation(n"NCRogueliteEcho", 0.4, echo, n"Linear", n"Linear");
    }

    if RLBoons.Has(run, n"Cyberpsychosis") && !RLBoonEffects.IsBerserk(combat, game) {
      combat.psychoKills += 1;
      if combat.psychoKills >= 12 {
        combat.psychoKills = 0;
        combat.berserkUntil = now + 8.0;
        RLNotify(game, "CYBERPSYCHOSIS", 3.0);
      }
    }
  }

  // --- Lethal hits -------------------------------------------------------------------------

  // The boon that saves V from a lethal hit (Family Ties first, then a
  // Second Wind charge), or none.
  public static func SaveFromLethal(run: ref<RLRunState>, combat: ref<RLCombatState>) -> CName {
    if RLBoons.Has(run, n"FamilyTies") && !combat.familyUsed {
      combat.familyUsed = true;
      return n"FamilyTies";
    }
    if RLBoons.UseSecondWind(run) {
      return n"SecondWind";
    }
    return n"";
  }

  // Health (percent) V is left with after the save.
  public static func SavedHealth(boon: CName) -> Float = Equals(boon, n"FamilyTies") ? 30.0 : 50.0

  // --- Tick --------------------------------------------------------------------------------

  // Once a second during a fight.
  public static func OnTick(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>) {
    let interval = RLBoons.Value(run, n"GhostProtocol");
    if interval > 0.0 {
      combat.ramTimer += 1.0;
      if combat.ramTimer >= interval {
        combat.ramTimer = 0.0;
        GameInstance.GetStatPoolsSystem(player.GetGame()).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, 1.0, null, false, false);
      }
    }
  }
}

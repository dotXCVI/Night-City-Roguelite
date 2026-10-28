// -----------------------------------------------------------------------------
// Night City Roguelite - elite affixes and explosions
// -----------------------------------------------------------------------------
// Elites (and, from Act 2, bosses) roll affixes that change how they fight -
// the Diablo / Hades "Elite" layer:
//
//   ARMORED       plating: takes 70% less until a quarter of its health is
//                 gone, then the plating shatters and it takes full damage
//   BERSERK       hits harder and moves faster (the game's own berserk buff)
//   REGENERATING  recovers 2% health a second
//   VOLATILE      explodes a moment after it dies - step away
//   VAMPIRIC      hitting V heals it for 8% health (once a second at most)
//
// Affixes are announced when the enemy spawns. The number of affixes grows
// with the act (Roll); a hot door's lieutenant always has two. A GLITCHED
// enemy doesn't regenerate. The explosion helper is shared with the effects.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLAffix {
  public static func Armored() -> Int32 = 1
  public static func Berserk() -> Int32 = 2
  public static func Regenerating() -> Int32 = 4
  public static func Volatile() -> Int32 = 8
  public static func Vampiric() -> Int32 = 16

  public static func All() -> array<Int32> = [1, 2, 4, 8, 16]
}

public abstract class RLAffixes {
  // Affixes for a new elite or boss: elites get one from floor 3 and two in
  // Act 3; bosses one from Act 2; a lieutenant two.
  public static func Roll(run: ref<RLRunState>, isBoss: Bool, opt isLieutenant: Bool) -> Int32 {
    let count = 0;
    if isLieutenant {
      count = 2;
    } else if isBoss {
      count = run.act >= 2 ? 1 : 0;
    } else if run.act >= 3 {
      count = 2;
    } else if run.act == 2 {
      count = RandF() < 0.4 ? 2 : 1;
    } else if run.Depth() >= 3 {
      count = 1;
    }
    let pool = RLAffix.All();
    let affixes = 0;
    while count > 0 && ArraySize(pool) > 0 {
      let i = RandRange(0, ArraySize(pool));
      affixes |= pool[i];
      ArrayErase(pool, i);
      count -= 1;
    }
    return affixes;
  }

  public static func Has(affixes: Int32, affix: Int32) -> Bool = (affixes & affix) != 0

  public static func Names(affixes: Int32) -> String {
    let names = "";
    for affix in RLAffix.All() {
      if RLAffixes.Has(affixes, affix) {
        names += (StrLen(names) > 0 ? " + " : "") + RLAffixes.Name(affix);
      }
    }
    return names;
  }

  public static func Name(affix: Int32) -> String {
    switch affix {
      case 1: return "ARMORED";
      case 2: return "BERSERK";
      case 4: return "REGENERATING";
      case 8: return "VOLATILE";
      case 16: return "VAMPIRIC";
    }
    return "";
  }

  // --- Effects ---------------------------------------------------------------------------

  // ARMORED plating: 70% of a hit stopped until the enemy is down to three
  // quarters of its health; then it shatters, with a flash and a crack.
  public static func DamageTakenFactor(fx: ref<RLFx>, foe: ref<RLFoe>, target: ref<ScriptedPuppet>, health: Float) -> Float {
    if !IsDefined(foe) || foe.platingBroken || !RLAffixes.Has(foe.affixes, RLAffix.Armored()) {
      return 1.0;
    }
    if health > 75.0 {
      return 0.3;
    }
    foe.platingBroken = true;
    RLKeywords.Tag(fx, "PLATING SHATTERED", n"MainColors.ActiveWhite");
    GameInstance.GetAudioSystem(fx.game).PlayShockwave(n"explosion", target.GetWorldPosition());
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.ExplosionStun", fx.player.GetEntityID());
    return 1.0;
  }

  // First sighting of the enemy.
  public static func OnSpawned(puppet: ref<ScriptedPuppet>, affixes: Int32) {
    if RLAffixes.Has(affixes, RLAffix.Berserk()) {
      StatusEffectHelper.ApplyStatusEffect(puppet, t"BaseStatusEffect.BerserkNPCBuff");
    }
  }

  // Once a second while the enemy lives. A GLITCHED enemy can't heal.
  public static func OnTick(puppet: ref<ScriptedPuppet>, affixes: Int32, glitched: Bool) {
    if RLAffixes.Has(affixes, RLAffix.Regenerating()) && !glitched {
      RLAffixes.Heal(puppet, 2.0);
    }
  }

  // The enemy hit V (direct hits only: no burn or bleed ticks). A shotgun's
  // pellets or an HMG's burst heal once a second, not once per bullet.
  public static func OnHitPlayer(puppet: ref<ScriptedPuppet>, affixes: Int32, combat: ref<RLCombatState>, hitEvent: ref<gameHitEvent>) {
    if !RLAffixes.Has(affixes, RLAffix.Vampiric()) || Equals(hitEvent.attackData.GetAttackType(), gamedataAttackType.Effect) {
      return;
    }
    let now = RLBoonEffects.Now(puppet.GetGame());
    if !combat.IsGlitched(combat.Foe(puppet.GetEntityID()), now) && combat.TryHeal(puppet.GetEntityID(), now) {
      RLAffixes.Heal(puppet, 8.0);
    }
  }

  // The enemy died: a Volatile one blows up a moment later.
  public static func OnDeath(puppet: ref<ScriptedPuppet>, affixes: Int32) {
    if RLAffixes.Has(affixes, RLAffix.Volatile()) && IsDefined(puppet) {
      RLDelay(puppet.GetGame(), RLDelayedBlast.Create(puppet, puppet.GetWorldPosition()), n"blast", 1.2);
    }
  }

  private static func Heal(puppet: ref<ScriptedPuppet>, percent: Float) {
    if IsDefined(puppet) && !puppet.IsDead() {
      GameInstance.GetStatPoolsSystem(puppet.GetGame())
        .RequestChangingStatPoolValue(Cast<StatsObjectID>(puppet.GetEntityID()), gamedataStatPoolType.Health, percent, null, false, true);
    }
  }
}

// A Volatile elite's death blast, set off after a short fuse.
public class RLDelayedBlast extends RLDelayTarget {
  private let m_source: wref<GameObject>;
  private let m_position: Vector4;

  public static func Create(source: ref<GameObject>, position: Vector4) -> ref<RLDelayedBlast> {
    let blast = new RLDelayedBlast();
    blast.m_source = source;
    blast.m_position = position;
    // Kept alive by the delay system's callback until it fires.
    RLExplosions.Keep(blast);
    return blast;
  }

  public func OnDelayed(action: CName) {
    if IsDefined(this.m_source) {
      RLExplosions.Blast(this.m_source, this.m_position, t"Attacks.AndroidDeathExplosion", 4.5);
    }
    RLExplosions.Release(this);
  }
}

public abstract class RLExplosions {
  // An explosion at a spot with one of the game's own explosion attacks (the
  // way the game's cyberware explosion does it): damage in the radius, the
  // shockwave sound, and a shove that throws bodies around. A body at the
  // centre loses limbs.
  public static func Blast(instigator: ref<GameObject>, position: Vector4, attackID: TweakDBID, radius: Float, opt body: ref<GameObject>, opt source: CName) {
    let record = TweakDBInterface.GetAttackRecord(attackID);
    if !IsDefined(record) || !IsDefined(instigator) {
      return;
    }
    let context: AttackInitContext;
    context.record = record;
    context.instigator = instigator;
    context.source = instigator;
    let attack = IAttack.Create(context) as Attack_GameEffect;
    if !IsDefined(attack) {
      return;
    }
    let effect = attack.PrepareAttack(instigator);
    let statMods: array<ref<gameStatModifierData>>;
    attack.GetStatModList(statMods);
    let shared = effect.GetSharedData();
    let defs = GetAllBlackboardDefs().EffectSharedData;
    EffectData.SetFloat(shared, defs.range, radius);
    EffectData.SetFloat(shared, defs.radius, radius);
    EffectData.SetVector(shared, defs.position, position);
    EffectData.SetVariant(shared, defs.attack, ToVariant(attack));
    EffectData.SetVariant(shared, defs.attackStatModList, ToVariant(statMods));
    let combat = RLExplosions.Combat();
    if instigator.IsPlayer() && IsDefined(combat) {
      let now = RLBoonEffects.Now(instigator.GetGame());
      combat.selfBlastUntil = now + 0.5;
      combat.TrackBlast(attack, now, source);
    }
    attack.StartAttack();
    GameInstance.GetAudioSystem(instigator.GetGame()).PlayShockwave(n"explosion", position);
    if IsDefined(body) {
      CombatGadgetHelper.SpawnPhysicalImpulse(body, radius);
      DismembermentComponent.RequestDismemberment(body, gameDismBodyPart.LEFT_ARM, gameDismWoundType.COARSE, position);
      DismembermentComponent.RequestDismemberment(body, gameDismBodyPart.RIGHT_LEG, gameDismWoundType.COARSE, position);
    }
  }

  // Pending delay targets (blasts, episode ends) are held by the fight's
  // state, so their delay callbacks (weak references) still find them.
  public static func Keep(blast: ref<IScriptable>) {
    let combat = RLExplosions.Combat();
    if IsDefined(combat) {
      combat.Keep(blast);
    }
  }

  public static func Release(blast: ref<IScriptable>) {
    let combat = RLExplosions.Combat();
    if IsDefined(combat) {
      combat.Release(blast);
    }
  }

  private static func Combat() -> ref<RLCombatState> {
    let system = RogueliteSystem.Get(GetGameInstance());
    return IsDefined(system) ? system.GetCombat() : null;
  }
}

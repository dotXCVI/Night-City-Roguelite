// -----------------------------------------------------------------------------
// Night City Roguelite - the fight in progress
// -----------------------------------------------------------------------------
// What one arena fight needs to remember, reset for every arena:
//
//   foes      one record per arena enemy: its role and affixes, how V last hit
//             it, and the keywords on it the game doesn't track (MARK,
//             GLITCH, BLEED stacks) - SHOCK and BURN are the game's own
//             Electrocuted and Burning effects (Combat/Keywords.reds);
//   V         FOCUS, MOMENTUM, the SHIELD, weapon heat and hit counters;
//   ledger    how often each effect fired and the damage it added, for the
//             telemetry (Core/Telemetry.reds).
//
// The hit flags describe how a hit landed (RLHitFlag); the style bits above
// them say which styles it belongs to (Rewards/Styles.reds).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLHitFlag {
  public static func Headshot() -> Int32 = 1
  public static func Crit() -> Int32 = 2
  public static func Ranged() -> Int32 = 4
  public static func Melee() -> Int32 = 8
  public static func Explosion() -> Int32 = 16
  public static func Quickhack() -> Int32 = 32
  // A hit with the main weapon (Rewards/Weapons.reds).
  public static func Main() -> Int32 = 64
  // A damage-over-time tick (burn, bleed, poison), not a fresh hit.
  public static func Tick() -> Int32 = 128

  public static func Has(flags: Int32, flag: Int32) -> Bool = (flags & flag) != 0

  // The bit for a style (Rewards/Styles.reds) above the hit kinds.
  public static func Style(style: Int32) -> Int32 {
    let bit = 256;
    let i = 0;
    while i < style {
      bit *= 2;
      i += 1;
    }
    return bit;
  }

  public static func WithStyles(flags: Int32, styles: array<Int32>) -> Int32 {
    for style in styles {
      flags |= RLHitFlag.Style(style);
    }
    return flags;
  }

  public static func Styles(flags: Int32) -> array<Int32> {
    let styles: array<Int32>;
    let i = 0;
    while i < RLStyle.Count() {
      if RLHitFlag.Has(flags, RLHitFlag.Style(i)) {
        ArrayPush(styles, i);
      }
      i += 1;
    }
    return styles;
  }
}

// What the hit hook knows about one hit.
public class RLHitContext {
  public let player: wref<PlayerPuppet>;
  public let target: wref<ScriptedPuppet>;
  public let foe: ref<RLFoe>;
  public let hitEvent: ref<gameHitEvent>;
  public let flags: Int32;
  public let now: Float;
  public let distance: Float;
  public let targetHealth: Float;
  // The hit's damage before the run's multipliers (health points).
  public let damage: Float;
  public let firstHit: Bool;
  public let recentHit: Bool;
  public let isBoss: Bool;
  public let isElite: Bool;
  public let affixes: Int32;
}

// One arena enemy.
public class RLFoe {
  public let id: EntityID;
  public let isBoss: Bool;
  public let isElite: Bool;
  public let affixes: Int32;
  public let dead: Bool;
  // V's last hit on it: how it landed, with what, when.
  public let hasHit: Bool;
  public let hitFlags: Int32;
  public let hitWeapon: ItemID;
  public let hitTime: Float;
  // Keywords the game doesn't track.
  public let markUntil: Float;
  public let markBonus: Float;
  // The game's ping outline is on it (it shows the MARK).
  public let markShown: Bool;
  public let glitchUntil: Float;
  public let bleedStacks: Int32;
  public let bleedUntil: Float;
  public let shockedAt: Float;
  // Blackwall Gate: when a chain last started from it (one at a time).
  public let chainAt: Float;
  // Cocktail: it already burst. Execution Order: it's been executed.
  public let burst: Bool;
  public let executed: Bool;
  // ARMORED plating shattered (Combat/Affixes.reds).
  public let platingBroken: Bool;
  // Knocked down by V (Kinetic Dash's overclock).
  public let knockedUntil: Float;
  // Main weapon hits on it (Tracer Rounds).
  public let mainHits: Int32;
  public let healTime: Float;
  public let ramTime: Float;
  public let quickhackTime: Float;
  // Last time V saw it burning (the game clears Burning when it dies).
  public let burnSeenAt: Float;
}

public class RLCombatState {
  public let kills: Int32;
  // V's own blasts (effects, objectives) don't hurt V: hits from V until then
  // are ignored.
  public let selfBlastUntil: Float;
  // The last enemy to hit V (telemetry: what killed V).
  public let lastAttacker: String;
  // Boosted hits logged this arena (the first few, to check effects apply).
  public let loggedHits: Int32;
  // The weapon of the killing hit (TakeHitFlags).
  public let killWeapon: ItemID;
  // Overdrive (Run/Overdrive.reds) and capacity overclock episodes.
  public let rampageUntil: Float;
  public let psychoUntil: Float;
  public let psychoTimer: Float;
  public let overdriveFiredAt: Float;
  // Style signatures (Rewards/Styles.reds).
  public let gunslingerShots: Int32;
  public let demoKills: Int32;
  public let sigSlowUntil: Float;

  // V's side of the keywords.
  public let focusUntil: Float;
  public let kenseiUsed: Bool;
  public let momentum: Int32;
  public let sprintSeconds: Int32;
  public let charged: Bool;
  public let dashUntil: Float;
  public let shield: Bool;
  public let lastDamageAt: Float;
  public let untouchableUntil: Float;
  public let heat: Int32;
  public let hotUntil: Float;
  public let lastMainHitAt: Float;
  // Hit counters on the main weapon (Payload, Lucky Round).
  public let payloadHits: Int32;
  public let luckyHits: Int32;
  // BLASTs this fight (Fire Mission) and BLAST kills (Ordnance).
  public let blasts: Int32;
  public let blastKills: Int32;
  public let focusKills: Int32;
  public let bulletTimeAt: Float;
  public let convoyAt: Float;
  public let getawayAt: Float;
  public let arcTimer: Float;
  public let ramRefundAt: Float;
  public let redMist: Bool;
  // Blackwall Gate: an arc is landing its SHOCK (it continues its own chain).
  public let arcing: Bool;
  // Arasaka's favour: the wave whose toughest enemy is already MARKED.
  public let markedWave: Int32;
  // Slipstream's speed, swapped as MOMENTUM changes.
  public let speedMod: ref<gameStatModifierData>;
  // Drone Escort (prototype): the drone on V's side.
  public let droneID: EntityID;

  // The ledger: per effect, how often it fired and the damage it added.
  public let damageDealt: Float;
  private let m_fxIDs: array<CName>;
  private let m_fxFires: array<Int32>;
  private let m_fxDamage: array<Float>;

  private let m_foes: array<ref<RLFoe>>;
  private let m_rampTarget: EntityID;
  private let m_rampCount: Int32;
  // Delay targets waiting to fire (blasts, arcs, echoes).
  private let m_pending: array<ref<IScriptable>>;

  public func ResetArena() {
    this.kills = 0;
    this.loggedHits = 0;
    this.lastAttacker = "";
    this.killWeapon = ItemID.None();
    this.rampageUntil = 0.0;
    this.psychoUntil = 0.0;
    this.psychoTimer = 0.0;
    this.gunslingerShots = 0;
    this.demoKills = 0;
    this.sigSlowUntil = 0.0;
    this.focusUntil = 0.0;
    this.kenseiUsed = false;
    this.momentum = 0;
    this.sprintSeconds = 0;
    this.charged = false;
    this.dashUntil = 0.0;
    this.shield = false;
    this.lastDamageAt = 0.0;
    this.untouchableUntil = 0.0;
    this.heat = 0;
    this.hotUntil = 0.0;
    this.lastMainHitAt = 0.0;
    this.payloadHits = 0;
    this.luckyHits = 0;
    this.blasts = 0;
    this.blastKills = 0;
    this.focusKills = 0;
    this.bulletTimeAt = 0.0;
    this.convoyAt = 0.0;
    this.getawayAt = 0.0;
    this.arcTimer = 0.0;
    this.ramRefundAt = 0.0;
    this.redMist = false;
    this.arcing = false;
    this.markedWave = 0;
    this.speedMod = null;
    this.droneID = EntityID();
    this.damageDealt = 0.0;
    ArrayClear(this.m_pending);
    ArrayClear(this.m_fxIDs);
    ArrayClear(this.m_fxFires);
    ArrayClear(this.m_fxDamage);
    ArrayClear(this.m_foes);
    this.m_rampTarget = EntityID();
    this.m_rampCount = 0;
  }

  // --- Foes ------------------------------------------------------------------------------

  public func RegisterEnemy(id: EntityID, isBoss: Bool, isElite: Bool, affixes: Int32) {
    let foe = this.Foe(id);
    if !IsDefined(foe) {
      foe = new RLFoe();
      foe.id = id;
      ArrayPush(this.m_foes, foe);
    }
    foe.isBoss = isBoss;
    foe.isElite = isElite;
    foe.affixes = affixes;
  }

  public func Foe(id: EntityID) -> ref<RLFoe> {
    for foe in this.m_foes {
      if foe.id == id {
        return foe;
      }
    }
    return null;
  }

  public func IsArenaEnemy(id: EntityID) -> Bool = IsDefined(this.Foe(id))

  public func IsBoss(id: EntityID) -> Bool {
    let foe = this.Foe(id);
    return IsDefined(foe) && foe.isBoss;
  }

  public func IsElite(id: EntityID) -> Bool {
    let foe = this.Foe(id);
    return IsDefined(foe) && foe.isElite;
  }

  public func Affixes(id: EntityID) -> Int32 {
    let foe = this.Foe(id);
    return IsDefined(foe) ? foe.affixes : 0;
  }

  // True the first time it's called for an enemy: its death procs fire once.
  public func MarkDead(id: EntityID) -> Bool {
    let foe = this.Foe(id);
    if !IsDefined(foe) || foe.dead {
      return false;
    }
    foe.dead = true;
    return true;
  }

  // --- Hits ------------------------------------------------------------------------------

  public func RecordHit(foe: ref<RLFoe>, flags: Int32, weapon: ItemID, now: Float) {
    foe.hasHit = true;
    foe.hitFlags = flags;
    foe.hitWeapon = weapon;
    foe.hitTime = now;
  }

  // How the enemy was last hit (0 if V never hit it). The weapon of that hit
  // is left in killWeapon.
  public func TakeHitFlags(id: EntityID) -> Int32 {
    let foe = this.Foe(id);
    if !IsDefined(foe) || !foe.hasHit {
      this.killWeapon = ItemID.None();
      return 0;
    }
    this.killWeapon = foe.hitWeapon;
    return foe.hitFlags;
  }

  // Consecutive hits on the same target (the Rifles signature).
  public func UpdateRamp(id: EntityID) {
    if this.m_rampTarget == id {
      this.m_rampCount += 1;
    } else {
      this.m_rampTarget = id;
      this.m_rampCount = 0;
    }
  }

  public func RampCount(id: EntityID) -> Int32 = this.m_rampTarget == id ? this.m_rampCount : 0

  // True at most once a second per enemy (and records the time): Vampiric.
  public func TryHeal(id: EntityID, now: Float) -> Bool {
    let foe = this.Foe(id);
    if !IsDefined(foe) || now - foe.healTime < 1.0 {
      return false;
    }
    foe.healTime = now;
    return true;
  }

  // --- MARK (the Smart style's marks bring their own bonus) --------------------------------

  public func Mark(id: EntityID, until: Float, bonus: Float) {
    let foe = this.Foe(id);
    if IsDefined(foe) {
      foe.markUntil = MaxF(foe.markUntil, until);
      foe.markBonus = MaxF(foe.markBonus, bonus);
    }
  }

  public func IsMarked(foe: ref<RLFoe>, now: Float) -> Bool = IsDefined(foe) && foe.markUntil > now

  public func IsGlitched(foe: ref<RLFoe>, now: Float) -> Bool = IsDefined(foe) && foe.glitchUntil > now

  public func IsBleeding(foe: ref<RLFoe>, now: Float) -> Bool = IsDefined(foe) && foe.bleedStacks > 0 && foe.bleedUntil > now

  public func Foes() -> array<ref<RLFoe>> = this.m_foes

  // --- The ledger --------------------------------------------------------------------------

  public func Fired(id: CName, damage: Float) {
    let i = ArrayFindFirst(this.m_fxIDs, id);
    if i < 0 {
      ArrayPush(this.m_fxIDs, id);
      ArrayPush(this.m_fxFires, 1);
      ArrayPush(this.m_fxDamage, MaxF(0.0, damage));
      return;
    }
    this.m_fxFires[i] += 1;
    this.m_fxDamage[i] += MaxF(0.0, damage);
  }

  // "ArcFlash:12:340,Pyre:3:510" - fires and damage per effect.
  public func Ledger() -> String {
    let text = "";
    let i = 0;
    while i < ArraySize(this.m_fxIDs) {
      text += (StrLen(text) > 0 ? "," : "") + NameToString(this.m_fxIDs[i]) + ":" + IntToString(this.m_fxFires[i]) + ":" + IntToString(RoundF(this.m_fxDamage[i]));
      i += 1;
    }
    return text;
  }

  // --- Delay targets -----------------------------------------------------------------------

  public func Keep(target: ref<IScriptable>) {
    ArrayPush(this.m_pending, target);
  }

  public func Release(target: ref<IScriptable>) {
    ArrayRemove(this.m_pending, target);
  }
}

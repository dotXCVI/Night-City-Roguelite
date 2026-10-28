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
  // The effects that last set it burning, bleeding or shocked: the game's
  // damage over time is credited to them in the ledger.
  public let burnSource: CName;
  // What it is, for the telemetry: its archetype ("ShotgunT3"), plus "elite"
  // or "boss".
  public let kind: String;
  public let bleedSource: CName;
  public let shockSource: CName;
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
  // The last quickhack upload on it (any that landed; uploadAt: the one the
  // upload hook or a spread counted, so one upload counts once).
  public let quickhackTime: Float;
  public let uploadAt: Float;
  // Kinetic Rounds on a deck: the upload came in the dash window, so the
  // hack's hits take the overclock's +30%.
  public let kineticUntil: Float;
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
  // Hits the main weapon landed this fight (the ledger's yardstick: a weapon
  // effect's fires against it).
  public let mainHitCount: Int32;
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
  // Arm mods (Rewards/ArmMods.reds): the Combo chain, the Capacitor's count,
  // the last shell (one per explosion), the RAM Cache's count.
  public let comboHits: Int32;
  public let comboAt: Float;
  public let armHits: Int32;
  public let lastShellAt: Float;
  public let lastSwingAt: Float;
  public let hackCount: Int32;
  // Signatures (Rewards/ArmChrome.reds): the last SHOCKWAVE or LIVE WIRE, the
  // last BELT FEED charge.
  public let signatureAt: Float;
  public let beltAt: Float;
  // Weapon effects read per action (Rewards/WeaponActions.reds): the shell in
  // flight and what it carries, and the deck's own heat.
  public let shellAt: Float;
  public let shellHot: Bool;
  public let shellLucky: Bool;
  // The last upload's quickhack family, for the hits it spreads into.
  public let lastUploadAt: Float;
  public let lastUploadFamily: CName;
  // Uploads this arena and seconds spent short of RAM (telemetry).
  public let uploads: Int32;
  public let ramLowSeconds: Int32;
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
  // The effect firing right now (the last one noted): blasts and statuses it
  // starts are credited to it when their damage lands.
  public let source: CName;
  private let m_blasts: array<ref<IAttack>>;
  private let m_blastSources: array<CName>;
  private let m_blastUntil: array<Float>;
  // The attacks burning, bleeding and electrocuted deal their ticks with.
  private let m_dots: array<TweakDBID>;

  private let m_foes: array<ref<RLFoe>>;
  private let m_hurtKinds: array<String>;
  private let m_hurtDamage: array<Float>;
  private let m_waveStarts: array<Float>;
  private let m_rampTarget: EntityID;
  private let m_rampCount: Int32;
  // Delay targets waiting to fire (blasts, arcs, echoes).
  private let m_pending: array<ref<IScriptable>>;

  public func ResetArena() {
    ArrayClear(this.m_hurtKinds);
    ArrayClear(this.m_hurtDamage);
    ArrayClear(this.m_waveStarts);
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
    this.mainHitCount = 0;
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
    this.comboHits = 0;
    this.comboAt = 0.0;
    this.armHits = 0;
    this.lastShellAt = 0.0;
    this.lastSwingAt = 0.0;
    this.hackCount = 0;
    this.signatureAt = 0.0;
    this.beltAt = 0.0;
    this.shellAt = 0.0;
    this.shellHot = false;
    this.shellLucky = false;
    this.lastUploadAt = 0.0;
    this.lastUploadFamily = n"";
    this.uploads = 0;
    this.ramLowSeconds = 0;
    this.markedWave = 0;
    this.speedMod = null;
    this.droneID = EntityID();
    this.damageDealt = 0.0;
    ArrayClear(this.m_pending);
    ArrayClear(this.m_fxIDs);
    ArrayClear(this.m_fxFires);
    ArrayClear(this.m_fxDamage);
    ArrayClear(this.m_blasts);
    ArrayClear(this.m_blastSources);
    ArrayClear(this.m_blastUntil);
    this.source = n"";
    ArrayClear(this.m_foes);
    this.m_rampTarget = EntityID();
    this.m_rampCount = 0;
  }

  // --- Foes ------------------------------------------------------------------------------

  public func RegisterEnemy(id: EntityID, isBoss: Bool, isElite: Bool, affixes: Int32, opt record: TweakDBID) {
    let foe = this.Foe(id);
    if !IsDefined(foe) {
      foe = new RLFoe();
      foe.id = id;
      ArrayPush(this.m_foes, foe);
    }
    foe.isBoss = isBoss;
    foe.isElite = isElite;
    foe.affixes = affixes;
    foe.kind = RLCombatState.Kind(record) + (isBoss ? " boss" : (isElite ? " elite" : ""));
  }

  // An enemy record's archetype ("ShotgunT3", "NetrunnerT2").
  public static func Kind(record: TweakDBID) -> String {
    let character = TweakDBInterface.GetCharacterRecord(record);
    if IsDefined(character) && IsDefined(character.ArchetypeData()) && IsDefined(character.ArchetypeData().Type()) {
      return NameToString(character.ArchetypeData().Type().EnumName());
    }
    return "Unknown";
  }

  // --- What hurt V ---------------------------------------------------------------------------

  // Damage V took this fight, by the kind of enemy that dealt it.
  public func Hurt(attacker: EntityID, damage: Float) {
    let foe = this.Foe(attacker);
    let kind = IsDefined(foe) ? foe.kind : "Other";
    let i = ArrayFindFirst(this.m_hurtKinds, kind);
    if i < 0 {
      ArrayPush(this.m_hurtKinds, kind);
      ArrayPush(this.m_hurtDamage, 0.0);
      i = ArraySize(this.m_hurtKinds) - 1;
    }
    this.m_hurtDamage[i] += MaxF(0.0, damage);
  }

  // "ShotgunT3 elite:420,GenericRangedT2:310,..." - the three that hurt most.
  public func HurtText() -> String {
    let kinds = this.m_hurtKinds;
    let damage = this.m_hurtDamage;
    let text = "";
    let shown = 0;
    while shown < 3 && ArraySize(kinds) > 0 {
      let best = 0;
      let i = 1;
      while i < ArraySize(kinds) {
        if damage[i] > damage[best] {
          best = i;
        }
        i += 1;
      }
      text += (shown > 0 ? "," : "") + kinds[best] + ":" + IntToString(RoundF(damage[best]));
      ArrayErase(kinds, best);
      ArrayErase(damage, best);
      shown += 1;
    }
    return text;
  }

  // When each wave began, for the floor's wave times.
  public func WaveStarted(now: Float) {
    ArrayPush(this.m_waveStarts, now);
  }

  // "12,20,31": seconds each wave took, the last up to `now`.
  public func WaveSeconds(now: Float) -> String {
    let text = "";
    let i = 0;
    while i < ArraySize(this.m_waveStarts) {
      let end = i + 1 < ArraySize(this.m_waveStarts) ? this.m_waveStarts[i + 1] : now;
      text += (i > 0 ? "," : "") + IntToString(RoundF(end - this.m_waveStarts[i]));
      i += 1;
    }
    return text;
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
    this.source = id;
    let i = this.LedgerIndex(id);
    this.m_fxFires[i] += 1;
    this.m_fxDamage[i] += MaxF(0.0, damage);
  }

  // A fire that leaves the credit where it is (Jackpot tripling another
  // effect's roll).
  public func Tally(id: CName) {
    this.m_fxFires[this.LedgerIndex(id)] += 1;
  }

  // Damage an effect dealt after the fact (its blast landing, a burn tick).
  public func Credit(id: CName, damage: Float) {
    if IsNameValid(id) && damage > 0.0 {
      this.m_fxDamage[this.LedgerIndex(id)] += damage;
    }
  }

  private func LedgerIndex(id: CName) -> Int32 {
    let i = ArrayFindFirst(this.m_fxIDs, id);
    if i < 0 {
      ArrayPush(this.m_fxIDs, id);
      ArrayPush(this.m_fxFires, 0);
      ArrayPush(this.m_fxDamage, 0.0);
      i = ArraySize(this.m_fxIDs) - 1;
    }
    return i;
  }

  // A blast set off by `source` (default: the effect firing now): what it
  // hits is credited to it.
  public func TrackBlast(attack: ref<IAttack>, now: Float, opt source: CName) {
    if !IsNameValid(source) {
      source = this.source;
    }
    if !IsNameValid(source) {
      return;
    }
    // Drop the ones that have long landed.
    while ArraySize(this.m_blasts) > 0 && this.m_blastUntil[0] < now {
      ArrayErase(this.m_blasts, 0);
      ArrayErase(this.m_blastSources, 0);
      ArrayErase(this.m_blastUntil, 0);
    }
    ArrayPush(this.m_blasts, attack);
    ArrayPush(this.m_blastSources, source);
    ArrayPush(this.m_blastUntil, now + 2.0);
  }

  // A hit landing on an arena enemy: if an effect's blast or a status an
  // effect started dealt it, the damage goes to that effect.
  public func CreditHit(foe: ref<RLFoe>, target: ref<ScriptedPuppet>, hitEvent: ref<gameHitEvent>) {
    let attack = hitEvent.attackData.GetAttackDefinition();
    // Hits on a body count for nothing.
    if !IsDefined(attack) || !IsDefined(foe) || foe.dead || target.IsDead() {
      return;
    }
    let damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    let i = 0;
    while i < ArraySize(this.m_blasts) {
      if this.m_blasts[i] == attack {
        this.Credit(this.m_blastSources[i], damage);
        return;
      }
      i += 1;
    }
    if !hitEvent.attackData.HasFlag(hitFlag.DamageOverTime) || !IsDefined(attack.GetRecord()) {
      return;
    }
    if ArraySize(this.m_dots) == 0 {
      this.m_dots = [RLCombatState.DotAttack(t"BaseStatusEffect.Burning"), RLCombatState.DotAttack(t"BaseStatusEffect.Bleeding"), RLCombatState.DotAttack(t"BaseStatusEffect.Electrocuted")];
    }
    switch ArrayFindFirst(this.m_dots, attack.GetRecord().GetID()) {
      case 0: this.Credit(foe.burnSource, damage); break;
      case 1: this.Credit(foe.bleedSource, damage); break;
      case 2: this.Credit(foe.shockSource, damage); break;
    }
  }

  // The attack a status effect deals its damage over time with.
  public static func DotAttack(status: TweakDBID) -> TweakDBID {
    let record = TweakDBInterface.GetStatusEffectRecord(status);
    let attack: ref<Attack_Record>;
    if IsDefined(record) && StatusEffectHelper.HasStatusEffectAttack(record, attack) && IsDefined(attack) {
      return attack.GetID();
    }
    return TDBID.None();
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

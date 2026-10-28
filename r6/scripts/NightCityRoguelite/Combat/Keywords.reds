// -----------------------------------------------------------------------------
// Night City Roguelite - keywords
// -----------------------------------------------------------------------------
// The words every effect speaks (Rewards/Boons.reds). Each has one name, one
// colour and one look in the world, and this is the only place that puts
// them there - so the effects that react to a keyword fire whatever applied
// it, and every one of them reads the same on screen:
//
//   MARK      the game's ping outline; V's MARKED targets take more from
//             Deadeye Tag and die to Execution Order
//   FOCUS     time slows (a short bullet time)
//   BLAST     an explosion (the game's own cyberware blast); grenades count
//   SHOCK     the game's Electrocuted: sparks, damage, a stagger
//   GLITCH    their cyberware shuts down (no dodging, Sandevistan, healing)
//   BURN      the game's Burning
//   BLEED     the game's Bleeding, plus a tick per stack (Rewards/BoonEffects)
//   MOMENTUM  stacks on V from moving fast
//   SHIELD    one absorbed hit
//   DEAL      a price now for a payoff later
//   LUCK      chance effects rolling in V's favour (RLLuck)
//   DRONE     a Militech drone on V's side
//
// When a keyword lands it shows a one-word tag on the HUD (UI/Hud.reds) and
// checks the reactions to it: Ghost Shot, Hemorrhage, Short Circuit,
// Blackwall Gate, Cocktail. Reactions that spread to other enemies run a
// short beat later (RLEffectStep), so a chain plays out where it can be seen.
// -----------------------------------------------------------------------------

module NightCityRoguelite

// One hook call's view of the run: who, where, when.
public class RLFx {
  public let run: ref<RLRunState>;
  public let combat: ref<RLCombatState>;
  public let player: wref<PlayerPuppet>;
  public let system: wref<RogueliteSystem>;
  public let game: GameInstance;
  public let now: Float;

  public static func Make(system: ref<RogueliteSystem>, run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>) -> ref<RLFx> {
    let fx = new RLFx();
    fx.system = system;
    fx.run = run;
    fx.combat = combat;
    fx.player = player;
    fx.game = player.GetGame();
    fx.now = RLBoonEffects.Now(fx.game);
    return fx;
  }

  // The fight in progress, for a delayed step (null outside a fight).
  public static func Current(game: GameInstance) -> ref<RLFx> {
    let system = RogueliteSystem.Get(game);
    let player = GetPlayer(game);
    if !IsDefined(system) || !IsDefined(player) || !system.IsFighting() {
      return null;
    }
    return RLFx.Make(system, system.GetRun(), system.GetCombat(), player);
  }

  public func Has(id: CName) -> Bool = RLBoons.Has(this.run, id)

  public func Overclocked(id: CName) -> Bool = RLBoons.IsOverclocked(this.run, id)
}

public abstract class RLKeywords {
  public static func Color(keyword: CName) -> CName {
    switch keyword {
      case n"MARK": return n"MainColors.ActiveYellow";
      case n"FOCUS": return n"MainColors.ActiveWhite";
      case n"BLAST": return n"MainColors.Yellow";
      case n"DRONE": return n"MainColors.Yellow";
      case n"SHOCK": return n"MainColors.Blue";
      case n"GLITCH": return n"MainColors.Green";
      case n"BURN": return n"MainColors.Red";
      case n"BLEED": return n"MainColors.Red";
      case n"MOMENTUM": return n"MainColors.Gold";
      case n"SHIELD": return n"MainColors.Gold";
      case n"DEAL": return n"MainColors.Purple";
      case n"LUCK": return n"MainColors.Purple";
    }
    return n"MainColors.ActiveWhite";
  }

  // --- Tags ------------------------------------------------------------------------------

  // A one-word tag on the HUD (the effect firing, or a keyword landing).
  public static func Tag(fx: ref<RLFx>, const label: String, color: CName) {
    if IsDefined(fx.system) {
      fx.system.ShowTag(label, color);
    }
  }

  // --- MARK --------------------------------------------------------------------------------

  public static func Mark(fx: ref<RLFx>, target: ref<ScriptedPuppet>, seconds: Float) {
    let foe = RLKeywords.Living(fx, target);
    if !IsDefined(foe) {
      return;
    }
    let fresh = foe.markUntil <= fx.now;
    let until = fx.Has(n"DeathSentence") ? fx.now + 100000.0 : fx.now + seconds;
    foe.markUntil = MaxF(foe.markUntil, until);
    if !foe.markShown {
      foe.markShown = true;
      StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.PingMarkStatusEffect", fx.player.GetEntityID());
    }
    if !fresh {
      return;
    }
    RLKeywords.Tag(fx, "MARK", n"MainColors.ActiveYellow");
    if fx.Has(n"Hemorrhage") {
      RLKeywords.Bleed(fx, target, 1);
    }
    RLKeywords.CheckCocktail(fx, foe, target);
  }

  public static func IsMarked(fx: ref<RLFx>, foe: ref<RLFoe>) -> Bool {
    if !IsDefined(foe) {
      return false;
    }
    return foe.markUntil > fx.now || (fx.Has(n"Hemorrhage") && fx.combat.IsBleeding(foe, fx.now));
  }

  // Takes the outline off MARKS that ran out (once a second).
  public static func ExpireMarks(fx: ref<RLFx>) {
    for foe in fx.combat.Foes() {
      if foe.markShown && foe.markUntil <= fx.now {
        foe.markShown = false;
        let puppet = GameInstance.FindEntityByID(fx.game, foe.id) as ScriptedPuppet;
        if IsDefined(puppet) {
          StatusEffectHelper.RemoveStatusEffect(puppet, t"BaseStatusEffect.PingMarkStatusEffect");
        }
      }
    }
  }

  // --- SHOCK and GLITCH ---------------------------------------------------------------------

  public static func Shock(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    let foe = RLKeywords.Living(fx, target);
    // Once every half second per enemy: chains don't stun-lock a crowd.
    if !IsDefined(foe) || fx.now - foe.shockedAt < 0.5 {
      return;
    }
    foe.shockedAt = fx.now;
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Electrocuted", fx.player.GetEntityID());
    RLKeywords.Tag(fx, "SHOCK", n"MainColors.Blue");
    if fx.Has(n"GhostProtocol") {
      RLKeywords.Glitch(fx, target);
    }
    if fx.Has(n"GhostShot") {
      RLKeywords.Mark(fx, target, 6.0);
    }
    if fx.Has(n"BlackwallGate") && !fx.combat.arcing {
      RLKeywords.StartChain(fx, foe, target);
    }
    RLKeywords.CheckCocktail(fx, foe, target);
  }

  public static func IsShocked(fx: ref<RLFx>, foe: ref<RLFoe>, target: ref<ScriptedPuppet>) -> Bool {
    if IsDefined(foe) && foe.shockedAt > 0.0 && fx.now - foe.shockedAt < 3.0 {
      return true;
    }
    return IsDefined(target) && StatusEffectSystem.ObjectHasStatusEffectOfType(target, gamedataStatusEffectType.Electrocuted);
  }

  public static func Glitch(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    let foe = RLKeywords.Living(fx, target);
    if !IsDefined(foe) {
      return;
    }
    let fresh = foe.glitchUntil <= fx.now;
    foe.glitchUntil = fx.now + 6.0;
    if !fresh {
      return;
    }
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.DisableCyberware", fx.player.GetEntityID());
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.ElectrocutedParticleStatus", fx.player.GetEntityID());
    RLKeywords.Tag(fx, "GLITCH", n"MainColors.Green");
    RLKeywords.CheckCocktail(fx, foe, target);
  }

  // Blackwall Gate: a SHOCK that lands sends an arc on to a new enemy a
  // second later, and on, until no enemy is left that this chain hasn't
  // reached (RLBoonEffects.ArcOn). The arcs' own SHOCKs don't start chains,
  // and an enemy starts one chain at a time, so chains always run out.
  private static func StartChain(fx: ref<RLFx>, foe: ref<RLFoe>, target: ref<ScriptedPuppet>) {
    if foe.chainAt > 0.0 && fx.now - foe.chainAt < 3.0 {
      return;
    }
    foe.chainAt = fx.now;
    let reached: array<EntityID>;
    ArrayPush(reached, foe.id);
    RLEffectStep.Chain(fx, n"arc", target.GetWorldPosition(), reached, 0, 1.0);
  }

  // --- BURN and BLEED ------------------------------------------------------------------------

  public static func Burn(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    let foe = RLKeywords.Living(fx, target);
    if !IsDefined(foe) {
      return;
    }
    let fresh = !RLKeywords.IsBurning(target);
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Burning", fx.player.GetEntityID());
    if !fresh {
      return;
    }
    RLKeywords.Tag(fx, "BURN", n"MainColors.Red");
    if fx.Has(n"ShortCircuit") {
      RLKeywords.Shock(fx, target);
    }
    RLKeywords.CheckCocktail(fx, foe, target);
  }

  public static func IsBurning(target: ref<ScriptedPuppet>) -> Bool {
    return IsDefined(target) && StatusEffectSystem.ObjectHasStatusEffectOfType(target, gamedataStatusEffectType.Burning);
  }

  public static func MaxBleed(fx: ref<RLFx>) -> Int32 = fx.Overclocked(n"Bloodletter") ? 5 : 3

  public static func Bleed(fx: ref<RLFx>, target: ref<ScriptedPuppet>, stacks: Int32) {
    let foe = RLKeywords.Living(fx, target);
    if !IsDefined(foe) || stacks <= 0 {
      return;
    }
    let fresh = !fx.combat.IsBleeding(foe, fx.now);
    if fresh {
      foe.bleedStacks = 0;
    }
    foe.bleedStacks = Min(Max(RLKeywords.MaxBleed(fx), 1), foe.bleedStacks + stacks);
    foe.bleedUntil = fx.now + 6.0;
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Bleeding", fx.player.GetEntityID());
    if !fresh {
      return;
    }
    RLKeywords.Tag(fx, "BLEED", n"MainColors.Red");
    RLKeywords.CheckCocktail(fx, foe, target);
  }

  // --- FOCUS and knockdowns ------------------------------------------------------------------

  // FOCUS for `seconds` of real time. Sim time crawls at the slow-down's
  // rate meanwhile, so `focusUntil` is kept in sim time at that rate (see
  // FocusLeft); whether V is in FOCUS is asked of the time system, so it
  // ends exactly when the slow-down visibly does.
  public static func Focus(fx: ref<RLFx>, seconds: Float) {
    let rate = RLKeywords.FocusRate();
    let until = fx.now + seconds * rate;
    let fresh = !RLKeywords.InFocus(fx);
    if !fresh && until <= fx.combat.focusUntil {
      return;
    }
    fx.combat.focusUntil = until;
    GameInstance.GetTimeSystem(fx.game).SetTimeDilation(n"NCRogueliteFocus", rate, seconds, n"Linear", n"Linear");
    if fresh {
      fx.combat.focusKills = 0;
      RLKeywords.Tag(fx, "FOCUS", n"MainColors.ActiveWhite");
    }
  }

  public static func FocusRate() -> Float = 0.35

  // Real seconds of FOCUS left.
  public static func FocusLeft(fx: ref<RLFx>) -> Float {
    return RLKeywords.InFocus(fx) ? MaxF(0.0, fx.combat.focusUntil - fx.now) / RLKeywords.FocusRate() : 0.0;
  }

  public static func InFocus(fx: ref<RLFx>) -> Bool = GameInstance.GetTimeSystem(fx.game).IsTimeDilationActive(n"NCRogueliteFocus")

  // True when the enemy went down.
  public static func Knockdown(fx: ref<RLFx>, target: ref<ScriptedPuppet>) -> Bool {
    let foe = RLKeywords.Living(fx, target);
    // Not bosses, and not an enemy still down: no knocking it back over
    // before it's up (no stun-lock).
    if !IsDefined(foe) || foe.isBoss || foe.knockedUntil > fx.now {
      return false;
    }
    StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Knockdown", fx.player.GetEntityID());
    foe.knockedUntil = fx.now + 3.0;
    return true;
  }

  // --- BLAST ---------------------------------------------------------------------------------

  // One of V's own blasts. `depth` counts House Edge echoes.
  public static func Blast(fx: ref<RLFx>, position: Vector4, radius: Float, body: ref<GameObject>, depth: Int32) {
    if !IsDefined(fx.player) {
      return;
    }
    let reach = fx.Overclocked(n"ShapedCharge") ? radius * 1.5 : radius;
    RLExplosions.Blast(fx.player, position, t"Attacks.CyberwareExplosion", reach, body);
    fx.combat.blasts += 1;
    RLKeywords.Tag(fx, "BLAST", n"MainColors.Yellow");
    if fx.Has(n"FireMission") && fx.combat.blasts % 20 == 0 {
      RLBoonEffects.FireMission(fx);
    }
    if fx.Has(n"HouseEdge") && depth < 3 && RLLuck.Roll(fx, 0.25) {
      fx.combat.Fired(n"HouseEdge", 0.0);
      let echoes = RLLuck.Times(fx);
      let i = 0;
      while i < echoes {
        RLEffectStep.Schedule(fx, n"echo", position, radius, depth + 1, 1.0 + 0.3 * Cast<Float>(i));
        i += 1;
      }
    }
  }

  // --- Cocktail ------------------------------------------------------------------------------

  // How many different statuses an enemy carries.
  public static func StatusCount(fx: ref<RLFx>, foe: ref<RLFoe>, target: ref<ScriptedPuppet>) -> Int32 {
    let count = 0;
    if foe.markUntil > fx.now { count += 1; }
    if RLKeywords.IsShocked(fx, foe, target) { count += 1; }
    if foe.glitchUntil > fx.now { count += 1; }
    if RLKeywords.IsBurning(target) { count += 1; }
    if fx.combat.IsBleeding(foe, fx.now) { count += 1; }
    return count;
  }

  private static func CheckCocktail(fx: ref<RLFx>, foe: ref<RLFoe>, target: ref<ScriptedPuppet>) {
    if !fx.Has(n"Cocktail") || foe.burst {
      return;
    }
    let needed = fx.Overclocked(n"Cocktail") ? 2 : 3;
    if RLKeywords.StatusCount(fx, foe, target) < needed {
      return;
    }
    foe.burst = true;
    fx.combat.Fired(n"Cocktail", 0.0);
    RLKeywords.Tag(fx, "COCKTAIL", n"MainColors.Purple");
    RLEffectStep.ScheduleOn(fx, n"cocktail", target, 0.25);
  }

  // The burst: everything on `source` copies onto everyone within `radius`
  // (5 m for Cocktail).
  public static func SpreadStatuses(fx: ref<RLFx>, source: ref<ScriptedPuppet>, opt radius: Float) {
    if radius <= 0.0 {
      radius = 5.0;
    }
    let foe = fx.combat.Foe(source.GetEntityID());
    if !IsDefined(foe) {
      return;
    }
    let marked = foe.markUntil > fx.now;
    let shocked = RLKeywords.IsShocked(fx, foe, source);
    let glitched = foe.glitchUntil > fx.now;
    let burning = RLKeywords.IsBurning(source);
    let bleeding = fx.combat.IsBleeding(foe, fx.now) ? foe.bleedStacks : 0;
    for other in RLKeywords.EnemiesNear(fx, source.GetWorldPosition(), radius) {
      if other.GetEntityID() != source.GetEntityID() {
        if marked { RLKeywords.Mark(fx, other, 6.0); }
        if shocked { RLKeywords.Shock(fx, other); }
        if glitched { RLKeywords.Glitch(fx, other); }
        if burning { RLKeywords.Burn(fx, other); }
        if bleeding > 0 { RLKeywords.Bleed(fx, other, bleeding); }
      }
    }
  }

  // --- Damage and targets ---------------------------------------------------------------------

  // Health points off an enemy, dealt by V (arcs, bleed ticks, jumps).
  public static func Damage(fx: ref<RLFx>, target: ref<ScriptedPuppet>, points: Float) {
    if !IsDefined(target) || target.IsDead() || points <= 0.0 {
      return;
    }
    GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health, -points, fx.player, false, false);
  }

  // A share of an enemy's health (0.15 = 15%), dealt by V.
  public static func DamagePercent(fx: ref<RLFx>, target: ref<ScriptedPuppet>, percent: Float) {
    if !IsDefined(target) || target.IsDead() || percent <= 0.0 {
      return;
    }
    GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health, -100.0 * percent, fx.player, false, true);
  }

  public static func EnemiesNear(fx: ref<RLFx>, position: Vector4, radius: Float) -> array<ref<ScriptedPuppet>> {
    let none: array<ref<ScriptedPuppet>>;
    return IsDefined(fx.system) ? fx.system.EnemiesNear(position, radius) : none;
  }

  // The nearest living arena enemy to a spot, other than `except`; MARKED
  // ones first when `preferMarked`.
  public static func Nearest(fx: ref<RLFx>, position: Vector4, radius: Float, except: EntityID, preferMarked: Bool) -> ref<ScriptedPuppet> {
    let best: ref<ScriptedPuppet>;
    let bestScore = 99999.0;
    for enemy in RLKeywords.EnemiesNear(fx, position, radius) {
      if enemy.GetEntityID() != except && !enemy.IsDead() {
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

  // The enemy's record when it's a living arena enemy.
  public static func Living(fx: ref<RLFx>, target: ref<ScriptedPuppet>) -> ref<RLFoe> {
    if !IsDefined(target) || target.IsDead() {
      return null;
    }
    let foe = fx.combat.Foe(target.GetEntityID());
    return IsDefined(foe) && !foe.dead ? foe : null;
  }
}

// LUCK: every chance effect goes through here.
public abstract class RLLuck {
  // Lucky Break rolls everything twice.
  public static func Roll(fx: ref<RLFx>, chance: Float) -> Bool {
    if RandF() < chance {
      return true;
    }
    return fx.Has(n"LuckyBreak") && RandF() < chance;
  }

  // How many times a chance effect that just fired goes off: three on a
  // Jackpot, otherwise once.
  public static func Times(fx: ref<RLFx>) -> Int32 {
    if !fx.Has(n"Jackpot") {
      return 1;
    }
    let chance = fx.Overclocked(n"Jackpot") ? 0.2 : 0.1;
    if !RLLuck.Roll(fx, chance) {
      return 1;
    }
    fx.combat.Fired(n"Jackpot", 0.0);
    RLKeywords.Tag(fx, "JACKPOT", n"MainColors.Purple");
    return 3;
  }
}

// A reaction that runs a moment later: an echo of a blast, an arc jumping on,
// a Cocktail burst, a Convoy charge, a Fire Mission strike.
public class RLEffectStep extends RLDelayTarget {
  private let m_kind: CName;
  private let m_position: Vector4;
  private let m_radius: Float;
  private let m_depth: Int32;
  private let m_target: wref<ScriptedPuppet>;
  // Chains: the enemies this one has already reached.
  private let m_reached: array<EntityID>;

  public static func Schedule(fx: ref<RLFx>, kind: CName, position: Vector4, radius: Float, depth: Int32, delay: Float) {
    let step = new RLEffectStep();
    step.m_kind = kind;
    step.m_position = position;
    step.m_radius = radius;
    step.m_depth = depth;
    fx.combat.Keep(step);
    RLDelay(fx.game, step, kind, delay);
  }

  // A step of a chain that must never hit the same enemy twice.
  public static func Chain(fx: ref<RLFx>, kind: CName, position: Vector4, reached: array<EntityID>, depth: Int32, delay: Float) {
    let step = new RLEffectStep();
    step.m_kind = kind;
    step.m_position = position;
    step.m_reached = reached;
    step.m_depth = depth;
    fx.combat.Keep(step);
    RLDelay(fx.game, step, kind, delay);
  }

  public static func ScheduleOn(fx: ref<RLFx>, kind: CName, target: ref<ScriptedPuppet>, delay: Float) {
    let step = new RLEffectStep();
    step.m_kind = kind;
    step.m_target = target;
    step.m_position = target.GetWorldPosition();
    fx.combat.Keep(step);
    RLDelay(fx.game, step, kind, delay);
  }

  public func OnDelayed(action: CName) {
    let fx = RLFx.Current(GetGameInstance());
    if IsDefined(fx) {
      fx.combat.Release(this);
      RLBoonEffects.OnStep(fx, this.m_kind, this.m_position, this.m_radius, this.m_depth, this.m_target, this.m_reached);
    }
  }
}

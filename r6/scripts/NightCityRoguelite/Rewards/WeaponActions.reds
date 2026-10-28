// -----------------------------------------------------------------------------
// Night City Roguelite - how the main weapon fires
// -----------------------------------------------------------------------------
// Weapon effects (Rewards/Boons.reds) live on the main slot, and the slot can
// hold a gun, a blade, arm chrome or a cyberdeck. They don't all fire at the
// same pace, so every weapon effect has a reading for each way a main weapon
// lands its blows - written for it, not a gun's numbers scaled down:
//
//   HIT     guns, blades, Gorilla Arms, Mantis Blades, Monowire: every hit
//   SHELL   the Projectile Launcher: one per shell, and the parts that touch
//           an enemy touch everything the shell catches
//   UPLOAD  a cyberdeck: one per quickhack that finishes uploading, damage or
//           not (a hack that spreads counts on every enemy it reaches)
//
//                 HIT                      SHELL                    UPLOAD
//   Tracer        3rd hit MARKS            shells MARK              hacks MARK
//   Payload       6th hit BLASTS           3rd shell is heavy       3rd hack BLASTS
//   Thunder       headshot strike          every shell strikes      2nd hack on one enemy strikes
//   Hot Barrel    heat, then BURN          3rd shell lands hot      3rd hack overheats the deck
//   Kinetic       dash, then knockdown     same, shells             same, hacks
//   Lucky Round   8th hit x3               4th shell x3             1 in 4 hacks jumps
//
// HIT readings stay where they always were (Rewards/BoonEffects.reds); the
// other two are here.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLMainAction {
  Hit = 0,
  Shell = 1,
  Upload = 2,
}

public abstract class RLWeaponActions {
  public static func Of(run: ref<RLRunState>) -> RLMainAction {
    if RLArms.IsMainDeck(run) {
      return RLMainAction.Upload;
    }
    if RLArms.IsMainArms(run) && Equals(RPGManager.GetItemType(run.mainWeapon), gamedataItemType.Cyb_Launcher) {
      return RLMainAction.Shell;
    }
    return RLMainAction.Hit;
  }

  // --- Card text ------------------------------------------------------------------------

  // A weapon effect's line as the main weapon reads it.
  public static func Text(run: ref<RLRunState>, def: ref<RLBoonDef>, overclock: Bool) -> String {
    if NotEquals(def.kind, RLBoonKind.Weapon) {
      return overclock ? def.overclock : def.text;
    }
    switch RLWeaponActions.Of(run) {
      case RLMainAction.Shell:
        return RLWeaponActions.ShellText(def.id, overclock);
      case RLMainAction.Upload:
        return RLWeaponActions.UploadText(def.id, overclock);
    }
    return overclock ? def.overclock : def.text;
  }

  private static func ShellText(id: CName, overclock: Bool) -> String {
    switch id {
      case n"TracerRounds": return overclock ? "The MARKS last twice as long." : "Your shells MARK everything they catch.";
      case n"Payload": return overclock ? "Every 2nd shell." : "Every 3rd shell is a heavy one: a second, bigger BLAST where it lands.";
      case n"ThunderRounds": return overclock ? "The strike SHOCKS everything within 4 m." : "Every shell calls down a SHOCK strike where it lands.";
      case n"HotBarrel": return overclock ? "Every 2nd shell." : "Every 3rd shell lands hot: everything it catches BURNS.";
      case n"KineticRounds": return overclock ? "Those hits deal +30%." : "For 2 s after a dash or slide, your shells knock down everything they catch. At full MOMENTUM, always.";
      case n"LuckyRound": return overclock ? "Every 3rd shell." : "Every 4th shell deals triple damage.";
    }
    return "";
  }

  private static func UploadText(id: CName, overclock: Bool) -> String {
    switch id {
      case n"TracerRounds": return overclock ? "Quickhacks on MARKED enemies give back 2 RAM." : "Every quickhack MARKS its target.";
      case n"Payload": return overclock ? "Every 2nd quickhack." : "Every 3rd quickhack BLASTS on its target.";
      case n"ThunderRounds": return overclock ? "The strike SHOCKS everything within 4 m." : "A second quickhack on the same enemy within 8 s calls down a SHOCK strike.";
      case n"HotBarrel": return overclock ? "Overheats on every 2nd." : "Every 3rd quickhack overheats your deck: for 6 s, your quickhacks BURN.";
      case n"KineticRounds": return overclock ? "Those quickhacks deal +30%." : "Quickhacks uploaded within 2 s of a dash or slide knock their target down. At full MOMENTUM, always.";
      case n"LuckyRound": return overclock ? "1 in 3." : "1 in 4 quickhacks jumps: everything on its target copies onto the nearest enemy.";
    }
    return "";
  }

  // --- SHELL ----------------------------------------------------------------------------

  // A new shell landed (its first main hit): what it carries.
  public static func OnShell(fx: ref<RLFx>, ctx: ref<RLHitContext>) {
    let combat = fx.combat;
    let target = ctx.target;
    let crit = RLHitFlag.Has(ctx.flags, RLHitFlag.Crit());
    combat.shellHot = false;
    combat.shellLucky = false;
    if fx.Has(n"Payload") {
      combat.payloadHits += RLWeaponActions.Step(fx, crit);
      if combat.payloadHits >= (fx.Overclocked(n"Payload") ? 2 : 3) {
        combat.payloadHits = 0;
        RLBoonEffects.Note(fx, n"Payload", 0.0);
        RLKeywords.Tag(fx, "HEAVY", n"MainColors.Yellow");
        RLEffectStep.Schedule(fx, n"charge", target.GetWorldPosition(), 4.5, 0, 0.2);
      }
    }
    if fx.Has(n"ThunderRounds") {
      RLWeaponActions.Strike(fx, target);
    }
    if fx.Has(n"HotBarrel") {
      combat.heat += RLWeaponActions.Step(fx, crit);
      if combat.heat >= (fx.Overclocked(n"HotBarrel") ? 2 : 3) {
        combat.heat = 0;
        combat.shellHot = true;
        RLBoonEffects.Note(fx, n"HotBarrel", 0.0);
        RLKeywords.Tag(fx, "HOT SHELL", n"MainColors.Red");
      }
    }
    if fx.Has(n"LuckyRound") {
      combat.luckyHits += RLWeaponActions.Step(fx, crit);
      if combat.luckyHits >= (fx.Overclocked(n"LuckyRound") ? 3 : 4) {
        combat.luckyHits = 0;
        combat.shellLucky = true;
        RLKeywords.Tag(fx, "LUCKY SHELL", n"MainColors.Purple");
      }
    }
  }

  // The shell in flight: still the one `OnShell` read (a quarter second).
  public static func InShell(fx: ref<RLFx>) -> Bool = fx.now - fx.combat.shellAt < 0.25

  // Every enemy a shell catches.
  public static func ShellHit(fx: ref<RLFx>, ctx: ref<RLHitContext>) {
    let target = ctx.target;
    if fx.Has(n"TracerRounds") {
      RLKeywords.Mark(fx, target, fx.Overclocked(n"TracerRounds") ? 12.0 : 6.0);
      RLBoonEffects.Note(fx, n"TracerRounds", 0.0);
    }
    if fx.combat.shellHot && RLWeaponActions.InShell(fx) {
      RLKeywords.Burn(fx, target);
    }
  }

  // Lucky Round on a lucky shell: triple, for everything it catches.
  public static func ShellMultiplier(fx: ref<RLFx>, ctx: ref<RLHitContext>) -> Float {
    if fx.combat.shellLucky && RLWeaponActions.InShell(fx) {
      return RLBoonEffects.Boost(fx, n"LuckyRound", ctx.damage, 3.0);
    }
    return 1.0;
  }

  // --- UPLOAD ---------------------------------------------------------------------------

  // A quickhack finished uploading onto `target`; `previous` is the upload
  // before it on the same enemy (0 for none), `marked` whether it was MARKED
  // before this hack.
  public static func OnUpload(fx: ref<RLFx>, target: ref<ScriptedPuppet>, foe: ref<RLFoe>, previous: Float, marked: Bool) {
    let combat = fx.combat;
    if fx.Has(n"TracerRounds") {
      if fx.Overclocked(n"TracerRounds") && marked {
        RLBoonEffects.GiveRam(fx, 2.0);
      }
      RLKeywords.Mark(fx, target, 6.0);
      RLBoonEffects.Note(fx, n"TracerRounds", 0.0);
    }
    if fx.Has(n"Payload") {
      combat.payloadHits += 1;
      if combat.payloadHits >= (fx.Overclocked(n"Payload") ? 2 : 3) {
        combat.payloadHits = 0;
        RLBoonEffects.Note(fx, n"Payload", 0.0);
        RLKeywords.Blast(fx, target.GetWorldPosition(), 3.0, null, 0);
      }
    }
    if fx.Has(n"ThunderRounds") && previous > 0.0 && fx.now - previous < 8.0 {
      RLWeaponActions.Strike(fx, target);
    }
    if fx.Has(n"HotBarrel") {
      // The deck heats up between overheats, not during one.
      if combat.hotUntil <= fx.now {
        combat.heat += 1;
        if combat.heat >= (fx.Overclocked(n"HotBarrel") ? 2 : 3) {
          combat.heat = 0;
          combat.hotUntil = fx.now + 6.0;
          RLBoonEffects.Note(fx, n"HotBarrel", 0.0);
          RLKeywords.Tag(fx, "OVERHEAT", n"MainColors.Red");
        }
      }
      if combat.hotUntil > fx.now {
        RLKeywords.Burn(fx, target);
      }
    }
    if fx.Has(n"KineticRounds") && (combat.dashUntil > fx.now || RLBoonEffects.FullMomentum(fx)) {
      // The hack's own hits land a moment later: they take the +30%.
      foe.kineticUntil = fx.now + 2.0;
      if RLKeywords.Knockdown(fx, target) {
        RLBoonEffects.Note(fx, n"KineticRounds", 0.0);
      }
    }
    if fx.Has(n"LuckyRound") && RLLuck.Roll(fx, fx.Overclocked(n"LuckyRound") ? 0.34 : 0.25) {
      // A beat later, once the hack's own statuses are on.
      RLBoonEffects.Note(fx, n"LuckyRound", 0.0);
      RLKeywords.Tag(fx, "JUMP", n"MainColors.Purple");
      let times = RLLuck.Times(fx);
      let i = 0;
      while i < times {
        RLEffectStep.ScheduleOn(fx, n"jump", target, 0.4 + 0.2 * Cast<Float>(i));
        i += 1;
      }
    }
  }

  // Lucky Round's jump: what's on `source` copies onto the nearest enemy.
  public static func Jump(fx: ref<RLFx>, source: ref<ScriptedPuppet>) {
    let foe = fx.combat.Foe(source.GetEntityID());
    if !IsDefined(foe) {
      return;
    }
    let next = RLKeywords.Nearest(fx, source.GetWorldPosition(), 15.0, source.GetEntityID(), false);
    if !IsDefined(next) {
      return;
    }
    if foe.markUntil > fx.now { RLKeywords.Mark(fx, next, 6.0); }
    if RLKeywords.IsShocked(fx, foe, source) { RLKeywords.Shock(fx, next); }
    if foe.glitchUntil > fx.now { RLKeywords.Glitch(fx, next); }
    if RLKeywords.IsBurning(source) { RLKeywords.Burn(fx, next); }
    if fx.combat.IsBleeding(foe, fx.now) { RLKeywords.Bleed(fx, next, foe.bleedStacks); }
  }

  // --- Shared ---------------------------------------------------------------------------

  // Thunder Rounds' strike on a shell or a second hack.
  private static func Strike(fx: ref<RLFx>, target: ref<ScriptedPuppet>) {
    RLBoonEffects.Note(fx, n"ThunderRounds", 0.0);
    RLKeywords.Tag(fx, "THUNDER", n"MainColors.Blue");
    RLKeywords.Shock(fx, target);
    if fx.Overclocked(n"ThunderRounds") {
      for other in RLKeywords.EnemiesNear(fx, target.GetWorldPosition(), 4.0) {
        RLKeywords.Shock(fx, other);
      }
    }
  }

  // Crits count twice on the counters with Loaded Dice.
  private static func Step(fx: ref<RLFx>, crit: Bool) -> Int32 = crit && fx.Has(n"LoadedDice") ? 2 : 1
}

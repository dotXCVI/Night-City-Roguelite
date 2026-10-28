// -----------------------------------------------------------------------------
// Night City Roguelite - arm mods (and the deck's daemons)
// -----------------------------------------------------------------------------
// Chrome in the main slot (Rewards/ArmChrome.reds) gets two mod slots of its
// own, named after the game's own parts, so it never competes with the weapon
// effects for room. Each slot takes one of three mods; a mod V holds comes
// back as its overclock. The cards are the Tune-Up door's (Hades' hammers),
// dealt while that chrome is the main weapon - and the stranger sells one,
// overclocked - and every mod speaks the keywords (Combat/Keywords.reds), so
// it plugs into the patrons' effects:
//
//   Gorilla Arms        KNUCKLES   Breaker, Detonator, Rending
//                       BATTERY    Combo, Capacitor, Adrenal
//   Mantis Blades       BLADE      Thermal, Serrated, Mono
//                       ACTUATOR   Leap, Shock, Deflector
//   Monowire            CABLE      Arc, Garrote, Barbed
//                       BATTERY    Uplink, Capacitor, Feedback
//   Projectile Launcher ROUND      Cluster, Sticky, Seeker
//                       WIRING     Autoloader, Recoil, Overpressure
//   Cyberdeck           ICEBREAKER Breach, Spike, Logic Bomb
//                       FIRMWARE   Cache, Overvolt, Ghost
//
// The rules are scripted with the effects' hooks (Rewards/BoonEffects.reds,
// RLArmModEffects below); this file holds the catalogue and what V holds.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLArmModDef {
  public let id: CName;
  // The chrome it fits: StrongArms, MantisBlades, NanoWires,
  // ProjectileLauncher, Deck.
  public let family: String;
  public let slot: String;
  public let name: String;
  public let text: String;
  public let overclock: String;
  public let makes: array<CName>;
  public let uses: array<CName>;
}

public abstract class RLArmMods {
  // --- Catalogue -----------------------------------------------------------------------------

  public static func All() -> array<ref<RLArmModDef>> {
    let list: array<ref<RLArmModDef>>;
    let none: array<CName>;
    // Gorilla Arms
    RLArmMods.Add(list, n"Breaker", "StrongArms", "KNUCKLES", "Breaker Knuckles", none, none,
      "Strong punches knock enemies down. Downed enemies take +40% from your fists.",
      "+80%, and the knockdown MARKS.");
    RLArmMods.Add(list, n"Detonator", "StrongArms", "KNUCKLES", "Detonator Knuckles", [n"BLAST"], none,
      "Strong punches BLAST on impact.",
      "Twice the blast.");
    RLArmMods.Add(list, n"Rending", "StrongArms", "KNUCKLES", "Rending Knuckles", [n"BLEED"], none,
      "Every punch makes them BLEED.",
      "Two stacks a punch.");
    RLArmMods.Add(list, n"Combo", "StrongArms", "BATTERY", "Combo Battery", [n"FOCUS"], none,
      "Five punches without a break trigger FOCUS.",
      "Four punches, and FOCUS lasts longer.");
    RLArmMods.Add(list, n"ArmsCapacitor", "StrongArms", "BATTERY", "Capacitor Battery", [n"SHOCK"], none,
      "Every 8th punch sends out a shockwave that SHOCKS everything within 5 m.",
      "Every 5th punch.");
    RLArmMods.Add(list, n"Adrenal", "StrongArms", "BATTERY", "Adrenal Battery", [n"MOMENTUM"], none,
      "Punch kills build MOMENTUM and heal 3%.",
      "Heal 6%.");
    // Mantis Blades
    RLArmMods.Add(list, n"ThermalEdge", "MantisBlades", "BLADE", "Thermal Edge", [n"BURN"], none,
      "Strong slashes set them on fire.",
      "Every slash does.");
    RLArmMods.Add(list, n"SerratedEdge", "MantisBlades", "BLADE", "Serrated Edge", [n"BLEED"], [n"BLEED"],
      "Slashes make them BLEED. At full BLEED, a slash opens them up: +100%, and the bleeding starts over.",
      "+200%.");
    RLArmMods.Add(list, n"MonoEdge", "MantisBlades", "BLADE", "Mono Edge", none, [n"MARK"],
      "Slashes on MARKED enemies always crit.",
      "And those crits MARK the nearest enemy.");
    RLArmMods.Add(list, n"LeapActuator", "MantisBlades", "ACTUATOR", "Leap Actuator", [n"MOMENTUM"], none,
      "Strong attacks count as a dash for your dash effects.",
      "And knock down everything within 3 m.");
    RLArmMods.Add(list, n"ShockActuator", "MantisBlades", "ACTUATOR", "Shock Actuator", [n"SHOCK"], none,
      "Strong attacks SHOCK their target and the nearest enemy.",
      "Every slash SHOCKS.");
    RLArmMods.Add(list, n"Deflector", "MantisBlades", "ACTUATOR", "Deflector Actuator", [n"SHIELD"], none,
      "A blade kill raises a SHIELD. One at a time.",
      "Blade kills heal 3% too.");
    // Monowire
    RLArmMods.Add(list, n"ArcCable", "NanoWires", "CABLE", "Arc Cable", none, none,
      "Every lash jumps to the nearest other enemy within 5 m for half damage.",
      "It jumps twice.");
    RLArmMods.Add(list, n"Garrote", "NanoWires", "CABLE", "Garrote Cable", [n"MARK"], [n"MARK"],
      "Lashes kill MARKED enemies under 30% health. Not bosses.",
      "Under 40%, and the kill MARKS the nearest enemy.");
    RLArmMods.Add(list, n"Barbed", "NanoWires", "CABLE", "Barbed Cable", [n"BLEED"], [n"BLEED"],
      "Lashes make them BLEED. BLEEDING enemies take +25% from the wire.",
      "+50%.");
    RLArmMods.Add(list, n"Uplink", "NanoWires", "BATTERY", "Uplink Battery", [n"GLITCH"], none,
      "Strong lashes GLITCH. Wire kills give back 2 RAM.",
      "Every lash GLITCHES.");
    RLArmMods.Add(list, n"WireCapacitor", "NanoWires", "BATTERY", "Capacitor Battery", [n"SHOCK"], none,
      "Every 10th lash SHOCKS everything within 6 m.",
      "Every 6th lash.");
    RLArmMods.Add(list, n"Feedback", "NanoWires", "BATTERY", "Feedback Battery", [n"GLITCH"], none,
      "Lashes deal +40% to enemies you've quickhacked in the last 8 s.",
      "+70%, and the lash GLITCHES.");
    // Projectile Launcher
    RLArmMods.Add(list, n"Cluster", "ProjectileLauncher", "ROUND", "Cluster Round", [n"BLAST"], none,
      "Every shell scatters three bomblets: small BLASTs around the impact.",
      "Five bomblets.");
    RLArmMods.Add(list, n"Sticky", "ProjectileLauncher", "ROUND", "Sticky Round", [n"BLAST"], none,
      "Every shell BLASTs again a moment later.",
      "And a third time.");
    RLArmMods.Add(list, n"Seeker", "ProjectileLauncher", "ROUND", "Seeker Round", [n"BLAST"], [n"MARK"],
      "Every shell sends a micro-missile at the nearest MARKED enemy.",
      "The missile MARKS what it hits.");
    RLArmMods.Add(list, n"Autoloader", "ProjectileLauncher", "WIRING", "Autoloader", none, none,
      "+1 launcher charge.",
      "+2 launcher charges.");
    RLArmMods.Add(list, n"Recoil", "ProjectileLauncher", "WIRING", "Recoil Wiring", [n"MOMENTUM"], none,
      "Every shell that lands counts as a dash for your dash effects.",
      "And you're untouchable for half a second.");
    RLArmMods.Add(list, n"Overpressure", "ProjectileLauncher", "WIRING", "Overpressure Wiring", none, none,
      "Shells knock down everything they hit.",
      "And hit 30% harder.");
    // Cyberdeck
    RLArmMods.Add(list, n"Breach", "Deck", "ICEBREAKER", "Breach Protocol", [n"MARK"], none,
      "Your first quickhack on each enemy MARKS it and gives back 4 RAM.",
      "8 RAM.");
    RLArmMods.Add(list, n"Spike", "Deck", "ICEBREAKER", "Spike", none, [n"GLITCH"],
      "Quickhacks deal +60% to GLITCHED enemies.",
      "+100%.");
    RLArmMods.Add(list, n"LogicBomb", "Deck", "ICEBREAKER", "Logic Bomb", [n"BLAST"], none,
      "Enemies you've quickhacked BLAST when they die.",
      "A bigger BLAST that SHOCKS.");
    RLArmMods.Add(list, n"Cache", "Deck", "FIRMWARE", "RAM Cache", none, none,
      "Every 4th quickhack gives back 6 RAM.",
      "Every 3rd.");
    RLArmMods.Add(list, n"Overvolt", "Deck", "FIRMWARE", "Overvolt", [n"SHOCK"], none,
      "Quickhacks SHOCK their target.",
      "And GLITCH it.");
    RLArmMods.Add(list, n"Ghost", "Deck", "FIRMWARE", "Ghost Firmware", none, none,
      "A quickhack kill makes you untouchable for 1 s.",
      "2 s.");
    return list;
  }

  private static func Add(out list: array<ref<RLArmModDef>>, id: CName, const family: String, const slot: String, const name: String, makes: array<CName>, uses: array<CName>, const text: String, const overclock: String) {
    let def = new RLArmModDef();
    def.id = id;
    def.family = family;
    def.slot = slot;
    def.name = name;
    def.text = text;
    def.overclock = overclock;
    def.makes = makes;
    def.uses = uses;
    ArrayPush(list, def);
  }

  public static func Get(id: CName) -> ref<RLArmModDef> {
    for def in RLArmMods.All() {
      if Equals(def.id, id) {
        return def;
      }
    }
    return null;
  }

  // The family the main slot's chrome takes mods for ("" for a gun).
  public static func MainFamily(run: ref<RLRunState>) -> String {
    if RLArms.IsMainDeck(run) {
      return "Deck";
    }
    if RLArms.IsMainArms(run) {
      return RLArms.Family(RPGManager.GetItemType(run.mainWeapon));
    }
    return "";
  }

  // "GORILLA ARMS" - for card kickers.
  public static func FamilyName(const family: String) -> String {
    switch family {
      case "StrongArms": return "GORILLA ARMS";
      case "MantisBlades": return "MANTIS BLADES";
      case "NanoWires": return "MONOWIRE";
      case "ProjectileLauncher": return "LAUNCHER";
      case "Deck": return "CYBERDECK";
    }
    return "";
  }

  // --- What V holds ------------------------------------------------------------------------------

  public static func Owned(run: ref<RLRunState>, id: CName) -> ref<RLBoonState> {
    if IsDefined(run) {
      for state in run.armMods {
        if Equals(state.id, id) {
          return state;
        }
      }
    }
    return null;
  }

  public static func Has(run: ref<RLRunState>, id: CName) -> Bool = IsDefined(RLArmMods.Owned(run, id))

  public static func IsOverclocked(run: ref<RLRunState>, id: CName) -> Bool {
    let state = RLArmMods.Owned(run, id);
    return IsDefined(state) && state.overclocked;
  }

  // The mod in a slot of the main chrome, or null.
  public static func InSlot(run: ref<RLRunState>, const slot: String) -> ref<RLArmModDef> {
    let family = RLArmMods.MainFamily(run);
    for state in run.armMods {
      let def = RLArmMods.Get(state.id);
      if IsDefined(def) && Equals(def.family, family) && Equals(def.slot, slot) {
        return def;
      }
    }
    return null;
  }

  // A card can be dealt: a mod for an empty slot, or the overclock of one held.
  public static func IsOfferable(run: ref<RLRunState>, def: ref<RLArmModDef>) -> Bool {
    if !Equals(def.family, RLArmMods.MainFamily(run)) || ArrayContains(run.banished, "mod:" + NameToString(def.id)) {
      return false;
    }
    let state = RLArmMods.Owned(run, def.id);
    if IsDefined(state) {
      return !state.overclocked;
    }
    return !IsDefined(RLArmMods.InSlot(run, def.slot));
  }

  public static func Offer(run: ref<RLRunState>, def: ref<RLArmModDef>) -> ref<RLOffer> {
    let overclock = RLArmMods.Has(run, def.id);
    let offer = new RLOffer();
    offer.kind = RLOfferKind.ArmMod;
    offer.boon = def.id;
    offer.overclock = overclock;
    offer.title = overclock ? def.name + "+" : def.name;
    offer.subtitle = (overclock ? "OVERCLOCK - " : "") + def.slot + " - " + RLArmMods.FamilyName(def.family);
    offer.description = overclock ? def.overclock : def.text;
    offer.makes = def.makes;
    offer.uses = def.uses;
    offer.links = RLArmMods.Links(run, def);
    offer.step = 6;
    offer.excitement = 1;
    return offer;
  }

  // Effects V holds that this mod works with: they use what it makes, or make
  // what it uses.
  public static func Links(run: ref<RLRunState>, def: ref<RLArmModDef>) -> array<CName> {
    let links: array<CName>;
    for state in run.boons {
      let effect = RLBoons.Get(state.id);
      if IsDefined(effect) {
        let linked = false;
        for keyword in def.makes {
          if ArrayContains(effect.uses, keyword) {
            linked = true;
          }
        }
        for keyword in def.uses {
          if ArrayContains(effect.makes, keyword) {
            linked = true;
          }
        }
        if linked {
          ArrayPush(links, state.id);
        }
      }
    }
    return links;
  }

  // One card for the main chrome's slots (Tune-Up screens, the stranger), or
  // null.
  public static func DealOne(run: ref<RLRunState>, exclude: array<CName>) -> ref<RLOffer> {
    let candidates: array<ref<RLArmModDef>>;
    for def in RLArmMods.All() {
      if !ArrayContains(exclude, def.id) && RLArmMods.IsOfferable(run, def) {
        ArrayPush(candidates, def);
      }
    }
    if ArraySize(candidates) == 0 {
      return null;
    }
    return RLArmMods.Offer(run, candidates[RandRange(0, ArraySize(candidates))]);
  }

  // --- Taking one ---------------------------------------------------------------------------------

  public static func Apply(player: ref<PlayerPuppet>, run: ref<RLRunState>, id: CName, overclock: Bool) {
    let def = RLArmMods.Get(id);
    if !IsDefined(def) {
      return;
    }
    let state = RLArmMods.Owned(run, id);
    if !IsDefined(state) {
      state = new RLBoonState();
      state.id = id;
      ArrayPush(run.armMods, state);
    }
    state.overclocked = state.overclocked || overclock;
    RLArmMods.SwapStats(player, state);
    RLLog("Arm mod: " + def.name + (state.overclocked ? " (overclocked)." : "."));
  }

  // The mods that are stat changes (Autoloader's charges).
  private static func SwapStats(player: ref<PlayerPuppet>, state: ref<RLBoonState>) {
    let stats = GameInstance.GetStatsSystem(player.GetGame());
    let objectID = Cast<StatsObjectID>(player.GetEntityID());
    for mod in state.mods {
      stats.RemoveModifier(objectID, mod);
    }
    ArrayClear(state.mods);
    if Equals(state.id, n"Autoloader") {
      ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.ProjectileLauncherMaxCharges, gameStatModifierType.Additive, state.overclocked ? 2.0 : 1.0));
    }
    for mod in state.mods {
      stats.AddModifier(objectID, mod);
    }
    if ArraySize(state.mods) > 0 {
      ConsumablesChargesHelper.RefreshAllCharges(player.GetGame(), gamedataStatPoolType.ProjectileLauncherCharges);
    }
  }

  // The run is over: every stat change goes.
  public static func RemoveAll(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    if IsDefined(player) {
      let stats = GameInstance.GetStatsSystem(player.GetGame());
      let objectID = Cast<StatsObjectID>(player.GetEntityID());
      for state in run.armMods {
        for mod in state.mods {
          stats.RemoveModifier(objectID, mod);
        }
      }
    }
    ArrayClear(run.armMods);
  }

  // "Breaker Knuckles+, Combo Battery" - the main chrome's mods.
  public static func Summary(run: ref<RLRunState>) -> String {
    let text = "";
    for state in run.armMods {
      let def = RLArmMods.Get(state.id);
      if IsDefined(def) {
        text += (StrLen(text) > 0 ? ", " : "") + def.name + (state.overclocked ? "+" : "");
      }
    }
    return text;
  }
}

// The mods' rules, called from the effects' hooks (Rewards/BoonEffects.reds).
// "Main" hits are the main chrome's: punches, lashes, shells, quickhacks.
public abstract class RLArmModEffects {
  private static func Has(fx: ref<RLFx>, id: CName) -> Bool = RLArmMods.Has(fx.run, id)

  private static func Overclocked(fx: ref<RLFx>, id: CName) -> Bool = RLArmMods.IsOverclocked(fx.run, id)

  private static func IsStrong(ctx: ref<RLHitContext>) -> Bool {
    let type = ctx.hitEvent.attackData.GetAttackType();
    return Equals(type, gamedataAttackType.StrongMelee) || Equals(type, gamedataAttackType.ChargedWhipAttack);
  }

  // Damage multipliers on a main hit.
  public static func Multiplier(fx: ref<RLFx>, ctx: ref<RLHitContext>, main: Bool) -> Float {
    if ArraySize(fx.run.armMods) == 0 {
      return 1.0;
    }
    let foe = ctx.foe;
    let factor = 1.0;
    let explosion = RLHitFlag.Has(ctx.flags, RLHitFlag.Explosion());
    let quickhack = RLHitFlag.Has(ctx.flags, RLHitFlag.Quickhack());
    if main && RLArmModEffects.Has(fx, n"Breaker") && foe.knockedUntil > fx.now {
      factor *= RLBoonEffects.Boost(fx, n"Breaker", ctx.damage, RLArmModEffects.Overclocked(fx, n"Breaker") ? 1.8 : 1.4);
    }
    if main && RLArmModEffects.Has(fx, n"Barbed") && fx.combat.IsBleeding(foe, fx.now) {
      factor *= RLBoonEffects.Boost(fx, n"Barbed", ctx.damage, RLArmModEffects.Overclocked(fx, n"Barbed") ? 1.5 : 1.25);
    }
    if main && RLArmModEffects.Has(fx, n"Feedback") && foe.quickhackTime > 0.0 && fx.now - foe.quickhackTime < 8.0 {
      factor *= RLBoonEffects.Boost(fx, n"Feedback", ctx.damage, RLArmModEffects.Overclocked(fx, n"Feedback") ? 1.7 : 1.4);
    }
    if main && explosion && RLArmModEffects.Overclocked(fx, n"Overpressure") {
      factor *= RLBoonEffects.Boost(fx, n"Overpressure", ctx.damage, 1.3);
    }
    if quickhack && RLArmModEffects.Has(fx, n"Spike") && fx.combat.IsGlitched(foe, fx.now) {
      factor *= RLBoonEffects.Boost(fx, n"Spike", ctx.damage, RLArmModEffects.Overclocked(fx, n"Spike") ? 2.0 : 1.6);
    }
    // Serrated Edge: a full BLEED is opened up, and starts over.
    if main && RLArmModEffects.Has(fx, n"SerratedEdge") && fx.combat.IsBleeding(foe, fx.now) && foe.bleedStacks >= RLKeywords.MaxBleed(fx) {
      foe.bleedStacks = 0;
      foe.bleedUntil = 0.0;
      factor *= RLBoonEffects.Boost(fx, n"SerratedEdge", ctx.damage, RLArmModEffects.Overclocked(fx, n"SerratedEdge") ? 3.0 : 2.0);
      RLKeywords.Tag(fx, "OPENED", n"MainColors.Red");
    }
    // Mono Edge: a slash on a MARKED enemy is a crit.
    if main && RLArmModEffects.Has(fx, n"MonoEdge") && !RLHitFlag.Has(ctx.flags, RLHitFlag.Crit()) && RLKeywords.IsMarked(fx, foe) {
      ctx.flags |= RLHitFlag.Crit();
      ctx.hitEvent.attackData.AddFlag(hitFlag.CriticalHit, n"NCRogueliteMonoEdge");
      let critDamage = GameInstance.GetStatsSystem(fx.game).GetStatValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatType.CritDamage);
      factor *= RLBoonEffects.Boost(fx, n"MonoEdge", ctx.damage, 1.0 + MaxF(0.5, critDamage / 100.0));
    }
    return factor;
  }

  // Garrote: a lash on a MARKED enemy low enough kills it.
  public static func Garrotes(fx: ref<RLFx>, ctx: ref<RLHitContext>, main: Bool) -> Bool {
    if !main || !RLArmModEffects.Has(fx, n"Garrote") || ctx.foe.isBoss || ctx.foe.executed || !RLKeywords.IsMarked(fx, ctx.foe) {
      return false;
    }
    let threshold = RLArmModEffects.Overclocked(fx, n"Garrote") ? 40.0 : 30.0;
    if ctx.targetHealth >= threshold {
      return false;
    }
    ctx.foe.executed = true;
    RLBoonEffects.Note(fx, n"Garrote", 0.0);
    RLKeywords.Tag(fx, "GARROTE", n"MainColors.ActiveYellow");
    if RLArmModEffects.Overclocked(fx, n"Garrote") {
      let next = RLKeywords.Nearest(fx, ctx.target.GetWorldPosition(), 15.0, ctx.target.GetEntityID(), false);
      if IsDefined(next) {
        RLKeywords.Mark(fx, next, 6.0);
      }
    }
    return true;
  }

  // A main hit landed (not a status tick).
  public static func OnMainHit(fx: ref<RLFx>, ctx: ref<RLHitContext>, dealt: Float) {
    if ArraySize(fx.run.armMods) == 0 {
      return;
    }
    let target = ctx.target;
    let combat = fx.combat;
    let explosion = RLHitFlag.Has(ctx.flags, RLHitFlag.Explosion());
    if explosion {
      RLArmModEffects.OnShell(fx, ctx);
      return;
    }
    let strong = RLArmModEffects.IsStrong(ctx);
    // Gorilla Arms
    if strong && RLArmModEffects.Has(fx, n"Breaker") && RLKeywords.Knockdown(fx, target) {
      RLBoonEffects.Note(fx, n"Breaker", 0.0);
      if RLArmModEffects.Overclocked(fx, n"Breaker") {
        RLKeywords.Mark(fx, target, 6.0);
      }
    }
    if strong && RLArmModEffects.Has(fx, n"Detonator") {
      RLBoonEffects.Note(fx, n"Detonator", 0.0);
      RLKeywords.Blast(fx, target.GetWorldPosition(), RLArmModEffects.Overclocked(fx, n"Detonator") ? 5.0 : 2.5, null, 0);
    }
    if RLArmModEffects.Has(fx, n"Rending") {
      RLBoonEffects.Note(fx, n"Rending", 0.0);
      RLKeywords.Bleed(fx, target, RLArmModEffects.Overclocked(fx, n"Rending") ? 2 : 1);
    }
    if RLArmModEffects.Has(fx, n"Combo") {
      combat.comboHits = fx.now - combat.comboAt > 1.5 ? 1 : combat.comboHits + 1;
      combat.comboAt = fx.now;
      let needed = RLArmModEffects.Overclocked(fx, n"Combo") ? 4 : 5;
      if combat.comboHits >= needed {
        combat.comboHits = 0;
        RLKeywords.Focus(fx, RLArmModEffects.Overclocked(fx, n"Combo") ? 2.5 : 1.5);
        RLKeywords.Tag(fx, "COMBO", n"MainColors.ActiveWhite");
        RLBoonEffects.Note(fx, n"Combo", 0.0);
      }
    }
    if RLArmModEffects.Has(fx, n"ArmsCapacitor") {
      RLArmModEffects.Capacitor(fx, n"ArmsCapacitor", RLArmModEffects.Overclocked(fx, n"ArmsCapacitor") ? 5 : 8, 5.0);
    }
    // Mantis Blades
    if RLArmModEffects.Has(fx, n"ThermalEdge") && (strong || RLArmModEffects.Overclocked(fx, n"ThermalEdge")) {
      RLBoonEffects.Note(fx, n"ThermalEdge", 0.0);
      RLKeywords.Burn(fx, target);
    }
    if RLArmModEffects.Has(fx, n"SerratedEdge") {
      RLBoonEffects.As(fx, n"SerratedEdge");
      RLKeywords.Bleed(fx, target, 1);
    }
    if RLArmModEffects.Overclocked(fx, n"MonoEdge") && RLHitFlag.Has(ctx.flags, RLHitFlag.Crit()) && RLKeywords.IsMarked(fx, ctx.foe) {
      let next = RLKeywords.Nearest(fx, target.GetWorldPosition(), 15.0, target.GetEntityID(), false);
      if IsDefined(next) {
        RLKeywords.Mark(fx, next, 6.0);
      }
    }
    if strong && RLArmModEffects.Has(fx, n"LeapActuator") {
      RLBoonEffects.Note(fx, n"LeapActuator", 0.0);
      RLBoonEffects.OnDash(fx);
      if RLArmModEffects.Overclocked(fx, n"LeapActuator") {
        for enemy in RLKeywords.EnemiesNear(fx, fx.player.GetWorldPosition(), 3.0) {
          RLKeywords.Knockdown(fx, enemy);
        }
      }
    }
    if RLArmModEffects.Has(fx, n"ShockActuator") && (strong || RLArmModEffects.Overclocked(fx, n"ShockActuator")) {
      RLBoonEffects.As(fx, n"ShockActuator");
      RLKeywords.Shock(fx, target);
      if strong {
        let other = RLKeywords.Nearest(fx, target.GetWorldPosition(), 8.0, target.GetEntityID(), false);
        if IsDefined(other) {
          RLKeywords.Shock(fx, other);
        }
      }
      RLBoonEffects.Note(fx, n"ShockActuator", 0.0);
    }
    // Monowire
    if RLArmModEffects.Has(fx, n"ArcCable") {
      RLArmModEffects.ArcCable(fx, target, dealt);
    }
    if RLArmModEffects.Has(fx, n"Barbed") {
      RLBoonEffects.As(fx, n"Barbed");
      RLKeywords.Bleed(fx, target, 1);
    }
    if RLArmModEffects.Has(fx, n"Uplink") && (strong || RLArmModEffects.Overclocked(fx, n"Uplink")) {
      RLKeywords.Glitch(fx, target);
      RLBoonEffects.Note(fx, n"Uplink", 0.0);
    }
    if RLArmModEffects.Has(fx, n"WireCapacitor") {
      RLArmModEffects.Capacitor(fx, n"WireCapacitor", RLArmModEffects.Overclocked(fx, n"WireCapacitor") ? 6 : 10, 6.0);
    }
    if RLArmModEffects.Overclocked(fx, n"Feedback") && ctx.foe.quickhackTime > 0.0 && fx.now - ctx.foe.quickhackTime < 8.0 {
      RLKeywords.Glitch(fx, target);
    }
  }

  // Every Nth swing or lash: a shockwave that SHOCKS everything around V. A
  // lash that catches three enemies is still one lash.
  private static func Capacitor(fx: ref<RLFx>, id: CName, every: Int32, radius: Float) {
    if fx.now - fx.combat.lastSwingAt < 0.15 {
      return;
    }
    fx.combat.lastSwingAt = fx.now;
    fx.combat.armHits += 1;
    if fx.combat.armHits < every {
      return;
    }
    fx.combat.armHits = 0;
    RLKeywords.Tag(fx, "DISCHARGE", n"MainColors.Blue");
    GameInstance.GetAudioSystem(fx.game).PlayShockwave(n"explosion", fx.player.GetWorldPosition());
    RLBoonEffects.Note(fx, id, 0.0);
    for enemy in RLKeywords.EnemiesNear(fx, fx.player.GetWorldPosition(), radius) {
      RLKeywords.Shock(fx, enemy);
    }
  }

  // Arc Cable: the lash carries on to the nearest others.
  private static func ArcCable(fx: ref<RLFx>, source: ref<ScriptedPuppet>, dealt: Float) {
    let jumps = RLArmModEffects.Overclocked(fx, n"ArcCable") ? 2 : 1;
    let reached: array<EntityID>;
    ArrayPush(reached, source.GetEntityID());
    let total = 0.0;
    let i = 0;
    while i < jumps {
      let next = RLBoonEffects.NearestExcept(fx, source.GetWorldPosition(), 5.0, reached);
      if !IsDefined(next) {
        break;
      }
      ArrayPush(reached, next.GetEntityID());
      RLKeywords.Damage(fx, next, dealt * 0.5);
      total += dealt * 0.5;
      i += 1;
    }
    if total > 0.0 {
      RLBoonEffects.Note(fx, n"ArcCable", total);
    }
  }

  // One shell, however many enemies its explosion catches.
  private static func OnShell(fx: ref<RLFx>, ctx: ref<RLHitContext>) {
    let combat = fx.combat;
    let target = ctx.target;
    if RLArmModEffects.Has(fx, n"Overpressure") {
      RLKeywords.Knockdown(fx, target);
    }
    if fx.now - combat.lastShellAt < 0.25 {
      return;
    }
    combat.lastShellAt = fx.now;
    let position = target.GetWorldPosition();
    if RLArmModEffects.Has(fx, n"Cluster") {
      RLBoonEffects.Note(fx, n"Cluster", 0.0);
      let bomblets = RLArmModEffects.Overclocked(fx, n"Cluster") ? 5 : 3;
      let i = 0;
      while i < bomblets {
        let angle = 6.283 * Cast<Float>(i) / Cast<Float>(bomblets);
        let spot = position + Vector4(2.5 * CosF(angle), 2.5 * SinF(angle), 0.0, 0.0);
        RLEffectStep.Schedule(fx, n"charge", spot, 2.0, 0, 0.3 + 0.1 * Cast<Float>(i));
        i += 1;
      }
    }
    if RLArmModEffects.Has(fx, n"Sticky") {
      RLBoonEffects.Note(fx, n"Sticky", 0.0);
      RLEffectStep.Schedule(fx, n"charge", position, 3.0, 0, 0.8);
      if RLArmModEffects.Overclocked(fx, n"Sticky") {
        RLEffectStep.Schedule(fx, n"charge", position, 3.0, 0, 1.6);
      }
    }
    if RLArmModEffects.Has(fx, n"Seeker") {
      let marked = RLBoonEffects.NearestMarked(fx, position, 20.0);
      if IsDefined(marked) {
        RLBoonEffects.Note(fx, n"Seeker", 0.0);
        RLEffectStep.ScheduleOn(fx, n"missile", marked, 0.4);
        if RLArmModEffects.Overclocked(fx, n"Seeker") {
          RLKeywords.Mark(fx, marked, 6.0);
        }
      }
    }
    if RLArmModEffects.Has(fx, n"Recoil") {
      RLBoonEffects.Note(fx, n"Recoil", 0.0);
      RLBoonEffects.OnDash(fx);
      if RLArmModEffects.Overclocked(fx, n"Recoil") {
        combat.untouchableUntil = MaxF(combat.untouchableUntil, fx.now + 0.5);
      }
    }
  }

  // A quickhack landed on an enemy, once per upload (the deck's daemons).
  public static func OnQuickhack(fx: ref<RLFx>, target: ref<ScriptedPuppet>, first: Bool) {
    if ArraySize(fx.run.armMods) == 0 {
      return;
    }
    if first && RLArmModEffects.Has(fx, n"Breach") {
      RLKeywords.Mark(fx, target, 8.0);
      RLBoonEffects.GiveRam(fx, RLArmModEffects.Overclocked(fx, n"Breach") ? 8.0 : 4.0);
      RLKeywords.Tag(fx, "BREACH", n"MainColors.Green");
      RLBoonEffects.Note(fx, n"Breach", 0.0);
    }
    if RLArmModEffects.Has(fx, n"Overvolt") {
      RLBoonEffects.Note(fx, n"Overvolt", 0.0);
      RLKeywords.Shock(fx, target);
      if RLArmModEffects.Overclocked(fx, n"Overvolt") {
        RLKeywords.Glitch(fx, target);
      }
    }
    if RLArmModEffects.Has(fx, n"Cache") {
      fx.combat.hackCount += 1;
      if fx.combat.hackCount >= (RLArmModEffects.Overclocked(fx, n"Cache") ? 3 : 4) {
        fx.combat.hackCount = 0;
        RLBoonEffects.GiveRam(fx, 6.0);
        RLKeywords.Tag(fx, "CACHE", n"MainColors.Green");
        RLBoonEffects.Note(fx, n"Cache", 0.0);
      }
    }
  }

  // An arena enemy died; `flags` is how V's last hit on it landed.
  public static func OnKill(fx: ref<RLFx>, body: ref<ScriptedPuppet>, foe: ref<RLFoe>, flags: Int32) {
    if ArraySize(fx.run.armMods) == 0 {
      return;
    }
    let main = RLHitFlag.Has(flags, RLHitFlag.Main());
    let quickhack = RLHitFlag.Has(flags, RLHitFlag.Quickhack());
    if main && RLArmModEffects.Has(fx, n"Adrenal") {
      RLBoonEffects.SetMomentum(fx, fx.combat.momentum + 1);
      let heal = RLArmModEffects.Overclocked(fx, n"Adrenal") ? 6.0 : 3.0;
      GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatPoolType.Health, heal, null, false, true);
      RLBoonEffects.Note(fx, n"Adrenal", 0.0);
    }
    if main && RLArmModEffects.Has(fx, n"Uplink") {
      RLBoonEffects.GiveRam(fx, 2.0);
    }
    if main && RLArmModEffects.Has(fx, n"Deflector") {
      if !fx.combat.shield {
        fx.combat.shield = true;
        RLKeywords.Tag(fx, "SHIELD UP", n"MainColors.Gold");
        if IsDefined(fx.system) {
          fx.system.RefreshHud();
        }
      }
      if RLArmModEffects.Overclocked(fx, n"Deflector") {
        GameInstance.GetStatPoolsSystem(fx.game).RequestChangingStatPoolValue(Cast<StatsObjectID>(fx.player.GetEntityID()), gamedataStatPoolType.Health, 3.0, null, false, true);
      }
      RLBoonEffects.Note(fx, n"Deflector", 0.0);
    }
    if IsDefined(foe) && IsDefined(body) && foe.quickhackTime > 0.0 && RLArmModEffects.Has(fx, n"LogicBomb") {
      let big = RLArmModEffects.Overclocked(fx, n"LogicBomb");
      RLBoonEffects.Note(fx, n"LogicBomb", 0.0);
      RLKeywords.Tag(fx, "LOGIC BOMB", n"MainColors.Green");
      RLKeywords.Blast(fx, body.GetWorldPosition(), big ? 4.5 : 3.0, body, 0);
      if big {
        for other in RLKeywords.EnemiesNear(fx, body.GetWorldPosition(), 4.5) {
          RLKeywords.Shock(fx, other);
        }
      }
    }
    if quickhack && RLArmModEffects.Has(fx, n"Ghost") {
      let seconds = RLArmModEffects.Overclocked(fx, n"Ghost") ? 2.0 : 1.0;
      fx.combat.untouchableUntil = MaxF(fx.combat.untouchableUntil, fx.now + seconds);
      RLKeywords.Tag(fx, "GHOST", n"MainColors.Green");
      RLBoonEffects.Note(fx, n"Ghost", 0.0);
    }
  }
}

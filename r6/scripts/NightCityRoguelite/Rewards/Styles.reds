// -----------------------------------------------------------------------------
// Night City Roguelite - styles
// -----------------------------------------------------------------------------
// Every reward feeds a style (Teamfight Tactics' traits), so a run full of
// choices still adds up to one build you can see:
//
//   points   an equipped weapon or arm cyberware of the style counts 2; every
//            perk, effect and weapon effect (for the main's style) counts 1; a
//            cyberdeck counts 2 for Netrunner, quickhacks 1 each (up to 3),
//            a grenade 1 for Demolitions; a finished gig adds 2.
//   ranks    I at 3 points, II at 6, III at 9.
//   bonus    hits of the style deal +10% / +20% / +35% (the best style a hit
//            belongs to counts, they don't stack); rank III adds the style's
//            signature (RLStyles.OnHit / OnKill).
//
// Points are recounted after every pick and when a fight starts, so the hit
// hooks only read the cached ranks.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLStyle {
  public static func Blades() -> Int32 = 0
  public static func Brawler() -> Int32 = 1
  public static func Monowire() -> Int32 = 2
  public static func Gunslinger() -> Int32 = 3
  public static func Heavy() -> Int32 = 4
  public static func Rifles() -> Int32 = 5
  public static func Marksman() -> Int32 = 6
  public static func Netrunner() -> Int32 = 7
  public static func Smart() -> Int32 = 8
  public static func Tech() -> Int32 = 9
  public static func Demolitions() -> Int32 = 10
  public static func Ninja() -> Int32 = 11

  public static func Count() -> Int32 = 12

  public static func Name(style: Int32) -> String {
    switch style {
      case 0: return "BLADES";
      case 1: return "BRAWLER";
      case 2: return "MONOWIRE";
      case 3: return "GUNSLINGER";
      case 4: return "HEAVY";
      case 5: return "RIFLES";
      case 6: return "MARKSMAN";
      case 7: return "NETRUNNER";
      case 8: return "SMART";
      case 9: return "TECH";
      case 10: return "DEMOLITIONS";
      case 11: return "NINJA";
    }
    return "";
  }

  // The rank III signature, for cards and the terminal.
  public static func Signature(style: Int32) -> String {
    switch style {
      case 0: return "Blade kills slow time for a second.";
      case 1: return "Blunt and fist kills send out a shockwave.";
      case 2: return "Monowire hits electrocute; kills restore RAM.";
      case 3: return "Headshot kills: your next 3 hits deal double damage.";
      case 4: return "Kills blow enemies apart, hitting those nearby.";
      case 5: return "Hits on the same target ramp up to +45% damage.";
      case 6: return "+60% damage beyond 20 m.";
      case 7: return "Quickhack kills restore RAM and jolt enemies nearby.";
      case 8: return "Kills mark enemies nearby: +25% damage taken for 5 s.";
      case 9: return "Kills electrocute enemies nearby.";
      case 10: return "Every 5 kills recharge a grenade.";
      case 11: return "Throwing kills make you invisible for a moment.";
    }
    return "";
  }

  // The style a build tag feeds (-1 for support tags: survival, mobility,
  // gear, chrome).
  public static func FromTag(tag: CName) -> Int32 {
    switch tag {
      case n"blade": return RLStyle.Blades();
      case n"blunt": return RLStyle.Brawler();
      case n"monowire": return RLStyle.Monowire();
      case n"handgun":
      case n"dual": return RLStyle.Gunslinger();
      case n"shotgun":
      case n"lmg": return RLStyle.Heavy();
      case n"rifle": return RLStyle.Rifles();
      case n"precision": return RLStyle.Marksman();
      case n"netrunner": return RLStyle.Netrunner();
      case n"smart": return RLStyle.Smart();
      case n"tech": return RLStyle.Tech();
      case n"explosive": return RLStyle.Demolitions();
      case n"throwable":
      case n"stealth": return RLStyle.Ninja();
    }
    return -1;
  }

  // Melee boons (tag "melee") feed both melee styles.
  public static func FromTags(tags: array<CName>) -> array<Int32> {
    let styles: array<Int32>;
    for tag in tags {
      if Equals(tag, n"melee") {
        RLStyle.AddUnique(styles, RLStyle.Blades());
        RLStyle.AddUnique(styles, RLStyle.Brawler());
      } else {
        let style = RLStyle.FromTag(tag);
        if style >= 0 {
          RLStyle.AddUnique(styles, style);
        }
      }
    }
    return styles;
  }

  public static func AddUnique(out styles: array<Int32>, style: Int32) {
    if style >= 0 && !ArrayContains(styles, style) {
      ArrayPush(styles, style);
    }
  }
}

public abstract class RLStyles {
  // Signature (the terminal) brings rank III a point sooner.
  public static func RankFor(points: Int32) -> Int32 {
    if points >= (RLTerminal.Has(n"Specialist", 2) ? 8 : 9) {
      return 3;
    }
    if points >= 6 {
      return 2;
    }
    return points >= 3 ? 1 : 0;
  }

  public static func RankName(rank: Int32) -> String {
    switch rank {
      case 1: return "I";
      case 2: return "II";
      case 3: return "III";
    }
    return "";
  }

  // Points for the next rank (0 at rank III).
  public static func NextRankAt(points: Int32) -> Int32 {
    if points < 3 {
      return 3;
    }
    if points < 6 {
      return 6;
    }
    return points < 9 ? 9 : 0;
  }

  public static func DamageBonus(rank: Int32) -> Float {
    switch rank {
      case 1: return 0.10;
      case 2: return 0.20;
      case 3: return 0.35;
    }
    return 0.0;
  }

  public static func Points(run: ref<RLRunState>, style: Int32) -> Int32 {
    return IsDefined(run) && style >= 0 && style < ArraySize(run.stylePoints) ? run.stylePoints[style] : 0;
  }

  public static func Rank(run: ref<RLRunState>, style: Int32) -> Int32 = RLStyles.RankFor(RLStyles.Points(run, style))

  // --- Counting ----------------------------------------------------------------------------

  // Recounts every style's points from what V holds; announces new ranks.
  public static func Refresh(player: ref<PlayerPuppet>, run: ref<RLRunState>, announce: Bool) {
    if !IsDefined(player) || !IsDefined(run) {
      return;
    }
    let points: array<Int32>;
    let i = 0;
    while i < RLStyle.Count() {
      ArrayPush(points, 0);
      i += 1;
    }
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    let quickhacks = 0;
    for item in items {
      if IsDefined(item) {
        let itemID = item.GetID();
        let equipped = IsDefined(equipment) && equipment.IsEquipped(itemID);
        let itemType = RPGManager.GetItemType(itemID);
        if Equals(RPGManager.GetItemCategory(itemID), gamedataItemCategory.Weapon) {
          // Fists and the default handgun are always there: they don't count.
          if equipped && RLWeapons.IsRealWeapon(itemID) {
            for style in RLStyles.ItemStyles(itemID) {
              points[style] += 2;
            }
          }
        } else if Equals(itemType, gamedataItemType.Prt_Program) {
          quickhacks += 1;
        } else if equipped && item.HasTag(n"Cyberdeck") {
          points[RLStyle.Netrunner()] += 2;
        } else if equipped && Equals(itemType, gamedataItemType.Gad_Grenade) {
          points[RLStyle.Demolitions()] += 1;
        } else if equipped {
          for style in RLStyles.ItemStyles(itemID) {
            points[style] += 2;
          }
        }
      }
    }
    points[RLStyle.Netrunner()] += Min(quickhacks, 3);
    let data = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(data) {
      for def in RLPerkCatalog.All() {
        if RLPerkCatalog.IsOwned(data, def.perk) {
          for style in RLStyle.FromTags(def.tags) {
            points[style] += 1;
          }
        }
      }
    }
    for state in run.boons {
      let boon = RLBoons.Get(state.id);
      if IsDefined(boon) {
        for style in RLStyle.FromTags(boon.tags) {
          points[style] += 1;
        }
      }
    }
    // Weapon effects count for the main weapon's style, and Specialist (the
    // terminal) starts it two points up.
    let mainStyle = RLWeapons.MainStyle(run);
    if mainStyle >= 0 {
      points[mainStyle] += RLBoons.WeaponEffectCount(run) + (RLTerminal.Has(n"Specialist", 1) ? 2 : 0);
    }
    if run.gigDone && run.gigStyle >= 0 {
      points[run.gigStyle] += 2;
    }
    if announce && ArraySize(run.stylePoints) == RLStyle.Count() {
      i = 0;
      while i < RLStyle.Count() {
        let before = RLStyles.RankFor(run.stylePoints[i]);
        let after = RLStyles.RankFor(points[i]);
        if after > before {
          RLNotify(player.GetGame(), RLStyle.Name(i) + " " + RLStyles.RankName(after) + (after == 3 ? " - " + RLStyle.Signature(i) : ""), 5.0);
          RLLog(s"Style \(RLStyle.Name(i)) reached rank \(after) (\(points[i]) points).");
        }
        i += 1;
      }
    }
    run.stylePoints = points;
  }

  // The styles a weapon or arm cyberware belongs to: its class, plus Smart or
  // Tech for those evolutions.
  public static func ItemStyles(itemID: ItemID) -> array<Int32> {
    let styles: array<Int32>;
    switch RPGManager.GetItemType(itemID) {
      case gamedataItemType.Cyb_MantisBlades:
        ArrayPush(styles, RLStyle.Blades());
        return styles;
      case gamedataItemType.Cyb_StrongArms:
        ArrayPush(styles, RLStyle.Brawler());
        return styles;
      case gamedataItemType.Cyb_NanoWires:
        ArrayPush(styles, RLStyle.Monowire());
        return styles;
      case gamedataItemType.Cyb_Launcher:
        ArrayPush(styles, RLStyle.Demolitions());
        return styles;
    }
    if !Equals(RPGManager.GetItemCategory(itemID), gamedataItemCategory.Weapon) {
      return styles;
    }
    RLStyle.AddUnique(styles, RLWeapons.FamilyStyle(RLWeapons.FamilyOf(RPGManager.GetItemType(itemID))));
    switch RPGManager.GetWeaponEvolution(itemID) {
      case gamedataWeaponEvolution.Smart:
        RLStyle.AddUnique(styles, RLStyle.Smart());
        break;
      case gamedataWeaponEvolution.Tech:
        RLStyle.AddUnique(styles, RLStyle.Tech());
        break;
    }
    return styles;
  }

  // The styles a hit belongs to: how it landed (quickhack, explosion,
  // monowire, throw) or the weapon that landed it.
  public static func HitStyles(hitEvent: ref<gameHitEvent>) -> array<Int32> {
    let styles: array<Int32>;
    let attack = hitEvent.attackData;
    if attack.HasFlag(hitFlag.QuickHack) || Equals(attack.GetAttackType(), gamedataAttackType.Hack) {
      ArrayPush(styles, RLStyle.Netrunner());
      return styles;
    }
    switch attack.GetAttackType() {
      case gamedataAttackType.Explosion:
      case gamedataAttackType.PressureWave:
        ArrayPush(styles, RLStyle.Demolitions());
        return styles;
      case gamedataAttackType.WhipAttack:
      case gamedataAttackType.ChargedWhipAttack:
        ArrayPush(styles, RLStyle.Monowire());
        return styles;
      case gamedataAttackType.Thrown:
        ArrayPush(styles, RLStyle.Ninja());
        return styles;
    }
    let weapon = attack.GetWeapon();
    if IsDefined(weapon) {
      return RLStyles.ItemStyles(weapon.GetItemID());
    }
    return styles;
  }

  // The best rank among the styles (for the damage bonus).
  public static func BestRank(run: ref<RLRunState>, styles: array<Int32>) -> Int32 {
    let best = 0;
    for style in styles {
      best = Max(best, RLStyles.Rank(run, style));
    }
    return best;
  }

  public static func HasSignature(run: ref<RLRunState>, styles: array<Int32>, style: Int32) -> Bool {
    return ArrayContains(styles, style) && RLStyles.Rank(run, style) >= 3;
  }

  // --- Display ------------------------------------------------------------------------------

  // "BLADES II (7) · NETRUNNER I (3)": up to `count` styles with a rank, best first.
  public static func Summary(run: ref<RLRunState>, count: Int32) -> String {
    if !IsDefined(run) || ArraySize(run.stylePoints) == 0 {
      return "";
    }
    let used: array<Int32>;
    let text = "";
    let shown = 0;
    while shown < count {
      let best = -1;
      let i = 0;
      while i < ArraySize(run.stylePoints) {
        if !ArrayContains(used, i) && run.stylePoints[i] >= 3 && (best < 0 || run.stylePoints[i] > run.stylePoints[best]) {
          best = i;
        }
        i += 1;
      }
      if best < 0 {
        break;
      }
      ArrayPush(used, best);
      text += (StrLen(text) > 0 ? "  ·  " : "") + RLStyle.Name(best) + " " + RLStyles.RankName(RLStyles.Rank(run, best)) + s" (\(run.stylePoints[best]))";
      shown += 1;
    }
    return text;
  }

  // The card line for an offer's styles: "BLADES 4 > 5" for each style it feeds.
  public static func OfferLine(run: ref<RLRunState>, tags: array<CName>) -> String {
    let text = "";
    for style in RLStyle.FromTags(tags) {
      let points = RLStyles.Points(run, style);
      text += (StrLen(text) > 0 ? "   " : "") + RLStyle.Name(style) + s" \(points) > \(points + 1)";
    }
    return text;
  }

  // True when the offer feeds a style V already has a rank in.
  public static func IsSynergy(run: ref<RLRunState>, tags: array<CName>) -> Bool {
    for style in RLStyle.FromTags(tags) {
      if RLStyles.Rank(run, style) >= 1 {
        return true;
      }
    }
    return false;
  }

  // Up to `count` styles with points, highest first (telemetry).
  public static func Telemetry(run: ref<RLRunState>) -> String {
    let text = "";
    let i = 0;
    while i < ArraySize(run.stylePoints) {
      if run.stylePoints[i] > 0 {
        text += (StrLen(text) > 0 ? "," : "") + RLStyle.Name(i) + ":" + IntToString(run.stylePoints[i]);
      }
      i += 1;
    }
    return text;
  }

  // --- Signatures ---------------------------------------------------------------------------

  // Rank III effects when a hit lands; returns a damage multiplier.
  public static func OnHit(run: ref<RLRunState>, combat: ref<RLCombatState>, context: ref<RLHitContext>, styles: array<Int32>) -> Float {
    let factor = 1.0;
    let targetID = context.target.GetEntityID();
    if RLStyles.HasSignature(run, styles, RLStyle.Rifles()) {
      factor *= 1.0 + MinF(0.03 * Cast<Float>(combat.RampCount(targetID)), 0.45);
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Marksman()) && context.distance > 20.0 {
      factor *= 1.6;
    }
    if combat.gunslingerShots > 0 && ArrayContains(styles, RLStyle.Gunslinger()) {
      combat.gunslingerShots -= 1;
      factor *= 2.0;
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Monowire()) && RandF() < 0.5 {
      StatusEffectHelper.ApplyStatusEffect(context.target, t"BaseStatusEffect.Electrocuted", context.player.GetEntityID());
    }
    return factor;
  }

  // Rank III effects when an enemy dies; `styles` are those of the killing hit.
  public static func OnKill(run: ref<RLRunState>, combat: ref<RLCombatState>, player: ref<PlayerPuppet>, body: ref<ScriptedPuppet>, styles: array<Int32>, flags: Int32) {
    let game = player.GetGame();
    let now = RLBoonEffects.Now(game);
    let playerID = Cast<StatsObjectID>(player.GetEntityID());
    let pools = GameInstance.GetStatPoolsSystem(game);
    let position = IsDefined(body) ? body.GetWorldPosition() : player.GetWorldPosition();
    if RLStyles.HasSignature(run, styles, RLStyle.Blades()) && combat.sigSlowUntil <= now {
      combat.sigSlowUntil = now + 3.0;
      GameInstance.GetTimeSystem(game).SetTimeDilation(n"NCRogueliteBlades", 0.3, 1.0, n"Linear", n"Linear");
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Brawler()) && IsDefined(body) {
      RLExplosions.Blast(player, position, t"Attacks.CyberwareExplosion", 5.0, body);
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Monowire()) {
      pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Memory, 2.0, null, false, false);
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Gunslinger()) && RLHitFlag.Has(flags, RLHitFlag.Headshot()) {
      combat.gunslingerShots = 3;
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Heavy()) && IsDefined(body) && RandF() < 0.35 {
      RLExplosions.Blast(player, position, t"Attacks.CyberwareExplosion", 4.0, body);
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Netrunner()) {
      pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Memory, 3.0, null, false, false);
      RLStyles.ApplyNearby(game, player, position, 6.0, t"BaseStatusEffect.Electrocuted");
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Tech()) {
      RLStyles.ApplyNearby(game, player, position, 6.0, t"BaseStatusEffect.Electrocuted");
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Smart()) {
      let system = RogueliteSystem.Get(game);
      if IsDefined(system) {
        for enemy in system.EnemiesNear(position, 10.0) {
          combat.Mark(enemy.GetEntityID(), now + 5.0, 0.25);
        }
      }
    }
    if RLStyles.Rank(run, RLStyle.Demolitions()) >= 3 {
      combat.demoKills += 1;
      if combat.demoKills >= 5 {
        combat.demoKills = 0;
        ConsumablesChargesHelper.RefreshAmountOfCharges(game, gamedataStatPoolType.GrenadesCharges, 1);
      }
    }
    if RLStyles.HasSignature(run, styles, RLStyle.Ninja()) {
      StatusEffectHelper.ApplyStatusEffect(player, t"BaseStatusEffect.OpticalCamoPlayerBuffRare");
    }
  }

  // A status effect on every arena enemy within `radius` of a spot.
  public static func ApplyNearby(game: GameInstance, player: ref<PlayerPuppet>, position: Vector4, radius: Float, effect: TweakDBID) {
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) {
      return;
    }
    for enemy in system.EnemiesNear(position, radius) {
      StatusEffectHelper.ApplyStatusEffect(enemy, effect, player.GetEntityID());
    }
  }
}

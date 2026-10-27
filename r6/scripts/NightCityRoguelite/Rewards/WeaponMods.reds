// -----------------------------------------------------------------------------
// Night City Roguelite - weapon mods
// -----------------------------------------------------------------------------
// The mod's own weapon mods, Hades' Daedalus hammers for Cyberpunk: each one
// changes how one weapon plays. A weapon has two slots (iconics three); mods
// come from Armory and Workshop screens, level-ups and the Fixer, and stay
// with the weapon when it evolves (Rewards/Weapons.reds).
//
//   any weapon   Executioner, Incendiary, Shock, Toxic
//   pistols      Quickdraw, Deadshot, Double Tap
//   rifles       Sustained Fire, Hollow Point, Tracer
//   heavy        Point Blank, Shrapnel, Slug
//   precision    Long Shot, Pierce, Spotter
//   blades       Momentum, Bloodletting, Vampiric Edge
//   blunt        Haymaker, Concussive, Rebound
//
// Each mod also counts 1 toward its weapon's style (Rewards/Styles.reds).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLModDef {
  public let id: CName;
  public let name: String;
  // RLWeaponFamily; None = any weapon.
  public let family: Int32;
  public let text: String;
}

// What the hit hook knows about a hit, for the mods.
public class RLHitContext {
  public let player: wref<PlayerPuppet>;
  public let target: wref<ScriptedPuppet>;
  public let hitEvent: ref<gameHitEvent>;
  public let flags: Int32;
  public let now: Float;
  public let distance: Float;
  public let targetHealth: Float;
  public let firstHit: Bool;
  public let recentHit: Bool;
  public let isBoss: Bool;
  public let isElite: Bool;
  public let affixes: Int32;
}

public abstract class RLWeaponMods {
  public static func All() -> array<ref<RLModDef>> {
    let list: array<ref<RLModDef>>;
    RLWeaponMods.Add(list, n"Executioner", "Executioner", 0, "+50% damage to enemies below 35% health.");
    RLWeaponMods.Add(list, n"Incendiary", "Incendiary", 0, "Hits have a 15% chance to set enemies on fire.");
    RLWeaponMods.Add(list, n"Shock", "Shock", 0, "Hits have a 15% chance to electrocute.");
    RLWeaponMods.Add(list, n"Toxic", "Toxic", 0, "Hits have a 15% chance to poison.");
    RLWeaponMods.Add(list, n"Quickdraw", "Quickdraw", 1, "Your first hit on each enemy deals +60% damage.");
    RLWeaponMods.Add(list, n"Deadshot", "Deadshot", 1, "Headshots deal +40% damage.");
    RLWeaponMods.Add(list, n"DoubleTap", "Double Tap", 1, "+25% damage to an enemy you hit in the last second.");
    RLWeaponMods.Add(list, n"SustainedFire", "Sustained Fire", 2, "Each hit on the same target adds +2% damage, up to +30%.");
    RLWeaponMods.Add(list, n"HollowPoint", "Hollow Point", 2, "+30% damage to regular enemies.");
    RLWeaponMods.Add(list, n"Tracer", "Tracer", 2, "Hits mark the enemy: +15% damage from everything for 3 s.");
    RLWeaponMods.Add(list, n"PointBlank", "Point Blank", 3, "+50% damage within 6 m.");
    RLWeaponMods.Add(list, n"Shrapnel", "Shrapnel", 3, "Kills have a 30% chance to blow up the body.");
    RLWeaponMods.Add(list, n"Slug", "Slug", 3, "+40% damage to elites and bosses.");
    RLWeaponMods.Add(list, n"LongShot", "Long Shot", 4, "+2% damage per meter beyond 10 m, up to +50%.");
    RLWeaponMods.Add(list, n"Pierce", "Pierce", 4, "+15% damage and ignores Armored.");
    RLWeaponMods.Add(list, n"Spotter", "Spotter", 4, "Headshots stun the enemy.");
    RLWeaponMods.Add(list, n"Momentum", "Momentum", 5, "Each hit adds +5% damage for 3 s, up to +40%.");
    RLWeaponMods.Add(list, n"Bloodletting", "Bloodletting", 5, "Hits have a 25% chance to cause bleeding.");
    RLWeaponMods.Add(list, n"VampiricEdge", "Vampiric Edge", 5, "Kills heal 4% health.");
    RLWeaponMods.Add(list, n"Haymaker", "Haymaker", 6, "Strong attacks deal +60% damage.");
    RLWeaponMods.Add(list, n"Concussive", "Concussive", 6, "Hits have a 20% chance to stun.");
    RLWeaponMods.Add(list, n"Rebound", "Rebound", 6, "Kills restore 30% stamina.");
    return list;
  }

  public static func Get(id: CName) -> ref<RLModDef> {
    for def in RLWeaponMods.All() {
      if Equals(def.id, id) {
        return def;
      }
    }
    return null;
  }

  // Mods that fit a weapon and aren't on it yet.
  public static func Candidates(run: ref<RLRunState>, itemID: ItemID) -> array<ref<RLModDef>> {
    let result: array<ref<RLModDef>>;
    let family = RLWeapons.FamilyOf(RPGManager.GetItemType(itemID));
    if family == RLWeaponFamily.None() {
      return result;
    }
    for def in RLWeaponMods.All() {
      if (def.family == 0 || def.family == family) && !RLWeapons.HasMod(run, itemID, def.id)
        && !ArrayContains(run.banished, "mod:" + NameToString(def.id)) {
        ArrayPush(result, def);
      }
    }
    return result;
  }

  // Family mods are offered twice as often as the universal ones.
  public static func PickFor(run: ref<RLRunState>, itemID: ItemID, exclude: array<CName>) -> ref<RLModDef> {
    let candidates: array<ref<RLModDef>>;
    let weights: array<Int32>;
    let total = 0;
    for def in RLWeaponMods.Candidates(run, itemID) {
      if !ArrayContains(exclude, def.id) {
        ArrayPush(candidates, def);
        let weight = def.family == 0 ? 1 : 2;
        ArrayPush(weights, weight);
        total += weight;
      }
    }
    if total == 0 {
      return null;
    }
    let roll = RandRange(0, total);
    let i = 0;
    while i < ArraySize(candidates) - 1 && roll >= weights[i] {
      roll -= weights[i];
      i += 1;
    }
    return candidates[i];
  }

  // A card for a mod on one of V's weapons.
  public static func Offer(run: ref<RLRunState>, itemID: ItemID, def: ref<RLModDef>) -> ref<RLOffer> {
    let offer = new RLOffer();
    offer.kind = RLOfferKind.WeaponMod;
    offer.itemID = itemID;
    offer.record = ItemID.GetTDBID(itemID);
    offer.mod = def.id;
    offer.title = def.name;
    let slots = RLWeapons.ModSlots(itemID);
    let used = RLWeapons.ModCount(run, itemID);
    offer.subtitle = s"MOD \(used + 1)/\(slots) - " + RLRewards.ItemName(offer.record);
    offer.description = def.text;
    offer.step = 6;
    offer.excitement = 1;
    let tag = RLWeapons.FamilyTag(RLWeapons.FamilyOf(RPGManager.GetItemType(itemID)));
    if IsNameValid(tag) {
      ArrayPush(offer.tags, tag);
    }
    return offer;
  }

  // Equipped weapons with a free mod slot (and their candidates).
  public static func Moddable(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> array<ItemID> {
    let result: array<ItemID>;
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemList(player, items);
    for item in items {
      if IsDefined(item) && IsDefined(equipment) {
        let itemID = item.GetID();
        if RLWeapons.IsRealWeapon(itemID) && equipment.IsEquipped(itemID) && RLWeapons.ModCount(run, itemID) < RLWeapons.ModSlots(itemID) {
          let candidates = RLWeaponMods.Candidates(run, itemID);
          if ArraySize(candidates) > 0 {
            ArrayPush(result, itemID);
          }
        }
      }
    }
    return result;
  }

  // Up to `count` mod cards for V's weapons (different mods, spread over the
  // weapons when there are several).
  public static func Offers(player: ref<PlayerPuppet>, run: ref<RLRunState>, count: Int32) -> array<ref<RLOffer>> {
    let offers: array<ref<RLOffer>>;
    let weapons = RLWeaponMods.Moddable(player, run);
    let used: array<CName>;
    let tries = 0;
    while ArraySize(offers) < count && ArraySize(weapons) > 0 && tries < 12 {
      let itemID = weapons[tries % ArraySize(weapons)];
      let def = RLWeaponMods.PickFor(run, itemID, used);
      if IsDefined(def) {
        ArrayPush(used, def.id);
        ArrayPush(offers, RLWeaponMods.Offer(run, itemID, def));
      }
      tries += 1;
    }
    return offers;
  }

  public static func Install(run: ref<RLRunState>, itemID: ItemID, mod: CName) {
    let state = RLWeapons.StateOrNew(run, itemID);
    if !ArrayContains(state.mods, mod) && ArraySize(state.mods) < RLWeapons.ModSlots(itemID) {
      ArrayPush(state.mods, mod);
    }
  }

  // --- Effects -----------------------------------------------------------------------------

  // Multiplier on a hit landed with a modded weapon; also fires on-hit procs.
  public static func OnHit(run: ref<RLRunState>, combat: ref<RLCombatState>, context: ref<RLHitContext>) -> Float {
    let weapon = context.hitEvent.attackData.GetWeapon();
    if !IsDefined(weapon) {
      return 1.0;
    }
    let state = RLWeapons.State(run, weapon.GetItemID());
    if !IsDefined(state) || ArraySize(state.mods) == 0 {
      return 1.0;
    }
    let factor = 1.0;
    let target = context.target;
    let targetID = target.GetEntityID();
    let playerID = context.player.GetEntityID();
    let effect = Equals(context.hitEvent.attackData.GetAttackType(), gamedataAttackType.Effect);
    for mod in state.mods {
      switch mod {
        case n"Executioner":
          if context.targetHealth < 35.0 { factor *= 1.5; }
          break;
        case n"Incendiary":
          if !effect && RandF() < 0.15 { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Burning", playerID); }
          break;
        case n"Shock":
          if !effect && RandF() < 0.15 { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Electrocuted", playerID); }
          break;
        case n"Toxic":
          if !effect && RandF() < 0.15 { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Poisoned", playerID); }
          break;
        case n"Quickdraw":
          if context.firstHit { factor *= 1.6; }
          break;
        case n"Deadshot":
          if RLHitFlag.Has(context.flags, RLHitFlag.Headshot()) { factor *= 1.4; }
          break;
        case n"DoubleTap":
          if context.recentHit { factor *= 1.25; }
          break;
        case n"SustainedFire":
          factor *= 1.0 + MinF(0.02 * Cast<Float>(combat.RampCount(targetID)), 0.30);
          break;
        case n"HollowPoint":
          if !context.isBoss && !context.isElite { factor *= 1.3; }
          break;
        case n"Tracer":
          combat.Mark(targetID, context.now + 3.0, 0.15);
          break;
        case n"PointBlank":
          if context.distance <= 6.0 { factor *= 1.5; }
          break;
        case n"Slug":
          if context.isBoss || context.isElite { factor *= 1.4; }
          break;
        case n"LongShot":
          factor *= 1.0 + ClampF(0.02 * (context.distance - 10.0), 0.0, 0.5);
          break;
        case n"Pierce":
          factor *= 1.15;
          if RLAffixes.Has(context.affixes, RLAffix.Armored()) { factor /= RLAffixes.DamageTakenFactor(context.affixes); }
          break;
        case n"Spotter":
          if !effect && RLHitFlag.Has(context.flags, RLHitFlag.Headshot()) { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Stun", playerID); }
          break;
        case n"Momentum":
          factor *= 1.0 + 0.05 * Cast<Float>(combat.AddMomentum(context.now));
          break;
        case n"Bloodletting":
          if !effect && RandF() < 0.25 { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Bleeding", playerID); }
          break;
        case n"Haymaker":
          if Equals(context.hitEvent.attackData.GetAttackType(), gamedataAttackType.StrongMelee) { factor *= 1.6; }
          break;
        case n"Concussive":
          if !effect && RandF() < 0.2 { StatusEffectHelper.ApplyStatusEffect(target, t"BaseStatusEffect.Stun", playerID); }
          break;
      }
    }
    return factor;
  }

  // Kill procs of the mods on the weapon that landed the killing hit.
  public static func OnKill(run: ref<RLRunState>, player: ref<PlayerPuppet>, weapon: ItemID, body: ref<ScriptedPuppet>) {
    let state = RLWeapons.State(run, weapon);
    if !IsDefined(state) {
      return;
    }
    let pools = GameInstance.GetStatPoolsSystem(player.GetGame());
    let playerID = Cast<StatsObjectID>(player.GetEntityID());
    for mod in state.mods {
      switch mod {
        case n"Shrapnel":
          if IsDefined(body) && RandF() < 0.3 { RLExplosions.Blast(player, body.GetWorldPosition(), t"Attacks.CyberwareExplosion", 4.0, body); }
          break;
        case n"VampiricEdge":
          pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Health, 4.0, null, false, true);
          break;
        case n"Rebound":
          pools.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Stamina, 30.0, null, false, true);
          break;
      }
    }
  }

  private static func Add(out list: array<ref<RLModDef>>, id: CName, const name: String, family: Int32, const text: String) {
    let def = new RLModDef();
    def.id = id;
    def.name = name;
    def.family = family;
    def.text = text;
    ArrayPush(list, def);
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - boons
// -----------------------------------------------------------------------------
// Run-only bonuses from the patrons (Rewards/Patrons.reds), Hades-style:
//
//   Core boons   five per patron. Each is taken once and then offered again as
//                an upgrade: COMMON > RARE > EPIC > HEROIC, every step a
//                stronger value (the text shows it, e.g. "+8% crit chance").
//   Legendary    one per patron, offered once V holds three of its boons.
//   Duo          shared by two patrons, offered once V holds a boon from each.
//
// Effects are either stat modifiers on V (applied here, swapped on upgrade,
// all removed when the run ends) or scripted (Rewards/BoonEffects.reds reads
// the boon's value through RLBoons.Value). Every boon also shows on the HUD
// buff bar (NCRoguelite.Boon_<id>, r6/tweaks/NightCityRoguelite/boons.yaml).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLBoonKind {
  Core = 0,
  Legendary = 1,
  Duo = 2,
}

public class RLBoonDef {
  public let id: CName;
  public let patron: CName;
  // Duo boons: the second patron.
  public let partner: CName;
  public let kind: RLBoonKind;
  public let name: String;
  // "{v}" is replaced by the value for the rarity.
  public let text: String;
  // One value per rarity (COMMON, RARE, EPIC, HEROIC); boons that don't grow
  // have a single value.
  public let values: array<Float>;
  public let tags: array<CName>;
}

// A boon V holds this run.
public class RLBoonState {
  public let id: CName;
  public let rarity: Int32;
  // Uses left (Second Wind).
  public let charges: Int32;
  public let mods: array<ref<gameStatModifierData>>;
}

public abstract class RLBoons {
  public static func MaxRarity() -> Int32 = 3

  public static func RarityName(rarity: Int32) -> String {
    switch rarity {
      case 1: return "RARE";
      case 2: return "EPIC";
      case 3: return "HEROIC";
    }
    return "COMMON";
  }

  // Quality step for the card colour (Common grey .. Legendary orange).
  public static func RarityStep(rarity: Int32) -> Int32 {
    switch rarity {
      case 1: return 4;
      case 2: return 6;
      case 3: return 8;
    }
    return 0;
  }

  // --- Catalogue -----------------------------------------------------------------------

  public static func All() -> array<ref<RLBoonDef>> = RogueliteService.Get().GetBoonCatalog()

  public static func Build() -> array<ref<RLBoonDef>> {
    let list: array<ref<RLBoonDef>>;
    // Arasaka - precision
    RLBoons.Core(list, n"Kenshin", n"Arasaka", "Kenshin Protocol", "+{v}% crit chance.", [5.0, 8.0, 11.0, 14.0], [n"precision"]);
    RLBoons.Core(list, n"Saburo", n"Arasaka", "Saburo's Gaze", "+{v}% crit damage.", [20.0, 30.0, 40.0, 50.0], [n"precision"]);
    RLBoons.Core(list, n"Hanako", n"Arasaka", "Hanako's Favor", "Headshots deal +{v}% damage.", [20.0, 30.0, 40.0, 50.0], [n"precision"]);
    RLBoons.Core(list, n"Bushido", n"Arasaka", "Bushido", "Hits on enemies at full health deal +{v}% damage.", [40.0, 60.0, 80.0, 100.0], [n"precision"]);
    RLBoons.Core(list, n"Sandevistan", n"Arasaka", "Sandevistan Echo", "Headshot kills slow time for {v} s.", [1.0, 1.5, 2.0, 2.5], [n"precision"]);
    RLBoons.Legendary(list, n"ShogunsEdge", n"Arasaka", "Shogun's Edge", "Critical hits on enemies below 25% health finish them (not bosses).", [n"precision"]);
    // Militech - firepower
    RLBoons.Core(list, n"HardenedRounds", n"Militech", "Hardened Rounds", "Ranged attacks deal +{v}% damage.", [10.0, 15.0, 20.0, 25.0], [n"rifle"]);
    RLBoons.Core(list, n"KillChain", n"Militech", "Kill Chain", "Kills restore {v}% of your ammo.", [5.0, 8.0, 11.0, 14.0], [n"rifle"]);
    RLBoons.Core(list, n"Ordnance", n"Militech", "Ordnance Specialist", "Explosions deal +{v}% damage.", [25.0, 40.0, 55.0, 70.0], [n"explosive"]);
    RLBoons.Core(list, n"QuickFuse", n"Militech", "Quick Fuse", "+{v}% grenade recharge speed.", [25.0, 35.0, 45.0, 55.0], [n"explosive"]);
    RLBoons.Core(list, n"Suppressive", n"Militech", "Suppressive Fire", "Enemies you shoot deal {v}% less damage for 3 s.", [15.0, 20.0, 25.0, 30.0], [n"rifle"]);
    RLBoons.Legendary(list, n"KillCount", n"Militech", "Kill Count", "Every kill in a fight adds +2% ranged damage, up to +40%.", [n"rifle"]);
    // Voodoo Boys - netrunning
    RLBoons.Core(list, n"SynapticOverclock", n"VoodooBoys", "Synaptic Overclock", "+{v} max RAM.", [2.0, 3.0, 4.0, 5.0], [n"netrunner"]);
    RLBoons.Core(list, n"GhostProtocol", n"VoodooBoys", "Ghost Protocol", "Recover 1 RAM every {v} s in fights.", [6.0, 5.0, 4.0, 3.0], [n"netrunner"]);
    RLBoons.Core(list, n"BlackIce", n"VoodooBoys", "Black ICE", "Quickhacks deal +{v}% damage.", [20.0, 30.0, 40.0, 50.0], [n"netrunner"]);
    RLBoons.Core(list, n"ContagionSeed", n"VoodooBoys", "Contagion Seed", "Quickhacks spread to {v} more target(s).", [1.0, 2.0, 3.0, 4.0], [n"netrunner"]);
    RLBoons.Core(list, n"DataLeech", n"VoodooBoys", "Data Leech", "Kills restore {v} RAM.", [1.0, 2.0, 3.0, 4.0], [n"netrunner"]);
    RLBoons.Legendary(list, n"LoasEmbrace", n"VoodooBoys", "Loa's Embrace", "Quickhack kills restore all your RAM.", [n"netrunner"]);
    // Maelstrom - brutality
    RLBoons.Core(list, n"Bloodlust", n"Maelstrom", "Bloodlust", "Kills heal {v}% health.", [3.0, 4.0, 5.0, 6.0], [n"melee"]);
    RLBoons.Core(list, n"ChromeFist", n"Maelstrom", "Chrome Fist", "Melee attacks deal +{v}% damage.", [20.0, 30.0, 40.0, 50.0], [n"melee"]);
    RLBoons.Core(list, n"RedMist", n"Maelstrom", "Red Mist", "Below 40% health, deal +{v}% damage.", [20.0, 30.0, 40.0, 50.0], [n"melee"]);
    RLBoons.Core(list, n"SubdermalPlating", n"Maelstrom", "Scrap Plating", "+{v} armor.", [40.0, 60.0, 80.0, 100.0], [n"survival"]);
    RLBoons.Core(list, n"VolatileKills", n"Maelstrom", "Volatile Kills", "Kills have a {v}% chance to blow up the body.", [10.0, 15.0, 20.0, 25.0], [n"explosive"]);
    RLBoons.Legendary(list, n"Cyberpsychosis", n"Maelstrom", "Cyberpsychosis", "Every 12 kills, go berserk for 8 s: +50% damage dealt, -50% damage taken.", [n"melee"]);
    // Aldecaldos - survival
    RLBoons.Core(list, n"ReinforcedFrame", n"Aldecaldos", "Reinforced Frame", "+{v}% max health.", [15.0, 20.0, 25.0, 30.0], [n"survival"]);
    RLBoons.Core(list, n"FastFeet", n"Aldecaldos", "Fast Feet", "+{v}% movement speed.", [8.0, 11.0, 14.0, 17.0], [n"mobility"]);
    RLBoons.Core(list, n"RoadEndurance", n"Aldecaldos", "Road Endurance", "+{v}% stamina.", [25.0, 35.0, 45.0, 55.0], [n"mobility"]);
    RLBoons.Core(list, n"ThickSkin", n"Aldecaldos", "Thick Skin", "Take {v}% less damage.", [8.0, 12.0, 16.0, 20.0], [n"survival"]);
    RLBoons.Core(list, n"SecondWind", n"Aldecaldos", "Second Wind", "A lethal hit leaves you at 50% health instead, {v} time(s) this run.", [1.0, 2.0, 3.0, 4.0], [n"survival"]);
    RLBoons.Legendary(list, n"FamilyTies", n"Aldecaldos", "Family Ties", "The first lethal hit in every arena leaves you at 30% health instead.", [n"survival"]);
    // The Afterlife - fortune
    RLBoons.Core(list, n"BountyHunter", n"Afterlife", "Bounty Hunter", "Kills pay {v} eddies.", [60.0, 90.0, 120.0, 150.0], []);
    RLBoons.Core(list, n"LuckyShot", n"Afterlife", "Lucky Shot", "{v}% chance for a hit to deal double damage.", [8.0, 12.0, 16.0, 20.0], [n"precision"]);
    RLBoons.Core(list, n"FixersCut", n"Afterlife", "Fixer's Cut", "The Fixer and paid rerolls cost {v}% less.", [15.0, 20.0, 25.0, 30.0], []);
    RLBoons.Core(list, n"StimRig", n"Afterlife", "Stim Rig", "+{v}% health item recharge speed.", [25.0, 35.0, 45.0, 55.0], [n"survival"]);
    RLBoons.Single(list, n"IronWill", n"Afterlife", "Professional", "Immune to knockdown and stun.", [n"survival"]);
    RLBoons.Legendary(list, n"AfterlifeLegend", n"Afterlife", "Afterlife Legend", "Every reward screen shows one more option.", []);
    // Duos
    RLBoons.Duo(list, n"SmartLink", n"Arasaka", n"Militech", "Smart Link", "Ranged headshots deal +35% damage.", [n"precision", n"rifle"]);
    RLBoons.Duo(list, n"DaemonPrecision", n"Arasaka", n"VoodooBoys", "Daemon Precision", "+20% quickhack crit chance.", [n"netrunner"]);
    RLBoons.Duo(list, n"CorporateBounty", n"Arasaka", n"Afterlife", "Corporate Bounty", "Elite and boss kills pay 500 eddies.", []);
    RLBoons.Duo(list, n"ShrapnelFrenzy", n"Militech", n"Maelstrom", "Shrapnel Frenzy", "Explosion kills heal 5% health.", [n"explosive"]);
    RLBoons.Duo(list, n"ConvoyArsenal", n"Militech", n"Aldecaldos", "Convoy Arsenal", "+1 grenade charge.", [n"explosive"]);
    RLBoons.Duo(list, n"ShortCircuit", n"VoodooBoys", n"Maelstrom", "Short Circuit", "Melee hits have a 25% chance to electrocute.", [n"melee", n"netrunner"]);
    RLBoons.Duo(list, n"DataBroker", n"VoodooBoys", n"Afterlife", "Data Broker", "Quickhack kills pay 150 eddies.", [n"netrunner"]);
    RLBoons.Duo(list, n"DesertFury", n"Maelstrom", n"Aldecaldos", "Desert Fury", "Below 40% health, take 30% less damage.", [n"survival"]);
    return list;
  }

  public static func Get(id: CName) -> ref<RLBoonDef> {
    for def in RLBoons.All() {
      if Equals(def.id, id) {
        return def;
      }
    }
    return null;
  }

  public static func HighestRarity(def: ref<RLBoonDef>) -> Int32 = Max(0, ArraySize(def.values) - 1)

  public static func ValueAt(def: ref<RLBoonDef>, rarity: Int32) -> Float {
    if ArraySize(def.values) == 0 {
      return 0.0;
    }
    return def.values[Clamp(rarity, 0, ArraySize(def.values) - 1)];
  }

  // The boon's text with the value for the rarity filled in.
  public static func Text(def: ref<RLBoonDef>, rarity: Int32) -> String {
    let value = RLBoons.ValueAt(def, rarity);
    let shown = value == Cast<Float>(RoundF(value)) ? IntToString(RoundF(value)) : FloatToStringPrec(value, 1);
    return StrReplace(def.text, "{v}", shown);
  }

  // --- Run state -------------------------------------------------------------------------

  public static func Owned(run: ref<RLRunState>, id: CName) -> ref<RLBoonState> {
    if IsDefined(run) {
      for state in run.boons {
        if Equals(state.id, id) {
          return state;
        }
      }
    }
    return null;
  }

  public static func Has(run: ref<RLRunState>, id: CName) -> Bool = IsDefined(RLBoons.Owned(run, id))

  // The boon's value at the rarity V holds it, or 0 when V doesn't hold it.
  public static func Value(run: ref<RLRunState>, id: CName) -> Float {
    let state = RLBoons.Owned(run, id);
    if !IsDefined(state) {
      return 0.0;
    }
    let def = RLBoons.Get(id);
    return IsDefined(def) ? RLBoons.ValueAt(def, state.rarity) : 0.0;
  }

  public static func CountForPatron(run: ref<RLRunState>, patron: CName) -> Int32 {
    let count = 0;
    if IsDefined(run) {
      for state in run.boons {
        let def = RLBoons.Get(state.id);
        if IsDefined(def) && Equals(def.kind, RLBoonKind.Core) && Equals(def.patron, patron) {
          count += 1;
        }
      }
    }
    return count;
  }

  // Can this boon (or its next rarity) be offered right now?
  public static func IsOfferable(run: ref<RLRunState>, def: ref<RLBoonDef>) -> Bool {
    let state = RLBoons.Owned(run, def.id);
    switch def.kind {
      case RLBoonKind.Legendary:
        return !IsDefined(state) && RLBoons.CountForPatron(run, def.patron) >= 3;
      case RLBoonKind.Duo:
        return !IsDefined(state) && RLBoons.CountForPatron(run, def.patron) > 0 && RLBoons.CountForPatron(run, def.partner) > 0;
    }
    return !IsDefined(state) || state.rarity < RLBoons.HighestRarity(def);
  }

  // Takes a boon at a rarity: new, or an upgrade of one V holds. Stat
  // modifiers are swapped for the new rarity's.
  public static func Apply(player: ref<PlayerPuppet>, run: ref<RLRunState>, id: CName, rarity: Int32) {
    let def = RLBoons.Get(id);
    if !IsDefined(def) || !IsDefined(player) {
      return;
    }
    let state = RLBoons.Owned(run, id);
    let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
    let objectID = Cast<StatsObjectID>(player.GetEntityID());
    if IsDefined(state) {
      for mod in state.mods {
        statsSystem.RemoveModifier(objectID, mod);
      }
      ArrayClear(state.mods);
      let gained = RoundF(RLBoons.ValueAt(def, rarity) - RLBoons.ValueAt(def, state.rarity));
      state.rarity = Max(state.rarity, rarity);
      if Equals(id, n"SecondWind") {
        state.charges += Max(0, gained);
      }
    } else {
      state = new RLBoonState();
      state.id = id;
      state.rarity = rarity;
      state.charges = RoundF(RLBoons.ValueAt(def, rarity));
      ArrayPush(run.boons, state);
      RLBoons.AddBuff(player, id);
      if Equals(id, n"AfterlifeLegend") {
        run.offerCount = Min(5, run.offerCount + 1);
      }
    }
    let value = RLBoons.ValueAt(def, state.rarity);
    switch id {
      case n"Kenshin":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.CritChance, gameStatModifierType.Additive, value));
        break;
      case n"Saburo":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.CritDamage, gameStatModifierType.Additive, value));
        break;
      case n"QuickFuse":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.GrenadesChargesRegenMult, gameStatModifierType.Additive, value / 100.0));
        break;
      case n"SynapticOverclock":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Memory, gameStatModifierType.Additive, value));
        break;
      case n"ContagionSeed":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.QuickHackSpreadNumber, gameStatModifierType.Additive, value));
        break;
      case n"SubdermalPlating":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Armor, gameStatModifierType.Additive, value));
        break;
      case n"ReinforcedFrame":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, value / 100.0));
        break;
      case n"FastFeet":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.MaxSpeed, gameStatModifierType.AdditiveMultiplier, value / 100.0));
        break;
      case n"RoadEndurance":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Stamina, gameStatModifierType.AdditiveMultiplier, value / 100.0));
        break;
      case n"StimRig":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.HealingItemsChargesRegenMult, gameStatModifierType.Additive, value / 100.0));
        break;
      case n"IronWill":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.KnockdownImmunity, gameStatModifierType.Additive, 1.0));
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.StunImmunity, gameStatModifierType.Additive, 1.0));
        break;
      case n"DaemonPrecision":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.QuickHackCritChance, gameStatModifierType.Additive, 20.0));
        break;
      case n"ConvoyArsenal":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.GrenadesMaxCharges, gameStatModifierType.Additive, 1.0));
        break;
    }
    for mod in state.mods {
      statsSystem.AddModifier(objectID, mod);
    }
  }

  // Takes a boon away (an event trade): its modifiers and HUD buff go too.
  public static func Remove(player: ref<PlayerPuppet>, run: ref<RLRunState>, id: CName) {
    let state = RLBoons.Owned(run, id);
    if !IsDefined(state) {
      return;
    }
    if IsDefined(player) {
      let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
      for mod in state.mods {
        statsSystem.RemoveModifier(Cast<StatsObjectID>(player.GetEntityID()), mod);
      }
      StatusEffectHelper.RemoveStatusEffect(player, RLBoons.BuffID(id));
    }
    ArrayRemove(run.boons, state);
    if Equals(id, n"AfterlifeLegend") {
      run.offerCount = Max(3, run.offerCount - 1);
    }
  }

  // A random boon V holds that can still be upgraded (or any boon V holds
  // when `upgradable` is false); none when there is none.
  public static func RandomOwned(run: ref<RLRunState>, upgradable: Bool) -> CName {
    let ids: array<CName>;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && (!upgradable || state.rarity < RLBoons.HighestRarity(def)) {
        ArrayPush(ids, state.id);
      }
    }
    return ArraySize(ids) > 0 ? ids[RandRange(0, ArraySize(ids))] : n"";
  }

  // Raises up to `count` random boons one rarity; returns how many.
  public static func UpgradeRandom(player: ref<PlayerPuppet>, run: ref<RLRunState>, count: Int32) -> Int32 {
    let upgraded = 0;
    while upgraded < count {
      let id = RLBoons.RandomOwned(run, true);
      if !IsNameValid(id) {
        break;
      }
      RLBoons.Apply(player, run, id, RLBoons.Owned(run, id).rarity + 1);
      upgraded += 1;
    }
    return upgraded;
  }

  // Second Wind: uses one charge; false when there is none left.
  public static func UseSecondWind(run: ref<RLRunState>) -> Bool {
    let state = RLBoons.Owned(run, n"SecondWind");
    if !IsDefined(state) || state.charges <= 0 {
      return false;
    }
    state.charges -= 1;
    return true;
  }

  // --- HUD buffs -----------------------------------------------------------------------

  public static func BuffID(id: CName) -> TweakDBID = TDBID.Create("NCRoguelite.Boon_" + NameToString(id))

  public static func AddBuff(player: ref<PlayerPuppet>, id: CName) {
    let buff = RLBoons.BuffID(id);
    if IsDefined(player) && IsDefined(TweakDBInterface.GetStatusEffectRecord(buff)) {
      StatusEffectHelper.ApplyStatusEffect(player, buff);
    }
  }

  // Every boon buff on V (end of a run, or left over from an earlier session).
  public static func ClearBuffs(player: ref<PlayerPuppet>) {
    if IsDefined(player) {
      StatusEffectHelper.RemoveStatusEffectsWithTag(player, n"NCRogueliteBoon");
    }
  }

  public static func RemoveAll(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    RLBoons.ClearBuffs(player);
    if IsDefined(player) {
      let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
      let objectID = Cast<StatsObjectID>(player.GetEntityID());
      for state in run.boons {
        for mod in state.mods {
          statsSystem.RemoveModifier(objectID, mod);
        }
      }
    }
    ArrayClear(run.boons);
  }

  // --- Definitions -----------------------------------------------------------------------

  private static func Core(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, const text: String, values: array<Float>, tags: array<CName>) {
    ArrayPush(list, RLBoons.Def(id, patron, n"", RLBoonKind.Core, name, text, values, tags));
  }

  private static func Single(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, const text: String, tags: array<CName>) {
    ArrayPush(list, RLBoons.Def(id, patron, n"", RLBoonKind.Core, name, text, [1.0], tags));
  }

  private static func Legendary(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, const text: String, tags: array<CName>) {
    ArrayPush(list, RLBoons.Def(id, patron, n"", RLBoonKind.Legendary, name, text, [1.0], tags));
  }

  private static func Duo(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, partner: CName, const name: String, const text: String, tags: array<CName>) {
    ArrayPush(list, RLBoons.Def(id, patron, partner, RLBoonKind.Duo, name, text, [1.0], tags));
  }

  private static func Def(id: CName, patron: CName, partner: CName, kind: RLBoonKind, const name: String, const text: String, values: array<Float>, tags: array<CName>) -> ref<RLBoonDef> {
    let def = new RLBoonDef();
    def.id = id;
    def.patron = patron;
    def.partner = partner;
    def.kind = kind;
    def.name = name;
    def.text = text;
    def.values = values;
    def.tags = tags;
    return def;
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - boons
// -----------------------------------------------------------------------------
// Run-only bonuses. Most are plain stat modifiers on V; three are scripted:
//   SecondWind  - a lethal hit restores 50% health instead (one stack used up)
//   Bloodlust   - every kill heals 4% health per stack
//   BountyHunter- every kill pays 100 eddies per stack
//   Demolitionist- every kill refunds 25% of a grenade charge per stack
// Applied modifiers are tracked so they can be removed when the run ends.
//
// Every stack also adds a stack of the boon's HUD buff (NCRoguelite.Boon_<id>,
// r6/tweaks/NightCityRoguelite/boons.yaml): an icon on the buff bar with the
// stack count. The buffs carry no stats; all of them are removed with the run.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLBoonDef {
  public let id: CName;
  public let name: String;
  public let description: String;
  public let maxStacks: Int32;
  // Rarity weight when rolling offers (higher = more common).
  public let weight: Int32;
}

public abstract class RLBoons {
  public static func All() -> array<ref<RLBoonDef>> {
    let list: array<ref<RLBoonDef>>;
    ArrayPush(list, RLBoons.Def(n"ReinforcedFrame", "Reinforced Frame", "+15% max health.", 3, 10));
    ArrayPush(list, RLBoons.Def(n"SubdermalPlating", "Subdermal Plating", "+40 armor.", 3, 10));
    ArrayPush(list, RLBoons.Def(n"KillerInstinct", "Killer Instinct", "+5% crit chance.", 4, 10));
    ArrayPush(list, RLBoons.Def(n"HollowPoints", "Hollow Points", "+20% crit damage.", 4, 10));
    ArrayPush(list, RLBoons.Def(n"SynapticOverclock", "Synaptic Overclock", "+2 max RAM.", 3, 8));
    ArrayPush(list, RLBoons.Def(n"FastFeet", "Fast Feet", "+8% movement speed.", 2, 7));
    ArrayPush(list, RLBoons.Def(n"ChromeTolerance", "Chrome Tolerance", "+15 cyberware capacity.", 3, 8));
    ArrayPush(list, RLBoons.Def(n"IronWill", "Iron Will", "Immune to knockdown and stun.", 1, 5));
    ArrayPush(list, RLBoons.Def(n"BigLungs", "Big Lungs", "+25% stamina.", 2, 7));
    ArrayPush(list, RLBoons.Def(n"SecondWind", "Second Wind", "A lethal hit leaves you at 50% health instead. Used up on trigger.", 3, 5));
    ArrayPush(list, RLBoons.Def(n"Bloodlust", "Bloodlust", "Kills heal 4% health.", 3, 7));
    ArrayPush(list, RLBoons.Def(n"BountyHunter", "Bounty Hunter", "Kills pay 100 eddies (spend them at the Fixer).", 3, 6));
    ArrayPush(list, RLBoons.Def(n"QuickFuse", "Quick Fuse", "+25% grenade recharge speed.", 3, 7));
    ArrayPush(list, RLBoons.Def(n"Demolitionist", "Demolitionist", "Kills restore 25% of a grenade charge.", 2, 6));
    ArrayPush(list, RLBoons.Def(n"StimRig", "Stim Rig", "+25% health item recharge speed.", 3, 7));
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

  private static func Def(id: CName, name: String, description: String, maxStacks: Int32, weight: Int32) -> ref<RLBoonDef> {
    let def = new RLBoonDef();
    def.id = id;
    def.name = name;
    def.description = description;
    def.maxStacks = maxStacks;
    def.weight = weight;
    return def;
  }

  // Applies one stack of a boon. Stat modifiers are recorded on the run so they
  // can be removed when the run ends.
  public static func ApplyStack(player: ref<PlayerPuppet>, id: CName, run: ref<RLRunState>) {
    RLBoons.AddBuffStack(player, id);
    let mods: array<ref<gameStatModifierData>>;
    switch id {
      case n"ReinforcedFrame":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, 0.15));
        break;
      case n"SubdermalPlating":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.Armor, gameStatModifierType.Additive, 40.0));
        break;
      case n"KillerInstinct":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.CritChance, gameStatModifierType.Additive, 5.0));
        break;
      case n"HollowPoints":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.CritDamage, gameStatModifierType.Additive, 20.0));
        break;
      case n"SynapticOverclock":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.Memory, gameStatModifierType.Additive, 2.0));
        break;
      case n"FastFeet":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.MaxSpeed, gameStatModifierType.AdditiveMultiplier, 0.08));
        break;
      case n"ChromeTolerance":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.Humanity, gameStatModifierType.Additive, 15.0));
        break;
      case n"IronWill":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.KnockdownImmunity, gameStatModifierType.Additive, 1.0));
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.StunImmunity, gameStatModifierType.Additive, 1.0));
        break;
      case n"QuickFuse":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.GrenadesChargesRegenMult, gameStatModifierType.Additive, 0.25));
        break;
      case n"StimRig":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.HealingItemsChargesRegenMult, gameStatModifierType.Additive, 0.25));
        break;
      case n"BigLungs":
        ArrayPush(mods, RPGManager.CreateStatModifier(gamedataStatType.Stamina, gameStatModifierType.AdditiveMultiplier, 0.25));
        break;
      default:
        // Scripted boons: no stat modifiers, the run system reads the stack count.
        return;
    }
    let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
    let objectID = Cast<StatsObjectID>(player.GetEntityID());
    for mod in mods {
      statsSystem.AddModifier(objectID, mod);
      ArrayPush(run.appliedMods, mod);
    }
  }

  // --- HUD buffs ------------------------------------------------------------------------

  public static func BuffID(id: CName) -> TweakDBID = TDBID.Create("NCRoguelite.Boon_" + NameToString(id))

  public static func AddBuffStack(player: ref<PlayerPuppet>, id: CName) {
    let buff = RLBoons.BuffID(id);
    if IsDefined(player) && IsDefined(TweakDBInterface.GetStatusEffectRecord(buff)) {
      StatusEffectHelper.ApplyStatusEffect(player, buff);
    }
  }

  // One stack used up (Second Wind).
  public static func RemoveBuffStack(player: ref<PlayerPuppet>, id: CName) {
    if IsDefined(player) {
      StatusEffectHelper.RemoveStatusEffect(player, RLBoons.BuffID(id), 1u);
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
      for mod in run.appliedMods {
        statsSystem.RemoveModifier(objectID, mod);
      }
    }
    ArrayClear(run.appliedMods);
  }
}

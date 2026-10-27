// -----------------------------------------------------------------------------
// Night City Roguelite - perk cards
// -----------------------------------------------------------------------------
// Training doors offer perk cards: hand-picked 2.5 perks (data in
// PerkCatalogData.reds) granted outright - no attribute requirement, no points.
//
//   Tree       a perk is offered once the perks it requires in the game's own
//              tree are owned (requirements outside the catalog - vehicle and
//              stealth perks - are granted silently along with it).
//   Signature  Master perks (power 4) only show up for a build that uses that
//              style, with its attribute at 15 (Hades' Duo and Legendary
//              boons work the same way).
//   Weighting  perks near the floor's expected power are common, stronger ones
//              rarer; the build profile raises matching perks (Director.reds).
//   Growth     taking a perk also raises its attribute by 1 (up to 20).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLPerkDef {
  public let perk: gamedataNewPerkType;
  public let name: String;
  // 1 novice, 2 adept / milestone, 3 expert milestone, 4 master (signature).
  public let power: Int32;
  public let tags: array<CName>;
  public let text: String;
}

public abstract class RLPerkCatalog {
  public static func All() -> array<ref<RLPerkDef>> = RogueliteService.Get().GetPerkCatalog()

  public static func Add(out list: array<ref<RLPerkDef>>, perk: gamedataNewPerkType, const name: String, power: Int32, tags: array<CName>, const text: String) {
    let record = RPGManager.GetNewPerkRecord(perk);
    if !IsDefined(record) || record.GetLevelsCount() == 0 {
      return;
    }
    let def = new RLPerkDef();
    def.perk = perk;
    def.name = name;
    def.power = power;
    def.tags = tags;
    def.text = text;
    ArrayPush(list, def);
  }

  public static func Find(perk: gamedataNewPerkType) -> ref<RLPerkDef> {
    for def in RLPerkCatalog.All() {
      if Equals(def.perk, perk) {
        return def;
      }
    }
    return null;
  }

  // The perk power a floor is expected to offer: 1 early, 4 at the end.
  public static func ExpectedPower(depth: Int32, totalFloors: Int32) -> Int32 {
    return Clamp(1 + (depth - 1) * 3 / Max(1, totalFloors - 1), 1, 4);
  }

  public static func IsOwned(data: ref<PlayerDevelopmentData>, perk: gamedataNewPerkType) -> Bool {
    return data.IsNewPerkBought(perk) > 0;
  }

  // Not owned yet, its tree requirements met, and (for signature perks) the
  // build uses its style.
  public static func IsOfferable(data: ref<PlayerDevelopmentData>, def: ref<RLPerkDef>, profile: ref<RLBuildProfile>) -> Bool {
    if RLPerkCatalog.IsOwned(data, def.perk) {
      return false;
    }
    let required: array<wref<NewPerk_Record>>;
    RPGManager.GetNewPerkRecord(def.perk).RequiresPerks(required);
    for record in required {
      if IsDefined(record) && IsDefined(RLPerkCatalog.Find(record.Type())) && !RLPerkCatalog.IsOwned(data, record.Type()) {
        return false;
      }
    }
    if def.power >= 4 && (!IsDefined(profile) || !profile.HasAny(def.tags) || !RLPerkCatalog.MeetsSignatureAttribute(data, def.perk)) {
      return false;
    }
    return true;
  }

  // Signature perks need their attribute at 15, like the game's own tree.
  public static func SignatureAttribute() -> Float = 15.0

  public static func MeetsSignatureAttribute(data: ref<PlayerDevelopmentData>, perk: gamedataNewPerkType) -> Bool {
    let stat = RLPerks.AttributeStat(perk);
    return Equals(stat, gamedataStatType.Invalid) || data.GetAttributeValue(stat) >= RLPerkCatalog.SignatureAttribute();
  }

  // Grants the perk at its max level, plus any requirement outside the catalog,
  // and +1 to its attribute: attributes grow with the perks V picks.
  public static func Grant(player: ref<PlayerPuppet>, def: ref<RLPerkDef>) {
    let data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return;
    }
    let required: array<wref<NewPerk_Record>>;
    RPGManager.GetNewPerkRecord(def.perk).RequiresPerks(required);
    for record in required {
      if IsDefined(record) && !RLPerkCatalog.IsOwned(data, record.Type()) {
        RLPerks.Grant(data, record.Type(), 0);
      }
    }
    RLPerks.Grant(data, def.perk, 0);
    let attribute = RLPerks.AttributeStat(def.perk);
    if NotEquals(attribute, gamedataStatType.Invalid) {
      data.RL_RaiseAttribute(attribute, 1);
    }
    data.UpdateUIBB();
  }

  // Up to `count` different offerable perks, weighted by power and build.
  // `spike`: at least one of them stronger than the floor expects.
  public static func Pick(player: ref<PlayerPuppet>, run: ref<RLRunState>, profile: ref<RLBuildProfile>, count: Int32, spike: Bool, exclude: array<gamedataNewPerkType>) -> array<ref<RLPerkDef>> {
    let picked: array<ref<RLPerkDef>>;
    let data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return picked;
    }
    let expected = RLPerkCatalog.ExpectedPower(run.Depth(), run.TotalFloors());
    let candidates: array<ref<RLPerkDef>>;
    for def in RLPerkCatalog.All() {
      if !ArrayContains(exclude, def.perk) && RLPerkCatalog.IsOfferable(data, def, profile) {
        ArrayPush(candidates, def);
      }
    }
    if spike {
      let strong: array<ref<RLPerkDef>>;
      for def in candidates {
        if def.power > expected {
          ArrayPush(strong, def);
        }
      }
      let first = RLPerkCatalog.WeightedPick(strong, expected, profile);
      if IsDefined(first) {
        ArrayPush(picked, first);
        ArrayRemove(candidates, first);
      }
    }
    while ArraySize(picked) < count && ArraySize(candidates) > 0 {
      let def = RLPerkCatalog.WeightedPick(candidates, expected, profile);
      ArrayPush(picked, def);
      ArrayRemove(candidates, def);
    }
    return picked;
  }

  // Power at or below the floor's expectation is common, above it rarer
  // (5 / 2 / 1 for +1 / +2 / +3); the build raises matching perks up to 40%.
  public static func Weight(def: ref<RLPerkDef>, expected: Int32, profile: ref<RLBuildProfile>) -> Float {
    let base = 10.0;
    let above = def.power - expected;
    if above == 1 {
      base = 5.0;
    } else if above == 2 {
      base = 2.0;
    } else if above >= 3 {
      base = 1.0;
    }
    return base * RLBuildProfile.Multiplier(profile, def.tags);
  }

  private static func WeightedPick(list: array<ref<RLPerkDef>>, expected: Int32, profile: ref<RLBuildProfile>) -> ref<RLPerkDef> {
    if ArraySize(list) == 0 {
      return null;
    }
    let total = 0.0;
    for def in list {
      total += RLPerkCatalog.Weight(def, expected, profile);
    }
    let roll = RandRangeF(0.0, total);
    for def in list {
      roll -= RLPerkCatalog.Weight(def, expected, profile);
      if roll <= 0.0 {
        return def;
      }
    }
    return list[ArraySize(list) - 1];
  }

  public static func AttributeName(perk: gamedataNewPerkType) -> String {
    let record = RPGManager.GetNewPerkRecord(perk);
    if IsDefined(record) && IsDefined(record.Attribute()) {
      switch record.Attribute().Type() {
        case gamedataAttributeDataType.BodyAttributeData: return "BODY";
        case gamedataAttributeDataType.ReflexesAttributeData: return "REFLEXES";
        case gamedataAttributeDataType.TechnicalAbilityAttributeData: return "TECHNICAL ABILITY";
        case gamedataAttributeDataType.IntelligenceAttributeData: return "INTELLIGENCE";
        case gamedataAttributeDataType.CoolAttributeData: return "COOL";
        case gamedataAttributeDataType.EspionageAttributeData: return "RELIC";
      }
    }
    return "PERK";
  }

  // UIIcon record of the perk's tree icon.
  public static func Icon(perk: gamedataNewPerkType) -> TweakDBID {
    let record = RPGManager.GetNewPerkRecord(perk);
    return IsDefined(record) && IsDefined(record.PerkIcon()) ? record.PerkIcon().GetID() : TDBID.None();
  }
}

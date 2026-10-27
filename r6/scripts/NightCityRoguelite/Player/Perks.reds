// -----------------------------------------------------------------------------
// Night City Roguelite - perks
// -----------------------------------------------------------------------------
// Perks are granted directly (unlock + force-buy to the wanted level), so they
// ignore attribute requirements and cost no points. Attributes grow with the
// perks V takes (+1 to the perk's attribute, see RLPerkCatalog.Grant).
//
// Baseline for every roguelite character: Slippery and Dash (Reflexes). Every
// action roguelite gives its core movement from the first minute; the reset
// between runs wipes perks, so the baseline is granted again after it.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLPerks {
  public static func Baseline() -> array<gamedataNewPerkType> {
    return [gamedataNewPerkType.Reflexes_Central_Milestone_1, gamedataNewPerkType.Reflexes_Central_Milestone_2];
  }

  public static func GrantBaseline(player: ref<PlayerPuppet>) {
    if !IsDefined(player) {
      return;
    }
    let data = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(data) {
      return;
    }
    for perk in RLPerks.Baseline() {
      RLPerks.Grant(data, perk, 0);
    }
    data.UpdateUIBB();
  }

  // Raises the perk to `level` (0 = its max level). Returns the levels added.
  public static func Grant(data: ref<PlayerDevelopmentData>, perk: gamedataNewPerkType, level: Int32) -> Int32 {
    data.UnlockNewPerk(perk);
    let target = level > 0 ? level : data.GetNewPerkMaxLevel(perk);
    let added = 0;
    while data.IsNewPerkBought(perk) < target && added < 5 {
      if !data.BuyNewPerk(perk, true) {
        break;
      }
      added += 1;
    }
    return added;
  }

  // The attribute a perk belongs to, as the stat that holds its value.
  public static func AttributeStat(perk: gamedataNewPerkType) -> gamedataStatType {
    let record = RPGManager.GetNewPerkRecord(perk);
    if IsDefined(record) && IsDefined(record.Attribute()) {
      switch record.Attribute().Type() {
        case gamedataAttributeDataType.BodyAttributeData: return gamedataStatType.Strength;
        case gamedataAttributeDataType.ReflexesAttributeData: return gamedataStatType.Reflexes;
        case gamedataAttributeDataType.TechnicalAbilityAttributeData: return gamedataStatType.TechnicalAbility;
        case gamedataAttributeDataType.IntelligenceAttributeData: return gamedataStatType.Intelligence;
        case gamedataAttributeDataType.CoolAttributeData: return gamedataStatType.Cool;
      }
    }
    return gamedataStatType.Invalid;
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - build profile
// -----------------------------------------------------------------------------
// What V's build is heading towards, read fresh before every reward roll from
// what V actually has:
//
//   weapons     by type (rifle, handgun, precision, shotgun, lmg, blade,
//               blunt, throwable) and evolution (smart, tech); equipped
//               weapons count double
//   cyberware   cyberdeck -> netrunner, arms (blades, gorilla arms,
//               monowire, launcher), legs -> mobility, the rest -> chrome
//   perks       the tags of every catalog perk owned
//   attributes  each point spent above the baseline leans towards that
//               attribute's styles
//
// Offers whose tags match get up to +40% weight (RLBuildProfile.Multiplier);
// the reward director keeps at least one card per screen off-build, so the
// profile nudges and never decides.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLBuildProfile {
  private let m_tags: array<CName>;
  private let m_weights: array<Float>;

  public static func Read(player: ref<PlayerPuppet>) -> ref<RLBuildProfile> {
    let profile = new RLBuildProfile();
    if !IsDefined(player) {
      return profile;
    }
    let transactionSystem = GameInstance.GetTransactionSystem(player.GetGame());
    let equipment = EquipmentSystem.GetData(player);
    let items: array<wref<gameItemData>>;
    transactionSystem.GetItemList(player, items);
    for item in items {
      if IsDefined(item) {
        let itemID = item.GetID();
        let equipped = IsDefined(equipment) && equipment.IsEquipped(itemID);
        switch RPGManager.GetItemCategory(itemID) {
          case gamedataItemCategory.Weapon:
            profile.AddAll(RLBuildProfile.WeaponTags(itemID), equipped ? 2.0 : 1.0);
            break;
          case gamedataItemCategory.Cyberware:
            if equipped {
              profile.AddAll(RLBuildProfile.CyberwareTags(item), 1.5);
            }
            break;
          case gamedataItemCategory.Gadget:
            profile.Add(n"explosive", 0.5);
            break;
        }
      }
    }
    let data = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(data) {
      for def in RLPerkCatalog.All() {
        if RLPerkCatalog.IsOwned(data, def.perk) {
          profile.AddAll(def.tags, 1.0);
        }
      }
    }
    profile.AddAttribute(player, gamedataStatType.Strength, [n"shotgun", n"lmg", n"blunt", n"survival"]);
    profile.AddAttribute(player, gamedataStatType.Reflexes, [n"rifle", n"blade", n"mobility"]);
    profile.AddAttribute(player, gamedataStatType.TechnicalAbility, [n"tech", n"chrome", n"gear", n"explosive"]);
    profile.AddAttribute(player, gamedataStatType.Intelligence, [n"netrunner", n"smart"]);
    profile.AddAttribute(player, gamedataStatType.Cool, [n"handgun", n"precision", n"throwable", n"dual"]);
    return profile;
  }

  public static func WeaponTags(itemID: ItemID) -> array<CName> {
    let tags: array<CName>;
    switch RPGManager.GetItemType(itemID) {
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_SubmachineGun:
        ArrayPush(tags, n"rifle");
        break;
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
        ArrayPush(tags, n"handgun");
        ArrayPush(tags, n"dual");
        break;
      case gamedataItemType.Wea_PrecisionRifle:
      case gamedataItemType.Wea_SniperRifle:
        ArrayPush(tags, n"precision");
        break;
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
        ArrayPush(tags, n"shotgun");
        break;
      case gamedataItemType.Wea_LightMachineGun:
        ArrayPush(tags, n"lmg");
        break;
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_Chainsword:
        ArrayPush(tags, n"blade");
        break;
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Axe:
        ArrayPush(tags, n"blade");
        ArrayPush(tags, n"throwable");
        break;
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_TwoHandedClub:
        ArrayPush(tags, n"blunt");
        break;
    }
    switch RPGManager.GetWeaponEvolution(itemID) {
      case gamedataWeaponEvolution.Smart:
        ArrayPush(tags, n"smart");
        break;
      case gamedataWeaponEvolution.Tech:
        ArrayPush(tags, n"tech");
        break;
    }
    return tags;
  }

  public static func CyberwareTags(item: wref<gameItemData>) -> array<CName> {
    let tags: array<CName>;
    let itemID = item.GetID();
    if item.HasTag(n"Cyberdeck") {
      ArrayPush(tags, n"netrunner");
      return tags;
    }
    switch RPGManager.GetItemType(itemID) {
      case gamedataItemType.Cyb_MantisBlades:
        ArrayPush(tags, n"blade");
        return tags;
      case gamedataItemType.Cyb_StrongArms:
        ArrayPush(tags, n"blunt");
        return tags;
      case gamedataItemType.Cyb_NanoWires:
        ArrayPush(tags, n"netrunner");
        return tags;
      case gamedataItemType.Cyb_Launcher:
        ArrayPush(tags, n"explosive");
        return tags;
    }
    if Equals(EquipmentSystem.GetEquipAreaType(itemID), gamedataEquipmentArea.LegsCW) {
      ArrayPush(tags, n"mobility");
    } else {
      ArrayPush(tags, n"chrome");
    }
    return tags;
  }

  // Tags of an offerable item record (weapons and cyberware).
  public static func RecordTags(record: TweakDBID) -> array<CName> {
    let tags: array<CName>;
    let item = TweakDBInterface.GetItemRecord(record);
    if !IsDefined(item) || !IsDefined(item.ItemCategory()) {
      return tags;
    }
    let itemID = ItemID.FromTDBID(record);
    switch item.ItemCategory().Type() {
      case gamedataItemCategory.Weapon:
        return RLBuildProfile.WeaponTags(itemID);
      case gamedataItemCategory.Cyberware:
        if item.TagsContains(n"Cyberdeck") {
          ArrayPush(tags, n"netrunner");
          return tags;
        }
        switch RPGManager.GetItemType(itemID) {
          case gamedataItemType.Cyb_MantisBlades: ArrayPush(tags, n"blade"); return tags;
          case gamedataItemType.Cyb_StrongArms: ArrayPush(tags, n"blunt"); return tags;
          case gamedataItemType.Cyb_NanoWires: ArrayPush(tags, n"netrunner"); return tags;
          case gamedataItemType.Cyb_Launcher: ArrayPush(tags, n"explosive"); return tags;
        }
        ArrayPush(tags, IsDefined(item.EquipArea()) && Equals(item.EquipArea().Type(), gamedataEquipmentArea.LegsCW) ? n"mobility" : n"chrome");
        return tags;
      case gamedataItemCategory.Gadget:
        ArrayPush(tags, n"explosive");
        return tags;
    }
    return tags;
  }

  // 1.0 for no match, up to 1.4 for the build's main style.
  public static func Multiplier(profile: ref<RLBuildProfile>, tags: array<CName>) -> Float {
    if !IsDefined(profile) {
      return 1.0;
    }
    return 1.0 + 0.4 * MinF(profile.Affinity(tags), 3.0) / 3.0;
  }

  // The strongest weight among the tags.
  public func Affinity(tags: array<CName>) -> Float {
    let best = 0.0;
    for tag in tags {
      best = MaxF(best, this.Weight(tag));
    }
    return best;
  }

  // The build clearly uses one of these styles.
  public func HasAny(tags: array<CName>) -> Bool = this.Affinity(tags) >= 1.0

  public func Weight(tag: CName) -> Float {
    let i = ArrayFindFirst(this.m_tags, tag);
    return i >= 0 ? this.m_weights[i] : 0.0;
  }

  public func Describe() -> String {
    let text = "";
    let i = 0;
    while i < ArraySize(this.m_tags) {
      if this.m_weights[i] >= 1.0 {
        text += (StrLen(text) > 0 ? ", " : "") + NameToString(this.m_tags[i]) + s" \(this.m_weights[i])";
      }
      i += 1;
    }
    return StrLen(text) > 0 ? text : "none yet";
  }

  public func Add(tag: CName, amount: Float) {
    let i = ArrayFindFirst(this.m_tags, tag);
    if i >= 0 {
      this.m_weights[i] += amount;
    } else {
      ArrayPush(this.m_tags, tag);
      ArrayPush(this.m_weights, amount);
    }
  }

  private func AddAll(tags: array<CName>, amount: Float) {
    for tag in tags {
      this.Add(tag, amount);
    }
  }

  private func AddAttribute(player: ref<PlayerPuppet>, stat: gamedataStatType, tags: array<CName>) {
    let value = GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), stat);
    let spent = value - RLConfig.BaseAttributeValue();
    if spent > 0.0 {
      this.AddAll(tags, 0.25 * spent);
    }
  }
}

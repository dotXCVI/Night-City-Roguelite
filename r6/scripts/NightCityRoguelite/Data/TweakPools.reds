// -----------------------------------------------------------------------------
// Night City Roguelite - runtime content pools
// -----------------------------------------------------------------------------
// Builds enemy and item pools straight from TweakDB (via TweakXL's record
// enumeration) the first time a run starts. Nothing is hardcoded except a few
// boss records the game scripts reference directly, so new patch content shows
// up automatically.
//
// Enemies: Character records filtered to combat-capable humans/androids of a
//          hostile faction, general (non-quest) affiliation, with a primary
//          weapon. Bucketed per faction into three tiers by NPC rarity.
// Items:   everything any vendor in the game stocks (VendorItem records),
//          which is a reliable "player-usable" filter, plus iconic weapons.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLFactionPool {
  public let faction: gamedataAffiliation;
  public let tier0: array<TweakDBID>; // Trash, Weak
  public let tier1: array<TweakDBID>; // Normal, Rare
  public let tier2: array<TweakDBID>; // Officer, Elite

  public func IsUsable() -> Bool {
    return ArraySize(this.tier0) + ArraySize(this.tier1) >= 3;
  }

  public func Total() -> Int32 {
    return ArraySize(this.tier0) + ArraySize(this.tier1) + ArraySize(this.tier2);
  }

  public func Pick(tier: Int32) -> TweakDBID {
    // Fall back to neighbouring tiers when a faction lacks one.
    if tier >= 2 && ArraySize(this.tier2) > 0 {
      return this.tier2[RandRange(0, ArraySize(this.tier2))];
    }
    if tier >= 1 && ArraySize(this.tier1) > 0 {
      return this.tier1[RandRange(0, ArraySize(this.tier1))];
    }
    if ArraySize(this.tier0) > 0 {
      return this.tier0[RandRange(0, ArraySize(this.tier0))];
    }
    if ArraySize(this.tier1) > 0 {
      return this.tier1[RandRange(0, ArraySize(this.tier1))];
    }
    return this.tier2[RandRange(0, ArraySize(this.tier2))];
  }
}

public class RLItemEntry {
  public let id: TweakDBID;
  public let itemType: gamedataItemType;
  public let area: gamedataEquipmentArea;
  // 0 Common, 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary (Plus variants share a band)
  public let band: Int32;
  public let iconic: Bool;
  public let cyberdeck: Bool;
  public let evolution: gamedataWeaponEvolution;
}

public class RLTweakPools {
  private let m_built: Bool;
  private let m_factions: array<ref<RLFactionPool>>;
  private let m_weapons: array<ref<RLItemEntry>>;
  private let m_iconics: array<ref<RLItemEntry>>;
  private let m_cyberware: array<ref<RLItemEntry>>;
  private let m_quickhacks: array<ref<RLItemEntry>>;
  private let m_seen: array<TweakDBID>;

  // --- Build ----------------------------------------------------------------------

  public func EnsureBuilt() {
    if this.m_built {
      return;
    }
    this.m_built = true;
    this.BuildEnemies();
    this.BuildItems();
    RLLog(s"Pools built: \(ArraySize(this.m_factions)) factions, \(ArraySize(this.m_weapons)) weapons, \(ArraySize(this.m_iconics)) iconics, \(ArraySize(this.m_cyberware)) cyberware, \(ArraySize(this.m_quickhacks)) quickhacks.");
  }

  // Enemies come from the curated roster (Data/EnemyRoster.reds): the game's
  // own open-world combat NPCs. Each record is checked before it is used.
  private func BuildEnemies() {
    let blocklist = RLConfig.EnemyBlocklist();
    let scanned = 0;
    let accepted = 0;
    let variants = 0;
    for faction in RLRoster.Factions() {
      let tier = 0;
      while tier <= 2 {
        for name in RLRoster.Records(faction, tier) {
          scanned += 1;
          let id = RLRoster.Resolve(name);
          if RLRoster.IsVariant(id) {
            variants += 1;
          }
          if RLTweakPools.IsUsableEnemy(TweakDBInterface.GetCharacterRecord(id), blocklist) {
            let pool = this.GetOrAddFaction(faction);
            if tier == 0 {
              ArrayPush(pool.tier0, id);
            } else if tier == 1 {
              ArrayPush(pool.tier1, id);
            } else {
              ArrayPush(pool.tier2, id);
            }
            accepted += 1;
          } else {
            RLDebug("Roster record skipped: " + name);
          }
        }
        tier += 1;
      }
    }
    // Drop factions that can't fill a wave.
    let usable: array<ref<RLFactionPool>>;
    for pool in this.m_factions {
      if pool.IsUsable() {
        ArrayPush(usable, pool);
        RLDebug(s"Faction \(RLEncounters.FactionName(pool.faction)): \(ArraySize(pool.tier0))/\(ArraySize(pool.tier1))/\(ArraySize(pool.tier2))");
      }
    }
    this.m_factions = usable;
    RLLog(s"Enemy roster: \(scanned) records, \(accepted) usable, \(ArraySize(usable)) factions, \(variants) roguelite variants (TweakXL).");
    if variants == 0 {
      RLLog("No roguelite enemy variants found - is TweakXL installed and r6/tweaks/NightCityRoguelite present? Using the game's own records.");
    }
  }

  // A roster record is usable when it exists, is a human or android and has a
  // weapon to fight with.
  public static func IsUsableEnemy(character: ref<Character_Record>, blocklist: array<TweakDBID>) -> Bool {
    if !IsDefined(character) || ArrayContains(blocklist, character.GetID()) {
      return false;
    }
    if character.IsCrowd() || character.IsChild() {
      return false;
    }
    let npcType = character.CharacterType();
    if !IsDefined(npcType) {
      return false;
    }
    let kind = npcType.Type();
    if NotEquals(kind, gamedataNPCType.Human) && NotEquals(kind, gamedataNPCType.Android) {
      return false;
    }
    return IsDefined(character.PrimaryEquipment()) || IsDefined(character.SecondaryEquipment());
  }

  private func GetOrAddFaction(faction: gamedataAffiliation) -> ref<RLFactionPool> {
    for pool in this.m_factions {
      if Equals(pool.faction, faction) {
        return pool;
      }
    }
    let pool = new RLFactionPool();
    pool.faction = faction;
    ArrayPush(this.m_factions, pool);
    return pool;
  }

  private func BuildItems() {
    for record in TweakDBInterface.GetRecords(n"VendorItem") {
      let vendorItem = record as VendorItem_Record;
      if IsDefined(vendorItem) {
        let item = vendorItem.Item();
        if IsDefined(item) {
          this.Classify(item, false);
        }
      }
    }
    for record in TweakDBInterface.GetRecords(n"WeaponItem") {
      let weapon = record as WeaponItem_Record;
      if IsDefined(weapon) && weapon.TagsContains(n"IconicWeapon") && IsDefined(weapon.Icon()) {
        this.Classify(weapon, true);
      }
    }
  }

  private func Classify(item: ref<Item_Record>, iconic: Bool) {
    let id = item.GetID();
    let blocklist = RLConfig.ItemBlocklist();
    if ArrayContains(this.m_seen, id) || ArrayContains(blocklist, id) {
      return;
    }
    ArrayPush(this.m_seen, id);
    if !IsDefined(item.ItemType()) || !IsDefined(item.ItemCategory()) {
      return;
    }
    let itemType = item.ItemType().Type();
    let category = item.ItemCategory().Type();
    let entry = new RLItemEntry();
    entry.id = id;
    entry.itemType = itemType;
    entry.area = IsDefined(item.EquipArea()) ? item.EquipArea().Type() : gamedataEquipmentArea.Invalid;
    entry.band = IsDefined(item.Quality()) ? RLTweakPools.BandOf(item.Quality().Type()) : 0;
    entry.iconic = iconic || item.TagsContains(n"IconicWeapon");
    entry.cyberdeck = item.TagsContains(n"Cyberdeck");
    let weapon = item as WeaponItem_Record;
    entry.evolution = IsDefined(weapon) && IsDefined(weapon.Evolution()) ? weapon.Evolution().Type() : gamedataWeaponEvolution.None;

    if Equals(category, gamedataItemCategory.Weapon) && RLTweakPools.IsPlayerWeaponType(itemType) {
      if entry.iconic {
        ArrayPush(this.m_iconics, entry);
      } else {
        ArrayPush(this.m_weapons, entry);
      }
      return;
    }
    if Equals(category, gamedataItemCategory.Cyberware) && RLTweakPools.IsCyberwareArea(entry.area) {
      ArrayPush(this.m_cyberware, entry);
      return;
    }
    if Equals(itemType, gamedataItemType.Prt_Program) {
      ArrayPush(this.m_quickhacks, entry);
      return;
    }
  }

  // --- Classification helpers --------------------------------------------------

  public static func IsHostileFaction(faction: gamedataAffiliation) -> Bool {
    switch faction {
      case gamedataAffiliation.Animals:
      case gamedataAffiliation.Maelstrom:
      case gamedataAffiliation.Scavengers:
      case gamedataAffiliation.SixthStreet:
      case gamedataAffiliation.TygerClaws:
      case gamedataAffiliation.Valentinos:
      case gamedataAffiliation.VoodooBoys:
      case gamedataAffiliation.Wraiths:
      case gamedataAffiliation.Barghest:
      case gamedataAffiliation.Arasaka:
      case gamedataAffiliation.Militech:
      case gamedataAffiliation.KangTao:
        return true;
    }
    return false;
  }

  public static func IsCorpFaction(faction: gamedataAffiliation) -> Bool {
    switch faction {
      case gamedataAffiliation.Barghest:
      case gamedataAffiliation.Arasaka:
      case gamedataAffiliation.Militech:
      case gamedataAffiliation.KangTao:
        return true;
    }
    return false;
  }

  public static func TierOf(rarity: gamedataNPCRarity) -> Int32 {
    switch rarity {
      case gamedataNPCRarity.Trash:
      case gamedataNPCRarity.Weak:
        return 0;
      case gamedataNPCRarity.Normal:
      case gamedataNPCRarity.Rare:
        return 1;
      case gamedataNPCRarity.Officer:
      case gamedataNPCRarity.Elite:
        return 2;
    }
    return -1;
  }

  public static func BandOf(quality: gamedataQuality) -> Int32 {
    switch quality {
      case gamedataQuality.Uncommon:
      case gamedataQuality.UncommonPlus:
        return 1;
      case gamedataQuality.Rare:
      case gamedataQuality.RarePlus:
        return 2;
      case gamedataQuality.Epic:
      case gamedataQuality.EpicPlus:
        return 3;
      case gamedataQuality.Legendary:
      case gamedataQuality.LegendaryPlus:
      case gamedataQuality.LegendaryPlusPlus:
      case gamedataQuality.Iconic:
        return 4;
    }
    return 0;
  }

  public static func IsPlayerWeaponType(itemType: gamedataItemType) -> Bool {
    switch itemType {
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_Axe:
      case gamedataItemType.Wea_Chainsword:
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_PrecisionRifle:
      case gamedataItemType.Wea_Revolver:
      case gamedataItemType.Wea_Rifle:
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_SubmachineGun:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_TwoHandedClub:
        return true;
    }
    return false;
  }

  public static func IsCyberwareArea(area: gamedataEquipmentArea) -> Bool {
    switch area {
      case gamedataEquipmentArea.ArmsCW:
      case gamedataEquipmentArea.CardiovascularSystemCW:
      case gamedataEquipmentArea.EyesCW:
      case gamedataEquipmentArea.FrontalCortexCW:
      case gamedataEquipmentArea.HandsCW:
      case gamedataEquipmentArea.ImmuneSystemCW:
      case gamedataEquipmentArea.IntegumentarySystemCW:
      case gamedataEquipmentArea.LegsCW:
      case gamedataEquipmentArea.MusculoskeletalSystemCW:
      case gamedataEquipmentArea.NervousSystemCW:
      case gamedataEquipmentArea.SystemReplacementCW:
      case gamedataEquipmentArea.FaceCW:
        return true;
    }
    return false;
  }

  // --- Queries ----------------------------------------------------------------------

  public func GetFactions() -> array<ref<RLFactionPool>> = this.m_factions

  public func PickFaction(preferCorp: Bool) -> ref<RLFactionPool> {
    let count = ArraySize(this.m_factions);
    if count == 0 {
      return null;
    }
    if preferCorp {
      let corps: array<ref<RLFactionPool>>;
      for pool in this.m_factions {
        if RLTweakPools.IsCorpFaction(pool.faction) {
          ArrayPush(corps, pool);
        }
      }
      if ArraySize(corps) > 0 && RandF() < 0.6 {
        return corps[RandRange(0, ArraySize(corps))];
      }
    }
    return this.m_factions[RandRange(0, count)];
  }

  // Picks one of the preferred factions when the installed game has it,
  // otherwise falls back to PickFaction.
  public func PickFactionPreferred(preferred: array<gamedataAffiliation>, preferCorp: Bool) -> ref<RLFactionPool> {
    let matches: array<ref<RLFactionPool>>;
    for pool in this.m_factions {
      if ArrayContains(preferred, pool.faction) {
        ArrayPush(matches, pool);
      }
    }
    if ArraySize(matches) > 0 {
      return matches[RandRange(0, ArraySize(matches))];
    }
    return this.PickFaction(preferCorp);
  }

  // A weapon of one of the item types (any when empty) and, when given, one of
  // the evolutions (Power, Tech, Smart, Blade...).
  public func PickWeapon(itemTypes: array<gamedataItemType>, opt evolutions: array<gamedataWeaponEvolution>) -> TweakDBID {
    let matches: array<TweakDBID>;
    for entry in this.m_weapons {
      let typeOk = ArraySize(itemTypes) == 0 || ArrayContains(itemTypes, entry.itemType);
      let evolutionOk = ArraySize(evolutions) == 0 || ArrayContains(evolutions, entry.evolution);
      if typeOk && evolutionOk {
        ArrayPush(matches, entry.id);
      }
    }
    if ArraySize(matches) == 0 {
      return TDBID.None();
    }
    return matches[RandRange(0, ArraySize(matches))];
  }

  public func PickIconic() -> TweakDBID {
    if ArraySize(this.m_iconics) == 0 {
      return TDBID.None();
    }
    return this.m_iconics[RandRange(0, ArraySize(this.m_iconics))].id;
  }

  // An iconic of the item type, else of the same family (an evolution).
  public func PickIconicFor(itemType: gamedataItemType) -> TweakDBID {
    let matches: array<TweakDBID>;
    for entry in this.m_iconics {
      if Equals(entry.itemType, itemType) {
        ArrayPush(matches, entry.id);
      }
    }
    if ArraySize(matches) == 0 {
      let family = RLWeapons.FamilyOf(itemType);
      for entry in this.m_iconics {
        if RLWeapons.FamilyOf(entry.itemType) == family {
          ArrayPush(matches, entry.id);
        }
      }
    }
    return ArraySize(matches) > 0 ? matches[RandRange(0, ArraySize(matches))] : TDBID.None();
  }

  // An Operating System of one kind (Sandevistan, Berserk or Cyberdeck),
  // close to the wanted quality band.
  public func PickOperatingSystem(kind: CName, band: Int32) -> TweakDBID {
    let distance = 0;
    while distance <= 4 {
      let matches: array<TweakDBID>;
      for entry in this.m_cyberware {
        if Equals(entry.area, gamedataEquipmentArea.SystemReplacementCW) && Abs(entry.band - band) == distance && RLTweakPools.IsOperatingSystem(entry, kind) {
          ArrayPush(matches, entry.id);
        }
      }
      if ArraySize(matches) > 0 {
        return matches[RandRange(0, ArraySize(matches))];
      }
      distance += 1;
    }
    return TDBID.None();
  }

  private static func IsOperatingSystem(entry: ref<RLItemEntry>, kind: CName) -> Bool {
    if Equals(kind, n"Cyberdeck") {
      return entry.cyberdeck;
    }
    let item = TweakDBInterface.GetItemRecord(entry.id);
    return !entry.cyberdeck && IsDefined(item) && (item.TagsContains(kind) || StrContains(TDBID.ToStringDEBUG(entry.id), NameToString(kind)));
  }

  // Picks cyberware close to the wanted quality band; `requireDeck` limits the
  // pick to cyberdecks, `excludeAreas` skips areas (e.g. already offered).
  public func PickCyberware(band: Int32, requireDeck: Bool, itemType: gamedataItemType, excludeIDs: array<TweakDBID>) -> TweakDBID {
    let distance = 0;
    while distance <= 4 {
      let matches: array<TweakDBID>;
      for entry in this.m_cyberware {
        let deckOk = !requireDeck || entry.cyberdeck;
        let typeOk = Equals(itemType, gamedataItemType.Invalid) || Equals(entry.itemType, itemType);
        if deckOk && typeOk && !ArrayContains(excludeIDs, entry.id) && Abs(entry.band - band) == distance {
          ArrayPush(matches, entry.id);
        }
      }
      if ArraySize(matches) > 0 {
        return matches[RandRange(0, ArraySize(matches))];
      }
      distance += 1;
    }
    return TDBID.None();
  }

  public func PickQuickhack(band: Int32, excludeIDs: array<TweakDBID>) -> TweakDBID {
    let distance = 0;
    while distance <= 4 {
      let matches: array<TweakDBID>;
      for entry in this.m_quickhacks {
        if !ArrayContains(excludeIDs, entry.id) && Abs(entry.band - band) == distance {
          ArrayPush(matches, entry.id);
        }
      }
      if ArraySize(matches) > 0 {
        return matches[RandRange(0, ArraySize(matches))];
      }
      distance += 1;
    }
    return TDBID.None();
  }

  public func HasQuickhacks() -> Bool = ArraySize(this.m_quickhacks) > 0
}

// Boss records: the open-world MaxTac squad (Data/EnemyRoster.reds), as
// roguelite variants when available. Each is validated at runtime before use.
public abstract class RLBosses {
  public static func MaxTac() -> array<TweakDBID> {
    let result: array<TweakDBID>;
    for name in RLRoster.MaxTac() {
      ArrayPush(result, RLRoster.Resolve(name));
    }
    return result;
  }

  public static func Exists(id: TweakDBID) -> Bool {
    return IsDefined(TweakDBInterface.GetCharacterRecord(id));
  }
}

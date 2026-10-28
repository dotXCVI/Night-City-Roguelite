// -----------------------------------------------------------------------------
// Night City Roguelite - what an item does, in the game's own words
// -----------------------------------------------------------------------------
// Cyberware, quickhacks and grenades on reward, Fixer and event cards show the
// lines the game's own tooltip shows: each effect the item puts on V (its
// gameplay logic packages, with their numbers filled in for the item's
// quality), or the item's blurb when it has none.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLItemText {
  // Kinds of reward that need the item's own text (weapons have their DPS
  // and playstyle, boons and perks their own text).
  public static func Wants(kind: RLOfferKind) -> Bool {
    switch kind {
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
      case RLOfferKind.OperatingSystem:
        return true;
    }
    return false;
  }

  // Adds up to `max` lines to the card; returns how many were added.
  public static func AddTo(card: ref<RLCard>, record: TweakDBID, color: CName, size: Int32, max: Int32) -> Int32 {
    let item = TweakDBInterface.GetItemRecord(record);
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(item) || !IsDefined(player) {
      return 0;
    }
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(record);
    params.quantity = 1;
    let itemData = Inventory.CreateItemData(params, player);
    let added = 0;
    let packages: array<wref<GameplayLogicPackage_Record>>;
    item.OnEquip(packages);
    added += RLItemText.AddPackages(card, packages, itemData, color, size, max - added);
    let attached: array<wref<GameplayLogicPackage_Record>>;
    item.OnAttach(attached);
    added += RLItemText.AddPackages(card, attached, itemData, color, size, max - added);
    if added == 0 {
      let blurb = GetLocalizedTextByKey(item.LocalizedDescription());
      if StrLen(blurb) > 0 && !StrContains(blurb, "{") {
        card.AddLine(blurb, color, size);
        added = 1;
      }
    }
    return added;
  }

  private static func AddPackages(card: ref<RLCard>, packages: array<wref<GameplayLogicPackage_Record>>, itemData: ref<gameItemData>, color: CName, size: Int32, max: Int32) -> Int32 {
    let added = 0;
    for package in packages {
      if added >= max {
        break;
      }
      let ui = IsDefined(package) ? package.UIData() : null;
      if IsDefined(ui) && IsStringValid(ui.LocalizedDescription()) {
        let text = GetLocalizedText(ui.LocalizedDescription());
        if StrLen(text) > 0 {
          let data = UILocalizationDataPackage.FromLogicUIDataPackage(ui, itemData);
          // A line whose numbers can't be filled in would show raw {float_0}s.
          if !StrContains(text, "{") || (IsDefined(data) && data.GetParamsCount() > 0) {
            card.AddParamLine(text, data, color, size);
            added += 1;
          }
        }
      }
    }
    return added;
  }
}

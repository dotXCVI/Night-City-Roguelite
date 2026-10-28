// -----------------------------------------------------------------------------
// Night City Roguelite - what an item does, in the game's own words
// -----------------------------------------------------------------------------
// Cyberware, quickhacks and grenades on reward, Fixer and event cards show the
// lines the game's own tooltip shows: each effect the item puts on V (its
// gameplay logic packages), or the item's blurb when it has none.
//
// The tooltip text is written for the game's rich-text widgets: {float_0}
// values, <Rich ...>highlight</> tags, <Input .../> key glyphs and a
// {__empty__} marker. It is rendered to plain text here - values filled in
// from the item at its quality, markup stripped - and anything that still
// can't be shown cleanly (a key glyph, an unknown value) drops the line
// rather than printing raw markup. Lines are kept short.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLItemText {
  public static func MaxLineLength() -> Int32 = 120

  // Kinds of reward that need the item's own text (weapons have their DPS
  // and playstyle, boons and perks their own text, Operating Systems the
  // Overdrive they unlock).
  public static func Wants(kind: RLOfferKind) -> Bool {
    switch kind {
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
        return true;
    }
    return false;
  }

  // Adds up to `max` lines to the card; returns how many were added.
  public static func AddTo(card: ref<RLCard>, record: TweakDBID, color: CName, size: Int32, max: Int32) -> Int32 {
    let lines = RLItemText.Lines(record, max);
    for line in lines {
      card.AddLine(line, color, size);
    }
    return ArraySize(lines);
  }

  public static func Lines(record: TweakDBID, max: Int32) -> array<String> {
    let lines: array<String>;
    let item = TweakDBInterface.GetItemRecord(record);
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(item) || !IsDefined(player) || max <= 0 {
      return lines;
    }
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(record);
    params.quantity = 1;
    let itemData = Inventory.CreateItemData(params, player);
    let packages: array<wref<GameplayLogicPackage_Record>>;
    item.OnEquip(packages);
    RLItemText.AddPackages(lines, packages, itemData, max);
    let attached: array<wref<GameplayLogicPackage_Record>>;
    item.OnAttach(attached);
    RLItemText.AddPackages(lines, attached, itemData, max);
    if ArraySize(lines) == 0 {
      let blurb = RLItemText.Render(GetLocalizedTextByKey(item.LocalizedDescription()), null);
      if StrLen(blurb) > 0 {
        ArrayPush(lines, blurb);
      }
    }
    return lines;
  }

  private static func AddPackages(out lines: array<String>, packages: array<wref<GameplayLogicPackage_Record>>, itemData: ref<gameItemData>, max: Int32) {
    for package in packages {
      if ArraySize(lines) >= max {
        return;
      }
      let ui = IsDefined(package) ? package.UIData() : null;
      if IsDefined(ui) && IsStringValid(ui.LocalizedDescription()) {
        let data = UILocalizationDataPackage.FromLogicUIDataPackage(ui, itemData);
        let text = RLItemText.Render(GetLocalizedText(ui.LocalizedDescription()), data);
        if StrLen(text) > 0 && !ArrayContains(lines, text) {
          ArrayPush(lines, text);
        }
      }
    }
  }

  // Plain text from tooltip text: "" when it can't be shown cleanly.
  public static func Render(const raw: String, data: ref<UILocalizationDataPackage>) -> String {
    if StrLen(raw) == 0 || StrContains(raw, "<Input") {
      return "";
    }
    let text = RLItemText.FillValues(raw, data);
    if StrLen(text) == 0 {
      return "";
    }
    text = RLItemText.StripTags(text);
    text = StrReplaceAll(text, "\n", " ");
    while StrContains(text, "  ") {
      text = StrReplaceAll(text, "  ", " ");
    }
    text = RLItemText.Trim(text);
    if StrLen(text) > RLItemText.MaxLineLength() {
      return "";
    }
    return text;
  }

  // Replaces every {...} placeholder; "" when one can't be filled.
  private static func FillValues(const raw: String, data: ref<UILocalizationDataPackage>) -> String {
    let out = "";
    let rest = raw;
    let open = StrFindFirst(rest, "{");
    while open >= 0 {
      let close = StrFindFirst(StrMid(rest, open), "}");
      if close < 0 {
        return "";
      }
      let key = StrMid(rest, open + 1, close - 1);
      let value: String;
      if !RLItemText.Value(key, data, value) {
        return "";
      }
      out += StrLeft(rest, open) + value;
      rest = StrMid(rest, open + close + 1);
      open = StrFindFirst(rest, "{");
    }
    return out + rest;
  }

  // "float_0", "int_1", "name_0", "stat_0" (anything after a comma or colon
  // is formatting the plain text doesn't need).
  private static func Value(const key: String, data: ref<UILocalizationDataPackage>, out value: String) -> Bool {
    let name = key;
    let cut = StrFindFirst(name, ",");
    if cut >= 0 {
      name = StrLeft(name, cut);
    }
    cut = StrFindFirst(name, ":");
    if cut >= 0 {
      name = StrLeft(name, cut);
    }
    if Equals(name, "__empty__") {
      value = "";
      return true;
    }
    if !IsDefined(data) {
      return false;
    }
    let under = StrFindFirst(name, "_");
    if under < 0 {
      return false;
    }
    let kind = StrLeft(name, under);
    let index = StringToInt(StrMid(name, under + 1));
    if Equals(kind, "float") && index < ArraySize(data.floatValues) {
      value = RLItemText.Number(data.floatValues[index]);
      return true;
    }
    if Equals(kind, "int") && index < ArraySize(data.intValues) {
      value = IntToString(data.intValues[index]);
      return true;
    }
    if Equals(kind, "name") && index < ArraySize(data.nameValues) {
      value = GetLocalizedText(NameToString(data.nameValues[index]));
      return true;
    }
    if Equals(kind, "stat") {
      if index < ArraySize(data.statValues) {
        value = RLItemText.Number(data.statValues[index]);
        return true;
      }
      if index < ArraySize(data.statNames) {
        value = GetLocalizedText(NameToString(data.statNames[index]));
        return true;
      }
    }
    return false;
  }

  private static func Number(value: Float) -> String {
    if AbsF(value - Cast<Float>(RoundF(value))) < 0.05 {
      return IntToString(RoundF(value));
    }
    return FloatToStringPrec(value, 1);
  }

  // Drops <...> markup, keeping the text between tags.
  private static func StripTags(const raw: String) -> String {
    let out = "";
    let rest = raw;
    let open = StrFindFirst(rest, "<");
    while open >= 0 {
      let close = StrFindFirst(StrMid(rest, open), ">");
      if close < 0 {
        break;
      }
      out += StrLeft(rest, open);
      rest = StrMid(rest, open + close + 1);
      open = StrFindFirst(rest, "<");
    }
    return out + rest;
  }

  private static func Trim(const raw: String) -> String {
    let text = raw;
    while StrBeginsWith(text, " ") {
      text = StrMid(text, 1);
    }
    while StrEndsWith(text, " ") {
      text = StrLeft(text, StrLen(text) - 1);
    }
    return text;
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - reward popup
// -----------------------------------------------------------------------------
// The cleared fight's cards (UI/Card.reds), read in one second, wanted in
// two. Every card says the same things in the same order:
//
//   frame    the quality colour (an effect blue, an overclock or duo purple,
//            a legendary gold)
//   banner   the patron's people and logo (effects), the item (gear)
//   kicker   what it is: EFFECT - VOODOO BOYS, OVERCLOCK, TUNE-UP...
//   title    its name
//   effect   one line, the whole decision
//   numbers  the one that matters, before and after (DPS 212 > 268)
//   chips    the keywords it makes and uses, in their colours; NEW when V
//            has never taken it
//   builds   BUILDS ON: the effects V holds it works with
//
// Under the cards, YOUR BUILD: every effect V holds, in its patron's colour.
// Hovering a card lights up the ones it builds on. Below that: reroll,
// banish, skip. A click in the first quarter second is ignored, so a held
// trigger never picks; a pick goes in at once, the picked card swells, the
// rest fall away, and the screen closes. Closing (C / ESC) keeps the cards:
// F7 brings them back.
// -----------------------------------------------------------------------------

module NightCityRoguelite
import Codeware.UI.*

public class RLRewardPopup extends InGamePopup {
  private let m_system: wref<RogueliteSystem>;
  private let m_offers: array<ref<RLOffer>>;
  private let m_title: String;
  private let m_fluff: String;
  private let m_content: ref<InGamePopupContent>;
  private let m_cards: array<wref<RLCard>>;
  // The YOUR BUILD chips and the effect each stands for.
  private let m_buildChips: array<wref<inkWidget>>;
  private let m_buildIDs: array<CName>;
  // Banish mode: the next card clicked is banished instead of taken.
  private let m_banishing: Bool;
  private let m_banishCard: wref<RLCard>;
  private let m_openedAt: Float;
  // The card being picked while its animation plays.
  private let m_picking: Int32;
  private let m_pickProxy: ref<inkAnimProxy>;

  // `fluff`: the header's right-hand line (a patron's tagline); "CHOOSE ONE"
  // when empty.
  public static func Open(system: ref<RogueliteSystem>, offers: array<ref<RLOffer>>, const title: String, opt fluff: String) -> ref<RLRewardPopup> {
    let popup = new RLRewardPopup();
    popup.m_system = system;
    popup.m_offers = offers;
    popup.m_title = title;
    popup.m_fluff = fluff;
    popup.m_picking = -1;
    RLUI.Show(popup);
    return popup;
  }

  public func UseCursor() -> Bool = true

  // No slow motion behind the menu: a menu that fails to show can never
  // leave the game crawling.
  protected func SetTimeDilation() {}

  protected func ResetTimeDilation() {}

  protected cb func OnShown() {
    RLLog("Menu shown.");
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetSize(Vector2(2200.0, 1240.0));
    this.m_openedAt = RLUI.Now();

    let header = InGamePopupHeader.Create();
    header.SetFluffLeft("");
    header.SetTitle(this.m_title);
    header.SetFluffRight(StrLen(this.m_fluff) > 0 ? this.m_fluff : "CHOOSE ONE");
    header.Reparent(this);

    let footer = InGamePopupFooter.Create();
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    let styles = RLStyles.Summary(run, 4);
    footer.SetFluffText(StrLen(styles) > 0 ? "STYLES  " + styles : "STYLES RANK UP AT 3, 6 AND 9 POINTS");
    footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    RLLog(s"Reward menu: building \(ArraySize(this.m_offers)) card(s).");
    this.Build();
  }

  private func Build() {
    let column = RLUI.VPanel(10.0);
    column.SetAnchor(inkEAnchor.Fill);
    column.SetMargin(RLUI.ContentMargin());
    column.Reparent(this.m_content.GetRootCompoundWidget());

    let cards = RLUI.HPanel(18.0);
    cards.SetHAlign(inkEHorizontalAlign.Center);
    cards.SetMargin(inkMargin(0.0, 12.0, 0.0, 0.0));
    cards.Reparent(column);

    let count = ArraySize(this.m_offers);
    let cardWidth = count > 4 ? 380.0 : (count > 3 ? 470.0 : 560.0);
    let i = 0;
    while i < count {
      this.BuildCard(cards, this.m_offers[i], i, cardWidth);
      i += 1;
    }

    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    if IsDefined(run) {
      this.BuildStrip(column, run);
    }

    if IsDefined(this.m_system) {
      let actions = RLUI.HPanel(18.0);
      actions.SetHAlign(inkEHorizontalAlign.Center);
      actions.SetMargin(inkMargin(0.0, 14.0, 0.0, 0.0));
      actions.Reparent(column);
      let reroll = RLRewardPopup.RerollCard(this.m_system, true);
      reroll.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
      reroll.Reparent(actions);
      reroll.PlayIntro(0.08 * Cast<Float>(count));
      if this.HasBanishable() {
        let banishes = this.m_system.GetBanishes();
        let banish = RLCard.Create(n"banish", 420.0, 120.0, banishes > 0 ? n"MainColors.Red" : n"MainColors.Grey");
        banish.SetCompact();
        banish.SetKicker(s"\(banishes) LEFT THIS ACT");
        banish.SetTitle("BANISH");
        banish.SetTitleSize(36);
        banish.SetDisabled(banishes <= 0);
        banish.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
        banish.Reparent(actions);
        banish.PlayIntro(0.08 * Cast<Float>(count + 1));
        this.m_banishCard = banish;
      }
      if this.m_system.CanSkipReward() {
        let skip = RLCard.Create(n"skip", 420.0, 120.0, n"MainColors.Gold");
        skip.SetCompact();
        skip.SetKicker(s"+\(this.m_system.GetSkipEddies()) EDDIES");
        skip.SetTitle("SKIP");
        skip.SetTitleSize(36);
        skip.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
        skip.Reparent(actions);
        skip.PlayIntro(0.08 * Cast<Float>(count + 2));
      }
    }
  }

  // YOUR BUILD: every effect V holds, in its patron's colour, overclocks
  // marked +, favours last.
  private func BuildStrip(parent: ref<inkCompoundWidget>, run: ref<RLRunState>) {
    if ArraySize(run.boons) == 0 {
      return;
    }
    let box = RLUI.VPanel(4.0);
    box.SetHAlign(inkEHorizontalAlign.Center);
    box.SetMargin(inkMargin(0.0, 8.0, 0.0, 0.0));
    box.Reparent(parent);
    let label = RLUI.Text("YOUR BUILD", 24, n"MainColors.Grey", true);
    label.SetHAlign(inkEHorizontalAlign.Center);
    label.Reparent(box);
    let row = RLUI.HPanel(0.0);
    row.SetChildMargin(inkMargin(0.0, 0.0, 10.0, 0.0));
    row.SetHAlign(inkEHorizontalAlign.Center);
    row.Reparent(box);
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && NotEquals(def.kind, RLBoonKind.Favour) {
        this.AddStripChip(row, state.id, RLBoons.HeldName(state), RLPatrons.Accent(def.patron));
      }
    }
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && Equals(def.kind, RLBoonKind.Favour) {
        this.AddStripChip(row, state.id, def.name, RLPatrons.Accent(def.patron));
      }
    }
  }

  private func AddStripChip(row: ref<inkCompoundWidget>, id: CName, const name: String, color: CName) {
    let chip = RLCard.Chip(name, color, 22);
    chip.SetOpacity(0.8);
    chip.Reparent(row);
    ArrayPush(this.m_buildChips, chip);
    ArrayPush(this.m_buildIDs, id);
  }

  private func HasBanishable() -> Bool {
    for offer in this.m_offers {
      if RLRewards.CanBanish(offer) {
        return true;
      }
    }
    return false;
  }

  // The reroll button used by the reward screen and the door picker.
  public static func RerollCard(system: ref<RogueliteSystem>, rewardScreen: Bool) -> ref<RLCard> {
    let charges = system.GetRerollCharges();
    let favour = rewardScreen && system.HasFavourReroll();
    let card = RLCard.Create(n"reroll", 420.0, 120.0, favour || charges > 0 ? n"MainColors.Blue" : n"MainColors.Grey");
    card.SetCompact();
    card.SetKicker(favour ? "FREE - THE AFTERLIFE'S FAVOUR" : (charges > 0 ? s"\(charges) LEFT" : "NONE LEFT THIS ACT"));
    card.SetTitle("REROLL");
    card.SetTitleSize(36);
    card.SetDisabled(!favour && charges <= 0);
    return card;
  }

  private func BuildCard(parent: ref<inkCompoundWidget>, offer: ref<RLOffer>, index: Int32, width: Float) {
    let isEffect = Equals(offer.kind, RLOfferKind.Boon);
    let accent = isEffect && IsNameValid(offer.patron) ? RLPatrons.Accent(offer.patron) : RLRewardPopup.KindAccent(offer.kind);
    let card = RLCard.Create(StringToName("offer_" + IntToString(index)), width, 760.0, accent);
    card.SetCompact();
    RLRewardPopup.SetOfferArt(card, offer, width);
    if NotEquals(offer.kind, RLOfferKind.Perk) {
      card.SetQuality(offer.step);
    }
    card.SetKicker(offer.subtitle);
    card.SetTitle(offer.title);
    card.SetTitleSize(42);
    if offer.isNew {
      card.SetNew();
    }
    // The effect, in one line.
    if StrLen(offer.description) > 0 {
      let warning = offer.disabled || (Equals(offer.kind, RLOfferKind.Cyberware) && offer.amount > 0);
      card.AddLine(offer.description, warning ? n"MainColors.Red" : n"MainColors.ActiveWhite", 30);
    }
    if RLItemText.Wants(offer.kind) {
      RLItemText.AddTo(card, offer.record, n"MainColors.ActiveWhite", 28, 2);
    }
    if StrLen(offer.dpsLine) > 0 {
      card.AddLine(offer.dpsLine, n"MainColors.Yellow", 30);
    }
    let run = IsDefined(this.m_system) ? this.m_system.GetRun() : null;
    if isEffect {
      RLRewardPopup.AddKeywordChips(card, offer);
      if ArraySize(offer.links) > 0 && IsDefined(run) {
        card.AddLine("BUILDS ON: " + RLRewardPopup.LinkNames(run, offer), n"MainColors.Gold", 26);
      }
    } else {
      let styles = RLStyles.OfferLine(run, offer.tags);
      if StrLen(styles) > 0 {
        card.AddLine(styles, RLStyles.IsSynergy(run, offer.tags) ? n"MainColors.Gold" : n"MainColors.Blue", 24);
      }
    }
    card.SetDisabled(offer.disabled);
    card.RegisterToCallback(n"OnBtnClick", this, n"OnButtonClick");
    card.RegisterToCallback(n"OnCardHoverOn", this, n"OnCardHoverOn");
    card.RegisterToCallback(n"OnCardHoverOff", this, n"OnCardHoverOff");
    card.Reparent(parent);
    card.PlayIntro(0.08 * Cast<Float>(index));
    card.PlayReveal(offer.step, 0.08 * Cast<Float>(index));
    ArrayPush(this.m_cards, card);
  }

  // MAKES / USES chips for an effect card, each keyword in its colour.
  private static func AddKeywordChips(card: ref<RLCard>, offer: ref<RLOffer>) {
    let def = RLBoons.Get(offer.boon);
    if !IsDefined(def) {
      return;
    }
    let labels: array<String>;
    let colors: array<CName>;
    for keyword in def.makes {
      ArrayPush(labels, "MAKES " + NameToString(keyword));
      ArrayPush(colors, RLKeywords.Color(keyword));
    }
    for keyword in def.uses {
      if !ArrayContains(def.makes, keyword) && ArraySize(labels) < 4 {
        ArrayPush(labels, "USES " + NameToString(keyword));
        ArrayPush(colors, RLKeywords.Color(keyword));
      }
    }
    card.AddChips(labels, colors);
  }

  // "Arc Flash, Pyre"
  private static func LinkNames(run: ref<RLRunState>, offer: ref<RLOffer>) -> String {
    let text = "";
    for id in offer.links {
      let state = RLBoons.Owned(run, id);
      if IsDefined(state) {
        text += (StrLen(text) > 0 ? ", " : "") + RLBoons.HeldName(state);
      }
    }
    return text;
  }

  // Effects show their patron's people and logo; gear its own picture; gigs
  // the fixer; perks their tree.
  private static func SetOfferArt(card: ref<RLCard>, offer: ref<RLOffer>, width: Float) {
    switch offer.kind {
      case RLOfferKind.Trade:
      case RLOfferKind.Iconic:
      case RLOfferKind.TuneUp:
      case RLOfferKind.Evolve:
        let iconWidth = MinF(width - 56.0, 400.0);
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), iconWidth, iconWidth / 2.0) {
          return;
        }
        break;
      case RLOfferKind.Cyberware:
      case RLOfferKind.Quickhack:
      case RLOfferKind.Grenade:
      case RLOfferKind.HealthUpgrade:
      case RLOfferKind.OperatingSystem:
        if card.SetRecordIcon(RLIcons.ItemIcon(offer.record), 190.0, 190.0) {
          return;
        }
        break;
      case RLOfferKind.Boon:
        card.SetBanner(RLArts.Patron(offer.patron));
        let patron = RLPatrons.Get(offer.patron);
        card.SetBadge(IsDefined(patron) && patron.isLogo ? RLIcons.LogoAtlas() : RLIcons.HubAtlas(), IsDefined(patron) ? patron.iconPart : n"ico_tarot");
        return;
      case RLOfferKind.Gig:
        card.SetBanner(RLArts.Fixer(offer.amount));
        card.SetBadge(RLIcons.HubAtlas(), n"ico_journal");
        return;
      case RLOfferKind.Perk:
        if card.SetRecordIcon(RLPerkCatalog.Icon(offer.perk), 150.0, 150.0) {
          return;
        }
        break;
      default:
        break;
    }
    card.SetAtlasIcon(RLIcons.HubAtlas(), RLRewardPopup.KindPart(offer.kind), 120.0);
  }

  public static func KindAccent(kind: RLOfferKind) -> CName {
    switch kind {
      case RLOfferKind.Trade: return n"MainColors.Red";
      case RLOfferKind.Iconic: return n"MainColors.Gold";
      case RLOfferKind.Cyberware: return n"MainColors.Blue";
      case RLOfferKind.Quickhack: return n"MainColors.Green";
      case RLOfferKind.Boon: return n"MainColors.Purple";
      case RLOfferKind.Grenade: return n"MainColors.Yellow";
      case RLOfferKind.Perk: return n"MainColors.ActiveWhite";
      case RLOfferKind.TuneUp:
      case RLOfferKind.HealthUpgrade: return n"MainColors.Gold";
      case RLOfferKind.Evolve: return n"MainColors.Gold";
      case RLOfferKind.Capacity: return n"MainColors.Blue";
      case RLOfferKind.OperatingSystem: return n"MainColors.Blue";
      case RLOfferKind.Gig: return n"MainColors.Gold";
    }
    return n"MainColors.ActiveWhite";
  }

  public static func KindPart(kind: RLOfferKind) -> CName {
    switch kind {
      case RLOfferKind.Trade: return n"ico_inventory";
      case RLOfferKind.Iconic: return n"ico_inventory";
      case RLOfferKind.Cyberware: return n"ico_cyberware";
      case RLOfferKind.Quickhack: return n"ico_deck";
      case RLOfferKind.Boon: return n"ico_tarot";
      case RLOfferKind.Perk: return n"ico_stats";
      case RLOfferKind.TuneUp: return n"ico_cafting_upgrading";
      case RLOfferKind.HealthUpgrade: return n"ico_cafting_upgrading";
      case RLOfferKind.Grenade: return n"ico_backpack";
      case RLOfferKind.Evolve: return n"ico_cafting_upgrading";
      case RLOfferKind.Capacity: return n"ico_cyberware";
      case RLOfferKind.OperatingSystem: return n"ico_cyberware";
      case RLOfferKind.Gig: return n"ico_journal";
    }
    return n"ico_map";
  }

  // --- Hover: light up what the card builds on ----------------------------------------------

  protected cb func OnCardHoverOn(widget: wref<inkWidget>) -> Bool {
    let index = this.CardIndex(widget);
    if index < 0 {
      return false;
    }
    let links = this.m_offers[index].links;
    let i = 0;
    while i < ArraySize(this.m_buildChips) {
      if IsDefined(this.m_buildChips[i]) {
        this.m_buildChips[i].SetOpacity(ArrayContains(links, this.m_buildIDs[i]) ? 1.0 : 0.3);
      }
      i += 1;
    }
    return true;
  }

  protected cb func OnCardHoverOff(widget: wref<inkWidget>) -> Bool {
    for chip in this.m_buildChips {
      if IsDefined(chip) {
        chip.SetOpacity(0.8);
      }
    }
    return true;
  }

  private func CardIndex(widget: wref<inkWidget>) -> Int32 {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) {
      return -1;
    }
    let name = NameToString(button.GetName());
    if !StrBeginsWith(name, "offer_") {
      return -1;
    }
    let index = StringToInt(StrAfterFirst(name, "_"));
    return index >= 0 && index < ArraySize(this.m_offers) ? index : -1;
  }

  // --- Input -----------------------------------------------------------------------------

  protected cb func OnButtonClick(widget: wref<inkWidget>) -> Bool {
    let button = widget.GetController() as CustomButton;
    if !IsDefined(button) || button.IsDisabled() || !IsDefined(this.m_system) || this.m_picking >= 0 {
      return false;
    }
    // A held trigger from the fight doesn't pick for V.
    if RLUI.Now() - this.m_openedAt < 0.25 {
      return false;
    }
    let name = NameToString(button.GetName());
    if Equals(name, "reroll") {
      this.Close();
      this.m_system.OnRewardReroll();
      return true;
    }
    if Equals(name, "skip") {
      this.Close();
      this.m_system.OnRewardSkip();
      return true;
    }
    if Equals(name, "banish") {
      this.m_banishing = !this.m_banishing;
      if IsDefined(this.m_banishCard) {
        this.m_banishCard.SetSelected(this.m_banishing);
        this.m_banishCard.SetKicker(this.m_banishing ? "NOW PICK A CARD" : s"\(this.m_system.GetBanishes()) LEFT THIS ACT");
      }
      return true;
    }
    let index = this.CardIndex(widget);
    if index < 0 {
      return false;
    }
    if this.m_banishing {
      if RLRewards.CanBanish(this.m_offers[index]) {
        this.Close();
        this.m_system.OnRewardBanish(index);
      }
      return true;
    }
    this.Pick(index);
    return true;
  }

  // The pick goes in at once; the picked card swells, the others fall away,
  // and the screen closes when that's done.
  private func Pick(index: Int32) {
    this.m_picking = index;
    this.m_system.OnRewardChosen(index);
    let i = 0;
    while i < ArraySize(this.m_cards) {
      if IsDefined(this.m_cards[i]) {
        if i == index {
          this.m_pickProxy = this.m_cards[i].PlayPick();
        } else {
          this.m_cards[i].PlayDismiss();
        }
      }
      i += 1;
    }
    if IsDefined(this.m_pickProxy) {
      this.m_pickProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnPickShown");
    } else {
      this.OnPickShown(null);
    }
  }

  protected cb func OnPickShown(proxy: ref<inkAnimProxy>) -> Bool {
    this.Close();
    return true;
  }

  protected cb func OnHide() {
    super.OnHide();
    if IsDefined(this.m_system) {
      this.m_system.OnPopupClosed();
    }
  }
}

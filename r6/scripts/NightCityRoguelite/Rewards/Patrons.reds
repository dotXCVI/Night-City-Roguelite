// -----------------------------------------------------------------------------
// Night City Roguelite - patrons
// -----------------------------------------------------------------------------
// Night City's powers sponsor V's run the way Hades' gods do: a patron door
// leads to a fight whose reward is three boons from that patron. Each patron
// has a style, five boons that grow in rarity, a legendary capstone for V's
// third boon from them, and duo boons shared with other patrons.
//
//   ARASAKA        precision    crits, headshots, first strikes, slow time
//   MILITECH       firepower    ranged and explosive damage, ammo, grenades
//   VOODOO BOYS    the Net      RAM, quickhack damage and spread
//   MAELSTROM      brutality    melee, low-health fury, exploding kills
//   ALDECALDOS     survival     health, speed, damage taken, second winds
//   THE AFTERLIFE  fortune      eddies, lucky hits, cheaper Fixer, more choice
//
// Boon data and effects: Rewards/Boons.reds, Rewards/BoonEffects.reds.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLPatron {
  public let id: CName;
  public let name: String;
  public let tagline: String;
  public let accent: CName;
  // The patron's logo (gang logo atlas; the Afterlife has none and uses the
  // hub menu's tarot icon).
  public let iconPart: CName;
  public let isLogo: Bool;
}

public abstract class RLPatrons {
  public static func All() -> array<ref<RLPatron>> {
    return [
      RLPatrons.Make(n"Arasaka", "ARASAKA", "Precision. Discipline. Loyalty.", n"MainColors.ActiveWhite", n"logo_arasaka", true),
      RLPatrons.Make(n"Militech", "MILITECH", "Overwhelming firepower.", n"MainColors.Yellow", n"logo_militech", true),
      RLPatrons.Make(n"VoodooBoys", "VOODOO BOYS", "The Net remembers.", n"MainColors.Green", n"logo_voodooboys", true),
      RLPatrons.Make(n"Maelstrom", "MAELSTROM", "More chrome. More blood.", n"MainColors.Red", n"logo_maelstrom", true),
      RLPatrons.Make(n"Aldecaldos", "ALDECALDOS", "Family keeps you breathing.", n"MainColors.Gold", n"logo_aldecados", true),
      RLPatrons.Make(n"Afterlife", "THE AFTERLIFE", "Every merc has a price.", n"MainColors.Blue", n"ico_tarot", false)
    ];
  }

  public static func Get(id: CName) -> ref<RLPatron> {
    for patron in RLPatrons.All() {
      if Equals(patron.id, id) {
        return patron;
      }
    }
    return null;
  }

  public static func Name(id: CName) -> String {
    let patron = RLPatrons.Get(id);
    return IsDefined(patron) ? patron.name : "PATRON";
  }

  // The patron behind a door: one V already serves is twice as likely (Hades
  // nudges towards depth), and every patron stays possible.
  public static func PickForDoor(run: ref<RLRunState>) -> CName {
    let patrons = RLPatrons.All();
    let total = 0;
    let weights: array<Int32>;
    for patron in patrons {
      let weight = RLBoons.CountForPatron(run, patron.id) > 0 ? 2 : 1;
      ArrayPush(weights, weight);
      total += weight;
    }
    let roll = RandRange(0, total);
    let i = 0;
    while i < ArraySize(patrons) {
      if roll < weights[i] {
        return patrons[i].id;
      }
      roll -= weights[i];
      i += 1;
    }
    return patrons[0].id;
  }

  public static func Accent(id: CName) -> CName {
    let patron = RLPatrons.Get(id);
    return IsDefined(patron) ? patron.accent : n"MainColors.Purple";
  }

  private static func Make(id: CName, const name: String, const tagline: String, accent: CName, iconPart: CName, isLogo: Bool) -> ref<RLPatron> {
    let patron = new RLPatron();
    patron.id = id;
    patron.name = name;
    patron.tagline = tagline;
    patron.accent = accent;
    patron.iconPart = iconPart;
    patron.isLogo = isLogo;
    return patron;
  }
}

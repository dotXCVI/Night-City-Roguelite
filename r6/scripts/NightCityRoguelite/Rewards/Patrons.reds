// -----------------------------------------------------------------------------
// Night City Roguelite - patrons
// -----------------------------------------------------------------------------
// Night City's powers sponsor V's run the way Hades' gods do: a patron door
// leads to a fight whose reward is a pick of that patron's effects
// (Rewards/Boons.reds). Each patron speaks two keywords:
//
//   ARASAKA        MARK, FOCUS      precision: tag them, slow time, finish
//   MILITECH       BLAST, DRONE     firepower: everything ends in a blast
//   VOODOO BOYS    SHOCK, GLITCH    the Net: current through crowds
//   MAELSTROM      BURN, BLEED      brutality: fire, blood, trophies
//   ALDECALDOS     MOMENTUM, SHIELD the road: keep moving, stay standing
//   THE AFTERLIFE  LUCK, DEAL       fortune: chances, and prices
//
// Four of the six work the city in any one run (RollLineup), shown on the
// terminal before it starts: fifteen line-ups, each a different web.
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

  // Four patrons for a run, at random - with Standing Offer (the terminal),
  // the one V has backed most across runs always among them.
  public static func RollLineup() -> array<CName> {
    let pool: array<CName>;
    for patron in RLPatrons.All() {
      ArrayPush(pool, patron.id);
    }
    let lineup: array<CName>;
    if RLTerminal.Has(n"PatronsEar", 2) {
      let favourite = RLPatrons.MostBacked();
      if IsNameValid(favourite) {
        ArrayPush(lineup, favourite);
        ArrayRemove(pool, favourite);
      }
    }
    while ArraySize(lineup) < 4 && ArraySize(pool) > 0 {
      let i = RandRange(0, ArraySize(pool));
      ArrayPush(lineup, pool[i]);
      ArrayErase(pool, i);
    }
    return lineup;
  }

  // The patron with the most different effects V has ever taken.
  public static func MostBacked() -> CName {
    let service = RogueliteService.Get();
    if !IsDefined(service) {
      return n"";
    }
    let taken = service.GetTakenBoons();
    let best: CName;
    let bestCount = 0;
    for patron in RLPatrons.All() {
      let count = 0;
      for id in taken {
        let def = RLBoons.Get(id);
        if IsDefined(def) && Equals(def.patron, patron.id) {
          count += 1;
        }
      }
      if count > bestCount {
        bestCount = count;
        best = patron.id;
      }
    }
    return best;
  }

  // "ARASAKA, VOODOO BOYS, MAELSTROM, THE AFTERLIFE"
  public static func LineupText(lineup: array<CName>) -> String {
    let text = "";
    for id in lineup {
      text += (StrLen(text) > 0 ? ", " : "") + RLPatrons.Name(id);
    }
    return text;
  }

  // The patron behind a door, from the run's four: one V already serves is
  // twice as likely (Hades nudges towards depth), and every one stays
  // possible.
  public static func PickForDoor(run: ref<RLRunState>) -> CName {
    let patrons = run.patrons;
    if ArraySize(patrons) == 0 {
      patrons = RLPatrons.RollLineup();
    }
    let total = 0;
    let weights: array<Int32>;
    for patron in patrons {
      let weight = RLBoons.CountForPatron(run, patron) > 0 ? 2 : 1;
      ArrayPush(weights, weight);
      total += weight;
    }
    let roll = RandRange(0, total);
    let i = 0;
    while i < ArraySize(patrons) {
      if roll < weights[i] {
        return patrons[i];
      }
      roll -= weights[i];
      i += 1;
    }
    return patrons[0];
  }

  // The patron V leans on most (none before the first effect).
  public static func Lead(run: ref<RLRunState>) -> CName {
    let best = n"";
    let bestCount = 0;
    for patron in run.patrons {
      let count = RLBoons.CountForPatron(run, patron);
      if count > bestCount {
        bestCount = count;
        best = patron;
      }
    }
    return best;
  }

  // The patron's keywords, for cards and the HUD (Militech's DRONE only
  // while the drone is dealt).
  public static func Keywords(id: CName) -> array<CName> {
    switch id {
      case n"Arasaka": return [n"MARK", n"FOCUS"];
      case n"Militech": return RLConfig.DroneEscort() ? [n"BLAST", n"DRONE"] : [n"BLAST"];
      case n"VoodooBoys": return [n"SHOCK", n"GLITCH"];
      case n"Maelstrom": return [n"BURN", n"BLEED"];
      case n"Aldecaldos": return [n"MOMENTUM", n"SHIELD"];
      case n"Afterlife": return [n"LUCK", n"DEAL"];
    }
    let none: array<CName>;
    return none;
  }

  // A short name for the HUD row ("VOODOO").
  public static func ShortName(id: CName) -> String {
    switch id {
      case n"VoodooBoys": return "VOODOO";
      case n"Afterlife": return "AFTERLIFE";
      case n"Aldecaldos": return "ALDECALDOS";
    }
    return RLPatrons.Name(id);
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

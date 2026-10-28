// -----------------------------------------------------------------------------
// Night City Roguelite - effects (patron boons)
// -----------------------------------------------------------------------------
// What the patrons give: rules that change how a fight plays, built as one
// web. Every effect makes, uses or converts a keyword (Combat/Keywords.reds),
// works on its own, and gets better next to the right neighbours:
//
//   Effect      four or five per patron. Taken once, then offered again as its
//               overclock - a stronger version - once V holds it.
//   Weapon      an effect bound to the main weapon (Rewards/Weapons.reds):
//               it works with whatever V has in the slot, blades included,
//               and moves with a trade. Two slots, three on an iconic.
//   Duo         one per pair of patrons, offered once V holds an effect from
//               each.
//   Legendary   the card a build chases, offered once V holds two of the
//               patron's effects.
//   Favour      not a card: three effects from one patron earn it for free
//               (the Binding of Isaac's transformations).
//
// The rules themselves are scripted in Rewards/BoonEffects.reds; this file
// holds the catalogue, what V holds, and the few effects that are stat
// changes on V (added here, removed when the run ends).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public enum RLBoonKind {
  Effect = 0,
  Weapon = 1,
  Duo = 2,
  Legendary = 3,
  Favour = 4,
}

public class RLBoonDef {
  public let id: CName;
  public let patron: CName;
  // Duos: the second patron.
  public let partner: CName;
  public let kind: RLBoonKind;
  public let name: String;
  public let text: String;
  // The overclock's text ("" when the effect has none).
  public let overclock: String;
  // Keywords the effect puts on enemies or V, and keywords it pays off on.
  public let makes: array<CName>;
  public let uses: array<CName>;
  // Build tags for the styles (Rewards/Styles.reds).
  public let tags: array<CName>;
}

// An effect V holds this run.
public class RLBoonState {
  public let id: CName;
  public let overclocked: Bool;
  public let mods: array<ref<gameStatModifierData>>;
}

public abstract class RLBoons {
  // --- Catalogue -----------------------------------------------------------------------

  public static func All() -> array<ref<RLBoonDef>> = RogueliteService.Get().GetBoonCatalog()

  public static func Build() -> array<ref<RLBoonDef>> {
    let list: array<ref<RLBoonDef>>;
    let mark: array<CName> = [n"MARK"];
    let focus: array<CName> = [n"FOCUS"];
    let blast: array<CName> = [n"BLAST"];
    let shock: array<CName> = [n"SHOCK"];
    let glitch: array<CName> = [n"GLITCH"];
    let burn: array<CName> = [n"BURN"];
    let bleed: array<CName> = [n"BLEED"];
    let momentum: array<CName> = [n"MOMENTUM"];
    let shield: array<CName> = [n"SHIELD"];
    let luck: array<CName> = [n"LUCK"];
    let deal: array<CName> = [n"DEAL"];
    let none: array<CName>;

    // Arasaka - precision: MARK the target, slow time, finish it.
    RLBoons.Effect(list, n"DeadeyeTag", n"Arasaka", "Deadeye Tag", mark, none,
      "Headshots MARK the target for 6 s. You deal +25% to MARKED enemies.",
      "A MARK jumps to the nearest enemy when its target dies.", [n"precision"]);
    RLBoons.Effect(list, n"KiroshiUplink", n"Arasaka", "Kiroshi Uplink", mark, none,
      "Your first hit on each enemy MARKS it.",
      "Quickhacks MARK everyone within 5 m of their target.", [n"precision"]);
    RLBoons.Effect(list, n"ExecutionOrder", n"Arasaka", "Execution Order", none, mark,
      "MARKED enemies under 25% health die to your next hit. Not bosses.",
      "Under 35% - and every execution MARKS everyone within 8 m.", [n"precision"]);
    RLBoons.Effect(list, n"Zanshin", n"Arasaka", "Zanshin", focus, mark,
      "Killing a MARKED enemy slows time for 1.5 s: FOCUS. Without MARKS, every 5th kill does.",
      "Every kill during FOCUS adds half a second.", [n"precision"]);
    RLBoons.Effect(list, n"Kensei", n"Arasaka", "Kensei", none, focus,
      "Your hits during FOCUS always crit. Dropping under 30% health triggers FOCUS, once a fight.",
      "Crits during FOCUS MARK.", [n"precision"]);
    RLBoons.WeaponEffect(list, n"TracerRounds", n"Arasaka", "Tracer Rounds", mark, none,
      "Every 3rd hit on the same enemy with your main weapon MARKS it.",
      "Every 2nd hit.");
    RLBoons.Legendary(list, n"DeathSentence", n"Arasaka", "Death Sentence", mark, mark,
      "MARKS never wear off, and killing a MARKED enemy MARKS everyone within 15 m.");

    // Militech - firepower: everything ends in a BLAST.
    RLBoons.Effect(list, n"KillSwitch", n"Militech", "Kill Switch", blast, none,
      "Kills fire a micro-missile at the nearest enemy: a small BLAST.",
      "Two missiles, at two enemies.", [n"explosive"]);
    RLBoons.Effect(list, n"ShapedCharge", n"Militech", "Shaped Charge", none, blast,
      "Your BLASTs deal +40% and knock enemies down. Grenades count.",
      "Your own BLASTs reach 50% further.", [n"explosive"]);
    RLBoons.Effect(list, n"Ordnance", n"Militech", "Ordnance", none, blast,
      "+1 grenade charge. Every 4th BLAST kill hands a grenade back.",
      "Every 2nd BLAST kill.", [n"explosive"]);
    RLBoons.Effect(list, n"Shrapnel", n"Militech", "Shrapnel", bleed, blast,
      "Your BLASTs make everything they hit BLEED.",
      "Shrapnel MARKS too.", [n"explosive"]);
    if RLConfig.DroneEscort() {
      RLBoons.Effect(list, n"DroneEscort", n"Militech", "Drone Escort", [n"DRONE"], none,
        "A Militech drone fights beside you in every fight.",
        "Its hits carry your MARK, SHOCK and BURN.", [n"tech"]);
    }
    RLBoons.WeaponEffect(list, n"Payload", n"Militech", "Payload", blast, none,
      "Every 6th hit with your main weapon explodes: a BLAST on the target.",
      "Every 4th hit.");
    RLBoons.Legendary(list, n"FireMission", n"Militech", "Fire Mission", blast, blast,
      "Every 20th BLAST calls down an orbital strike on the biggest group of enemies.");

    // Voodoo Boys - the Net: SHOCK them, GLITCH their chrome.
    RLBoons.Effect(list, n"ArcFlash", n"VoodooBoys", "Arc Flash", shock, none,
      "Crits arc to 2 nearby enemies for 40% of the hit and SHOCK them.",
      "Arcs to 3, and arcs can crit.", [n"netrunner"]);
    RLBoons.Effect(list, n"FeedbackLoop", n"VoodooBoys", "Feedback Loop", none, shock,
      "SHOCKED enemies take +30% damage from everything.",
      "SHOCKED enemies SHOCK their neighbours when they die.", [n"netrunner"]);
    RLBoons.Effect(list, n"GhostProtocol", n"VoodooBoys", "Ghost Protocol", glitch, shock,
      "Quickhacks and SHOCK also GLITCH for 6 s: no dodging, no Sandevistan, no healing.",
      "Main weapon hits on GLITCHED enemies give back RAM.", [n"netrunner"]);
    RLBoons.Effect(list, n"DaisyChain", n"VoodooBoys", "Daisy Chain", shock, none,
      "A quickhack kill jumps: the nearest enemy is SHOCKED and loses 15% health.",
      "It jumps twice.", [n"netrunner"]);
    RLBoons.WeaponEffect(list, n"ThunderRounds", n"VoodooBoys", "Thunder Rounds", shock, none,
      "Headshots and strong attacks with your main weapon call down a SHOCK strike.",
      "The strike SHOCKS everything within 4 m.");
    RLBoons.Legendary(list, n"BlackwallGate", n"VoodooBoys", "Blackwall Gate", shock, shock,
      "SHOCK keeps arcing: every SHOCK you land jumps to a new enemy each second until it runs out of targets.");

    // Maelstrom - brutality: BURN and BLEED, and grow off the bodies.
    RLBoons.Effect(list, n"Pyre", n"Maelstrom", "Pyre", blast, burn,
      "BURNING enemies explode when they die: a BLAST that sets their neighbours on fire.",
      "Bigger, and the fire spreads to two more.", [n"explosive"]);
    RLBoons.Effect(list, n"Bloodletter", n"Maelstrom", "Bloodletter", bleed, none,
      "Crits and melee hits make enemies BLEED, stacking up to 3 times.",
      "Stacks up to 5 times.", [n"melee"]);
    RLBoons.Effect(list, n"RedMist", n"Maelstrom", "Red Mist", none, [n"BURN", n"BLEED"],
      "Regain 2% health a second while an enemy within 10 m is BURNING or BLEEDING.",
      "Also +15% damage while it's on.", [n"melee"]);
    RLBoons.Effect(list, n"TrophyWall", n"Maelstrom", "Trophy Wall", none, none,
      "Every 10 kills: +5% damage for the rest of the run. No cap.",
      "Melee, BURN and BLEED kills count double.", [n"melee"]);
    RLBoons.WeaponEffect(list, n"HotBarrel", n"Maelstrom", "Hot Barrel", burn, none,
      "Keep firing or swinging and your main weapon heats up. At full heat its hits BURN.",
      "Heats up twice as fast.");
    RLBoons.Legendary(list, n"Cyberpsychosis", n"Maelstrom", "Cyberpsychosis", [n"BURN", n"BLEED"], none,
      "Under half health: +60% damage, and every hit BURNS and BLEEDS.");

    // Aldecaldos - the road: keep moving, MOMENTUM and SHIELDS.
    RLBoons.Effect(list, n"Slipstream", n"Aldecaldos", "Slipstream", momentum, none,
      "Sprinting, sliding and dashing build MOMENTUM, up to 5. Each stack: +6% damage and speed. A hit taken costs one.",
      "Up to 8.", [n"mobility"]);
    RLBoons.Effect(list, n"RoadWarrior", n"Aldecaldos", "Road Warrior", none, momentum,
      "Full MOMENTUM, or 2 s of sprinting, charges your next hit: double damage and a knockdown.",
      "Charged hits BLAST.", [n"mobility"]);
    RLBoons.Effect(list, n"KineticDash", n"Aldecaldos", "Kinetic Dash", none, none,
      "Dashing past enemies within 3 m knocks them down.",
      "Knocked-down enemies take +30%.", [n"mobility"]);
    RLBoons.Effect(list, n"HoloMantle", n"Aldecaldos", "Holo-Mantle", shield, none,
      "The first hit you take in each fight is absorbed by a SHIELD.",
      "The SHIELD comes back after 20 s without taking damage.", [n"survival"]);
    RLBoons.Effect(list, n"RiotPlating", n"Aldecaldos", "Riot Plating", shock, shield,
      "While SHIELDED, dashing into an enemy sends it flying. A breaking SHIELD SHOCKS everything near you.",
      "Rams BLAST on impact.", [n"survival"]);
    RLBoons.WeaponEffect(list, n"KineticRounds", n"Aldecaldos", "Kinetic Rounds", none, momentum,
      "For 2 s after a dash or slide, hits with your main weapon knock enemies down. At full MOMENTUM, always.",
      "Those hits deal +30%.");
    RLBoons.Legendary(list, n"NomadRun", n"Aldecaldos", "Nomad Run", momentum, momentum,
      "MOMENTUM goes up to 20, and from 10 stacks your hits knock enemies down.");

    // The Afterlife - fortune: LUCK, and DEALS with a price.
    RLBoons.Effect(list, n"LoadedDice", n"Afterlife", "Loaded Dice", luck, none,
      "+10% crit chance. Hit counters (Payload, Hot Barrel, Tracer and Lucky Rounds) count crits twice.",
      "+20% crit chance.", [n"precision"]);
    RLBoons.Effect(list, n"Jackpot", n"Afterlife", "Jackpot", none, luck,
      "When a chance effect fires, 1 in 10 times it hits the jackpot and goes off three times.",
      "1 in 5.", none);
    RLBoons.Effect(list, n"Cocktail", n"Afterlife", "Cocktail", none, [n"MARK", n"SHOCK", n"GLITCH", n"BURN", n"BLEED"],
      "An enemy carrying three different statuses bursts: every one of them copies onto everyone within 5 m.",
      "Two statuses are enough.", none);
    RLBoons.Effect(list, n"LoanShark", n"Afterlife", "Loan Shark", deal, none,
      "Three fights at -25% max health. Then +40% damage for the rest of the run.",
      "One fight fewer.", none);
    RLBoons.WeaponEffect(list, n"LuckyRound", n"Afterlife", "Lucky Round", luck, none,
      "Every 8th hit with your main weapon deals triple damage.",
      "Every 6th hit.");
    RLBoons.Legendary(list, n"GlassChrome", n"Afterlife", "Glass Chrome", deal, none,
      "+100% damage. -50% max health.");
    RLBoons.Legendary(list, n"LuckyBreak", n"Afterlife", "Lucky Break", none, luck,
      "Every chance effect rolls twice, and your crit chance doubles.");

    // Duos: one for every pair of patrons.
    RLBoons.Duo(list, n"GhostShot", n"Arasaka", n"VoodooBoys", "Ghost Shot", [n"SHOCK", n"MARK"], [n"MARK", n"SHOCK"],
      "Quickhacks on MARKED enemies SHOCK them, and SHOCKED enemies are MARKED.");
    RLBoons.Duo(list, n"SmartLink", n"Arasaka", n"Militech", "Smart Link", none, [n"MARK", n"BLAST"],
      "Kill Switch missiles go for MARKED enemies first, and your BLASTs deal +50% to MARKED enemies.");
    RLBoons.Duo(list, n"Hemorrhage", n"Arasaka", n"Maelstrom", "Hemorrhage", bleed, [n"MARK", n"BLEED"],
      "MARKED enemies BLEED, and BLEEDING enemies count as MARKED.");
    RLBoons.Duo(list, n"BulletTime", n"Arasaka", n"Aldecaldos", "Bullet Time", focus, momentum,
      "A dash at full MOMENTUM triggers FOCUS.");
    RLBoons.Duo(list, n"DeadMansHand", n"Arasaka", n"Afterlife", "Dead Man's Hand", none, [n"MARK", n"LUCK"],
      "Every execution flips a coin. Heads, the nearest enemy is executed too. Not bosses.");
    RLBoons.Duo(list, n"EMPPayload", n"Militech", n"VoodooBoys", "EMP Payload", [n"SHOCK", n"GLITCH"], blast,
      "Your BLASTs SHOCK and GLITCH everything they hit.");
    RLBoons.Duo(list, n"Napalm", n"Militech", n"Maelstrom", "Napalm", burn, blast,
      "Your BLASTs set everything they hit on fire.");
    RLBoons.Duo(list, n"Convoy", n"Militech", n"Aldecaldos", "Convoy", blast, none,
      "Every dash drops a charge that BLASTs a second later.");
    RLBoons.Duo(list, n"HouseEdge", n"Militech", n"Afterlife", "House Edge", blast, [n"BLAST", n"LUCK"],
      "1 in 4 of your BLASTs goes off again a second later - and the echo can echo.");
    RLBoons.Duo(list, n"ShortCircuit", n"VoodooBoys", n"Maelstrom", "Short Circuit", shock, burn,
      "BURNING enemies are SHOCKED too.");
    RLBoons.Duo(list, n"StaticShield", n"VoodooBoys", n"Aldecaldos", "Static Shield", [n"SHOCK", n"GLITCH"], shield,
      "While SHIELDED, enemies that hit you are SHOCKED and GLITCHED.");
    RLBoons.Duo(list, n"RiggedICE", n"VoodooBoys", n"Afterlife", "Rigged ICE", shock, luck,
      "1 in 4 quickhacks refunds 4 RAM and SHOCKS the nearest other enemy too.");
    RLBoons.Duo(list, n"Burnout", n"Maelstrom", n"Aldecaldos", "Burnout", burn, none,
      "Dashing sets everyone within 4 m on fire.");
    RLBoons.Duo(list, n"BloodMoney", n"Maelstrom", n"Afterlife", "Blood Money", none, [n"BURN", n"BLEED", n"LUCK"],
      "1 in 4 BURN or BLEED kills passes the victim's fire and blood to the nearest enemy.");
    RLBoons.Duo(list, n"Getaway", n"Aldecaldos", n"Afterlife", "Getaway", none, [n"MOMENTUM", n"LUCK"],
      "At full MOMENTUM, 1 in 3 dashes comes straight back and makes you untouchable for 1 s.");

    // Favours: earned with three effects from one patron.
    RLBoons.Favour(list, n"Favour_Arasaka", n"Arasaka", "Arasaka's Favour", "Elites, bosses and the first enemy you see in every wave start MARKED.");
    RLBoons.Favour(list, n"Favour_Militech", n"Militech", "Militech's Favour", "Your BLASTs and grenades can't hurt you, and +1 grenade charge.");
    RLBoons.Favour(list, n"Favour_VoodooBoys", n"VoodooBoys", "The Loa's Favour", "SHOCKED enemies arc to each other every 2 s.");
    RLBoons.Favour(list, n"Favour_Maelstrom", n"Maelstrom", "Maelstrom's Favour", "Fire and bleeding can't hurt you, and standing in fire heals you.");
    RLBoons.Favour(list, n"Favour_Aldecaldos", n"Aldecaldos", "Family's Favour", "Every fight starts at full MOMENTUM with a SHIELD up.");
    RLBoons.Favour(list, n"Favour_Afterlife", n"Afterlife", "The Afterlife's Favour", "One free reroll on every reward screen.");
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

  public static func KindName(kind: RLBoonKind) -> String {
    switch kind {
      case RLBoonKind.Weapon: return "WEAPON EFFECT";
      case RLBoonKind.Duo: return "DUO";
      case RLBoonKind.Legendary: return "LEGENDARY";
      case RLBoonKind.Favour: return "FAVOUR";
    }
    return "EFFECT";
  }

  // Effects that count for a patron's favour and legendary.
  public static func CountsForPatron(def: ref<RLBoonDef>) -> Bool {
    return Equals(def.kind, RLBoonKind.Effect) || Equals(def.kind, RLBoonKind.Weapon);
  }

  // The name V sees for an effect it holds: "Arc Flash+" once overclocked.
  public static func HeldName(state: ref<RLBoonState>) -> String {
    let def = RLBoons.Get(state.id);
    if !IsDefined(def) {
      return NameToString(state.id);
    }
    return state.overclocked ? def.name + "+" : def.name;
  }

  // --- Run state -------------------------------------------------------------------------

  public static func Owned(run: ref<RLRunState>, id: CName) -> ref<RLBoonState> {
    if IsDefined(run) {
      for state in run.boons {
        if Equals(state.id, id) {
          return state;
        }
      }
    }
    return null;
  }

  public static func Has(run: ref<RLRunState>, id: CName) -> Bool = IsDefined(RLBoons.Owned(run, id))

  public static func IsOverclocked(run: ref<RLRunState>, id: CName) -> Bool {
    let state = RLBoons.Owned(run, id);
    return IsDefined(state) && state.overclocked;
  }

  public static func CountForPatron(run: ref<RLRunState>, patron: CName) -> Int32 {
    let count = 0;
    if IsDefined(run) {
      for state in run.boons {
        let def = RLBoons.Get(state.id);
        if IsDefined(def) && RLBoons.CountsForPatron(def) && Equals(def.patron, patron) {
          count += 1;
        }
      }
    }
    return count;
  }

  // Weapon effects on the main weapon.
  public static func WeaponEffectCount(run: ref<RLRunState>) -> Int32 {
    let count = 0;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && Equals(def.kind, RLBoonKind.Weapon) {
        count += 1;
      }
    }
    return count;
  }

  // Every keyword V's effects put on enemies or V.
  public static func Makes(run: ref<RLRunState>) -> array<CName> {
    let made: array<CName>;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) {
        for keyword in def.makes {
          if !ArrayContains(made, keyword) {
            ArrayPush(made, keyword);
          }
        }
      }
    }
    return made;
  }

  // The effects V holds that a card works with: what it uses that they make,
  // what it makes that they use, its parents for a duo or an overclock.
  public static func Links(run: ref<RLRunState>, def: ref<RLBoonDef>) -> array<CName> {
    let links: array<CName>;
    for state in run.boons {
      let held = RLBoons.Get(state.id);
      if IsDefined(held) && NotEquals(held.id, def.id) && !Equals(held.kind, RLBoonKind.Favour) {
        let linked = false;
        for keyword in def.uses {
          if ArrayContains(held.makes, keyword) {
            linked = true;
          }
        }
        for keyword in def.makes {
          if ArrayContains(held.uses, keyword) {
            linked = true;
          }
        }
        if Equals(def.kind, RLBoonKind.Duo) && (Equals(held.patron, def.patron) || Equals(held.patron, def.partner)) && RLBoons.CountsForPatron(held) {
          linked = true;
        }
        if linked {
          ArrayPush(links, held.id);
        }
      }
    }
    return links;
  }

  // Can this effect (or its overclock) be offered right now?
  public static func IsOfferable(run: ref<RLRunState>, def: ref<RLBoonDef>) -> Bool {
    let state = RLBoons.Owned(run, def.id);
    if Equals(def.id, n"LoanShark") && !IsDefined(state) && !RLBoons.CanCutHealth(run, 0.25) {
      return false;
    }
    // Quickhacks never headshot or swing: Thunder Rounds has nothing to do
    // on a deck.
    if Equals(def.id, n"ThunderRounds") && RLArms.IsMainDeck(run) {
      return false;
    }
    if ArrayContains(run.banished, "boon:" + NameToString(def.id)) {
      return false;
    }
    switch def.kind {
      case RLBoonKind.Favour:
        return false;
      case RLBoonKind.Legendary:
        if Equals(def.id, n"GlassChrome") && !RLBoons.CanCutHealth(run, 0.5) {
          return false;
        }
        return !IsDefined(state) && RLBoons.CountForPatron(run, def.patron) >= 2;
      case RLBoonKind.Duo:
        return !IsDefined(state) && RLBoons.CountForPatron(run, def.patron) > 0 && RLBoons.CountForPatron(run, def.partner) > 0;
      case RLBoonKind.Weapon:
        if !IsDefined(state) && RLBoons.WeaponEffectCount(run) >= RLWeapons.EffectSlots(run) {
          return false;
        }
        break;
    }
    return !IsDefined(state) || (!state.overclocked && StrLen(def.overclock) > 0);
  }

  // Max health V's deals have taken: event trade-offs, Glass Chrome and a
  // running loan. Never past three quarters - a deal that would go further
  // isn't offered.
  public static func HealthCut(run: ref<RLRunState>) -> Float {
    let cut = run.healthCut;
    if RLBoons.Has(run, n"GlassChrome") {
      cut += 0.5;
    }
    if RLBoons.Has(run, n"LoanShark") && run.loanFights > 0 {
      cut += 0.25;
    }
    return cut;
  }

  public static func CanCutHealth(run: ref<RLRunState>, cut: Float) -> Bool = RLBoons.HealthCut(run) + cut <= 0.751

  // Takes an effect: new, or its overclock. Stat changes are swapped for the
  // overclock's, and three from one patron bring the patron's favour.
  public static func Apply(player: ref<PlayerPuppet>, run: ref<RLRunState>, id: CName, overclock: Bool) {
    let def = RLBoons.Get(id);
    if !IsDefined(def) || !IsDefined(player) {
      return;
    }
    let state = RLBoons.Owned(run, id);
    let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
    let objectID = Cast<StatsObjectID>(player.GetEntityID());
    if IsDefined(state) {
      for mod in state.mods {
        statsSystem.RemoveModifier(objectID, mod);
      }
      ArrayClear(state.mods);
      state.overclocked = state.overclocked || overclock;
    } else {
      state = new RLBoonState();
      state.id = id;
      state.overclocked = overclock;
      ArrayPush(run.boons, state);
      RogueliteService.Get().MarkBoonTaken(id);
    }
    switch id {
      case n"Ordnance":
      case n"Favour_Militech":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.GrenadesMaxCharges, gameStatModifierType.Additive, 1.0));
        break;
      case n"LoadedDice":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.CritChance, gameStatModifierType.Additive, state.overclocked ? 20.0 : 10.0));
        break;
      case n"LuckyBreak":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.CritChance, gameStatModifierType.Multiplier, 2.0));
        break;
      case n"GlassChrome":
        ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, -0.5));
        break;
      case n"LoanShark":
        if run.loanFights <= 0 && !overclock {
          run.loanFights = 3;
        }
        if overclock {
          run.loanFights = Max(0, run.loanFights - 1);
        }
        if run.loanFights > 0 {
          ArrayPush(state.mods, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.AdditiveMultiplier, -0.25));
        }
        break;
    }
    for mod in state.mods {
      statsSystem.AddModifier(objectID, mod);
    }
    RLBoons.CheckFavour(player, run, def.patron);
  }

  // Three effects from one patron: the favour lands, once.
  private static func CheckFavour(player: ref<PlayerPuppet>, run: ref<RLRunState>, patron: CName) {
    let favour = StringToName("Favour_" + NameToString(patron));
    if !IsNameValid(patron) || RLBoons.Has(run, favour) || RLBoons.CountForPatron(run, patron) < 3 {
      return;
    }
    let def = RLBoons.Get(favour);
    if !IsDefined(def) {
      return;
    }
    RLBoons.Apply(player, run, favour, false);
    RLNotify(player.GetGame(), StrUpper(def.name) + ": " + def.text, 7.0);
    RLLog("Favour earned: " + def.name + ".");
  }

  // The loan is paid off: the health comes back, the damage stays.
  public static func SettleLoan(player: ref<PlayerPuppet>, run: ref<RLRunState>) {
    let state = RLBoons.Owned(run, n"LoanShark");
    if !IsDefined(state) || !IsDefined(player) {
      return;
    }
    let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
    for mod in state.mods {
      statsSystem.RemoveModifier(Cast<StatsObjectID>(player.GetEntityID()), mod);
    }
    ArrayClear(state.mods);
    RLNotify(player.GetGame(), "LOAN PAID OFF. +40% damage, for good.", 5.0);
  }

  // Takes an effect away (an event trade): its stat changes go too. A
  // favour already earned stays.
  public static func Remove(player: ref<PlayerPuppet>, run: ref<RLRunState>, id: CName) {
    let state = RLBoons.Owned(run, id);
    if !IsDefined(state) {
      return;
    }
    if IsDefined(player) {
      let statsSystem = GameInstance.GetStatsSystem(player.GetGame());
      for mod in state.mods {
        statsSystem.RemoveModifier(Cast<StatsObjectID>(player.GetEntityID()), mod);
      }
    }
    ArrayRemove(run.boons, state);
  }

  // A random effect V holds that an event can take (no favours), or none.
  public static func RandomOwned(run: ref<RLRunState>) -> CName {
    let ids: array<CName>;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && !Equals(def.kind, RLBoonKind.Favour) {
        ArrayPush(ids, state.id);
      }
    }
    return ArraySize(ids) > 0 ? ids[RandRange(0, ArraySize(ids))] : n"";
  }

  // Overclocks up to `count` random effects V holds; returns how many.
  public static func OverclockRandom(player: ref<PlayerPuppet>, run: ref<RLRunState>, count: Int32) -> Int32 {
    let ids: array<CName>;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && !state.overclocked && StrLen(def.overclock) > 0 {
        ArrayPush(ids, state.id);
      }
    }
    let done = 0;
    while done < count && ArraySize(ids) > 0 {
      let i = RandRange(0, ArraySize(ids));
      RLBoons.Apply(player, run, ids[i], true);
      ArrayErase(ids, i);
      done += 1;
    }
    return done;
  }

  public static func CanOverclockAny(run: ref<RLRunState>) -> Bool {
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && !state.overclocked && StrLen(def.overclock) > 0 {
        return true;
      }
    }
    return false;
  }

  // A legendary V qualifies for and doesn't hold, or none.
  public static func QualifiedLegendary(run: ref<RLRunState>) -> CName {
    for def in RLBoons.All() {
      if Equals(def.kind, RLBoonKind.Legendary) && ArrayContains(run.patrons, def.patron) && RLBoons.IsOfferable(run, def) {
        return def.id;
      }
    }
    return n"";
  }

  // Overclocks every effect V holds that has one; returns how many.
  public static func OverclockAll(player: ref<PlayerPuppet>, run: ref<RLRunState>) -> Int32 {
    let ids: array<CName>;
    for state in run.boons {
      let def = RLBoons.Get(state.id);
      if IsDefined(def) && !state.overclocked && StrLen(def.overclock) > 0 {
        ArrayPush(ids, state.id);
      }
    }
    for id in ids {
      RLBoons.Apply(player, run, id, true);
    }
    return ArraySize(ids);
  }

  // Leftovers from builds before effects (HUD buffs of the old boons).
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
      for state in run.boons {
        for mod in state.mods {
          statsSystem.RemoveModifier(objectID, mod);
        }
      }
    }
    ArrayClear(run.boons);
  }

  // --- Definitions -----------------------------------------------------------------------

  private static func Effect(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, makes: array<CName>, uses: array<CName>, const text: String, const overclock: String, tags: array<CName>) {
    let def = RLBoons.Def(id, patron, n"", RLBoonKind.Effect, name, text, makes, uses);
    def.overclock = overclock;
    def.tags = tags;
    ArrayPush(list, def);
  }

  private static func WeaponEffect(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, makes: array<CName>, uses: array<CName>, const text: String, const overclock: String) {
    let def = RLBoons.Def(id, patron, n"", RLBoonKind.Weapon, name, text, makes, uses);
    def.overclock = overclock;
    ArrayPush(list, def);
  }

  private static func Legendary(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, makes: array<CName>, uses: array<CName>, const text: String) {
    ArrayPush(list, RLBoons.Def(id, patron, n"", RLBoonKind.Legendary, name, text, makes, uses));
  }

  private static func Duo(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, partner: CName, const name: String, makes: array<CName>, uses: array<CName>, const text: String) {
    ArrayPush(list, RLBoons.Def(id, patron, partner, RLBoonKind.Duo, name, text, makes, uses));
  }

  private static func Favour(out list: array<ref<RLBoonDef>>, id: CName, patron: CName, const name: String, const text: String) {
    let none: array<CName>;
    ArrayPush(list, RLBoons.Def(id, patron, n"", RLBoonKind.Favour, name, text, none, none));
  }

  private static func Def(id: CName, patron: CName, partner: CName, kind: RLBoonKind, const name: String, const text: String, makes: array<CName>, uses: array<CName>) -> ref<RLBoonDef> {
    let def = new RLBoonDef();
    def.id = id;
    def.patron = patron;
    def.partner = partner;
    def.kind = kind;
    def.name = name;
    def.text = text;
    def.makes = makes;
    def.uses = uses;
    return def;
  }
}

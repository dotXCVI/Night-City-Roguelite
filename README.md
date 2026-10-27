# Night City Roguelite (v0.0.17)

> **Versions:** alpha builds are v0.0.X. v0.X.X starts once the foundation is
> solid, v1.0.0 is the finished mod. (Builds before v0.0.8 were numbered
> v0.1-v0.7; they are the same series.)

A run-based arena mode for Cyberpunk 2077 2.5, built only from the game's own
assets and systems. Start a new roguelite character from the main menu, fight
through 3 acts of 6 arenas (bosses on floors 6, 12 and 18), pick one of three
rewards after every floor, and bank meta Cred when you flatline. Home is where
a run starts and ends; in between you go from arena to arena. The design rule:
fights should be easy to read, and all the thinking happens between them.

> **Status:** v0.0.15 was tested in game; v0.0.16 and v0.0.17 fix what
> that test turned up and are untested. See CHANGELOG.md for every version. Start a **new** roguelite character for this build. Compiles cleanly with redscript 0.5.32 against the 2.5 game scripts, Codeware 1.21.0
> and TweakXL 1.12.0.

## Requirements

- Cyberpunk 2077 **2.5** with **Phantom Liberty** (the mode uses the
  Phantom Liberty standalone start to skip the story)
- RED4ext 1.31.0+, redscript 0.5.32+, Codeware 1.21.0+, TweakXL 1.12.0+,
  ArchiveXL (for the mod's own text: the computer prompt and buff names)

redscript is what compiles `.reds` files when the game starts. Without it the
mod does nothing at all, and there is no ROGUELITE entry in the menu.

No CET is needed.

## Install

Copy the `r6` and `archive` folders into the game folder, so you have
`Cyberpunk 2077/r6/scripts/NightCityRoguelite/`,
`Cyberpunk 2077/r6/tweaks/NightCityRoguelite/` and
`Cyberpunk 2077/archive/pc/mod/NightCityRoguelite.archive` (+ `.archive.xl`).
With Vortex or MO2, install the zip as a normal mod.

The archive skips the Phantom Liberty opening (book scene and Songbird's call)
for roguelite characters only; normal new games play it as usual. It keeps the
screen black until the mod has V in the apartment (at most 45 seconds). It replaces
one quest file, so a future game patch that changes that file needs a rebuilt
archive (`source/quest-patch/README.md`). Without the archive the mod still
works: it just waits for the opening call to end before taking over.

## How to play

1. Main menu -> **ROGUELITE** (top of the list). The campaign, difficulty,
   life path, origin and attribute screens are all skipped (the mod sets them);
   you go straight to the body type screen. Make your V, confirm.
2. There's no opening scene: the screen stays black while the mod resets V to
   level 1 (clothes kept) and moves V into **V's apartment in Megabuilding
   H10**, then fades in with V standing inside. The front door is sealed.
3. Use **V's computer** (prompt: "Roguelite Terminal") or press **F7** for the
   terminal: pick one of 8 kits (locked kits are bought by clicking them), buy
   unlocks, toggle **ASSIST**, then **START RUN**.
4. The first fight is a light fight in a random arena. Every trip fades to
   black with the destination on screen and fades back in once the area has
   loaded; the first wave comes after a 5-second countdown. The arena is
   ringed by a solid wall that lights up as red NCPD holo-tape as you walk up
   to it.
5. Clearing a wave refills part of your ammo and one health charge. Clear the
   last one and the reward screen opens right there: pick one of three rewards
   of that fight's type - every pick also grants +1 level.
6. Then pick your next fight by its reward, Hades-style, and travel straight
   there (V patches up on the way). Each door shows the reward type, the
   threat, the arena and the gang you'll face:

   | Reward | What you choose from | Threat |
   | --- | --- | --- |
   | TRAINING | Perks, granted outright | Light |
   | ARMORY | Weapons and grenades (sometimes an iconic) | Standard |
   | PATRON | Boons from one of Night City's powers (see Patrons) | Standard |
   | DAEMONS | Quickhacks | Standard |
   | WORKSHOP | Upgrade a weapon, your MaxDoc or your grenade | Standard |
   | CHROME | Cyberware, installed on the spot (from floor 3) | Heavy |
   | ICONIC | Iconic weapons (rare door, from floor 3) | Heavy |
   | BOUNTY | A lone cyberpsycho; pays eddies and a patron's boons (Act 2+) | Heavy |
   | ? | An event instead of a fight (from floor 2) | - |

   Light fights have smaller waves of weaker enemies; heavy fights have bigger
   waves (an extra wave in Act 3) and roll better rewards. From floor 3 some
   fights come with an **objective** (see Objectives). Before a boss floor
   there is a single boss door.
7. After each elite floor, before the boss door, the **Fixer** is in: spend
   the eddies you've earned.
8. When health hits zero V dies - for real, the game's own death - and comes
   to back home, ready for the next run. Quitting or crashing mid-run counts as
   a flatline too. A run won ends with the trip home as well.

Cred is earned for every arena you clear (never for a lost one), plus a bonus
for completing a run. Experience comes only from rewards: kills and skill use
give none, and levels bring no attribute or perk points (see Character).

| Computer or F7 at home | F7 during a fight | F7 between fights |
| --- | --- | --- |
| Terminal (kit, run start) | Run status, abandon | Reward, Fixer or next fight |

**Test runs:** the terminal's FLOOR card picks a floor (1, 5, 6, 7, 11, 12, 13,
17 or 18) and TEST RUN starts there, with the levels, eddies and three Rare
boons a run would have by then. Every door screen offers an event and (from Act
2) a bounty, and fights roll objectives more often. Test runs pay no Cred and
don't count in the stats - they're for trying bosses and new content quickly.

**Found a bug?** Press **F8** (or MARK BUG on the F7 screen in a fight) the moment it
happens. The log gets a snapshot of the fight - state, wave, every enemy's
position and health - so the report can say exactly where to look.

Closing a reward, Fixer or door screen (C / ESC) keeps it waiting - F7 brings it
back. Saving is locked during a run. Normal story saves are never touched. For
roguelite characters NCPD is switched off and the story stays out of the way:
incoming calls are declined before they ring, message and quest pop-ups are
hidden, and the journal is kept empty (`SilenceStory()` in `Config.reds`). The
Phantom Liberty opening is skipped by the quest patch in the archive.

### Rewards and the director

Reward quality follows the run - weaker items are likelier early, and the
expected quality climbs from Common on floor 1 to Legendary+ on floor 18.
Each card rolls a step around that expectation (most at it, some a step above,
rarely two); heavy and elite fights roll higher, light ones lower, and bosses
always pay out well. Smart weapons appear from floor 7, Tech from floor 4.

A director keeps the rolls interesting without choosing for you:

- **Pity.** A screen of flat offers makes the next one better; after two flat
  screens in a row one card is guaranteed to stand out. Taking a big upgrade
  resets it, and every big upgrade you take makes the next one a bit rarer.
- **Build nudges.** The director reads your build (weapons, cyberware, perks,
  attributes) and gives matching rewards up to 40% more weight. At least one
  card on every screen is something off-build, so you can always pivot.
- **Signature perks.** Master perks only show up once your build uses their
  style, and a perk is only offered once its tree prerequisites are owned.

A screen never offers the same item twice (in any quality), shows at most one
grenade, and never offers a weapon or grenade you already carry - the Workshop
is where owned gear gets better. Cards carry a bar in the item's quality
colour.

### Rerolls

Reward screens and door picks can be rerolled (Hades' Fated Authority,
Balatro's shop). Every act gives one free reroll (Fixer Contacts I/II add one
more each, and the Fixer sells two). Out of free ones, a reroll costs eddies:
the price grows with the run and by half again for each paid reroll on the
same screen.

### Character

There are no points to spend. Each kit sets two attributes (+4 to its main
one, +3 to the second; the Edge unlocks add to the main one), and every perk
you take raises its attribute by 1, up to 20. The Character menu can't buy,
sell or reset anything for roguelite characters.

### Workshop

Workshop doors show up on floors 4 and 10 (if you pass one over, it comes back
on the next screen once). They upgrade what you already have: a weapon one or
two quality steps, your MaxDoc, or your grenade.

### The Fixer

Clearing arenas also pays eddies (more on heavy fights and bosses). After each
elite floor, before the boss, the Fixer sells a short stock - a MaxDoc upgrade,
a grenade, a boon, a perk, a weapon upgrade, or a contact (two free rerolls).
Your balance is on top, and every card says what it costs (or how much you're
short). Prices rise with the run; the Street Smart unlock takes 20% off.

### Health, grenades and movement

V carries one MaxDoc. It never falls behind the run: on every trip its quality
is raised automatically when the floor calls for it, and one upgrade can drop
per arena - always from a boss, from one elite in four. Grenades are rewards
(Armory cards and the Workshop), one type at a time. Every run starts with
Dash, Slippery and Muscle Memory, so dashing and sliding work from floor 1 and
sprinting or vaulting doesn't restart a reload. The Quick Fuse and Stim Rig
boons speed up grenade and healing charges.

### Pacing

A pacing director (after Left 4 Dead's) watches how hard each fight was -
damage taken, close calls, heals. After a rough wave it waits longer before
the next one and trims it; across arenas it nudges wave size and incoming
damage up when you're cruising and down when you're struggling. One line per
arena goes in the log for tuning.

### Assist mode

The ASSIST toggle on the terminal cuts the damage V takes by 20%, and by 2%
more for every run lost while it's on (up to 80%). It never changes rewards.

### Unlocks

Cred buys kits and unlocks that mostly widen choice rather than raw power:
rerolls (Fixer Contacts I/II), a fourth reward card (Wide Net), a fourth door
(Street Map), an Armory pick at the start of every run (Quartermaster), Fixer
discounts (Street Smart), plus a few head starts (Med Kit, Head Start,
Vitality, Edge). Kits: Solo and Blade from the start; Netrunner, Marksman,
Brawler, Gunslinger, Demolitions and Juggernaut to unlock - each with its own
starting perk.

### No looting

Every kit starts with a basic frag grenade. Bodies are emptied - there is
nothing to search mid-fight. Ammo comes back as
you clear waves, your MaxDoc is upgraded automatically as the run goes on, and
grenades are Armory rewards. Anything you pick up in an arena anyway is
taken away again right after, and on every trip any weapon the run didn't
hand out (one an enemy dropped) is taken away as well.

### Difficulty

Enemy levels follow the floor, not V: Act 1 enemies are a level below the
floor number, Act 3 a level above, and V gains a level with every reward. Damage
V takes scales from 55% on floor 1 to 100% on floor 18 (on top of the game's
Hard difficulty), adjusted a little by the pacing director and cut by assist
mode. Waves grow with depth: two waves per fight in Act 1, three later; the
elite floor (5, 11, 17) has an elite in every wave. Curves are in `Config.reds`
and `Run/Encounters.reds`.

### Music

Fights get either a radio station - the Edgerunners station, Morro Rock or
the metal station, likelier the harder the fight - or the game's own
interactive combat music (never both at once): the faction's street-story
set for regular fights (tense until the last wave in light fights), the
Konpeki heist or Kang Tao sets for heavy and elite fights, and story boss music
on boss floors (Royce, the mall fight, Adam Smasher).

### Time and weather

Each arena rolls its own time of day and weather on the way in: light fights
are mostly daytime and clear, heavy and elite fights lean to night, rain, fog
and smog (sandstorms in the Badlands), and boss fights get the full storm.

### Enemies

Enemies are roguelite versions of the game's own open-world combat NPCs for
each faction (`r6/tweaks/NightCityRoguelite/enemies.yaml`, made from the list
in `Data/EnemyRoster.reds`): hostile to V from the start, on combat alert
instead of relaxed, all on one side, with the loot described above. They spawn
inside the arena on spots you can reach on foot, at the run's level, and
an enemy that hangs back is sent running at you. If 40 seconds pass without a
kill, the enemies left are brought to you (twice), and after that removed, so
an enemy stuck behind a locked door can never softlock a run.
Without TweakXL the game's original records are used.

### Bosses and elites

Each act ends with a boss: Act 1 the gang's own leader (or an outpost boss)
with a lieutenant, Act 2 a MaxTac squad, Act 3 a Minotaur mech with a MaxTac
escort. A boss's health shows under the HUD line; hurt, it calls in
reinforcements, and near death it enrages.

Elites (and bosses from Act 2) roll **affixes**, announced when they appear:
ARMORED (takes 35% less damage), BERSERK (hits harder, moves faster),
REGENERATING (2% health a second), VOLATILE (explodes a moment after it dies -
step away) and VAMPIRIC (heals when it hits you). Elites get one from floor 3,
sometimes two in Act 2, always two in Act 3.

### Objectives

Some fights (from floor 3, never the boss) come with a job. Enemies keep
coming until it's done, then nobody else joins and the fight ends with the
last one standing. A finished objective pays bonus eddies.

- **SURVIVE** - hold out until the timer runs out.
- **HOLD THE UPLINK** - stand in the marked zone until the upload completes
  (it pauses while you're outside).
- **SABOTAGE** - plant charges at three marked spots (a few seconds each);
  they go off when the last one is set.

### Events

A "?" door is a stop without a fight. It counts as a floor and brings a
level, like a reward:

- **Back-Alley Ripperdoc** - a free MaxDoc patch-up, paid street chrome, or
  bone lacing (+10% max health).
- **The Bookie** - bet half your eddies at even odds, or bet a boon for an
  Epic one.
- **Misty's Reading** - three tarot cards, each a blessing with a price (more
  eddies but more damage taken, upgraded boons for less health...).
- **A Stranger's Offer** - an iconic weapon that makes you a target (15% more
  damage taken for the run), or sell a boon for eddies.

### Patrons

Boons come from six of Night City's powers, Hades-style. A patron door is a
fight whose reward is three of that patron's boons; a patron you already serve
turns up more often.

| Patron | Style |
| --- | --- |
| ARASAKA | Precision: crits, headshots, first strikes, slowed time |
| MILITECH | Firepower: ranged and explosive damage, ammo, grenades |
| VOODOO BOYS | The Net: RAM, quickhack damage and spread |
| MAELSTROM | Brutality: melee, low-health fury, exploding bodies |
| ALDECALDOS | Survival: health, speed, less damage, second winds |
| THE AFTERLIFE | Fortune: eddies, lucky hits, a cheaper Fixer, more choice |

- Each patron has five boons. A boon comes in a rarity - COMMON, RARE, EPIC
  or HEROIC - and is offered again later as an upgrade to the next one. Deep
  runs and lucky rolls give rarer boons.
- Hold three of a patron's boons and its **legendary** can appear (Shogun's
  Edge, Kill Count, Loa's Embrace, Cyberpsychosis, Family Ties, Afterlife
  Legend).
- Serve two patrons and their **duo** boon can appear (eight in all, e.g.
  Smart Link for Arasaka + Militech).

Every boon shows on the HUD buff bar; F7 during a fight lists them by patron.
Everything is removed when the run ends.

### Menus

The terminal, the door picker, the reward and event screens are built from
cards in the game's own menu style: reward cards show the item's icon
(weapons, cyberware, quickhacks) or the boon's buff icon in the patron's
colour; door cards show the reward (or the patron's logo), threat, objective,
arena and the enemy gang's logo.

### Arenas

Arenas are cleared for the fight: no pedestrians or traffic, and anyone else
standing around (vendors, workers) is moved away; shops inside an arena don't
holster your weapon. This only happens around your fights - the world itself
isn't edited. An enemy that ends up under the floor, on a roof or hanging back
at the end of a wave is brought back near you.

Petrochem Off-Limits, Industrial Park, Grand Imperial Mall, Oil Fields, Old
Drive-In, Junkyard, Wind Farm and The Crater. Each has a gang that fits the
location. Edit `Combat/Arenas.reds` to change radii, start points or disable one.

The walls are built from the game's own holo-tape hologram and a "Player
Blocker" collider. They stop V (and gunfire through them). An enemy that ends
up outside is put back inside, and a position check stays on behind the walls
as a safety net for V. Panel width, reveal distance and the
safety margin are in `Config.reds`.

### Hub settings

`UseApartmentHub()` in `Config.reds` switches the apartment hub off (home is
then wherever the takeover happened). If the apartment ever fails to load, the
mod falls back to that spot for the session on its own.

## Tuning

Everything adjustable lives in `r6/scripts/NightCityRoguelite/Core/Config.reds`:
key, countdowns, run length, spawn distances, wave pacing, arena walls, police
toggle, enemy/item blocklists, and verbose logging.

## Logs

The game doesn't write script log lines to disk, so the mod keeps its last 600
log lines in Codeware's persistent store,
`red4ext/plugins/Codeware/Persistent/ScriptableServiceContainer.dat` (saved when
the game closes; readable with any text viewer). Script compile errors are in
`r6/logs/redscript_rCURRENT.log`; framework logs are in `red4ext/logs`.

The same file holds **run telemetry**: one record per run start, door, fight,
reward screen, pick, build, death and run end (about the last 50 runs). Read it
with

    python3 tools/runreport.py "<game folder>"            # floor-by-floor report
    python3 tools/runreport.py "<game folder>" --csv out  # CSV for charts
    python3 tools/runreport.py "<game folder>" --marks    # every F8 bug mark
    python3 tools/runreport.py "<game folder>" --log 100  # the last log lines

The record format is documented in `Core/Telemetry.reds`.

## Files

| File | Purpose |
| --- | --- |
| `Core/Config.reds` | Settings: run shape, difficulty curves, pacing, toggles |
| `Core/Runtime.reds` | Logging, notifications, delay callbacks |
| `Core/Telemetry.reds` | Run telemetry records (read by `tools/runreport.py`) |
| `Core/RogueliteService.reds` | Meta progression (outside saves), assist mode, hotkeys, session hooks |
| `Core/RogueliteSystem.reds` | Per-save state machine: takeover, hub, run, trips, floors, rewards, rerolls, Fixer, death |
| `Core/RunState.reds` | In-memory run state |
| `Core/Story.reds` | Keeps the story quiet: journal guard, blocked calls, hidden pop-ups |
| `Hub/ApartmentHub.reds` | V's apartment hub, getting in, soft lock |
| `Hub/HomeDevices.reds` | Sealed front door, desk computer as the terminal |
| `Menu/MainMenuEntry.reds` | ROGUELITE menu item, skipped campaign/origin screens |
| `Player/CharacterReset.reds` | Level-1 reset (keeps clothes and V's body items), no XP or points from the game, body repair |
| `Player/Kits.reds` | The 8 starting kits, gear granting |
| `Player/Perks.reds` | Direct perk grants, baseline Dash and Slippery, perk attributes |
| `Player/Consumables.reds` | Quality steps, MaxDoc ladder, grenades |
| `Player/DeathGuard.reds` | Immortal god mode + health listener |
| `Player/Death.reds` | The real death and coming to (death menu held back, Second Heart resurrection) |
| `Data/TweakPools.reds` | Enemy and item pools built at runtime |
| `Data/EnemyRoster.reds` | Open-world combat NPCs per faction (generated from the 2.5 TweakDB) |
| `Run/Difficulty.reds` | Enemy level curve, damage-taken curve and hook |
| `Run/Encounters.reds` | Wave plans: sizes, tiers, elites, bosses, bounties |
| `Run/Objectives.reds` | Survive, uplink and sabotage objectives |
| `Run/Events.reds` | "?" doors: ripperdoc, bookie, tarot, stranger |
| `Run/Pacing.reds` | Pacing director (intensity, relax, pressure) |
| `Run/Fixer.reds` | Eddie payouts and the Fixer's stock |
| `Combat/Arenas.reds` | The arena list |
| `Combat/ArenaDirector.reds` | Arena teleport, wall tick, safety-net position check |
| `Combat/ArenaWalls.reds` | Collision walls with proximity holo-tape visuals |
| `Combat/ArenaCleaner.reds` | No bystanders in arenas, no safe zones mid-fight |
| `Combat/WaveSpawner.reds` | Wave spawning, level matching, chasing, kill tracking, boss phases |
| `Combat/Affixes.reds` | Elite affixes and the explosion helper |
| `Combat/DamageHooks.reds` | Boons and affixes in the damage pipeline; death hook |
| `Combat/Loot.reds` | Ammo refill, empty bodies, arena pickup filter |
| `Audio/Music.reds` | Arena music: combat scores and radio stations |
| `World/Atmosphere.reds` | Time of day and weather per arena |
| `Rewards/RewardSystem.reds` | Reward doors, offer rolling and granting |
| `Rewards/Director.reds` | Quality rolls, pity, magnificence, spikes |
| `Rewards/BuildProfile.reds` | Reads V's build into style tags |
| `Rewards/PerkCatalog.reds` | Perk cards: prerequisites, signature perks, weighting |
| `Rewards/PerkCatalogData.reds` | The perk list (generated from `source/perks/catalog.tsv`) |
| `Rewards/Patrons.reds` | The six patrons |
| `Rewards/Boons.reds` | The boon catalogue, rarities, upgrades |
| `Rewards/BoonEffects.reds` | What boons do in fights (hits, kills, saves) |
| `Meta/MetaProgression.reds` | Unlocks, kits, Cred payout |
| `UI/Card.reds` | The card used by every menu, icon helpers |
| `UI/Transition.reds` | Fade to black with the destination (trips, death) |
| `UI/*.reds` | HUD line and boss bar, terminal, reward, event and Fixer popups |
| `r6/tweaks/NightCityRoguelite/*.yaml` | Enemy variants and loot, boon buffs, computer prompt (TweakXL) |
| `archive/pc/mod/NightCityRoguelite.archive` | Quest patch (skips the Phantom Liberty opening for roguelite starts) and English text |
| `source/quest-patch/` | How the archive is built (Python + WolvenKit) |
| `source/perks/` | Perk catalogue (tsv) and the generator for `PerkCatalogData.reds` |
| `source/tweaks/gen_tweaks.py` | Generates the yaml files and the text list |
| `source/localization/` | English text and its converter for ArchiveXL |

## License

MIT for the mod's own code, data and docs (see LICENSE). Cyberpunk 2077 and
its content belong to CD PROJEKT RED; this is an unofficial fan mod.
Source and every release: https://github.com/dotXCVI/night-city-roguelite

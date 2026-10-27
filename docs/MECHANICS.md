# Night City Roguelite - the full rundown

Everything the mod does, system by system. The [README](../README.md) is the
short version; [TESTING.md](../TESTING.md) is the tester guide.

## How a run goes

1. Main menu -> **ROGUELITE** (top of the list). The campaign, difficulty,
   life path, origin and attribute screens are all skipped (the mod sets them);
   you go straight to the body type screen. Make your V, confirm.
2. There's no opening scene: the screen stays black while the mod resets V to
   level 1 (clothes kept) and moves V into **V's apartment in Megabuilding
   H10**, then fades in with V standing inside. The front door is sealed. The
   first time home, a six-page guide explains the apartment and the run (the
   terminal's HOW IT WORKS card brings it back).
3. Walk into the **armory** - the weapon room at the back, opened up by the
   mod - and use its stash (prompt "Gear") to pick one of 9 kits; locked kits
   are bought there with Cred. (No stash on a character? F7 in the room
   does the same.) Then use **V's computer** (prompt: "Roguelite Terminal")
   or press **F7** anywhere else for the terminal: buy upgrades, toggle
   **ASSIST**, then **START RUN**. If the apartment didn't load and home is
   the hallway, the terminal's kit card opens the armory instead.
4. A run opens with a choice of three **gigs** (see Gigs). The first fight is
   a light fight in a random arena. Every trip fades to
   black with the destination on screen and fades back in once the area has
   loaded; the first wave comes after a 5-second countdown. The arena is
   ringed by a solid wall that lights up as red NCPD holo-tape as you walk up
   to it.
5. Clearing a wave refills part of your ammo and one health charge. Clear the
   last one and the reward screen opens right there: pick one of three rewards
   of that fight's type, then a **level-up** (see Level-ups).
6. Then pick your next fight by its reward, Hades-style, and travel straight
   there (V patches up on the way). Each door shows the reward type, the
   threat, the arena and the gang you'll face:

   | Reward | What you choose from | Threat |
   | --- | --- | --- |
   | TRAINING | Perks, granted outright | Light |
   | ARMORY | A better weapon, an upgrade or mod for yours, grenades | Standard |
   | PATRON | Boons from one of Night City's powers (see Patrons) | Standard |
   | DAEMONS | Quickhacks | Standard |
   | WORKSHOP | Evolve or upgrade a weapon, a weapon mod, your MaxDoc or grenade (floors 4, 10, 16) | Standard |
   | CHROME | Cyberware, installed on the spot (from floor 3) | Heavy |
   | BOUNTY | A lone cyberpsycho; pays eddies and a patron's boons (Act 2+) | Heavy |
   | ? | An event instead of a fight (from floor 2) | - |

   Light fights have smaller waves of weaker enemies; heavy fights have bigger
   waves (an extra wave in Act 3) and roll better rewards. From floor 3 some
   fights come with an **objective** (see Objectives). Before a boss floor
   there is a single boss door; the Act 1 boss pays out an Operating System
   (see Overdrive).
7. After each elite floor, before the boss door, the **Fixer** is in: spend
   the eddies you've earned.
8. When health hits zero V dies - for real, the game's own death - and comes
   to back home, ready for the next run. Quitting or crashing mid-run counts as
   a flatline too. A run won ends with the trip home as well.

Cred is earned for every arena you clear (never for a lost one), plus a bonus
for completing a run. Experience comes only from level-ups: kills and skill
use give none, and levels bring no attribute or perk points (see Character).

| F7 in the armory | Computer or F7 elsewhere at home | F7 during a fight | F7 between fights |
| --- | --- | --- | --- |
| Kit picker | Terminal (run start, upgrades) | Run status, abandon | Reward, Fixer or next fight |

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
  attributes) and gives matching rewards up to 40% more weight - up to 150%
  once you've taken an Operating System at the Act 1 boss. At least one card
  on every screen is something off-build, so you can always pivot.
- **Signature perks.** Master perks only show up once your build uses their
  style and their attribute is at 15, and a perk is only offered once its
  tree prerequisites are owned.

**Saying no.** A door's reward screen can be skipped for eddies (Slay the
Spire's skip). Once per act you can **banish** a card: click BANISH, then the
card - it's replaced and never offered again this run.

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

### Level-ups

Every floor pays twice: the door's reward (the big pick), then a **level-up**
(the small pick) - one of three cards that deepen what you already have:

- **+1 to an attribute**, usually one of your two best.
- **A perk from a tree you're already in.**
- **One more:** an evolution when a weapon is ready for one, otherwise a
  weapon mod, a quality step for an equipped weapon, a boon one rarity up, or
  +4 cyberware capacity.

The level-up is the only way V gains levels. Event doors are followed by one
too.

### Character

There are no points to spend. Each kit sets two attributes (+4 to its main
one, +3 to the second; the Edge unlocks add to the main one); every perk you
take raises its attribute by 1, and level-ups add more, up to 20. Signature
perks need their attribute at 15. The Character menu can't buy, sell or reset
anything for roguelite characters.

### Weapons

- **Weapon cards say what you're getting:** the class and the attribute it
  leans on ("Revolver · COOL"), its DPS against the best weapon you have
  equipped ("DPS 312 +38% vs Lexington"), and a line on how it plays.
- **New weapons never step down:** an Armory weapon is at least the quality of
  your best equipped one. Every Armory screen also has one card that improves a
  weapon you carry (two quality steps, or a mod).
- **Weapon mods** (the mod's own, Hades' hammers): two slots per weapon, three
  on iconics. Each weapon family has its own (pistols: Quickdraw, Deadshot,
  Double Tap; rifles: Sustained Fire, Hollow Point, Tracer; heavy: Point Blank,
  Shrapnel, Slug; precision: Long Shot, Pierce, Spotter; blades: Momentum,
  Bloodletting, Vampiric Edge; blunt: Haymaker, Concussive, Rebound), plus four
  for any weapon (Executioner, Incendiary, Shock, Toxic).
- **Iconics are earned.** A Legendary weapon with both mod slots filled can
  **evolve** into an iconic of its type (Workshop or level-up), keeping its
  mods and gaining a third slot. There's no ICONIC door any more; the
  stranger's iconic (Act 2 on) is the only other way to one.
- **Keep your main gun up:** a weapon well below the floor's expected quality
  deals up to 30% less damage (a little more when it's ahead).

### Styles

Every reward feeds a **style**: BLADES, BRAWLER, MONOWIRE, GUNSLINGER, HEAVY,
RIFLES, MARKSMAN, NETRUNNER, SMART, TECH, DEMOLITIONS or NINJA. An equipped
weapon or arm cyberware counts 2 points; every perk, boon and weapon mod with
the style counts 1 (a cyberdeck 2 for Netrunner, quickhacks 1 each up to 3, a
grenade 1 for Demolitions). Cards show which styles they feed, in gold when
you already have a rank.

At 3, 6 and 9 points a style reaches rank I, II and III: hits of that style
deal +10%, +20% and +35% damage (the best style a hit belongs to counts), and
rank III adds a signature:

| Style | Rank III signature |
| --- | --- |
| BLADES | Blade kills slow time for a second |
| BRAWLER | Blunt and fist kills send out a shockwave |
| MONOWIRE | Monowire hits electrocute; kills restore RAM |
| GUNSLINGER | Headshot kills: the next 3 hits deal double damage |
| HEAVY | Kills blow enemies apart, hitting those nearby |
| RIFLES | Hits on the same target ramp up to +45% damage |
| MARKSMAN | +60% damage beyond 20 m |
| NETRUNNER | Quickhack kills restore RAM and jolt enemies nearby |
| SMART | Kills mark nearby enemies: +25% damage taken for 5 s |
| TECH | Kills electrocute enemies nearby |
| DEMOLITIONS | Every 5 kills recharge a grenade |
| NINJA | Throwing kills make you invisible for a moment |

The reward footer and the F7 screen in a fight list your styles.

### Overdrive

The Act 1 boss pays out a choice of **Operating System**: a Sandevistan, a
Berserk or a cyberdeck (which comes with the Overclock perk). It brings its
own capacity and unlocks **Overdrive**, the run's ultimate. The meter (on the
HUD) fills from kills - more from elites and bosses - and from damage you
take, and carries over between fights. When it's full, activate your OS as
usual and it overdrives:

| OS | Overdrive |
| --- | --- |
| Sandevistan | **ZERO HOUR** - time nearly stops for 7 s, +50% damage |
| Berserk | **RAMPAGE** - a shockwave, then 8 s of +60% damage, 70% less damage taken, kills heal |
| Cyberdeck | **BLACKWALL** - every enemy within 40 m loses half its health (bosses 15%), is electrocuted and stunned; RAM refills |

### Gigs

A run opens with three gigs from the city's fixers; take one. Each is a kill
count in one style (e.g. 40 pistol kills) to finish before the Act 2 boss
falls. A finished gig pays 1,000 eddies and 2 points in its style for the rest
of the run. Its progress is on the HUD.

### Capacity overclock

Chrome that doesn't fit your capacity can be installed anyway: the card says
how far over it goes. Every point over capacity raises the odds of a
**cyberpsychosis episode** in a fight - 6 seconds of 30% more damage dealt and
taken. Capacity level-ups pay the overclock down.

### Workshop

Workshop doors show up on floors 4, 10 and 16 (if you pass one over, it comes
back on the next screen once). They work on what you already have: an
evolution when a weapon is ready, a weapon two quality steps up, a weapon mod,
your MaxDoc, or your grenade.

### The Fixer

Clearing arenas also pays eddies (more on heavy fights and bosses). After each
elite floor, before the boss, the Fixer sells a short stock - a MaxDoc upgrade,
a grenade, a boon, a perk, a weapon upgrade, a weapon mod, or a contact (two
free rerolls) - and buys back weapons and cyberware you carry but don't have
equipped. Your balance is on top, and every card says what it costs (or how
much you're short). Prices rise with the run; the Street Smart unlock takes
20% off.

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

Cred buys kits (in the armory) and upgrades (at the terminal) that mostly
widen choice rather than raw power:
rerolls (Fixer Contacts I/II), a fourth reward card (Wide Net), a fourth door
(Street Map), an Armory pick at the start of every run (Quartermaster), Fixer
discounts (Street Smart), plus a few head starts (Med Kit, Head Start,
Vitality, Edge). Kits: Solo and Blade from the start; Netrunner, Marksman,
Brawler, Gunslinger, Demolitions, Juggernaut and Wireman (Monowire, a
cyberdeck, a quickhack and Siphon) to unlock - each with its own starting
perk.

### No looting

Every kit starts with a basic frag grenade. Bodies are emptied - there is
nothing to search mid-fight. Ammo comes back as
you clear waves, your MaxDoc is upgraded automatically as the run goes on, and
grenades are Armory rewards. Anything you pick up in an arena anyway is
taken away again right after, and on every trip any weapon the run didn't
hand out (one an enemy dropped) is taken away as well.

### Difficulty

Enemy levels follow the floor, not V: Act 1 enemies are a level below the
floor number, Act 3 a level above, and V gains a level with every level-up.
From Act 2 bosses shrug off part of your damage (15%, 25% in Act 3), and in
Act 3 every enemy does (10%): a run without a build behind it stalls there.
Damage
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
reinforcements, and near death it enrages. The Act 1 boss pays out an
Operating System (see Overdrive), the others chrome.

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

A "?" door is a stop without a fight. It counts as a floor and is followed by a
level-up:

- **Back-Alley Ripperdoc** - a free MaxDoc patch-up, paid street chrome, or
  bone lacing (+10% max health).
- **The Bookie** - bet half your eddies at even odds, or bet a boon for an
  Epic one.
- **Misty's Reading** - three tarot cards, each a blessing with a price (more
  eddies but more damage taken, upgraded boons for less health...).
- **A Stranger's Offer** (Act 2 on) - an iconic weapon that makes you a target
  (15% more damage taken for the run), or sell a boon for eddies.

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

The terminal, the armory, the door picker, the reward and event screens are
built from cards in the game's own menu style, with pictures from the game's
codex: door cards show the arena with the reward's badge on it, then threat,
objective and the enemy gang's logo; boon cards show the patron's people,
gig cards the fixer, kit cards the kit's weapon; events open with whoever
you're dealing with (Misty deals real tarot cards). Hovering lifts a card and
lights its frame - the text never sits on a colour fill.

### Arenas

Arenas are cleared for the fight: no pedestrians or traffic, and anyone else
standing around (vendors, workers) is moved away; shops inside an arena don't
holster your weapon. This only happens around your fights - the world itself
isn't edited. An enemy that ends up under the floor, on a roof or hanging back
at the end of a wave is brought back near you.

Petrochem Off-Limits, Industrial Park, Grand Imperial Mall, Oil Fields, Old
Drive-In, Junkyard, Wind Farm and The Crater. Each has a gang that fits the
location, and the door says what the ground is like (OPEN GROUND, MIXED or
CLOSE QUARTERS): long guns like the open ones, shotguns and blades the tight
ones. Edit `Combat/Arenas.reds` to change radii, start points or disable one.

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
| `Hub/HomeDevices.reds` | Sealed front door, desk computer as the terminal, the armory |
| `Menu/MainMenuEntry.reds` | ROGUELITE menu item, skipped campaign/origin screens |
| `Player/CharacterReset.reds` | Level-1 reset (keeps clothes and V's body items), no XP or points from the game, body repair |
| `Player/Kits.reds` | The 9 starting kits, gear granting |
| `Player/OSHooks.reds` | Sees Operating System activations (Overdrive) |
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
| `Run/Fixer.reds` | Eddie payouts, the Fixer's stock and buy-backs |
| `Run/Overdrive.reds` | Overdrive (the ultimate) and capacity overclock episodes |
| `Run/Gigs.reds` | The gig taken at the start of a run |
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
| `Rewards/BoonEffects.reds` | What boons do in fights (hits, kills, saves); the hit and kill hooks |
| `Rewards/Styles.reds` | Styles: points, ranks, damage bonuses, signatures |
| `Rewards/Weapons.reds` | Weapon families, DPS previews, evolution, the quality curve |
| `Rewards/WeaponMods.reds` | Weapon mods and their effects |
| `Rewards/LevelUp.reds` | The level-up after every floor |
| `Meta/MetaProgression.reds` | Unlocks, kits, Cred payout |
| `UI/Card.reds` | The card used by every menu, icon helpers |
| `UI/Art.reds` | Codex pictures for arenas, patrons, kits, fixers, events |
| `UI/ArmoryPopup.reds` | The kit picker |
| `UI/GuidePopup.reds` | The six-page how-it-works guide |
| `UI/Transition.reds` | Fade to black with the destination (trips, death) |
| `UI/*.reds` | HUD line and boss bar, terminal, reward, event and Fixer popups |
| `r6/tweaks/NightCityRoguelite/*.yaml` | Enemy variants and loot, boon buffs, computer and armory prompts (TweakXL) |
| `archive/pc/mod/NightCityRoguelite.archive` | Quest patch (skips the Phantom Liberty opening for roguelite starts) and English text |
| `source/quest-patch/` | How the archive is built (Python + WolvenKit) |
| `source/perks/` | Perk catalogue (tsv) and the generator for `PerkCatalogData.reds` |
| `source/tweaks/gen_tweaks.py` | Generates the yaml files and the text list |
| `source/localization/` | English text and its converter for ArchiveXL |


# Night City Roguelite (v0.0.12)

> **Versions:** alpha builds are v0.0.X. v0.X.X starts once the foundation is
> solid, v1.0.0 is the finished mod. (Builds before v0.0.8 were numbered
> v0.1-v0.7; they are the same series.)

A run-based arena mode for Cyberpunk 2077 2.5, built only from the game's own
assets and systems. Start a new roguelite character from the main menu, fight
through 3 acts of 6 arenas (bosses on floors 6, 12 and 18), pick one of three
rewards after every floor, and
bank meta Cred when you flatline.

> **Status:** first in-game test done; v0.5 fixes what it turned up. Compiles
> cleanly with redscript 0.5.32 against the 2.5 game scripts, Codeware 1.21.0
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
   life path and attribute screens are skipped (the mod sets all of them);
   pick a body type, make your V, confirm.
2. There's no opening scene: the screen stays black while the mod resets V to
   level 1 (clothes kept, Dash included) and moves V into **V's apartment in Megabuilding
   H10**, then fades in with V standing inside. The front door is sealed.
3. Use **V's computer** (prompt: "Roguelite Terminal") or press **F7** for the
   terminal: pick a kit (locked kits are bought by clicking them), buy
   unlocks, then **START RUN**.
4. The first fight is a light Training fight in a random arena. You arrive with full ammo and full health
   and grenade charges; the first wave comes after a 5-second countdown. The
   arena is ringed by a solid wall: invisible from a distance, it lights up as
   red NCPD holo-tape ("POLICE LINE - DO NOT CROSS") as you walk up to it, more
   solid the closer you get.
5. Clearing a wave refills part of your ammo and one health charge. Clear the
   last one and you're sent home a few seconds later (F7 goes at once). Pick
   one of three rewards of that fight's type - every pick also grants +1 level.
6. Then pick your next fight by its reward, Hades-style. Each door shows the
   reward type, the arena and the threat:

   | Reward | What you choose from | Threat |
   | --- | --- | --- |
   | TRAINING | Extra attribute points, perk points or a boon | Light |
   | ARMORY | Weapons, grenades (sometimes an iconic) | Standard |
   | BOONS | Run-only bonuses | Standard |
   | DAEMONS | Quickhacks | Standard |
   | CHROME | Cyberware, installed on the spot | Heavy |
   | ICONIC | Iconic weapons (rare door) | Heavy |

   Light fights have smaller waves of weaker enemies; heavy fights (from floor
   3 on) have bigger waves, more elites, an extra wave from Act 2 and enemies a
   level up, and roll better quality. Reward quality follows the run (Common on
   floor 1, Legendary at the end), with elite floors rolling better and bosses
   always paying out high. Smart weapons appear from floor 7, Tech from floor 4.
   Before a boss floor there is a single boss door.
7. When health hits zero the run ends: enemies vanish, a 5-second countdown runs,
   and you're sent home. Quitting or crashing mid-run counts as a flatline too.

Cred is earned for every arena you clear (never for a lost one), plus a bonus
for completing a run. Experience comes only from rewards: kills and skill use
give none. Trips between home and arenas use the game's glitch transition.

| Computer or F7 at home | F7 in an arena | F7 after clearing |
| --- | --- | --- |
| Terminal (kit, run start, rewards, next fight) | Run status, abandon | Go home now |

Saving works only between runs. Normal story saves are never touched. For
roguelite characters NCPD is switched off and the story stays out of the way:
incoming calls never ring, message and quest pop-ups are hidden, and the
journal is kept empty (anything that turns up is cleared within a moment;
`SilenceStory()` in `Config.reds`). The Phantom Liberty opening is skipped by
the quest patch in the archive. If the story ever starts a call or conversation anyway, teleports,
the terminal and the reward screen wait until it's over (looking at something
with a prompt doesn't count).

### No looting

Bodies are emptied - there is nothing to search mid-fight. Ammo comes back as
you clear waves, your MaxDoc is upgraded automatically at home as the run goes
on, and grenades are Armory rewards. Anything you pick up in an arena anyway is
taken away again right after.

### Difficulty

Enemy levels follow the floor, not V: Act 1 enemies are a level below the
floor number, Act 3 a level above, and V gains a level with every reward. Damage
V takes scales from 55% on floor 1 to 100% on floor 18 (on top of the game's
Hard difficulty). Both curves are in `Config.reds`.

### Music

Fights use the game's own interactive combat music: the faction's street-story
set for regular fights (tense until the last wave in light fights), the
Konpeki heist or Kang Tao sets for heavy and elite fights, and story boss music
on boss floors (Royce, the mall fight, Adam Smasher).

### Enemies

Enemies are roguelite versions of the game's own open-world combat NPCs for
each faction (`r6/tweaks/NightCityRoguelite/enemies.yaml`, made from the list
in `Data/EnemyRoster.reds`): hostile to V from the start, on combat alert
instead of relaxed, all on one side, with the loot described above. They spawn
inside the arena on spots you can reach on foot, at the run's level, and
an enemy that hangs back is sent running at you. Acts 2 and 3 end with MaxTac.
Without TweakXL the game's original records are used.

### Boons

Every boon you take shows on the HUD buff bar with its stack count, and the
buffs are removed when the run ends.

### Menus

The terminal, the door picker and the reward screen are built from cards in
the game's own menu style: reward cards show the item's icon (weapons,
cyberware, quickhacks) or the boon's buff icon, door cards show the reward
type, threat and arena.

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

## Files

| File | Purpose |
| --- | --- |
| `Core/Config.reds` | Settings, logging, delay helper |
| `Core/RogueliteService.reds` | Meta progression (outside saves), hotkeys, session hooks |
| `Core/RogueliteSystem.reds` | Per-save state machine: takeover, hub, run, floors, rewards, death |
| `Core/Story.reds` | Keeps the story quiet: journal guard, blocked incoming calls, hidden message/quest pop-ups, busy checks for calls/dialogue, stale caller cards |
| `Hub/ApartmentHub.reds` | V's apartment hub, getting in, soft lock |
| `Hub/HomeDevices.reds` | Sealed front door, desk computer as the terminal |
| `Core/RunState.reds` | In-memory run state |
| `Menu/MainMenuEntry.reds` | ROGUELITE menu item and new-game routing |
| `Player/CharacterReset.reds` | Level-1 reset (keeps clothes and V's body items), body repair |
| `Player/Kits.reds` | Starting kits, gear/cyberware/quickhack granting |
| `Player/DeathGuard.reds` | Immortal god mode + health listener |
| `Data/TweakPools.reds` | Enemy and item pools built at runtime |
| `Data/EnemyRoster.reds` | Open-world combat NPCs per faction (generated from the 2.5 TweakDB) |
| `Combat/Arenas.reds` | The arena list |
| `Combat/ArenaDirector.reds` | Arena teleport, wall tick, safety-net position check |
| `Combat/ArenaWalls.reds` | Collision walls with proximity holo-tape visuals |
| `Combat/ArenaCleaner.reds` | No bystanders in arenas, no safe zones mid-fight |
| `Combat/WaveSpawner.reds` | Wave spawning, level matching, chasing, kill tracking |
| `Combat/Loot.reds` | Ammo refill, empty bodies, arena pickup filter |
| `Run/Difficulty.reds` | Enemy level curve, damage-taken curve |
| `Player/Consumables.reds` | Quality steps, MaxDoc ladder, grenades |
| `Player/Perks.reds` | Direct perk grants, baseline Dash |
| `Audio/Music.reds` | Arena combat music |
| `Rewards/RewardSystem.reds` | Reward doors, threat, offer rolling and granting |
| `Rewards/Boons.reds` | Run-only bonuses |
| `Meta/MetaProgression.reds` | Unlocks, kits, Cred payout |
| `UI/Card.reds` | The card used by every menu, icon helpers |
| `UI/*.reds` | HUD line, terminal and reward popups |
| `r6/tweaks/NightCityRoguelite/*.yaml` | Enemy variants and loot, boon buffs, computer prompt (TweakXL) |
| `archive/pc/mod/NightCityRoguelite.archive` | Quest patch (skips the Phantom Liberty opening for roguelite starts) and English text |
| `source/quest-patch/` | How the archive is built (Python + WolvenKit) |
| `source/tweaks/gen_tweaks.py` | Generates the yaml files and the text list |
| `source/localization/` | English text and its converter for ArchiveXL |

# Night City Roguelite (v0.3.0, untested)

A run-based arena mode for Cyberpunk 2077 2.5, built only from the game's own
assets and systems. Start a new roguelite character from the main menu, fight
through 3 acts of 5 arenas, pick one of three rewards after every floor, and
bank meta Cred when you flatline.

> **Status:** type-checked against the decompiled 2.5 game scripts, Codeware
> 1.21.0 and TweakXL 1.12.0. First in-game test pending.

## Requirements

- Cyberpunk 2077 **2.5** with **Phantom Liberty** (the mode uses the
  Phantom Liberty standalone start to skip the story)
- RED4ext 1.31.0+, redscript 0.5.32+, Codeware 1.21.0+, TweakXL 1.12.0+

No ArchiveXL, CET or new archives are needed.

## Install

Copy the `r6` folder into the game folder, so the scripts end up in
`Cyberpunk 2077/r6/scripts/NightCityRoguelite/`. With Vortex or MO2, install
the zip as a normal mod.

## How to play

1. Main menu -> **ROGUELITE** (top of the list). The expansion choice is skipped
   automatically; make your V as usual.
2. The moment V can move, the mod takes over: V is reset to level 1 (clothes
   kept) and locked in **V's apartment in Megabuilding H10**. Walk out and you're
   put back inside. If the opening scene holds V, press **F7** to skip ahead.
3. Press **F7** for the terminal: pick a kit, switch roguelite/roguelike mode,
   buy unlocks, then **START RUN**.
4. The terminal lists the arenas. Pick one and you're teleported to its start.
   The first wave comes after a 5-second countdown. Invisible walls keep you in.
5. Clear every wave and you have 30 seconds to loot (F7 skips), then you're sent
   home. Choose a reward on the terminal, then the next arena.
6. When health hits zero the run ends: enemies vanish, a 5-second countdown runs,
   and you're sent home with your Cred. Quitting or crashing mid-run counts as a
   flatline too.

| F7 at home | F7 in an arena | F7 after clearing |
| --- | --- | --- |
| Terminal (kit, run start, rewards, arena picker) | Run status, abandon | Go home now |

Saving works only between runs. Normal story saves are never touched. NCPD is
switched off for roguelite characters, and the story quest is untracked.

### Arenas

Petrochem Off-Limits, Industrial Park, Grand Imperial Mall, Oil Fields, Old
Drive-In, Junkyard, Wind Farm and The Crater. Each has a gang that fits the
location. Edit `Combat/Arenas.reds` to change radii, start points or disable one.

### Hub settings

`UseApartmentHub()` in `Config.reds` switches the apartment hub off (home is
then wherever the takeover happened). If the apartment ever fails to load, the
mod falls back to that spot for the session on its own.

## Tuning

Everything adjustable lives in `r6/scripts/NightCityRoguelite/Core/Config.reds`:
key, countdowns, run length, spawn distances, wave pacing, police toggle,
enemy/item blocklists, and verbose logging.

## Logs

Lines prefixed `[NightCityRoguelite]` go to `r6/logs/redscript_rCURRENT.log`.
Script compile errors show in the same file. Framework logs are in
`red4ext/logs` and `red4ext/plugins/<plugin>/`.

## Files

| File | Purpose |
| --- | --- |
| `Core/Config.reds` | Settings, logging, delay helper |
| `Core/RogueliteService.reds` | Meta progression (outside saves), hotkeys, session hooks |
| `Core/RogueliteSystem.reds` | Per-save state machine: takeover, hub, run, floors, rewards, death |
| `Hub/ApartmentHub.reds` | V's apartment hub, soft door lock, door diagnostics |
| `Core/RunState.reds` | In-memory run state |
| `Menu/MainMenuEntry.reds` | ROGUELITE menu item and new-game routing |
| `Player/CharacterReset.reds` | Level-1 reset (keeps clothes) |
| `Player/Kits.reds` | Starting kits, gear/cyberware/quickhack granting |
| `Player/DeathGuard.reds` | Immortal god mode + health listener |
| `Data/TweakPools.reds` | Enemy and item pools read from TweakDB at runtime |
| `Combat/Arenas.reds` | The arena list |
| `Combat/ArenaDirector.reds` | Arena teleport, invisible walls |
| `Combat/WaveSpawner.reds` | Wave spawning, hostility, kill tracking |
| `Rewards/RewardSystem.reds` | Offer rolling and granting |
| `Rewards/Boons.reds` | Run-only bonuses |
| `Meta/MetaProgression.reds` | Unlocks, kits, Cred payout |
| `UI/*.reds` | HUD line, terminal and reward popups |

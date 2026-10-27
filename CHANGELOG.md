# Changelog

Every build of Night City Roguelite, newest first. Each version is a tagged
release on GitHub with its ZIP attached.

## v0.0.11 - New-game freeze fix (2026-10-26)

- Fixed new characters freezing on a black screen:
  - The journal guard no longer changes entries inside the journal's own callback. It queues them and sweeps 0.25 s later.
  - The quest gate is removed.
- Quiet world without the gate:
  - incoming calls are dropped;
  - message, contact and quest pop-ups are muted for roguelite characters.

## v0.0.10 - Quiet world, XP only from rewards (2026-10-26)

- Quiet world, first attempt: a base-game quest gate plus a journal guard. It caused a freeze and was replaced in v0.0.11.
- XP only comes from rewards; arenas no longer grant a level.
- Cred only for completed arenas (6 + 4 x act + 3 x threat, +30 on a boss floor); +150 for a won run.
- Roguelike mode removed.
- Terminal: kits are bought from their cards, and the unlock grid no longer overlaps the footer.
- Transitions: the game's glitch effect between home and arenas.

## v0.0.9 - Freeze and missing-enemy fixes (2026-10-26)

- Fixed the freeze on returning home. Menus now wait until V has been placed, run without slow motion, and load icons in the background.
- Missing last enemy: enemies below the floor are brought back at once, on another level after 8 s, and stragglers after 20 s.
- Arenas are cleared of bystanders for the fight only. Normal saves are untouched.
- The first fight is always a light Training fight.
- The difficulty screen is skipped; the mod sets Hard.

## v0.0.8 - New version numbering, opening fixes (2026-10-26)

- Version scheme: alpha builds are now v0.0.X.
- Opening skip: V is teleported to solid ground and the screen stays black until V is standing in the apartment (45 s safety net). Previously the game faded in before the world had loaded and V fell through the map.
- The front door stays sealed: any open, unlock or unseal request on it is ignored, and the seal is re-checked every second.
- The terminal no longer refuses to open because a prompt is on screen. The busy check now asks whether V is actually in a dialogue.

## v0.0.7 - TweakXL data, home devices, new menus (2026-10-26)

Originally released as v0.7.0.

- TweakXL data:
  - roguelite enemy variants (hostile from the start, on combat alert, one team, loot emptied);
  - HUD buffs for boons;
  - the computer's "Roguelite Terminal" prompt.
- V's desk computer opens the terminal, and the front door is sealed.
- The mod's English text is loaded through ArchiveXL.
- Card-based menus in the game's own style for the terminal, door picker and reward screen.

## v0.0.6 - Phantom Liberty opening skipped (2026-10-26)

Originally released as v0.6.0.

- New archive with a quest patch that skips the Phantom Liberty opening (book scene and Songbird's call), for roguelite characters only.
- The scripts and the quest patch hand off through quest facts, and the screen stays black until V is in the apartment.

## v0.0.5 - Fixes from the first in-game test (2026-10-26)

Originally released as v0.5.2.

- Fixed the nine issues from the first test:
  - a stuck Songbird caller card;
  - enemies spawning outside the arena or inside buildings;
  - passive enemies;
  - V placed in the hallway;
  - invisible arms (V's body items were removed along with the gear);
  - upside-down wall lettering;
  - an unkillable enemy;
  - a single magazine of ammo;
  - junk loot.
- Hades-style doors: pick the next fight by its reward. The first arena is random.
- Ammo and loot rework; an enemy roster of the game's open-world combat NPCs per faction.

## v0.0.4 - Compiles cleanly on 2.5 (2026-10-25)

Originally released as v0.4.0.

- Compiles cleanly with redscript 0.5.32 against the 2.5 game scripts, Codeware 1.21.0 and TweakXL 1.12.0.
- Arena walls: a solid ring around each arena that lights up as red NCPD holo-tape as V gets close.
- Untested in game.

## v0.0.3 - First complete build (2026-10-25)

Originally released as v0.3.0 (builds before v0.0.8 used v0.X numbering; same series).

- ROGUELITE entry on the main menu: a new character on the Phantom Liberty standalone start, with the story kept out of the way.
- Takeover: V is reset to level 1 and moved into V's apartment in Megabuilding H10, which is the hub.
- Terminal on F7: starting kits, meta unlocks bought with Cred, start a run.
- Runs of 3 acts x 5 arenas: enemy waves from the game's own NPCs, a reward after every floor (weapons, cyberware, quickhacks, boons, points), bosses.
- Death guard: a flatline ends the run, banks Cred and wipes run gear.
- Untested in game.

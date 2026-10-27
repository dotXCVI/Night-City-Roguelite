# Changelog

Every build of Night City Roguelite, newest first. Each version is a tagged
release on GitHub with its ZIP attached.

## v0.0.15 - Hotfix: blank screen on new character (2026-10-27)

- Fixed a blank screen with nothing to click when starting a new roguelite character. v0.0.14 cut the campaign screen's intro animation short, but the menu only moves on when that animation finishes. The screen is now hidden and the animation is left to finish.

## v0.0.14 - Arena-to-arena runs, real death, rerolls (2026-10-27)

From the v0.0.13 playtest, the first build that felt like a real game mode.

- Arena to arena: home only at the start and end of a run. The reward, the Fixer and the doors open in the arena after a clear.
- Real transitions: a fade to black with the destination's name. V is moved only while the screen is black, and it fades back in once the arena has loaded.
- Real death: V dies with the game's own death and comes to at home. The game-over menu is held back and the Second Heart revive is used.
- Rerolls on reward screens and door choices: one free per act, then eddies with an escalating price.
- No attribute or perk points: kits set attributes, and each perk taken adds +1 to its attribute.
- Rewards: no duplicates in any quality, at most one grenade per screen, nothing you already carry; quality-coloured bars on cards.
- Fixes:
  - half-buried enemies;
  - overlapping music;
  - two MaxDoc drops in one boss fight;
  - Judy's call (calls are now declined);
  - the campaign screen still showing.
- UI polish: centred, staggered cards with less text. The Fixer shows your balance and how much you're short.
- Saving is locked during runs.
- Added a tester guide (TESTING.md) and developer handoff notes (DEVELOPER_NOTES.md).

## v0.0.13 - Balance pass, part 2 (2026-10-26)

- Code cleanup: runtime helpers in one place, and a Run/ folder for encounters, pacing and the Fixer.
- Pacing director (Left 4 Dead style): breathers after rough waves, and pressure nudges wave size and damage between arenas.
- Reward director:
  - quality rolls with pity and spikes;
  - big picks get rarer the more you take;
  - build-aware weighting (max +40%), with one off-build card on every screen.
- Perk cards: Training doors offer perks from a catalogue of 124, granted outright. Signature perks need a matching build.
- Workshop doors on floors 4 and 10: upgrade a weapon, your MaxDoc or your grenade.
- The Fixer shop, paid in eddies earned per arena.
- MaxDoc drops from bosses and elites; new boons Quick Fuse, Stim Rig and Demolitionist.
- 8 kits with identity perks; meta unlocks focused on choice (rerolls, a 4th card, a 4th door, Quartermaster and more).
- Assist mode: 20% less damage taken, +2% per run lost while it's on (max 80%).

## v0.0.12 - Balance pass, part 1 (2026-10-26)

- Runs are 3 acts of 6 arenas: an elite on floor 5 and a boss on floor 6 of each act (bosses on floors 6, 12 and 18).
- Difficulty: enemy level follows the floor (Act 1 one level below, Act 3 one above). Damage V takes scales from 55% on floor 1 to 100% on floor 18.
- Waves grow with depth; elite floors have an elite in every wave.
- Reward quality rolls around an expected step (Common on floor 1 to Legendary+ on floor 18). Heavy and elite fights roll higher.
- Every reward pick gives +1 level. Dash and Slippery are baseline for everyone.
- No looting: bodies are emptied, and each cleared wave refills ammo and one health charge.
- MaxDoc quality floor that rises with depth; grenades are Armory rewards.
- Arena music from the game's interactive combat sets, with heavier sets for heavy fights and boss music on boss floors.
- The campaign, life path and attribute screens are skipped.

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

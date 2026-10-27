# Night City Roguelite - developer handoff (v0.0.17 + unreleased dev work)

You are picking up an in-progress Cyberpunk 2077 mod from another AI. Read this
whole file before changing anything. The mod's source is the attached ZIP; the
player-facing README.md is inside it. This file is the "why" behind the code.

---

## 1. What the project is

A run-based roguelite game mode for **Cyberpunk 2077 2.5 + Phantom Liberty**,
built only from the game's own assets and systems (no new art, no new models).

- Main menu gets a **ROGUELITE** entry. It makes a new character, skips every
  creation screen except body type / appearance, and skips the story opening.
- **Hub:** V's apartment in Megabuilding H10 (front door sealed). The desk
  computer or **F7** opens the terminal: pick a kit, buy unlocks, toggle assist,
  start a run.
- **A run:** 3 acts x 6 floors = 18 arenas. Floor 5 of each act is an elite
  floor, floor 6 a boss. V travels arena -> arena (fade to black between them).
  After each clear, right in the arena: pick 1 of 3 rewards (+1 level each),
  the Fixer shop before each boss, then pick the next fight from 3 "doors"
  (Hades-style: the door shows the reward type, threat, arena, enemy gang).
- **Death:** V really dies (game's own death animation), then comes to at home.
  Cred (meta currency) is banked per cleared arena and buys unlocks/kits.

## 2. Who you're working with, and how they like to work

- The owner is the designer/tester. They have a CS degree and have coded before,
  but expect you to do the engineering. Talk in plain language about results.
- **Think things through thoroughly before building.** Wasted builds and
  follow-up fixes for sloppy work cost them usage. Read the relevant code first.
- **Fix issues you notice yourself** instead of listing them or asking. Only
  check in for big changes or decisions that genuinely need their input.
- Code must read like it was written by a very talented human engineer:
  clean, consistent, industry-standard, well-commented (comments explain *why*).
- Versioning: alpha builds are **v0.0.X**. Bump X for every build you hand over
  (next is v0.0.18). Update the README's title/status line and keep a short
  changelog entry for each version.
- Deliver: a ZIP of the full mod folder (README.md, r6/, archive/, source/),
  plus a plain summary of what changed and what is least certain. Every
  version also gets a CHANGELOG.md entry and a GitHub release (section 12).
- Testing: the owner installs by copying `r6/` and `archive/` into the game
  folder, plays, quits **through the main menu** (so the log is saved), and
  shares log files (section 9).

## 3. Design philosophy (keep these)

1. **All the thinking happens between arenas, not in them.** Fights should be
   readable and fair; decisions live on the reward / Fixer / door screens.
   "Easy on the player" - extrapolate this to every new feature.
2. **The director nudges, never decides.** Rewards are weighted toward the
   player's build (max +40%), but every screen keeps at least one off-build
   card. No hidden difficulty tricks: the owner explicitly rejected a secret
   always-on assist; assist mode stays an honest, visible toggle.
3. **Borrow from the genre's best**, and say where it's from in comments:
   Hades (doors, boon rarity, God Mode -> assist, Charon -> Fixer, Daedalus
   hammers -> Workshop, Fated Authority -> door rerolls), Slay the Spire (act
   quality tables), Balatro (escalating paid rerolls), Left 4 Dead (pacing
   director), Returnal (health item never falls behind the run), Roboquest
   (meta unlocks that add *choice* rather than raw power).
4. **The game's own look and assets.** Menus are built from the game's atlases,
   styles and fonts (UI/Card.reds). Music uses the game's Wwise combat sets.
5. **Minimal text.** The owner wants no "wacky blurbs" or explainers. A card
   shows what it is, its quality, and one line only if it helps the choice.
6. **Never break the player's normal game.** Everything is gated to roguelite
   characters (`RogueliteSystem.IsRoguelitePlaythrough()` /
   `IsHomeTerminalActive()`, `RLQuiet.IsOn`). Normal saves and new games must
   behave exactly like vanilla.
7. **Never hang.** Every wait has a timeout and a fallback (opening skip 45 s,
   arena streaming ~7 s, death 15 s -> vanilla death menu, busy waits 30 s).
8. **No looting.** Bodies are emptied; ammo refills per wave; health and
   grenades come from rewards/upgrades only.
9. Run gear and buffs are wiped at run end; meta progression is choice-focused.

## 4. Toolchain and constraints

- **redscript 0.5.32** (compiles all `.reds` at game start), **Codeware 1.21**,
  **TweakXL 1.12**, **ArchiveXL**, **RED4ext 1.31+**. No CET.
- One compile error anywhere = the whole mod silently does nothing. Compile
  errors are in `r6/logs/redscript_rCURRENT.log` in the game folder.
- **The previous AI compiled against the real 2.5 script cache. You probably
  can't, so be conservative:** only call functions you can verify exist in the
  2.5 game scripts (search a decompiled dump, e.g. the redmodding "cyberpunk
  2077 scripts" dumps, or Codeware's docs). Mimic existing call patterns in this
  codebase - they are all verified to compile.
- redscript 0.5.32 gotchas that bit us:
  - No `continue` statement. Use if-blocks.
  - "use of a temporary value is not allowed": don't pass a method-call result
    straight into some calls (e.g. `ArraySize(x.GetList())`) - store it in a
    `let` first.
  - Class types in signatures must be `ref<...>`/`wref<...>` (e.g. wrapping
    `HasSecondHeart(scriptInterface: ref<StateGameScriptInterface>)` even
    though decompiled dumps show it without `ref<>`).
  - A ternary mixing `null` and a ref type fails to type-check; use if/else.
  - `@wrapMethod` must match the original signature exactly (const, final,
    opt, out).
  - Only use style colour names already used in this code (MainColors.Red,
    Blue, Grey, Gold, Green, Purple, Yellow, ActiveYellow, ActiveWhite,
    Fullscreen_PrimaryBackgroundDarkest). `MainColors.Orange` doesn't exist.
    For arbitrary colours use `SetTintColor(HDRColor(...))` after
    `UnbindProperty(n"tintColor")` (see RLCard.SetQuality).
  - Hub atlas part names are exact and odd: `ico_cafting_upgrading` (sic).
  - `TDBID.ToStringDEBUG` is unreliable in release builds - never use it for
    logic.

## 5. Code layout (r6/scripts/NightCityRoguelite/)

Every file starts with a header comment explaining its design - read it.

| Area | Files |
| --- | --- |
| Core | `Config.reds` (all tunables), `Runtime.reds` (RLLog/RLDebug/RLNotify, RLDelay timers, RLDelayTarget), `RogueliteService.reds` (meta progression persisted outside saves, F7 key, session hooks), `RogueliteSystem.reds` (per-save state machine - the orchestrator), `RunState.reds`, `Story.reds` (quiet story) |
| Run | `Difficulty.reds` (enemy level + damage curves, act gates, incoming damage hook), `Encounters.reds` (wave plans, bosses, bounties), `Pacing.reds` (L4D director), `Fixer.reds` (+ buy-backs), `Objectives.reds` (survive / uplink / sabotage), `Events.reds` ("?" doors), `Overdrive.reds` (the ultimate, overclock episodes), `Gigs.reds` |
| Rewards | `RewardSystem.reds` (doors, offers, granting, skip/banish), `Director.reds` (quality rolls, pity, spikes), `BuildProfile.reds`, `PerkCatalog.reds` + generated `PerkCatalogData.reds`, `Patrons.reds`, `Boons.reds` (catalogue, rarities, stat boons), `BoonEffects.reds` (RLCombatState + the hit/kill/tick hooks everything plugs into), `Styles.reds`, `Weapons.reds` (families, DPS previews, evolution, quality curve), `WeaponMods.reds`, `LevelUp.reds` |
| Combat | `Arenas.reds` (8 arenas), `ArenaDirector.reds` (teleport, walls tick, bounds), `ArenaWalls.reds`, `ArenaCleaner.reds`, `WaveSpawner.reds` (+ boss phases, objective hold-open), `Affixes.reds` (elite affixes, `RLExplosions`), `DamageHooks.reds` (outgoing hit + NPC death hooks), `Loot.reds` |
| Player | `CharacterReset.reds`, `Kits.reds`, `Perks.reds`, `Consumables.reds` (quality steps, MaxDoc ladder, grenades), `DeathGuard.reds`, `Death.reds`, `OSHooks.reds` (OS activation -> Overdrive) |
| Hub/Menu/Audio | `ApartmentHub.reds`, `HomeDevices.reds`, `MainMenuEntry.reds`, `Music.reds` |
| UI | `Card.reds` (the one card widget everything uses; `RLIcons` incl. the gang logo atlas), `Widgets.reds`, `Hud.reds` (+ boss bar), `Transition.reds`, `TerminalPopup.reds`, `RewardPopup.reds`, `EventPopup.reds`, `FixerPopup.reds` |

Generated files - edit the generator, not the output:
- `Rewards/PerkCatalogData.reds` <- `source/perks/catalog.tsv` via `source/perks/build_catalog.py`
- `r6/tweaks/NightCityRoguelite/*.yaml` and `source/localization/en-us.tsv` <- `source/tweaks/gen_tweaks.py`
- `archive/pc/mod/NightCityRoguelite.archive` <- `source/quest-patch/` + `source/localization/` (needs WolvenKit CLI; see that README). Avoid rebuilding unless necessary.

Conventions: `module NightCityRoguelite`; everything prefixed `RL`; static
helpers as `public abstract class RLThing`; timers via `RLDelay(game, target,
n"action", seconds)` + `OnDelayed(action)` switch - never busy loops; tunables
in `Config.reds`; `RLLog` for meaningful events, `RLDebug` for verbose detail.

## 6. The run flow (RogueliteSystem state machine)

```
new game -> AwaitingTakeover -> Hub
Hub --START RUN--> Preparing --> RunHome (first door; Quartermaster reward)
RunHome / Cleared --door--> Traveling (fade out, teleport while black,
    wait for arena navmesh, fade in) --> Deploying (5 s countdown, music)
    --> InEncounter (waves; an objective holds the encounter open) --> Cleared
Cleared: reward popup (auto-opens after 2.5 s) -> AdvanceFloor() ->
    Fixer if next floor is a boss -> door picker -> Traveling ...
"?" door: no trip - OpenEvent -> event popup -> OnEventChoice (+1 level,
    counts as a floor) -> AdvanceFloor() -> next doors
InEncounter --health at 1%--> Flatlined (real death, resurrect) --> Ending
    (home, reset) --> Hub
Final floor cleared --> Cleared (5 s) --> Ending --> Hub
```

- `run.advancePending`: the floor counter advances only when the reward is
  picked, so the reward screen belongs to the cleared floor and the
  Fixer/doors to the next one.
- F7 between fights reopens whatever is waiting (`OpenNextStep`): reward ->
  Fixer -> doors. Closing a popup never discards anything.
- Saving is locked during a run (`SaveLocksManager`, reason
  `NightCityRoguelite.Run`). Quitting mid-run = abandoned run = flatline on
  next load (`RogueliteService` run token).

## 7. DO NOT change or overwrite (learned the hard way)

1. **`RLCharacterReset.ShouldRemove` / `BodyItems()`.** V's arms, heads,
   holstered fists etc. must never be removed - doing so gave V invisible
   limbs. Clothing is kept on purpose.
2. **Never change journal state inside a journal callback.** `RLJournalGuard`
   only records entries in the callback and sweeps them 0.25 s later via
   RLDelay. Doing it inline froze new games on a black screen (v0.0.10).
3. **Never gate or block the base-game quest graph** (also part of the v0.0.10
   freeze). The story is quieted only by: untracking, setting journal entries
   inactive, hiding pop-ups, and declining incoming calls.
4. **Quest patch facts** shared between the archive and scripts:
   `nc_roguelite_start`, `nc_roguelite_skipping`, `nc_roguelite_ready`,
   `nc_roguelite_opening_skipped`. Renaming them breaks the opening skip.
5. **Persistent field names** in `RogueliteService` and `RogueliteSystem` and
   **unlock IDs** (`kit.Netrunner`, `perk.Reroll`, ...) are stored on disk.
   Renaming them silently wipes testers' Cred/unlocks. Add new ones instead.
6. **Death sequence** (`Player/Death.reds` + `RogueliteSystem.Flatline/
   DeathTick`): V is Immortal during runs (DeathGuard). On lethal damage the
   guard is disarmed, fact `block_death_menu` is set to 1 (old value restored
   after), health is set to 0, and the `HasSecondHeart` wrap returns true so
   the game's own Second Heart resurrection revives V. Keep every fallback.
7. **Teleport only while the screen is black** (`RLTransition`), and wait for
   the destination to stream in before fading back in.
8. **Calls are declined**, not dropped (`PhoneSystem.OnTriggerCall` wrap sets
   the phone fact to `Rejected`). Dropping made quests retry forever. Calls the
   story starts directly (StartCall) are left alone on purpose: hiding them
   leaves the scene running unseen.
9. **No attribute/perk points ever** for roguelite characters: AddDevelopment-
   Points, Buy/Sell/ResetAttribute, non-forced BuyNewPerk and SellNewPerk are
   blocked. The mod's own grants use `BuyNewPerk(perk, true)` and
   `SetAttribute`. Kits set attributes; each perk card adds +1 to its
   attribute. XP only comes from `RL_GrantLevels` (1 level per reward).
10. **Main menu skip** (`MainMenuEntry.reds`): the campaign screen is hidden
    with `SetVisible(false)` - not opacity, which its intro animation
    overrides. Never stop or skip its intro animation: the intro's end calls
    `OnIntroComplete`, which is where the mod moves on (v0.0.14 jumped the
    intro to its end and testers got stuck on a blank screen). The life path / attribute screens are skipped via scenario
    wraps; don't reintroduce them.
11. **Music sets must use events from one Wwise combo each** (mixing combos
    leaves a track playing that the set's stop event doesn't end). Event names
    were taken from the game's sound metadata; don't invent new ones.
12. **WaveSpawner: leave enemies alone for 2 s after spawning** (their
    position reads as the world origin at first; moving them then left one
    half-buried).
13. **One MaxDoc drop per arena** (`m_healthDropTaken`).
13b. **Rewards are granted inside the arena, where pickups are filtered.**
    Every granted item must be registered first (`ExpectOfferGrant` /
    `ExpectGrant`), or the no-looting filter takes it away again (v0.0.15 bug:
    missing/wrong rewards).
13c. **Music: a fight plays either a Wwise score set or a radio station,
    never both** (`RLMusic.Prepare`, `RLRadio`). Radio goes through the
    pocket radio emitter with AudioSwitch, exactly as PocketRadio does.
14. Apartment coordinates/boxes in `Config.reds` and the apartment entry logic
    (hallway first, step inside once the floor streams in) were tuned in game.
15. Enemies are TweakXL variants (`enemies.yaml`) of the game's open-world NPCs:
    hostile from the start, combat-alert, one team, emptied loot. Keep the
    roster generator flow (the boss lists in `EnemyRoster.reds` are part of it).
16. **Combat hooks:** V's outgoing hits are scaled in a wrap of
    `DamageSystem.ProcessCrowdTarget` (runs right after the game's global
    modifiers, before `DealDamages`) and skip `projectionPipeline` hits; hits
    V takes in `ProcessPlayerIncomingDamageMultiplier`. Kill effects fire
    once per enemy (`RLCombatState.MarkDead`): from the `NPCPuppet.OnDeath`
    wrap, or from the spawner's poll for enemies that were defeated instead.
    Enemies removed by Unstick never fire them.
17. **V's own blasts** (Volatile Kills, sabotage charges) set
    `RLCombatState.selfBlastUntil`; hits from V in that window are zeroed so
    they can't hurt V. Keep that when adding new player explosions.
18. **Hit flags carry styles:** `RLHitFlag` bits 1-32 are how a hit landed,
    bits from 256 up are its styles (`RLHitFlag.Style`). The last hit's
    flags and weapon are what the kill hook sees, so style signatures,
    weapon mods' kill effects and gig counts all read the killing hit. Keep
    new hit kinds below 256.
19. **Between fights, the floor advances on the level-up**, not the reward:
    reward (or event, or skip) -> `BeginLevelUp` -> level-up pick ->
    `AdvanceFloor`. Gig and starter-pick screens come before the first door
    and never advance anything (`advancePending` is false then).

## 8. Balance (all numbers live in Config.reds or the named file)

- Enemy level = floor depth + act offset (-1 / 0 / +1). V gains 1 level per
  reward (only XP source).
- Damage V takes: 55% on floor 1 -> 100% on floor 18 (game difficulty Hard),
  x pacing (+/-8%), x (1 - assist), x boons, x (1 + event trade-offs).
  Assist = 20% + 2% per run lost while on, max 80%, visible toggle only.
- Doors: event 22% (from floor 2), bounty 15% (Act 2+), objective 30% of
  fights (from floor 3). Boon weights per patron screen: new 10, upgrade 6,
  duo 6, legendary 4; rarity = director roll above expectation (+1 from floor
  10); upgrades +1 (+2 on a big roll).
- Bosses: reinforcements at 60% health, enrage at 30%. Affixes: elites 1 from
  floor 3, 1-2 in Act 2, 2 in Act 3; bosses 1 from Act 2.
- Waves: 2 per fight in Act 1, 3 later; per-wave size grows with depth and
  threat; elite floors have an elite every wave; boss floor = 2 waves + boss.
- Reward quality expectation: Common (floor 1) -> Legendary+ (floor 18);
  director odds [25 below, 55 at, 16 +1, 4 +2]; heavy/elite and light shift
  them; pity +6 per flat screen, spike after 2 flat screens; magnificence
  makes big picks rarer.
- Eddies per arena: (100 + 40 x depth) x 0.75 light / 1.0 / 1.4 heavy, +400
  on boss floors. Fixer prices scale with depth; Street Smart -20%.
- Rerolls: 1 free per act (+1 per Fixer Contacts unlock, Fixer sells +2);
  then eddies: (60 + 20 x depth), +50% per paid reroll on the same screen.
- MaxDoc floor: rises with depth (`HealthFloorStep`); one extra drop per arena
  (boss always, elite 25%), max floor + 2.
- The v0.0.13 playtest log (good tuning reference): a Solo run reached floor 8
  and was lost to a heavy Chrome fight (19 enemies, Act 2); floors 1-7 felt
  right ("first build where it's a viable and fun game mode").

## 9. Testing and logs

- The game doesn't write script logs to disk in release builds, so the mod
  keeps its last 600 log lines inside
  `red4ext/plugins/Codeware/Persistent/ScriptableServiceContainer.dat`
  (readable with `strings`). It's written only when the game unloads a world or
  saves, so **testers must quit through the menu**; a crash loses that
  session's log.
- Compile errors: `r6/logs/redscript_rCURRENT.log`.
- **Telemetry** (`Core/Telemetry.reds`): machine-readable records in the same
  .dat, `T1|<seq>|<run id>|<KIND>|k=v;...` - RUN, FLOOR (door, objective,
  arena, faction, waves, seconds, damage, lowest health, heals, kills), OFFER
  (every card), PICK, BUILD (level, attributes, build tags, boons), DEATH (the
  last attacker, with role and affixes), END, MARK. Last 1500 records.
  Records are numbered because the store keeps identical names once.
  `tools/runreport.py <game folder>` prints a floor table per run; `--csv`
  writes runs/floors/picks CSVs; `--marks` prints every bug mark. When adding
  a decision point (a new screen, door type or event), record its OFFER/PICK.
- **Bug marks:** F8 (`RLConfig.BugKey()`) or the MARK BUG card logs
  `===== BUG MARK #n =====` with the state machine, popup/countdown flags,
  arena, run and the spawner's view of every enemy (`RLWaveSpawner.Describe`).
- Useful log lines: `Pacing: floor N threat T cleared in Xs, damage taken
  ...` (one per arena), `Reward director: ...`, `Declined an incoming call
  (...)`, `Call from the story: ...`, `Flatlined: V is going down.`,
  `V came to after Xs.`

## 10. Status and what's next

- **The content patch (dev, untested in game):** level-ups after every floor,
  styles, the weapons rework (DPS on cards, mods, evolutions), Overdrive from
  an OS at the Act 1 boss, gigs, capacity overclock, skip/banish/buy-back,
  act gates, the Wireman kit and 33 more perks. Design: the "Runs That Build"
  doc. Least certain - check first:
  1. The between-fights flow: reward -> level-up -> (Fixer) -> doors, after
     events too; skip and banish (log "Banished: ...").
  2. Weapon DPS previews (`RLWeapons.PreviewDPS`: a dry item via
     `Inventory.CreateItemData` + `ForceItemTier`) - a card without a DPS line
     means the stat came back 0.
  3. Overdrive firing on OS activation (status effects in
     `Player/OSHooks.reds`; log "Overdrive: ..."), and ZERO HOUR's time
     dilation leaving V at full speed.
  4. Evolution swapping the weapon and equipping the iconic.
  5. Capacity overclock: the Humanity modifier keeps the game from refusing
     over-capacity chrome.
  6. Relic perks (Espionage_*) being granted outside Phantom Liberty's quest.
- **Unreleased (on the `dev` branch, untested in game):** patrons and boon
  rarities, bosses with phases, elite affixes, objectives, events, bounties,
  gang logos in menus. Least certain - check first in the next test log:
  1. Boss records spawning and fighting (gang bosses, Minotaur mechs,
     cyberpsychos via DynamicEntitySystem) - log lines "Spawned ..." /
     "Enemy never spawned".
  2. Explosions (`RLExplosions.Blast`: damage from the attack record, no
     fire VFX - only shockwave sound, impulse and dismemberment).
  3. Map pins for objectives (`Mappins.QuestStaticMappinDefinition`).
  4. Boon damage multipliers actually applying (log a hit if unsure).
  5. The gang logo atlas showing on cards (`gang_logos.inkatlas`).
- **Dogtown arenas:** not added. No reliable coordinates were found online
  (AMM's location list only has the Dogtown apartment interior). Needs
  in-game positions read from the "Arena start" log line.

- **v0.0.16 and v0.0.17 are untested in game.** It was built from the owner's v0.0.15
  playtest notes (see CHANGELOG.md). Still open from that test: a story call
  (Judy) that the quest force-starts after being declined still shows its
  call card (it didn't interrupt anything). v0.0.17 logs the id of every
  journal entry it quiets (debug lines "Journal: quieted ...") so the quest
  behind it can be identified from the next log. Least certain, check these first with the
  first test log:
  1. Death -> resurrection -> home sequence (Player/Death.reds).
  2. The fade overlay covering the screen (`inkGameNotificationsLayer`).
  3. Campaign screen fully hidden.
  4. Judy's call (and other story calls) staying declined.
  5. Card intro animations / centred layouts at 1080p and 1440p.
- Ideas discussed but not built (ask before doing big ones): a run summary
  screen at home; tighter city arenas (Dogtown); more boons; Overdrive boons
  from patrons; the "Never Fade Away" narrative.
- Known design decision to keep: the Fixer appears after the elite floor,
  before the boss door (Hades' Charon placement).

## 11. How to work with the owner this week

1. Ask for the latest log files and their notes after each test.
2. Read the files you'll touch, plus their header comments, before writing.
3. Make focused changes that match the existing style; keep comments current.
4. Update README.md (and this file's section 10) with what changed.
5. Hand back a v0.0.X ZIP and a short, plain summary: what changed, what's
   least certain, and anything they should test.

## 12. Version control and releases

- Repo: https://github.com/dotXCVI/night-city-roguelite (public, MIT
  licensed - see LICENSE). One commit per version, oldest v0.0.3 (v0.0.3-v0.0.7
  were first released as v0.3.0-v0.7.0). `CHANGELOG.md` has every version,
  newest first.
- **A version commit is any commit on main whose message starts with
  `vX.Y.Z: <title>`.** The Release workflow (`.github/workflows/release.yml`
  running `tools/publish-releases.sh`) tags each version commit that has no
  release yet, builds the ZIP from that commit's files, takes the notes from
  that version's CHANGELOG.md section, and publishes the release with the ZIP
  attached as `NightCityRoguelite.zip` and `NightCityRoguelite-<tag>.zip`. The
  highest version is marked latest.
- Testers use the permanent link
  https://github.com/dotXCVI/night-city-roguelite/releases/latest/download/NightCityRoguelite.zip
  which always serves the newest release.
- To publish a version: bump README.md's title/status, write the changelog
  entry, then `tools/release.sh v0.0.16 "Short title" notes.md` (it adds the
  entry to CHANGELOG.md, commits as `v0.0.16: Short title` and pushes).
  Non-version commits (docs, tooling) must NOT start with `vX.Y.Z:`.
- Without a shell: on github.com, edit/upload the changed files, add the
  CHANGELOG.md entry (`## v0.0.16 - Title (date)` at the top), and commit with
  the message `v0.0.16: Title`. The workflow does the rest.

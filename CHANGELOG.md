# Changelog

Every build of Night City Roguelite, newest first. Each version is a tagged
release on GitHub with its ZIP attached.

## Unreleased

**Arenas**

- **Thirteen new arenas** across the city: Rocky Ridge, Jackson Plains, Coronado Hideout, East Coronado, West Wind Estate, Longshore Stacks, Dogtown Back Streets, Japantown Backlot, Tyger Sweatshop, Charter Hill, Wellsprings, West Downtown and Northside Yards - gang outposts, cyberpsycho spots and gig sites picked by an arena scout that measured how much of each is walkable. Gig sites that started their gig, a call or a scene when V showed up were left out.
- **Bosses fight at landmarks.** A boss floor's door takes you to one of the act's story locations - the Grand Imperial Mall hosts Act 2's boss now. More are lined up (the All Foods plant, Konpeki Plaza, Arasaka Tower's atrium, CEO floor and roof, Mikoshi, the Arasaka estate, Embers, Totentanz, Batty's Hotel, Dogtown's stadium, the Black Sapphire, Cynosure, the spaceport) and switch on once they're scouted.
- **Arenas up high:** V is held at the start while an arena streams in, so a rooftop arena doesn't load under a V who fell to the street.

**Terminal**

- **The hub and the upgrades screen fit the screen:** the stats row and the cards no longer run past the panel, and the upgrades header isn't cut off. The ON tag is gone - the lit take is the one that's on.

**Fixes**

- **Objective markers you can't reach:** a sabotage charge spot could land somewhere V can't get to, like a shop behind a locked door in the Grand Imperial Mall. Markers now need a full walking path to V on V's floor, and one you get stuck near (close, not getting closer) moves to you after a few seconds. Thanks to Jon for the report.
- **Locked rooms in arenas open up:** locked, sealed and keypad doors inside an arena are opened when you arrive, so you never need a campaign code or a skill check to reach an enemy or a marker. Thanks to Jon.
- **The legendary hammer (and any weapon knocked out of an enemy's hands)** no longer lands on the floor - disarms, finishers and bosses losing their weapon used to leave one lying in the arena.
- **Logs that keep what matters:** long telemetry records were cut off at 255 characters (build records lost the OS, weapon and effects); they're saved whole now. The log keeps 2,000 lines instead of 600, and an F8 bug mark records the arena, V's position, the wave and the objective's markers in the run telemetry, which outlives the log.
- **The effect ledger counts everything an effect does:** blasts, strikes, missiles and the burns, bleeds and shocks an effect starts are credited to it as they land (Kill Switch, Payload and Napalm used to read 0 damage). Fights also log the main weapon's hits, so a weapon effect's fires can be read against them. `tools/runreport.py --effects` totals it all.
- **Only quickhacks that fight:** every quickhack card is now one of the thirteen hacks the mod knows (each as likely as the next - before, a hack with more versions in the game came up more), so stealth and distraction hacks are gone. Memory Wipe is out; Ping only MARKS, so it's dealt only once something you hold uses MARK, and never starts a deck. DAEMONS doors only show up while you have a cyberdeck.
- **Doors you pass over come back less** (2/3 as likely after one screen, 1/2 after two) until you take one, so the same door doesn't fill every screen.
- **Run reports across testers:** every run records its build, terminal upgrades and patron line-up; every fight its wave times, the enemy types that hurt V most and the effects held (so one that never fires still shows); every pick how long the screen was up. A run left by quitting says where, and terminal purchases and kit unlocks are logged. `tools/runreport.py` takes one file per player and sums them up (`--summary`, or `--html` for a page): depth and deaths by kit, damage taken by act, what hurts, arenas, objectives, card and door take rates, effects per hit. `tools/collect-logs.bat` zips a tester's logs onto the desktop.

## v0.0.19 - Runs that hit different (2026-10-28)

Runs that hit different: the patrons are rebuilt around effects that combine,
the run builds one gun, and health stops being a resource. Start a new
roguelite character for this build.

**Patrons and effects**

- **Effects, not stat boons.** Every patron reward is now a rule that changes how a fight plays - Headshots MARK. Kills fire micro-missiles. Crits arc to the crowd. BURNING enemies explode. Blasts throw shrapnel. Dashing knocks enemies down.
- **Keywords.** Effects speak eleven words - MARK, FOCUS, BLAST, SHOCK, GLITCH, BURN, BLEED, MOMENTUM, SHIELD, LUCK, DEAL - and fire whatever applied them, so effects from different patrons feed each other. A word flashes on the HUD when one lands; chains play out a beat apart so you can watch them go.
- **26 effects, 6 weapon effects, 15 duos, 7 legendaries, 6 favours.** Every effect has an **overclock**, a stronger version offered once you hold it. A duo for every pair of patrons; a legendary once you hold two of a patron's effects; a free **favour** for three.
- **Four patrons a run,** shown on the terminal before you start: fifteen line-ups, each a different web.
- **Patron screens are dealt:** one card that builds on what you hold, one you haven't seen, one open. The first door of a run is always a patron, and its first screen only deals effects that start something.
- **Cards show how they fit:** keyword chips, NEW, BUILDS ON, and a YOUR BUILD strip that lights up the effects a card links to when you hover it.
- **The HUD's build row:** each patron's count, your cover, SHIELD and MOMENTUM.

**Weapons**

- **One main weapon.** Your kit's gun takes every weapon reward: Tune-Ups (a quality step, with DPS before and after), weapon effects (two slots, three on an iconic; they work on blades too) and the evolution.
- **Sidearm:** your kit's backup steps up after every boss. So does the main.
- **Trades:** a new gun arrives at your main slot's quality and keeps its weapon effects - swapping is about how it plays.
- **Arm chrome is a main weapon:** the Brawler's Gorilla Arms and the Wireman's Monowire take the main slot (their gun becomes the sidearm). Tune-Ups follow the game's own upgrade path for arm chrome, the Armory offers a **REWIRE** instead of a trade - Thermal arms BURN, Electric arms SHOCK, Chemical arms make them BLEED - and the evolution goes to Legendary++ with a third weapon effect slot. Kit chrome brings its own capacity, so it's never refused at level 1.
- **Weapon mods are gone** (weapon effects replace them), and so is the weapon-quality damage penalty.

**Kits are their main weapon**

- **Every kit lives in its main slot.** The Netrunner's cyberdeck is its main weapon now (its quickhacks are its hits), the Demolitions kit fights with the Projectile Launcher (the SMG backs it up), and the Brawler's backup is a pistol, with Wrecking Ball - the blunt perk Gorilla Arms use - instead of a shotgun perk.
- **Chrome mods:** main-weapon chrome gets two mod slots of its own - Gorilla Arms KNUCKLES and BATTERY, Mantis Blades BLADE and ACTUATOR, Monowire CABLE and BATTERY, the launcher ROUND and WIRING, the deck ICEBREAKER and FIRMWARE - three mods each, every one with an overclock, all speaking the keywords. 30 in all, dealt on Tune-Up doors (our Daedalus hammers), so they never crowd the Armory.
- **Weapon effects read your weapon.** A launcher fires shells and a deck uploads quickhacks, so every weapon effect has its own version for each, written for it: Payload's every 3rd shell is a heavy one, and every 3rd quickhack BLASTS. Hot Barrel overheats the deck. Lucky Round makes 1 in 4 quickhacks jump to the next enemy. Thunder Rounds is back on decks: a second hack on the same enemy calls down the strike.
- **Evolution is a new trick.** Evolved chrome gets a signature that changes how it plays, on top of Legendary++ and the third effect slot: SHOCKWAVE (Gorilla Arms' strong punches floor everything around), BLOOD RUSH (a Mantis kill slows time and gives your dodge back), LIVE WIRE (a lash copies its target's statuses around), BELT FEED (a shell that kills hands its charge back), CASCADE (every quickhack spreads to two more enemies).
- **The stranger deals in chrome too:** a PROTOTYPE of your chrome's signature and its third slot, early (Tune-Ups take it the rest of the way), or once it has its signature an off-market mod that comes overclocked. Same price as his iconic.
- **Arm chrome from a Chrome door** can become your new main; your gun steps down to sidearm.

**Netrunner**

- **Quickhacks are your gun.** Your slotted hacks run at your deck's quality, and every deck Tune-Up takes them up with it.
- **A start that kills:** the Netrunner opens with one damage hack (Overheat, Short Circuit or Contagion) and one control hack. The Wireman's deck brings a setup hack for the wire.
- **Hacks speak the keywords:** Overheat BURNS, Short Circuit SHOCKS, Ping MARKS, Weapon Glitch and Cyberware Malfunction GLITCH, and Contagion's poison counts as BLEED. Their cards carry the chips and BUILDS ON.
- **Your loadout is yours to shape:** the Armory offers a new quickhack in place of a trade, Daemons doors deal hacks your deck doesn't run, and a full deck asks which hack to swap out - with a BACK if you change your mind.
- **Your deck on screen:** the YOUR BUILD strip and the terminal show your hacks in their keyword colours.
- **The first gig** always matches your main weapon, and perks for the main weapon turn up twice as often in Training.

**Favors and the terminal**

- **DATABASE:** a new terminal screen (at home, on the door picker and mid-fight) with every keyword in its colours, the run's terms, each patron's effects with their overclocks, the duos, every chrome's evolution and mods, and the quickhacks - styled like the cards, read from the same data.
- **A cleaner terminal:** test runs and MARK BUG are gone from it (F8 still marks a bug); assist, the database, the guide and upgrades share the column beside START RUN.

- **Favors:** kits are called in with favors now, not Cred. A fixer owes you one for every boss you put down, one for winning, and one the first time you reach Act 2, Act 3 and the end. Kits cost 2 to 8 (30 for all seven). Kits you own stay yours.
- **The terminal, rebuilt:** UPGRADES is ten rows - Cover, Choice, Rerolls, Head Start, Eddies, Body, Overdrive, Heat, Style, Fortune - each with two takes on the idea (Hades' Mirror). Buy a row's ranks once, switch takes for free. Every rank has its own name and line. Your old unlocks carried over as the nearest ranks; Edge III (and Street Map, if you also had Wide Net) is refunded.

**Run shape**

- **HOT doors:** one in Act 1, two in Acts 2 and 3, placed when you need a spike most. Elites in every wave and a lieutenant with two affixes; the reward comes two steps up, with a card more and half again the eddies.
- **Full health every fight.** **Trauma Team cover** - one a run, two with the new Trauma Platinum unlock - gets you back up at half health instead of a flatline.
- **No level-ups:** one pick a floor, three cards a screen (four with Wide Net). Levels are set per act - 3, 10, 17 - for V and enemies alike, so every pick inside an act is pure gain.
- **No act gates:** enemies never shrug off your damage. ARMORED is now plating that shatters once a quarter of its health is gone.
- **Damage taken per act:** 60%, 80%, 95%.
- **CRED doors** now and then: skip the card, bank Cred for good.
- **Rerolls** come from charges only (one an act, more from unlocks, the Fixer and the Afterlife's favour) - no more eddies.
- **Doors lead with the reward:** the patron's art, what the screen deals, its keywords and how many of its effects you hold.
- **Events retuned:** the Ripperdoc restores a spent cover, the Bookie bets an effect on its overclock, Misty's cards overclock and widen screens, the stranger buys your cover for a legendary.
- **Unlocks:** Head Start and Vitality are retired and refunded (the rest now live in the terminal's rows).

**Weather**

- **Arena looks:** eight time-and-weather pairs that read at a glance - HIGH NOON, GOLDEN HOUR, CLEAR NIGHT, FOG BANK, NEON RAIN, SMOG, TOXIC STORM, SANDSTORM. Random weather mostly landed on clouds at night, which nobody could see. Storms come with hot doors, elites and bosses. The mod checks the weather took and asks again if it didn't.

**Fixes from the first v0.0.18 run**

- **Gorilla Arms and Monowire never went in:** the Brawler and Wireman kits handed out their gun but the arms were quietly refused at install, leaving bare hands. Kit arms are now a fixed Uncommon model installed after V's level is set, bring their own capacity, are put back on any trip they're missing from, and the log says why if the game ever refuses chrome. Arm chrome is also safe from the stray-weapon sweep. Thanks to Jon for catching this one and for testing.
- **Eddies:** NCPD bounties no longer pay out for roguelite characters. Most gang members carry one, which flooded runs with eddies - enough to buy out the Fixer by floor 5.
- **Doors say what they pay:** "Pick 1 of 3 quickhacks", "Pick 1 of 3 Militech effects", "No fight - MISTY'S READING", and the objective spelled out.
- **Cyberware, quickhack, grenade and OS cards show what the item does,** in the game's own tooltip words and numbers. MaxDoc and grenade upgrades say what they change.
- **Quickhacks that didn't install:** vendors also list crafting specs, and one of those ("Bait") could be offered and given instead of the quickhack. Specs are out of the pools.
- **Music doubling after the Act 1 boss:** Royce's boss loop is now ended with its own outro.
- **The Junkyard's locked garage:** enemies no longer spawn in it, and an enemy that can't be moved out of somewhere is removed (and counts as killed) right away instead of after two minutes.
- **Logs:** reward kinds and the run state are named properly in the telemetry and bug marks; every fight logs how much damage each effect did, and with a deck how many quickhacks you uploaded and how long you sat short of RAM.
- **Music stacking between arenas:** every trip ends every score the mod can play, not just the last one, and cuts any outro still ringing once the screen goes black, so each arena starts in silence.
- **Your own pocket radio** no longer plays on top of the score. It's switched off for the run and comes back when you get home. Turn it on mid-run and your station replaces the score until you turn it off.
- **Stuck in the floor on arrival:** V is placed again once the arena's ground has loaded, before the fade-in.
- **Glitch transitions actually show:** the game's glitch played under the black, where nobody could see it. Trips now glitch the world first, then the black comes down with the destination's name tearing in red and blue, and the arena glitches back in as it lifts.
- **Enemies that wouldn't move** are now moved with the AI's own teleport as well.
- **Air Dash** has a 1.5 s cooldown.
- **Card text:** item effects are rendered to plain text (no more raw markup or {__empty__}); Operating System cards show their Overdrive instead of the game's long tooltip. The stray code in popup headers is gone.

**Updating:** delete both `r6/scripts/NightCityRoguelite` and `r6/tweaks/NightCityRoguelite` before installing - an old `boons.yaml` left behind is harmless but stale.

## v0.0.18 - Runs that build, the armory (2026-10-27)

A big content patch - runs that build - plus a polish pass on home and the menus. Start a new roguelite character for this build.

**Home and menus**

- **The armory:** kits are picked at the stash in the weapon room at the back of the apartment (the mod opens its door). Locked kits are bought there. No stash on your character? F7 in the room does the same.
- **A guide** the first time you come home: six pictures covering the apartment, the terminal, the armory, the run, patrons and flatlining. HOW IT WORKS on the terminal brings it back.
- **Pictures on the cards,** from the game's own codex: door cards show the arena with the reward as a badge, boon cards the patron's crew, gig cards the fixer, kit cards the weapon. Events open with whoever you're dealing with, and Misty deals real tarot cards.
- **Hover is an animation now:** the card lifts and its frame lights up. No more colour fill behind the text.
- **The terminal** is laid out around START RUN and your kit, with assist, test runs and the guide beside them.
- **Text pass** across cards, doors and notifications.
- **README** rewritten; the full reference moved to docs/MECHANICS.md.

**Builds and choices**

- **A level-up after every floor:** after the door's reward, pick one of three small upgrades - an attribute, a perk from a tree you're in, or a weapon mod, weapon tune-up, boon upgrade or capacity. Twice the picks per run; the level comes with it.
- **Styles:** every reward feeds one of 12 styles (Blades, Brawler, Monowire, Gunslinger, Heavy, Rifles, Marksman, Netrunner, Smart, Tech, Demolitions, Ninja). Ranks at 3, 6 and 9 points add +10/+20/+35% damage, and rank III a signature effect. Cards show the styles they feed; the reward footer and the F7 screen show yours.
- **Weapons rework:** weapon cards show DPS against your best equipped weapon, the class, its attribute and how it plays. New weapons are never worse than what you have, and every Armory screen offers an upgrade or mod for your own gun.
- **Weapon mods:** 22 mods (Hades' hammers) in two slots per weapon - three on iconics.
- **Iconics are earned:** a Legendary weapon with both mod slots filled evolves into an iconic of its type. The ICONIC door and random Armory iconics are gone; the stranger's deal waits until Act 2.
- **Overdrive:** the Act 1 boss now pays out a choice of Operating System (Sandevistan, Berserk or a cyberdeck with Overclock). It unlocks Overdrive, a meter that fills from kills and damage taken; activating your OS at full charge triggers ZERO HOUR, RAMPAGE or BLACKWALL.
- **Gigs:** a run opens with three gigs from Night City's fixers - a style kill count before the Act 2 boss, paying eddies and style points.
- **Capacity overclock:** chrome that doesn't fit can go in anyway, at the risk of cyberpsychosis episodes.
- **Saying no:** skip a reward screen for eddies, banish one card per act, and the Fixer buys back gear you don't use. The Fixer also sells a weapon mod.
- **Workshop** on floors 4, 10 and 16, with mods and evolutions.
- **Build weighting** leans much harder towards your build once you've taken an Operating System, and Signature perks need their attribute at 15.
- **Gates:** from Act 2, bosses take 15% less damage (25% in Act 3), and every Act 3 enemy 10% less. A weapon far below the floor's quality deals less damage.
- **New kit, Wireman:** Monowire, a cyberdeck, a quickhack and Siphon.
- **33 more perks in Training:** the monowire perks (Siphon, Finisher: Live Wire), the Relic tree (Jailbreak, Data Tunneling, Spatial Mapping, Vulnerability Analytics, Emergency Cloaking...), Ticking Time Bomb, Doomlauncher, the throwing and stealth branches.
- **Door cards say what the ground is like:** OPEN GROUND, MIXED or CLOSE QUARTERS.

**Patrons and the rest**

- **Patrons.** Boons now come from six of Night City's powers - Arasaka, Militech, the Voodoo Boys, Maelstrom, the Aldecaldos and the Afterlife - each with its own style. A patron door offers three of that patron's boons. 44 boons in all.
- **Boon rarities and upgrades.** Boons come as Common, Rare, Epic or Heroic, and a boon you hold is offered again as an upgrade. Three boons from one patron unlock its legendary; boons from two patrons unlock their duo (eight duos).
- **Boons that change how you fight:** damage on headshots, crits, first hits, melee, explosions and quickhacks, kill effects (healing, eddies, ammo, RAM, exploding bodies, slowed time), damage reduction, second chances.
- **Bosses.** Act 1 ends with the gang's own leader, Act 2 with a MaxTac squad, Act 3 with a Minotaur mech. Bosses have a health bar, call reinforcements when hurt and enrage near death.
- **Elite affixes:** Armored, Berserk, Regenerating, Volatile and Vampiric, announced when the elite appears.
- **Objectives:** some fights ask you to Survive, Hold the Uplink or plant charges (Sabotage), with map markers and bonus eddies.
- **Events:** "?" doors with no fight - a back-alley ripperdoc, a bookie, Misty's tarot reading, a stranger with an iconic.
- **Bounties:** from Act 2, a door to hunt a lone cyberpsycho for eddies and boons.
- **Menus:** patron and gang logos on door cards, patron colours on boon cards, a boss health bar, and your boons listed by patron on the F7 screen during a fight.
- Fixer's Cut makes the Fixer and paid rerolls cheaper; Afterlife Legend adds a card to every reward screen.
- **Test runs:** the terminal can start a run on any floor (bosses, Act 2, Act 3) with the levels, eddies and a few boons a real run would have by then. Test runs show the new door types every time, pay no Cred and don't count in your stats.
- **Bug marker:** press F8 (or MARK BUG on the F7 screen in a fight) when something goes wrong; the log gets a snapshot of the fight.
- **Run telemetry:** every run records its doors, fight times, damage taken, reward offers, picks, build and cause of death. `tools/runreport.py` turns it into a floor-by-floor report or CSV.
- Fixed: the HUD line stayed hidden for every run after the first one in a session.
- Fixed: waves no longer keep coming for a few seconds after V goes down.


## v0.0.17 - Stray weapons removed, call tracing (2026-10-27)

Finishing the v0.0.15 test notes.

- **Picked-up weapons can't stay.** On every trip, any weapon the run didn't hand out (kit or rewards) is removed - a safety net behind the pickup filter for weapons enemies drop (the legendary hammer).
- **Judy's call:** the log now records which story entries keep coming back, so the quest behind her forced call can be found and handled in the next build.
- Checked against the game: the weather states used for arenas are the game's own `24h_weather_*` states.

## v0.0.16 - Rewards fixed, radio, weather, no softlocks (2026-10-27)

From the v0.0.15 playtest.

- **Rewards always arrive.** Rewards are picked inside the arena now, and the no-looting rule was taking the reward items away again (the missing EMP grenade, the wrong pistol). Granted items are now exempt.
- **Iconics are never below Rare**, and the card says their quality.
- **Every kit starts with a basic frag grenade**, and Armory screens offer grenades a little more often.
- **Muscle Memory for everyone:** sprinting, sliding and vaulting no longer restart a reload.
- **No more softlocks from stuck enemies:** 40 s without a kill brings the remaining enemies to you (twice), then removes them as kills. This also covers enemies stuck in doorways.
- **Radio in fights:** each fight plays either a radio station (the Edgerunners station, Morro Rock, metal - likelier the harder the fight) or the game's combat score, never both.
- **Time and weather per arena:** daylight and clear skies for light fights, night, rain, fog and smog for heavy ones, sandstorms in the Badlands, full storms for bosses.
- Known: a story call the quest forces through (Judy) can still show its call card.

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

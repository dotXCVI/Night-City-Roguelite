# Night City Roguelite - tester guide

Thanks for testing! This is an early alpha of a roguelite mode for Cyberpunk
2077. You fight through 18 arenas, pick rewards between fights, and unlock new
stuff as you go. It won't touch your normal saves or playthroughs.

## What you need

- **Cyberpunk 2077 version 2.5** with the **Phantom Liberty** expansion.
  On Steam or GOG, just make sure the game is fully updated.
- These five free framework mods, all on Nexus Mods (a free account is enough):
  - RED4ext: https://www.nexusmods.com/cyberpunk2077/mods/2380
  - redscript: https://www.nexusmods.com/cyberpunk2077/mods/1511
  - Codeware: https://www.nexusmods.com/cyberpunk2077/mods/7780
  - TweakXL: https://www.nexusmods.com/cyberpunk2077/mods/4197
  - ArchiveXL: https://www.nexusmods.com/cyberpunk2077/mods/4198

  Get the latest version of each. If you already mod Cyberpunk, you probably
  have them; just update them.

## Download

Always grab the newest build from this link (it never changes):
https://github.com/dotXCVI/night-city-roguelite/releases/latest/download/NightCityRoguelite.zip

What changed in each version: https://github.com/dotXCVI/night-city-roguelite/blob/main/CHANGELOG.md

## Install

**Option A - Vortex (easiest if you already use it)**
1. Install the five mods above with the "Mod Manager Download" button on each
   page.
2. Drag the Night City Roguelite ZIP into Vortex's Mods tab, then click
   Install and Enable.
3. Click Deploy if Vortex asks.

**Option B - by hand**
1. For each of the five mods above, use "Manual Download". Open each ZIP and
   copy what's inside into your Cyberpunk 2077 game folder, letting it merge
   folders.
   - Steam: right-click Cyberpunk 2077 -> Manage -> Browse local files.
2. Open the Night City Roguelite ZIP and copy its `r6` and `archive` folders into
   the same game folder, merging with the folders that are already there.
   - You can ignore the other files in the ZIP.

To check it worked: start the game. The main menu should have a **ROGUELITE**
entry at the top.

## Updating from an older version

Your Cred, unlocks and stats carry over - they aren't stored in the mod's
files.

**Vortex:** drag the new ZIP into the Mods tab. When it asks, pick
**Replace**, then Enable and Deploy.

**By hand:**
1. In your game folder, delete the `r6/scripts/NightCityRoguelite` and
   `r6/tweaks/NightCityRoguelite` folders. (Old files that a new version
   dropped can cause errors if they stay.)
2. Copy the new ZIP's `r6` and `archive` folders into the game folder,
   letting it replace files when Windows asks.

Then update the five framework mods above if any have a newer version, and
start a **new** roguelite character - old ones may carry leftovers from the
last build.

## Playing

1. Main menu -> **ROGUELITE**. Pick a body type, make your V, and confirm.
2. The screen stays black for up to about 45 seconds while the mod sets things
   up. That's normal, so don't press anything. You'll fade in at V's apartment.
3. A guide pops up the first time. Read it - it's six pictures, not homework.
4. Walk into the **armory** (the weapon room at the back of the apartment) and
   open the stash ("Gear") to pick your kit. Locked kits are bought there with
   Cred.
5. Use **V's computer** and hit **START RUN**. You can save at the apartment between runs; saving is locked
   during a run.
6. In a run:
   - Take a gig, then clear every wave in the arena.
   - Pick a reward.
   - Pick your next fight. Each door shows what it pays first, then the place
     and who's waiting. **HOT** doors are harder and pay double.
   - **F7** reopens any screen you closed.
7. Before each boss, the **Fixer** sells upgrades for the eddies you've earned.
   - Not sure what a word on a card means? The terminal's **DATABASE** lists
     every keyword, effect, mod and quickhack.
8. When you die, you wake up back home. You keep the **Cred** you earned and
   spend it on kits (armory) and upgrades (terminal).

Your Cred and unlocks are stored outside your save files, so they carry over to
new roguelite characters on the same PC.

## Reporting bugs and feedback

1. Always quit through the main menu (Esc -> Exit to Main Menu, or Quit Game).
   Don't use Alt+F4. The mod's log is only saved when you quit properly.
2. Hit a bug mid-run? Press **F8** right away.
   It saves a snapshot of the fight to the log, so I know exactly when and
   where it happened. Mark as many as you like.
3. Send me:
   - **What happened** and roughly when: which floor, and what you were doing.
     A screenshot helps a lot.
   - **Your logs.** The easy way: copy `tools/collect-logs.bat` from the ZIP
     into your Cyberpunk 2077 folder once. After playing (quit through the
     menu first), double-click it and send the ZIP it puts on your desktop.
     Or send these two files from your game folder by hand:
     - `red4ext/plugins/Codeware/Persistent/ScriptableServiceContainer.dat`
     - `r6/logs/redscript_rCURRENT.log`
   - **How it felt:** too hard, too easy, boring rewards, confusing screens,
     anything.

If the ROGUELITE entry doesn't show up at all, send the
`r6/logs/redscript_rCURRENT.log` file. It means a framework mod is missing,
outdated, or didn't install properly.

## Uninstall

Delete these from your game folder:
- `r6/scripts/NightCityRoguelite`
- `r6/tweaks/NightCityRoguelite`
- `archive/pc/mod/NightCityRoguelite.archive` and `NightCityRoguelite.archive.xl`

The five framework mods are safe to keep, since lots of other mods use them.

## Things to keep an eye on in this build

v0.0.20 takes the fights across the city: thirteen new arenas, and bosses
now fight at the story's landmarks. The database is rebuilt, and quickhack
cards are cleaned up. Your v0.0.19 character carries over - no need to start
a new one. Tell me how these feel:

**Arenas**
- **New arenas:** thirteen of them - Rocky Ridge, Jackson Plains, Coronado
  Hideout, East Coronado, West Wind Estate, Longshore Stacks, Dogtown Back
  Streets, Japantown Backlot, Tyger Sweatshop, Charter Hill, Wellsprings,
  West Downtown and Northside Yards. Does one start a gig, ring your phone,
  play a scene or show a quest marker? Press F8 there and tell me which. Is
  any too cramped, too big, or full of spots enemies can't reach?
- **Boss arenas:** every boss fights at a story landmark now. Act 1: the All
  Foods plant, Totentanz, Ghost Town, Konpeki Plaza and its roof. Act 2: the
  Grand Imperial Mall, Batty's Hotel, Embers, the Arasaka estate, Dogtown's
  stadium, the Black Sapphire. Act 3: Arasaka Tower's CEO floor and roof,
  Mikoshi, the spaceport roof. Does the boss floor feel like an occasion?
  Any enemy spawning inside a wall, or something from the story playing?
  F8.
- **Rooftops:** arriving at a high arena (Konpeki's roof, the tower), do
  you ever land on the street or fall?
- **Locked rooms:** locked, sealed and keypad doors inside an arena should
  be open when you arrive. Any objective marker or enemy you still can't
  reach? Press F8 right there.
- **Dropped weapons:** the legendary hammer at the mall (or any weapon an
  enemy loses) should never land on the floor now.

**Cards and doors**
- **Quickhacks:** only hacks that fight should come up - no stealth or
  distraction hacks, no Memory Wipe. Ping only shows up once you hold
  something that uses MARK, and DAEMONS doors only while you have a deck.
- **Doors:** a door type you keep passing over should show up less until
  you take it. Do the door screens feel more varied?

**The terminal**
- **DATABASE** (home, the door picker, and F7 in a fight): hover a name to
  read it, click to keep it up. Can you find what any word on a card means,
  and what makes a keyword? Does anything run off the screen?
- **Hub and UPGRADES:** does everything fit inside the panel now - the stats
  row, the START RUN card's line-up, the upgrades header?

**Still worth a look from v0.0.19**
- **Kits and their main weapon:** is the Brawler's, Wireman's, Demolitions'
  or Netrunner's chrome installed from the first arena? Do chrome mods (from
  TUNE-UP doors, floors 4, 10, 16) change how the weapon fights?
- **Weapon effects:** do Payload, Hot Barrel, Lucky Round and the rest fire
  about as often as their cards say? On Gorilla Arms especially.
- **Netrunner:** do your hacks set off your effects (Overheat BURNS, Short
  Circuit SHOCKS)? Does a Netrunner run keep up with a gun run by Act 2?
- **Combos:** did two effects from different patrons set each other off?
  Which combo felt best, and which effect did nothing you could notice?
- **Run shape:** did your build come together by the Act 2 boss? Were HOT
  doors worth it? Did Trauma Team cover save a run?
- **Trips and music:** the glitch, the black with the arena's name, the
  glitch back in - and one track per arena, never two at once.
- **The basics:** does dying play out properly (V goes down, fade, you come
  to at home)? Did any story phone call get through during a run?

The more runs I get logs from, the better: the run reports now compare
testers side by side, so send your logs even from a run where nothing went
wrong.

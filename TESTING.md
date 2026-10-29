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

A big one: the patrons are rebuilt around effects that combine, every kit now
fights with its main weapon (chrome and decks included), kits cost favors,
and the terminal is new. Start a **new** roguelite character for this build.
Tell me how these feel:

**Kits and their main weapon**
- Try the **Brawler** (Gorilla Arms), **Wireman** (Monowire),
  **Demolitions** (Projectile Launcher) and **Netrunner** (cyberdeck). Is the
  chrome installed from the first arena? Send the log if a line says "Chrome
  refused".
- **Chrome mods** come from TUNE-UP doors (floors 4, 10, 16). Do they change
  how the weapon fights? Take Mantis Blades from a Chrome door on a gun kit -
  they have their own mods now.
- **Weapon effects read your weapon:** on a launcher they count shells, on a
  deck they count quickhacks. Do Payload, Hot Barrel, Lucky Round and the
  rest fire about as often as their cards say? On Gorilla Arms especially:
  in the last log Hot Barrel never went off in five floors.
- **New arenas:** thirteen of them (Rocky Ridge, Longshore Stacks, Tyger
  Sweatshop and the rest). Does one start a gig, ring your phone, play a
  scene or show a quest marker? Press F8 and say which. Is any too cramped,
  too big, or full of spots enemies can't reach?
- **Boss arenas:** bosses fight at story landmarks now - the All Foods
  plant, Konpeki Plaza, the Black Sapphire, Arasaka Tower's roof, Mikoshi
  and more. Does the boss floor feel like an occasion? Any landmark where
  enemies spawn somewhere odd, or something from the story plays? F8.
- **Arenas with rooms:** locked, sealed and keypad doors inside an arena
  should be open when you arrive. Any objective marker or enemy you still
  can't reach? Press F8 right there.
- **Evolution:** chrome that evolves (Legendary with two weapon effects)
  learns a trick - SHOCKWAVE, BLOOD RUSH, LIVE WIRE, BELT FEED, CASCADE.
  Can you see it happen? The stranger (a ? door from Act 2) sells it early.

**Netrunner**
- Do you start with one hack that kills and one that controls?
- After a Tune-Up or a boss, are your hacks still slotted, and a quality
  higher?
- Pick a quickhack with a full deck: does it ask which one to swap out, and
  does BACK work?
- Do your hacks set off your effects (Overheat BURNS, Ping MARKS, Short
  Circuit SHOCKS)?
- Does a Netrunner run keep up with a gun run by Act 2? Do you run out of RAM
  a lot? (The log counts both, so send it.)

**The terminal**
- **DATABASE** (home, the door picker, and F7 in a fight): hover a name to
  read it, click to keep it up. Can you find what any word on a card means,
  and what makes a keyword?
- **UPGRADES:** switch a row's take and buy a rank. Does it read well? Did
  your old unlocks carry over?
- **Favors:** beat a boss and a fixer owes you one - spend it on a kit at the
  armory.

**Trips**
- Going to a fight, the world should glitch, then the screen goes black with
  the arena's name tearing in red and blue, then the arena glitches back in.
  Do you see all three? Does the black hide the loading pop-in?
- Music: one track per arena, never two at once. Start a run with your pocket
  radio on - it should go quiet for the run and come back when you get home.

**Effects and combos**
- Every effect speaks in keywords (MARK, SHOCK, BURN, BLAST, MOMENTUM...).
  When one lands, a word flashes on the HUD. Do you see them? Do the enemies
  show it (outline for MARK, sparks for SHOCK, fire for BURN)?
- Did two effects from different patrons ever set each other off? Which
  combo felt best, and which effect did nothing you could notice?
- Hover a card on a patron screen: the effects it BUILDS ON light up in the
  YOUR BUILD strip. Does that help you plan?
- Did you get a duo, a legendary or a favour (three effects from one patron)?

**Run shape**
- **HOT doors** (pulsing): one in Act 1, two later, harder, and they pay
  double. Did they show up at good moments? Were they worth it?
- **Trauma Team:** you start every fight at full health and have one cover a
  run. Did it save a run? Did it make dying feel fair?
- Did Tune-Ups feel worth it (the card shows DPS before and after)? Did you
  trade guns, and did your weapon effects come along?
- **Overall:** did your build come together by the Act 2 boss? Was Act 3
  harder in a good way?

**The basics**
- Does dying play out properly: V goes down, the screen fades, and you come to
  at home?
- Did any story phone call (for example from Judy) get through during a run?

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

## Playing

1. Main menu -> **ROGUELITE**. Pick a body type, make your V, and confirm.
2. The screen stays black for up to about 45 seconds while the mod sets things
   up. That's normal, so don't press anything. You'll fade in at V's apartment.
3. A guide pops up the first time. Read it - it's six pictures, not homework.
4. Walk into the **armory** (the weapon room at the back of the apartment) and
   press **F7** to pick your kit. Locked kits are bought there with Cred.
5. Use **V's computer** (or press **F7** anywhere else at home) and hit
   **START RUN**. You can save at the apartment between runs; saving is locked
   during a run.
6. In a run:
   - Take a gig, then clear every wave in the arena.
   - Pick a reward, then a level-up.
   - Pick your next fight. Each door shows the place, what it pays, how hard
     it is, and who's waiting.
   - **F7** reopens any screen you closed.
7. Before each boss, the **Fixer** sells upgrades for the eddies you've earned.
   - Want to try a boss or a later act without playing up to it? Use the
     **FLOOR** card on the terminal to pick where to start and press
     **TEST RUN**. Test runs pay no Cred and don't count in your stats.
8. When you die, you wake up back home. You keep the **Cred** you earned and
   spend it on kits (armory) and upgrades (terminal).

Your Cred and unlocks are stored outside your save files, so they carry over to
new roguelite characters on the same PC.

## Reporting bugs and feedback

1. Always quit through the main menu (Esc -> Exit to Main Menu, or Quit Game).
   Don't use Alt+F4. The mod's log is only saved when you quit properly.
2. Hit a bug mid-run? Press **F8** right away (or MARK BUG on the F7 screen in a fight).
   It saves a snapshot of the fight to the log, so I know exactly when and
   where it happened. Mark as many as you like.
3. Send me:
   - **What happened** and roughly when: which floor, and what you were doing.
     A screenshot helps a lot.
   - **These two files** from your Cyberpunk 2077 game folder:
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

Big content patch plus a polish pass. Tell me how these feel:

**Home**
- Did the guide show up the first time? Did the pictures load?
- Can you get into the armory? Does the HUD say ARMORY when you're in there,
  and does F7 open the kit screen? If the room has a stash on the wall, does
  it say "Gear" and open the same screen?
- Does the terminal still open from the computer and from F7 elsewhere?

**Menus**
- Door, reward, kit and event cards now have pictures. Do they load, and do
  they look right (not stretched, not blank)?
- Hovering a card should lift it and light the frame - no color wash behind
  the text. Easy to read now?
- Anything that reads wrong, sounds off or is just too long? Screenshot it.
- Does every menu fit on your screen? Tell me your resolution if one doesn't.

**Builds**
- **Level-ups:** after every reward there's a LEVEL UP screen. Too many
  screens, or does it feel good?
- **Weapon cards:** do they show a DPS line ("DPS 312 +38% vs ...")? Do new
  weapons feel like upgrades now?
- **Weapon mods and evolutions:** did a mod change how a gun played? Did you
  get a weapon to evolve into an iconic, and did it equip properly?
- **Styles:** do the style lines on cards and the footer make sense? Did you
  hit a rank III signature?
- **The Act 1 boss:** pick an Operating System. Fill the Overdrive meter (on
  the HUD), then activate your OS. Did ZERO HOUR / RAMPAGE / BLACKWALL fire?
- **Gigs:** take one at the start; does the counter on the HUD go up?
- **Skip, banish, sell back:** do they work?
- **Overall:** did your build come together by the Act 2 boss? Was Act 3
  harder in a good way?

**The basics**
- Does dying play out properly: V goes down, the screen fades, and you come to
  at home?
- Do the fades between arenas hide all the loading pop-in?
- Did any story phone call (for example from Judy) get through during a run?

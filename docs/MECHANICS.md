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
   are called in there with favors (see Favors and the terminal). (No stash on a character? F7 in the room
   does the same.) Then use **V's computer** (prompt: "Roguelite Terminal")
   or press **F7** anywhere else for the terminal: buy upgrades, toggle
   **ASSIST**, then **START RUN**. If the apartment didn't load and home is
   the hallway, the terminal's kit card opens the armory instead.
4. The terminal shows the run's **line-up** before it starts: the four patrons
   working the city this time (see Patrons). A run opens with a choice of
   three **gigs** (see Gigs), and the first door is always a patron door, so
   the first pick starts a build. Every trip glitches out - the game's own
   signal glitch on the world, then black with the destination on screen,
   its title tearing - and glitches back in once the area has loaded; the first wave comes after a 5-second countdown. The arena is
   ringed by a solid wall that lights up as red NCPD holo-tape as you walk up
   to it.
5. Clearing a wave refills part of your ammo and one health charge. Clear the
   last one and the reward screen opens right there: pick one of three cards
   (four with Wide Net). That's the only pick a floor - there are no
   level-ups.
6. Then pick your next fight by its reward, Hades-style, and travel straight
   there. Every fight starts at full health. Each door leads with what it
   pays, then the arena and the gang you'll face:

   | Door | What you choose from |
   | --- | --- |
   | PATRON (by name) | That patron's effects (see Patrons) |
   | ARMORY | Your main weapon: a Tune-Up, weapon effects, a trade, grenades |
   | TUNE-UP | The evolution, a big Tune-Up, your MaxDoc or grenade (floors 4, 10, 16) |
   | CHROME | Cyberware, installed on the spot (from floor 3) |
   | DAEMONS | Quickhacks (from floor 3, likelier for netrunners) |
   | TRAINING | Perks - the only place they come from |
   | BOUNTY | A lone cyberpsycho; eddies and a patron pick (Act 2+) |
   | CRED | No fight reward card: Cred for the meta, now and then (from floor 3) |
   | ? | An event instead of a fight (from floor 2) |

   Regular doors are all the same fight; the danger lives on **HOT** doors
   (see Hot doors). From floor 3 some fights come with an **objective** (see
   Objectives). Before a boss floor there is a single boss door; the Act 1
   boss pays out an Operating System (see Overdrive).
7. After each elite floor, before the boss door, the **Fixer** is in: spend
   the eddies you've earned.
8. When health hits zero, a **Trauma Team cover** gets V back up (see
   Health). With none left, V dies - for real, the game's own death - and
   comes to back home, ready for the next run. Quitting or crashing mid-run counts as
   a flatline too. A run won ends with the trip home as well.

Cred is earned for every arena you clear (never for a lost one), plus a bonus
for completing a run. Levels are set per act (see Difficulty): kills and
skill use give no experience, and levels bring no attribute or perk points
(see Character).

| F7 in the armory | Computer or F7 elsewhere at home | F7 during a fight | F7 between fights |
| --- | --- | --- | --- |
| Kit picker | Terminal (run start, upgrades, database) | Run status, database, abandon | Reward, Fixer or next fight |

**Test runs** (developers: `RLConfig.DevTools()`): the terminal grows a FLOOR
card that picks a floor (1, 5, 6, 7, 11, 12, 13, 17 or 18) and TEST RUN starts
there, with the level, eddies, weapon quality and three patron effects a run
would have by then. Every door screen offers an event and (from Act 2) a
bounty, and fights roll objectives more often. Test runs pay no Cred and
don't count in the stats.

**Found a bug?** Press **F8** the moment it
happens. The log gets a snapshot of the fight - state, wave, every enemy's
position and health - so the report can say exactly where to look.

Closing a reward, Fixer or door screen (C / ESC) keeps it waiting - F7 brings it
back. Saving is locked during a run. Normal story saves are never touched. For
roguelite characters NCPD is switched off and the story stays out of the way:
incoming calls are declined before they ring, message and quest pop-ups are
hidden, and the journal is kept empty (`SilenceStory()` in `Config.reds`). The
Phantom Liberty opening is skipped by the quest patch in the archive.

### Patrons and effects

The heart of a build. Six of Night City's powers sponsor runs, Hades-style,
and four of them work the city in any one run - the line-up is on the
terminal before you start, so every run is a different web. A patron door's
reward is a pick of that patron's **effects**: rules that change how a fight
plays, not stat bumps.

Every effect speaks in **keywords**. Each patron owns one or two; an effect
makes a keyword, uses one, or both - and effects that use a keyword fire
whatever applied it, so effects from different patrons feed each other:

| Patron | Keywords | Plays like |
| --- | --- | --- |
| ARASAKA | MARK, FOCUS | Tag them, slow time, finish them |
| MILITECH | BLAST | Everything ends in an explosion |
| VOODOO BOYS | SHOCK, GLITCH | Current through crowds, chrome shut down |
| MAELSTROM | BURN, BLEED | Fire, blood, trophies |
| ALDECALDOS | MOMENTUM, SHIELD | Keep moving, stay standing |
| THE AFTERLIFE | LUCK, DEAL | Chances, and prices |

| Keyword | What it is |
| --- | --- |
| MARK | The game's ping outline on an enemy; MARK effects pay off on it |
| FOCUS | Time slows for a moment |
| BLAST | An explosion; grenades count |
| SHOCK | Electrocuted: sparks, damage, a stagger |
| GLITCH | The enemy's chrome shuts down: no dodging, Sandevistan or healing |
| BURN / BLEED | Burning, bleeding (BLEED stacks) |
| MOMENTUM | Stacks on V from sprinting, sliding and dashing |
| SHIELD | One absorbed hit |
| LUCK | Chance effects rolling your way |
| DEAL | A price now for a payoff later |

A keyword landing flashes a one-word tag on the HUD in its colour. Chains
that spread from enemy to enemy play out a beat apart, so you can watch them
go.

What a patron offers:

- **Effects** - four or five per patron (Deadeye Tag, Kill Switch, Arc Flash, Pyre,
  Slipstream, Loaded Dice...). Once you hold one, it can come back as its
  **overclock**, a stronger version (shown as "Arc Flash+").
- **Weapon effects** - one per patron, bound to your main weapon (Tracer
  Rounds, Payload, Thunder Rounds, Hot Barrel, Kinetic Rounds, Lucky Round).
  They work on blades and chrome too and stay through a trade. Two slots,
  three on an iconic or evolved chrome. Each reads the way your main weapon
  lands its blows (see below).
- **Legendaries** - seven, offered once you hold two of the patron's effects
  (Death Sentence, Fire Mission, Blackwall Gate, Cyberpsychosis, Nomad Run,
  Glass Chrome, Lucky Break).
- **Duos** - fifteen, one for every pair of patrons, offered once you hold an
  effect from each (Ghost Shot, Smart Link, Hemorrhage, Napalm, Short
  Circuit...).
- **Favours** - not a card: hold three effects from one patron and its favour
  is yours for free (Arasaka marks the toughest enemy of every wave, the
  Afterlife gives a free reroll on every screen...).

Patron screens are dealt, not drawn: one card builds on what you hold (an
overclock, a duo, or an effect that uses a keyword yours make), one you
haven't seen this run, one open. Cards show their keywords as chips, a NEW
tag, and BUILDS ON with the effects they link to; the YOUR BUILD strip under
the cards lights up those effects when you hover one. The HUD's build row
shows each patron's count (with a "+" for a favour), your cover, SHIELD and
MOMENTUM. Everything is removed when the run ends.

#### Weapon effects, weapon by weapon

Guns, blades, Gorilla Arms, Mantis Blades and the Monowire land **hits**; the
Projectile Launcher fires **shells** (one shell, whatever it catches); a
cyberdeck **uploads** (one per quickhack that finishes uploading, damage or
not - a hack that spreads counts on every enemy it reaches). Every weapon
effect has its own version for each, written for it:

| Effect | Hits | Shells | Uploads |
| --- | --- | --- | --- |
| Tracer Rounds | Every 3rd hit on one enemy MARKS it (2nd) | Shells MARK everything they catch (MARKS last twice as long) | Every quickhack MARKS its target (hacks on MARKED enemies give back 2 RAM) |
| Payload | Every 6th hit BLASTS (4th) | Every 3rd shell is heavy: a second, bigger BLAST (2nd) | Every 3rd quickhack BLASTS on its target (2nd) |
| Thunder Rounds | Headshots and strong attacks call down a SHOCK strike (4 m) | Every shell calls down a strike (4 m) | A second hack on the same enemy within 8 s calls down a strike (4 m) |
| Hot Barrel | Keep firing: at full heat, hits BURN (twice as fast) | Every 3rd shell lands hot: all it catches BURNS (2nd) | Every 3rd quickhack overheats the deck: 6 s of BURNING hacks (2nd) |
| Kinetic Rounds | 2 s after a dash or slide, hits knock down (+30%) | The same, for everything a shell catches | Hacks uploaded in that window knock their target down (+30%) |
| Lucky Round | Every 8th hit triple damage (6th) | Every 4th shell triple damage (3rd) | 1 in 4 hacks jumps: what's on its target copies onto the nearest enemy (1 in 3) |

(Overclocks in brackets.)

### Hot doors

One door in Act 1 and two in Acts 2 and 3 burn **HOT**: an elite in every wave
and a lieutenant (an elite with two affixes) in the last, for a reward two
quality steps up, one card more, a big card on patron screens, and half again
the eddies. The Director places them when you need a spike most - your main
weapon behind the floor, a run of flat screens, a cover spent - never on a
run's first floor, never two floors running, never on the elite floor or
before a boss.

### The Director

Item quality follows the run - from Common on floor 1 to Legendary+ on floor
18. Each card rolls a step around that expectation (most at it, some a step
above, rarely two); elite floors roll higher, and bosses and hot doors always
pay two steps up. Smart weapons appear from floor 7, Tech from floor 4.

- **Pity.** A screen of flat offers makes the next one better; after two flat
  screens in a row one card is guaranteed to stand out. Every big upgrade you
  take makes the next one a bit rarer.
- **Build nudges.** The director reads your build (weapons, cyberware, perks,
  attributes) and gives matching rewards more weight - much more once you've
  taken an Operating System at the Act 1 boss. At least one card on every
  screen is something off-build, so you can always pivot.
- **Signature perks.** Master perks only show up once your build uses their
  style and their attribute is at 15, and a perk is only offered once its
  tree prerequisites are owned.

**Saying no.** A door's reward screen can be skipped for eddies (Slay the
Spire's skip). Once per act (twice with Burn Notice) you can **banish** a
card: click BANISH, then the card - it's replaced and never offered again
this run.

A screen never offers the same item twice (in any quality) and shows at most
one grenade.

### Rerolls

Reward screens and door picks can be rerolled with charges: one every act,
one more with Know a Guy, and two from a Fixer contact. The Afterlife's
favour adds a free reroll on every reward screen, and Inner Circle makes the
first door reroll on each floor free. Rerolls never cost eddies.

### Character

There are no points to spend. Each kit sets two attributes (+4 to its main
one, +3 to the second; the terminal's Edge row adds to both); every perk you
take raises its attribute by 1, up to 20. Signature perks need their
attribute at 15. The Character menu can't buy, sell or reset anything for
roguelite characters.

### Weapons

You play one gun, so the run builds one gun:

- **Main weapon** - your kit's weapon. It takes every weapon reward: a
  **Tune-Up** (a quality step - the card shows DPS before and after),
  **weapon effects** (see Patrons) and the **evolution**.
- **Sidearm** - your kit's backup. It never takes a card; it steps up with
  every act.
- **Trades.** An Armory screen can offer a TRADE: a different gun that takes
  the main slot at the slot's quality, keeping its weapon effects - swapping
  is about how a gun plays, never a step down. Trade cards show the class and
  the attribute it leans on ("Revolver · COOL"), its DPS against your main
  gun, and a line on how it plays.
- **Evolution.** A Legendary main weapon with two weapon effects can evolve
  into an iconic of its type (at a TUNE-UP door), effects and all, and gains
  a third effect slot. The stranger's iconic (Act 2 on) is the only other
  way to one. Chrome evolves into its signature instead (below).
- **Act step.** Beating a boss steps both weapons up one quality.

### Chrome as the main weapon

Every kit's identity lives in its main slot, so some mains are chrome:

| Kit | Main | Sidearm |
| --- | --- | --- |
| Brawler | Gorilla Arms | Pistol |
| Wireman | Monowire | Pistol |
| Demolitions | Projectile Launcher | SMG |
| Netrunner | Cyberdeck (its quickhacks are its hits) | Pistol |

Weapon effects work on chrome like on any gun, read for how it lands its
blows (shells, uploads - see Patrons). Its rewards follow the game's own
upgrade path:

- **Tune-Ups** swap in the next quality of the same chrome. Arm chrome
  starts at Uncommon. A deck's Tune-Up takes its slotted quickhacks up with
  it.
- **REWIRE** takes the place of a trade for arms: the same arms in another
  element. Thermal hits BURN, Electric hits SHOCK, Chemical hits make them
  BLEED. A deck's trade is a new quickhack (see Quickhacks).
- **Evolution** takes chrome to the top of its line with a third weapon
  effect slot and its **signature**, a trick that changes how it plays:

| Chrome | Signature |
| --- | --- |
| Gorilla Arms | SHOCKWAVE: strong punches knock down everything within 4 m and hit each for half |
| Mantis Blades | BLOOD RUSH: a kill with the blades slows time and gives your dodge back |
| Monowire | LIVE WIRE: every lash copies what's on its target onto everyone within 4 m |
| Projectile Launcher | BELT FEED: a shell that kills hands its charge back |
| Cyberdeck | CASCADE: every quickhack spreads to two more enemies |

- **Chrome mods:** two slots of the chrome's own, three mods each, every mod
  with an overclock. They're dealt on TUNE-UP doors while the chrome is the
  main (our Daedalus hammers), never on the Armory:

| Chrome | Slot | Mods |
| --- | --- | --- |
| Gorilla Arms | KNUCKLES | Breaker (strong punches knock down; downed enemies take +40%), Detonator (strong punches BLAST), Rending (punches BLEED) |
| Gorilla Arms | BATTERY | Combo (five punches without a break trigger FOCUS), Capacitor (every 8th punch SHOCKS everything near), Adrenal (punch kills build MOMENTUM and heal) |
| Mantis Blades | BLADE | Thermal (strong slashes BURN), Serrated (slashes BLEED; at full BLEED a slash opens them for +100%), Mono (slashes on MARKED enemies always crit) |
| Mantis Blades | ACTUATOR | Leap (strong attacks count as a dash), Shock (strong attacks SHOCK the target and the nearest enemy), Deflector (blade kills raise a SHIELD) |
| Monowire | CABLE | Arc (lashes jump to the next enemy for half damage), Garrote (lashes kill MARKED enemies under 30%), Barbed (lashes BLEED; +25% to BLEEDING enemies) |
| Monowire | BATTERY | Uplink (strong lashes GLITCH; wire kills give RAM), Capacitor (every 10th lash SHOCKS everything near), Feedback (+40% to enemies you quickhacked) |
| Launcher | ROUND | Cluster (bomblets), Sticky (shells BLAST again), Seeker (a micro-missile at the nearest MARKED enemy) |
| Launcher | WIRING | Autoloader (+1 charge), Recoil (every shell that lands counts as a dash), Overpressure (shells knock down) |
| Cyberdeck | ICEBREAKER | Breach (first hack on each enemy MARKS it and gives RAM), Spike (+60% to GLITCHED enemies), Logic Bomb (hacked enemies BLAST when they die) |
| Cyberdeck | FIRMWARE | Cache (every 4th hack gives RAM), Overvolt (hacks SHOCK), Ghost (hack kills make you untouchable) |

Chrome brings its own capacity, goes back in on the next trip if anything
takes it, and isn't replaced by other arms or an Operating System from a
Chrome door. At the Act 1 boss a deck goes into Overdrive itself (BLACKWALL)
and steps up twice. The stranger sells chrome a PROTOTYPE of its signature
early, with the third slot, at the chrome's own quality - it then skips the
evolution, and Tune-Ups take it the rest of the way (once it holds its
signature, he sells an off-market mod that comes overclocked instead).
Arm chrome a Chrome door offers to a gun build - Mantis Blades included - can
become **your new main**: the gun steps down to sidearm, the weapon effects
stay with the slot.

### Quickhacks

A cyberdeck's quickhacks are read as weapons. Every hack speaks a keyword
when its upload lands, and each has a role:

| Role | Quickhacks |
| --- | --- |
| Damage | Overheat (BURN), Short Circuit (SHOCK), Contagion (its poison counts as BLEED), Synapse Burnout, Detonate Grenade (a BLAST) |
| Control | Ping (MARK), Weapon Glitch (GLITCH), Cyberware Malfunction (GLITCH), Cripple Movement, Reboot Optics, Memory Wipe, Cyberpsychosis |
| Ultimate | Suicide, System Collapse |

With the deck as the main weapon:

- **Your hacks run at the deck's quality.** Every Tune-Up, act step, the
  Act 1 boss's step and the evolution take them up with the deck.
- **The Netrunner starts** with one damage hack (Overheat, Short Circuit or
  Contagion) and one control hack. The Wireman's deck brings Ping, Weapon
  Glitch or Cyberware Malfunction to set up the wire.
- **Shaping the loadout:** the Armory deals a quickhack your deck doesn't run
  in place of a trade, and DAEMONS doors deal only those - at the deck's
  quality, about which hack and never a step down (a hot door or a spike
  lets the big ones in early). Cards carry their keyword chips and BUILDS ON.
- **A full deck asks:** pick a quickhack card with every slot taken and the
  screen turns to your deck - pick the hack it replaces, or BACK.
- The YOUR BUILD strip and the terminal show your hacks in their keyword
  colours.

### Styles

Every reward feeds a **style**: BLADES, BRAWLER, MONOWIRE, GUNSLINGER, HEAVY,
RIFLES, MARKSMAN, NETRUNNER, SMART, TECH, DEMOLITIONS or NINJA. An equipped
weapon or arm cyberware counts 2 points; every perk and effect with the
style counts 1 (weapon effects count for the main weapon's style) (a cyberdeck 2 for Netrunner, quickhacks 1 each up to 3, a
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
taken. Capacity cards at a TUNE-UP door pay the overclock down.

### Tune-Up doors

TUNE-UP doors show up on floors 4, 10 and 16 (if you pass one over, it comes
back on the next screen once). They work on what you already have: the
evolution when your main weapon is ready, a Tune-Up two steps up, mods for
main-weapon chrome (up to two cards), your MaxDoc, your grenade, or capacity
when you're over it.

### The Fixer

Clearing arenas also pays eddies (more on heavy fights and bosses). After each
elite floor, before the boss, the Fixer sells a short stock - a MaxDoc upgrade,
a grenade, an effect from one of the run's patrons, a perk, a Tune-Up, a
weapon effect, or a contact (two free rerolls) - and buys back weapons and
cyberware you carry but don't have equipped. Your balance is on top, and every card says what it costs (or how
much you're short). Prices rise with the run; Street Smart takes 15% off
(30% with Made Man, which also shelves a second effect).

### Health and Trauma Team

Every fight starts at full health, so health is never something to bank or
gamble. What carries over is **cover**: one Trauma Team cover a run (two with
Platinum Plan). Health hitting zero spends it instead of a flatline: V is
back up at half health (three quarters with Gold Plan), everyone within 8 m is knocked down, and the run goes
on. With no cover left, the next one is real. The Ripperdoc can restore a
spent cover; the stranger buys one. Deals that cost max health (Glass Chrome, Loan Shark,
Misty's cards) never take more than three quarters of it together - a deal
that would go further isn't offered.

### Grenades and movement

V carries one MaxDoc. It never falls behind the run: on every trip its quality
is raised automatically when the floor calls for it, and one upgrade can drop
per arena - always from a boss, from one elite in four. Grenades are rewards
(Armory cards and the Workshop), one type at a time. Every run starts with
Dash, Slippery and Muscle Memory, so dashing and sliding work from floor 1 and
sprinting or vaulting doesn't restart a reload.

### Pacing

A pacing director (after Left 4 Dead's) watches how hard each fight was -
damage taken, close calls, heals. After a rough wave it waits longer before
the next one and trims it; across arenas it nudges wave size and incoming
damage up when you're cruising and down when you're struggling. One line per
arena goes in the log for tuning.

### Assist mode

The ASSIST toggle on the terminal cuts the damage V takes by 20%, and by 2%
more for every run lost while it's on (up to 80%). It never changes rewards.

### Favors and the terminal

Two currencies carry over between runs:

- **Favors** call in kits at the armory. A fixer owes V one for every boss put
  down, one more for winning, and one the first time V reaches Act 2, Act 3
  and the end. Solo and Blade are free; Netrunner and Marksman cost 2,
  Gunslinger 3, Juggernaut 4, Demolitions 5, Brawler 6 and Wireman 8 (30 for
  all, around 20 runs). A kit out of reach shakes when clicked.
- **Cred** (every cleared arena, Cred doors, a won run) buys the terminal's
  **UPGRADES**: ten rows, each one idea with two takes. A row's ranks are
  bought once (rank I 250 Cred, rank II 600; Choice is one rank at 400) and
  serve whichever take is on; switching takes is free at home.

| Row | Take | Rank I | Rank II |
| --- | --- | --- | --- |
| Cover | Trauma Team | Gold Plan: cover gets you up at 75% | Platinum Plan: two covers a run |
| Cover | Back-Alley Doc | House Call: an Uncommon MaxDoc | Repeat Customer: one more MaxDoc charge |
| Choice | Wide Net | Four cards on every reward screen | |
| Choice | Street Map | Four doors to pick from | |
| Rerolls | Fixer Contacts | Know a Guy: one more reroll an act | Inner Circle: the first door reroll on each floor is free |
| Rerolls | Burn Notice | Two banishes an act | Blacklist: a banished card comes back as a standout |
| Head Start | Quartermaster | Requisition: a free Armory pick | Priority Requisition: that pick two steps up |
| Head Start | Patron's Ear | Open Line: the first patron screen deals a card more | Standing Offer: your most-backed patron always works the run |
| Eddies | Street Smart | Haggler: the Fixer takes 15% off | Made Man: 30% off and a second effect on the shelf |
| Eddies | Skim | Arenas pay 20% more eddies | Off the Books: a skipped screen pays double |
| Body | Edge | +1 main attribute | Honed: +1 second attribute |
| Body | Tolerance | +10 capacity | Neural Dampers: overclock episodes half as often |
| Overdrive | Primed | Overdrive comes online full | Hair Trigger: the meter fills 25% faster |
| Overdrive | Meltdown | Afterburn: Overdrive refills the MaxDoc | Meltdown: Overdrive goes off with a BLAST |
| Heat | Hot Streak | Hot doors deal a card more | Marked Man: a second hot door in Act 1 |
| Heat | Bounty Board | Bounties from Act 1 | Wanted: bounties pay double eddies |
| Style | Specialist | The main weapon's style starts 2 points up | Signature: rank III at 8 points |
| Style | Gig Economy | Repeat Client: gigs pay 1,500 | Long Contract: gigs run to the Act 3 boss |
| Fortune | Lucky Star | Runs start with the Director's pity built up | Sure Thing: every act's first reward screen has a standout |
| Fortune | Inside Man | Tip-Off: ? doors twice as often | Inside Man: Acts 2 and 3 open with a door from your lead patron |

The old one-off unlocks carried over as the nearest ranks (Edge III, and
Street Map when bought alongside Wide Net, were refunded).

### No looting

Every kit starts with a basic frag grenade. Bodies are emptied - there is
nothing to search mid-fight. Ammo comes back as
you clear waves, your MaxDoc is upgraded automatically as the run goes on, and
grenades are Armory rewards. Anything you pick up in an arena anyway is
taken away again right after, and on every trip any weapon the run didn't
hand out (one an enemy dropped) is taken away as well.

### Difficulty

Levels are set per act, for V and the enemies alike: 3, 10 and 17. Inside an
act nothing scales, so every pick is pure gain; beating the boss steps both
(and V's weapons). Elites are a level up, bosses two. Damage V takes is set
per act too - 60%, 80% and 95% (on top of the game's Hard difficulty) -
adjusted a little by the pacing director and cut by assist mode. There are
no hidden taxes: enemies never shrug off part of your damage. Waves grow with
depth: two waves per fight in Act 1, three later; the elite floor (5, 11, 17)
has an elite in every wave. Numbers are in `Config.reds` and
`Run/Encounters.reds`.

### Music

Fights get either a radio station - the Edgerunners station, Morro Rock or
the metal station, likelier the harder the fight - or the game's own
interactive combat music (never both at once): the faction's street-story
set for regular fights (tense until the last wave in light fights), the
Konpeki heist or Kang Tao sets for heavy and elite fights, and story boss music
on boss floors (Royce, the mall fight, Adam Smasher).

Nothing carries into the next arena: every trip ends the music over the
glitch and cuts anything still ringing once the screen is black. V's own
pocket radio is switched off for the run and comes back at home; turn it on
mid-run and your station plays instead of the score until you turn it off.

### Time and weather

Each arena gets a **look** on the way in - a time of day and weather picked
to read together: HIGH NOON, GOLDEN HOUR, CLEAR NIGHT, FOG BANK, NEON RAIN,
SMOG, TOXIC STORM and SANDSTORM (the Badlands only). Act 1 is calmer; hot
doors, elite floors and bosses get the storms. The same look never comes
twice in a row. A few seconds in, the mod checks what the game is actually
showing and asks again if something overrode it (both go in the log).

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
ARMORED (plating: 70% less damage until a quarter of its health is gone,
then it shatters), BERSERK (hits harder, moves faster),
REGENERATING (2% health a second, not while GLITCHED), VOLATILE (explodes a moment after it dies -
step away) and VAMPIRIC (heals when it hits you). Elites get one from floor 3,
two in Act 3; a hot door's lieutenant always has two.

### Objectives

Some fights (from floor 3, never the boss) come with a job. Enemies keep
coming until it's done, then nobody else joins and the fight ends with the
last one standing. A finished objective pays bonus eddies.

- **SURVIVE** - hold out until the timer runs out.
- **HOLD THE UPLINK** - stand in the marked zone until the upload completes
  (it pauses while you're outside).
- **SABOTAGE** - plant charges at three marked spots (a few seconds each);
  they go off when the last one is set.

A marker you can't get to - behind a door that won't open, up a ledge you
can't climb - moves to you once you've been stuck near it for a few seconds.
An uplink or sabotage still going after 150 seconds completes on its own.

### Events

A "?" door is a stop without a fight. It counts as a floor:

- **Back-Alley Ripperdoc** - a MaxDoc upgrade, paid street chrome, and a
  Trauma Team policy that restores a spent cover (bone lacing when you
  haven't spent one).
- **The Bookie** - bet half your eddies at even odds, or bet an effect on an
  overclocked one.
- **Misty's Reading** - three tarot cards, each a blessing with a price (The
  Tower overclocks two effects for max health, Death takes an effect for one
  more card on every screen, The Hermit trades max health for a cover...).
- **A Stranger's Offer** (Act 2 on) - an iconic for your main slot that makes
  you a target (15% more damage taken for the run) - for chrome, a PROTOTYPE
  of its signature or an off-market mod, overclocked, at the same price -
  sell an effect for eddies, or sell your cover for a legendary (or every
  effect you hold overclocked).

### Menus

The terminal, the armory, the door picker, the reward and event screens are
built from cards in the game's own menu style, with pictures from the game's
codex: door cards lead with the reward - the patron's art, what the screen
deals, its keywords and how many of its effects you hold - then the
objective and the arena with the gang's logo; HOT doors pulse. Effect cards
show the patron's people,
gig cards the fixer, kit cards the kit's weapon; events open with whoever
you're dealing with (Misty deals real tarot cards). Hovering lifts a card and
lights its frame - the text never sits on a colour fill.

The terminal's **DATABASE** (at home, on the door picker and in a fight) is
everything a run talks about, dressed the way the cards are: the keywords in
their colours, the run's terms, every patron's effects with their overclocks
and keyword chips (weapon effects with all three readings), the duos, each
chrome's evolution and mods, and the quickhacks. It reads the same
catalogues the cards are dealt from, so it never disagrees with them.

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

The game doesn't write script log lines to disk, so the mod keeps its last
2,000 log lines in Codeware's persistent store,
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
    python3 tools/runreport.py "<game folder>" --effects  # each effect's fires and damage

The record format is documented in `Core/Telemetry.reds`. With a deck, every
fight also logs `uploads` (quickhacks that landed) and `ramlow` (seconds spent
under a quarter of your RAM), so a run shows whether RAM or damage holds a
netrunner back.

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
| `Combat/DamageHooks.reds` | Effects and affixes in the damage pipeline; death hook |
| `Combat/CombatState.reds` | Per-fight state: enemies, keyword timers, MOMENTUM, SHIELD, the effect ledger |
| `Combat/Keywords.reds` | The keywords: how each lands, looks and reacts; luck rolls; chain steps |
| `Combat/Loot.reds` | Ammo refill, empty bodies, arena pickup filter |
| `Audio/Music.reds` | Arena music: combat scores and radio stations |
| `World/Atmosphere.reds` | The arena looks: time of day and weather, read back and re-asked |
| `Rewards/RewardSystem.reds` | Reward doors, offer rolling and granting |
| `Rewards/Director.reds` | Quality rolls, pity, magnificence, spikes, hot doors |
| `Rewards/BuildProfile.reds` | Reads V's build into style tags |
| `Rewards/PerkCatalog.reds` | Perk cards: prerequisites, signature perks, weighting |
| `Rewards/PerkCatalogData.reds` | The perk list (generated from `source/perks/catalog.tsv`) |
| `Rewards/Patrons.reds` | The six patrons, their keywords, the run's line-up |
| `Rewards/Boons.reds` | The effect catalogue (effects, weapon effects, duos, legendaries, favours), what V holds |
| `Rewards/BoonEffects.reds` | What effects do in fights (hits, kills, dashes, ticks) |
| `Rewards/Styles.reds` | Styles: points, ranks, damage bonuses, signatures |
| `Rewards/Weapons.reds` | Main weapon and sidearm slots, Tune-Ups, trades, evolution, DPS previews |
| `Rewards/ArmChrome.reds` | Arm chrome and decks as the main weapon: records, REWIRE, evolution and signatures, taking over the slot |
| `Rewards/ArmMods.reds` | The main chrome's mod slots and their rules |
| `Rewards/WeaponActions.reds` | How the main weapon lands its blows (hits, shells, uploads) and the weapon effects' readings for each |
| `Rewards/Quickhacks.reds` | Quickhack families, roles and keywords; the deck's loadout, its quality and the swap |
| `Meta/MetaProgression.reds` | Kits and their favor prices, favors, Cred payout |
| `Meta/Terminal.reds` | The terminal's ten upgrade rows, ranks, takes, the migration of old unlocks |
| `UI/Card.reds` | The card used by every menu, icon helpers |
| `UI/Art.reds` | Codex pictures for arenas, patrons, kits, fixers, events |
| `UI/ArmoryPopup.reds` | The kit picker |
| `UI/GuidePopup.reds` | The six-page how-it-works guide |
| `UI/Transition.reds` | Glitch to black with the destination (trips, death) |
| `UI/Database.reds` | The terminal's DATABASE: keywords, terms, effects, mods, quickhacks |
| `UI/*.reds` | HUD line and boss bar, terminal, reward, event and Fixer popups |
| `r6/tweaks/NightCityRoguelite/*.yaml` | Enemy variants and loot, the escort drone, computer and armory prompts (TweakXL) |
| `archive/pc/mod/NightCityRoguelite.archive` | Quest patch (skips the Phantom Liberty opening for roguelite starts) and English text |
| `source/quest-patch/` | How the archive is built (Python + WolvenKit) |
| `source/perks/` | Perk catalogue (tsv) and the generator for `PerkCatalogData.reds` |
| `source/tweaks/gen_tweaks.py` | Generates the yaml files and the text list |
| `source/localization/` | English text and its converter for ArchiveXL |


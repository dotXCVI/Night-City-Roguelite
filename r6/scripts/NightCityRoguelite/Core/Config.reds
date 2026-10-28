// -----------------------------------------------------------------------------
// Night City Roguelite - tuning and settings
// -----------------------------------------------------------------------------
// Everything a player or tester may want to tweak lives here.
// Values are read through static functions so they can be changed without
// touching game logic.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLConfig {
  // --- Keys -------------------------------------------------------------------

  // Opens the terminal (at home), run status (in an arena), or skips the
  // return-home countdown after an arena is cleared.
  public static func TerminalKey() -> EInputKey = EInputKey.IK_F7
  // Marks a bug: a snapshot of the run goes into the log (RogueliteSystem.MarkBug).
  public static func BugKey() -> EInputKey = EInputKey.IK_F8

  // --- Hub (V's apartment) --------------------------------------------------------

  // When true the hub is V's apartment in Megabuilding H10 and V is kept inside
  // it whenever V isn't in an arena. When false the hub is wherever the
  // takeover happened.
  public static func UseApartmentHub() -> Bool = true
  // Spawn point in the middle of the main room, and the room's bounds. Both
  // come from the apartment's own quest markers in the 2.5 world data (the
  // front door is at x = -1389.5; everything west of it is the hallway).
  public static func ApartmentPosition() -> Vector4 = Vector4(-1381.77, 1270.79, 123.07, 1.0)
  public static func ApartmentYaw() -> Float = 90.0
  public static func ApartmentMin() -> Vector4 = Vector4(-1389.2, 1259.5, 121.5, 1.0)
  public static func ApartmentMax() -> Vector4 = Vector4(-1371.0, 1283.0, 127.5, 1.0)
  // The hallway right outside the front door. V lands here first and steps
  // inside once the apartment has streamed in (it can take a few seconds);
  // if it never does, the hallway is home for that session.
  public static func HallwayPosition() -> Vector4 = Vector4(-1391.8707, 1271.6887, 123.0824, 1.0)
  public static func HallwayYaw() -> Float = -99.25
  public static func HallwayMin() -> Vector4 = Vector4(-1397.0, 1265.0, 121.5, 1.0)
  public static func HallwayMax() -> Vector4 = Vector4(-1389.2, 1279.0, 127.5, 1.0)
  // How long to wait in the hallway for the apartment to load.
  public static func ApartmentLoadTimeout() -> Float = 20.0
  // Seconds outside before V is put back inside.
  public static func ApartmentLeashSeconds() -> Float = 2.0
  // The game difficulty for roguelite characters (the difficulty screen is
  // skipped for them and this is applied every session).
  public static func GameDifficulty() -> gameDifficulty = gameDifficulty.Hard
  // No story distractions for roguelite characters: the journal is kept
  // empty, incoming calls don't ring and message/quest pop-ups are hidden.
  public static func SilenceStory() -> Bool = true
  // Turn NCPD off for roguelite characters (gunfire in arenas won't draw police).
  public static func DisablePolice() -> Bool = true

  // --- Run structure ------------------------------------------------------------

  // 3 acts of 6 arenas: floors 1-4 are regular, 5 is the elite floor and 6
  // the act boss (overall floors 6, 12 and 18).
  public static func Acts() -> Int32 = 3
  public static func FloorsPerAct() -> Int32 = 6
  public static func EliteFloor() -> Int32 = 5
  public static func BossFloor() -> Int32 = 6

  // --- Character baseline -------------------------------------------------------

  // Attributes start here; kits add to two of them (Player/Kits.reds).
  public static func BaseAttributeValue() -> Float = 3.0

  // --- Arenas -------------------------------------------------------------------

  // Arena list, radii and start points: Combat/Arenas.reds.
  // Dropping this far below the arena start counts as leaving the arena.
  public static func ArenaFloorDrop() -> Float = 12.0
  // Arena walls: approximate width of one wall segment (holo-tape panel).
  public static func WallSegmentLength() -> Float = 8.5
  // Walls are invisible beyond this distance and fully lit at arm's length.
  public static func WallRevealDistance() -> Float = 10.0
  // Safety net behind the collision walls: past the wall by this much, V is
  // put back inside.
  public static func WallBackstopMargin() -> Float = 1.5
  // Distance band (from arena center) where enemies spawn.
  public static func SpawnMinDistance() -> Float = 16.0
  public static func SpawnMaxDistance() -> Float = 30.0
  // Countdown after arriving in an arena before the first wave.
  public static func DeployCountdown() -> Int32 = 5
  // Fade to / from black around every trip (UI/Transition.reds).
  public static func FadeSeconds() -> Float = 0.8
  // How long a trip's glitch plays on screen before the black comes down.
  public static func GlitchLead() -> Float = 0.45

  // --- Waves --------------------------------------------------------------------

  // Seconds between a wave being cleared and the next one spawning.
  public static func WaveGap() -> Float = 3.0
  // The gap when the pacing director calls for a breather (Run/Pacing.reds).
  public static func RelaxWaveGap() -> Float = 8.0
  // An enemy that has not spawned within this many seconds is dropped.
  public static func SpawnTimeout() -> Float = 8.0
  // Living enemies get their threat on V refreshed this often.
  public static func ThreatRefreshSeconds() -> Float = 10.0
  // Enemies further than this from V for StrayTimeout seconds are removed.
  public static func StrayDistance() -> Float = 90.0
  public static func StrayTimeout() -> Float = 60.0
  // An enemy further than ChaseDistance that hasn't closed in on V for
  // ChaseAfterSeconds is sent running at V.
  public static func ChaseDistance() -> Float = 15.0
  public static func ChaseAfterSeconds() -> Float = 5.0
  // Hard cap on simultaneously alive enemies.
  public static func MaxAlive() -> Int32 = 12
  // Seconds without a kill before the enemies left are brought to V (twice),
  // then removed (WaveSpawner.Unstick) - nothing can softlock a fight.
  public static func UnstickSeconds() -> Float = 40.0

  // --- Doors (Rewards/RewardSystem.reds) ----------------------------------------

  // Chance that one door is an event (from floor 2, not before an elite).
  public static func EventDoorChance() -> Float = 0.22
  // Chance that one door is a cyberpsycho bounty (Act 2 on).
  public static func BountyDoorChance() -> Float = 0.15
  // Chance that a fight comes with an objective (from floor 3).
  public static func ObjectiveChance() -> Float = 0.3
  // Chance that one door pays Cred instead of a card (from floor 3).
  public static func CredDoorChance() -> Float = 0.08

  // --- Run rules -----------------------------------------------------------------

  // Trauma Team covers a run starts with (the Platinum unlock adds one).
  public static func CoverPerRun() -> Int32 = 1
  // Health (percent) V gets back up with when a cover is spent.
  public static func CoverHealth() -> Float = 50.0
  // Drone Escort is a prototype: its card is only dealt when this is on.
  public static func DroneEscort() -> Bool = false

  // Developer tools on the terminal: test runs that start on any floor.
  public static func DevTools() -> Bool = false

  // --- Bosses and elites (Combat/Bosses.reds, Combat/Affixes.reds) --------------

  // Boss health (percent) at which reinforcements arrive / the boss enrages.
  public static func BossReinforceAt() -> Float = 60.0
  public static func BossEnrageAt() -> Float = 30.0

  // --- Difficulty (Run/Difficulty.reds) ----------------------------------------

  // V's level and the enemies' base level for each act. Inside an act they
  // never move, so every pick is pure gain; beating the boss steps both.
  public static func ActLevel(act: Int32) -> Int32 {
    if act <= 1 { return 3; }
    if act == 2 { return 10; }
    return 17;
  }
  // Damage V takes, per act (1.0 = the game's own Hard difficulty).
  public static func ActIncomingDamage(act: Int32) -> Float {
    if act <= 1 { return 0.6; }
    if act == 2 { return 0.8; }
    return 0.95;
  }
  // Share of each ammo type's carry limit refilled when a wave is cleared.
  public static func WaveAmmoRefill() -> Float = 0.4

  // --- Death --------------------------------------------------------------------

  // Health percentage at which V counts as flatlined (V is Immortal during runs,
  // so health stops at 1 point; this catches that).
  public static func FlatlineThresholdPercent() -> Float = 1.0

  // --- Debug --------------------------------------------------------------------

  public static func VerboseLogging() -> Bool = true

  // Character records that passed the filters but misbehave when spawned.
  // Add record IDs here after testing, e.g. t"Character.some_broken_record".
  public static func EnemyBlocklist() -> array<TweakDBID> {
    let list: array<TweakDBID>;
    return list;
  }

  // Item records that should never be offered.
  public static func ItemBlocklist() -> array<TweakDBID> {
    let list: array<TweakDBID>;
    return list;
  }
}

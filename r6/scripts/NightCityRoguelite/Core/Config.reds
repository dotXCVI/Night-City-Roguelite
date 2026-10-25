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

  // --- Hub (V's apartment) --------------------------------------------------------

  // When true the hub is V's apartment in Megabuilding H10 and V is kept inside
  // it whenever V isn't in an arena. When false the hub is wherever the
  // takeover happened.
  public static func UseApartmentHub() -> Bool = true
  // Interior spawn point (from Appearance Menu Mod's location database).
  public static func ApartmentPosition() -> Vector4 = Vector4(-1391.8707, 1271.6887, 123.0824, 1.0)
  public static func ApartmentYaw() -> Float = -99.25
  // District the game reports while V is inside the apartment.
  public static func ApartmentDistrict() -> String = "LittleChina_VApartment"
  // Fallback "inside" test, used until the district has been seen once.
  public static func ApartmentRadius() -> Float = 12.0
  public static func ApartmentHeightTolerance() -> Float = 3.0
  // Seconds outside before V is put back inside.
  public static func ApartmentLeashSeconds() -> Float = 2.0
  // Turn NCPD off for roguelite characters (gunfire in arenas won't draw police).
  public static func DisablePolice() -> Bool = true
  // Log every door that streams in near the apartment (to find the front door).
  public static func LogApartmentDoors() -> Bool = true

  // --- Run structure ------------------------------------------------------------

  public static func Acts() -> Int32 = 3
  public static func FloorsPerAct() -> Int32 = 5
  // Floor numbers (within an act) that are elite / boss floors.
  public static func EliteFloor() -> Int32 = 4
  public static func BossFloor() -> Int32 = 5

  // --- Character baseline -------------------------------------------------------

  public static func BaseAttributeValue() -> Float = 3.0
  public static func StartingAttributePoints() -> Int32 = 7
  public static func StartingPerkPoints() -> Int32 = 1

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
  // Countdown after arriving in an arena before the first wave (also lets the
  // area stream in).
  public static func DeployCountdown() -> Int32 = 5
  // Countdown after an arena is cleared (loot time) before V is sent home.
  public static func ClearedCountdown() -> Int32 = 30
  // Countdown after a flatline before V is sent home.
  public static func FlatlineCountdown() -> Int32 = 5

  // --- Waves --------------------------------------------------------------------

  // Seconds between a wave being cleared and the next one spawning.
  public static func WaveGap() -> Float = 3.0
  // An enemy that has not spawned within this many seconds is dropped.
  public static func SpawnTimeout() -> Float = 8.0
  // Living enemies get their threat on V refreshed this often.
  public static func ThreatRefreshSeconds() -> Float = 10.0
  // Enemies further than this from V for StrayTimeout seconds are removed.
  public static func StrayDistance() -> Float = 90.0
  public static func StrayTimeout() -> Float = 60.0
  // Hard cap on simultaneously alive enemies.
  public static func MaxAlive() -> Int32 = 14

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

public func RLLog(const msg: String) {
  FTLog("[NightCityRoguelite] " + msg);
}

public func RLDebug(const msg: String) {
  if RLConfig.VerboseLogging() {
    FTLog("[NightCityRoguelite][debug] " + msg);
  }
}

public func RLNotify(game: GameInstance, const msg: String, opt duration: Float) {
  let message: SimpleScreenMessage;
  message.isShown = true;
  message.isInstant = true;
  message.duration = duration > 0.0 ? duration : 5.0;
  message.message = msg;
  message.type = SimpleMessageType.Undefined;
  GameInstance.GetBlackboardSystem(game)
    .Get(GetAllBlackboardDefs().UI_Notifications)
    .SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(message), true);
}

// Delay helper. Routes the callback back to the owning object with an action
// name. Only the mod's own classes are supported targets.
public class RLDelayCallback extends DelayCallback {
  private let m_target: wref<IScriptable>;
  private let m_action: CName;

  public static func Create(target: ref<IScriptable>, action: CName) -> ref<RLDelayCallback> {
    let cb = new RLDelayCallback();
    cb.m_target = target;
    cb.m_action = action;
    return cb;
  }

  public func Call() {
    let system = this.m_target as RogueliteSystem;
    if IsDefined(system) {
      system.OnDelayed(this.m_action);
      return;
    }
    let spawner = this.m_target as RLWaveSpawner;
    if IsDefined(spawner) {
      spawner.OnDelayed(this.m_action);
      return;
    }
    let arenas = this.m_target as RLArenaDirector;
    if IsDefined(arenas) {
      arenas.OnDelayed(this.m_action);
      return;
    }
    let apartment = this.m_target as RLApartmentHub;
    if IsDefined(apartment) {
      apartment.OnDelayed(this.m_action);
    }
  }
}

public func RLDelay(game: GameInstance, target: ref<IScriptable>, action: CName, seconds: Float) -> DelayID {
  return GameInstance.GetDelaySystem(game).DelayCallback(RLDelayCallback.Create(target, action), seconds, false);
}

public func RLCancel(game: GameInstance, id: DelayID) {
  GameInstance.GetDelaySystem(game).CancelCallback(id);
}

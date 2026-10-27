// -----------------------------------------------------------------------------
// Night City Roguelite - run state
// -----------------------------------------------------------------------------
// In-memory state of the current run. Saving is locked for the whole run, so
// this never needs to go into a save file.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLRunState {
  public let token: Int32;
  public let kit: CName;
  public let credEarned: Int32;
  public let act: Int32;
  public let floor: Int32;
  public let floorsCleared: Int32;
  public let kills: Int32;
  public let bossesKilled: Int32;
  // A test run (terminal): starts on any floor, pays no Cred, doesn't count
  // in the stats, and rolls the new door types every time.
  public let isTest: Bool;
  // Telemetry (Core/Telemetry.reds): this run's id and when it started.
  public let id: Int32;
  public let startTime: Float;
  // Boons held this run (Rewards/Boons.reds).
  public let boons: array<ref<RLBoonState>>;
  // Trade-offs taken at events (Run/Events.reds): extra damage V takes (0.15
  // = +15%), and stat modifiers that are removed when the run ends.
  public let damageTakenBonus: Float;
  public let appliedMods: array<ref<gameStatModifierData>>;
  // Every weapon the run handed out (kit and rewards): any other weapon V
  // carries was picked up in an arena and is taken away on the next trip.
  public let grantedWeapons: array<TweakDBID>;
  // Free reroll charges (refilled at the start of every act) and paid rerolls
  // bought on the current screen (each one costs more).
  public let rerolls: Int32;
  public let rerollsPerAct: Int32;
  public let paidRerolls: Int32;
  public let offerCount: Int32;
  // The fight in progress (or just cleared): its reward type and threat.
  public let door: ref<RLDoor>;

  // Reward director (Rewards/Director.reds).
  public let pityOffset: Int32;
  public let flatStreak: Int32;
  public let magnificence: Int32;

  // Workshop doors (floors 4 and 10; offered once more if passed over).
  public let workshopShown: Bool;
  public let workshopCarry: Bool;

  // Fixer stop after the elite floor, before the boss door.
  public let fixerPending: Bool;

  // The floor was cleared and its reward is waiting: the run moves on to the
  // next floor once it has been picked.
  public let advancePending: Bool;

  public func Threat() -> Int32 = IsDefined(this.door) ? this.door.threat : 2

  public static func Create(token: Int32, kit: CName) -> ref<RLRunState> {
    let run = new RLRunState();
    run.token = token;
    run.kit = kit;
    run.act = 1;
    run.floor = 1;
    run.offerCount = 3;
    return run;
  }

  // 1-based overall floor number (1..Acts*FloorsPerAct).
  public func Depth() -> Int32 {
    return (this.act - 1) * RLConfig.FloorsPerAct() + this.floor;
  }

  public func TotalFloors() -> Int32 {
    return RLConfig.Acts() * RLConfig.FloorsPerAct();
  }

  public func IsBossFloor() -> Bool = this.floor == RLConfig.BossFloor()
  public func IsEliteFloor() -> Bool = this.floor == RLConfig.EliteFloor()
  public func IsFinalFloor() -> Bool = this.act >= RLConfig.Acts() && this.floor >= RLConfig.FloorsPerAct()

  public func Advance() {
    this.floor += 1;
    if this.floor > RLConfig.FloorsPerAct() {
      this.floor = 1;
      this.act += 1;
      this.rerolls = Max(this.rerolls, this.rerollsPerAct);
    }
  }

  // Jumps to an overall floor (1-based), for test runs.
  public func SetDepth(depth: Int32) {
    let d = Clamp(depth, 1, this.TotalFloors()) - 1;
    this.act = d / RLConfig.FloorsPerAct() + 1;
    this.floor = d % RLConfig.FloorsPerAct() + 1;
  }

  public func FloorLabel() -> String {
    let label = s"ACT \(this.act) - FLOOR \(this.floor)";
    if this.isTest {
      label = "TEST - " + label;
    }
    if this.IsBossFloor() {
      label += " (BOSS)";
    } else if this.IsEliteFloor() {
      label += " (ELITE)";
    }
    return label;
  }
}

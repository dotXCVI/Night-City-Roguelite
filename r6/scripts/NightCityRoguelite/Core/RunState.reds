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
  public let roguelike: Bool;
  public let act: Int32;
  public let floor: Int32;
  public let floorsCleared: Int32;
  public let kills: Int32;
  public let bossesKilled: Int32;
  // One entry per stack.
  public let boons: array<CName>;
  public let appliedMods: array<ref<gameStatModifierData>>;
  public let rerollsPerFloor: Int32;
  public let rerollsLeft: Int32;
  public let offerCount: Int32;
  // The fight in progress (or just cleared): its reward type and threat.
  public let door: ref<RLDoor>;

  public func Threat() -> Int32 = IsDefined(this.door) ? this.door.threat : 2

  public static func Create(token: Int32, kit: CName, roguelike: Bool) -> ref<RLRunState> {
    let run = new RLRunState();
    run.token = token;
    run.kit = kit;
    run.roguelike = roguelike;
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
    }
  }

  public func BoonStacks(id: CName) -> Int32 {
    let count = 0;
    for boon in this.boons {
      if Equals(boon, id) {
        count += 1;
      }
    }
    return count;
  }

  public func ConsumeBoon(id: CName) -> Bool {
    let i = 0;
    while i < ArraySize(this.boons) {
      if Equals(this.boons[i], id) {
        ArrayErase(this.boons, i);
        return true;
      }
      i += 1;
    }
    return false;
  }

  public func FloorLabel() -> String {
    let label = s"ACT \(this.act) - FLOOR \(this.floor)";
    if this.IsBossFloor() {
      label += " (BOSS)";
    } else if this.IsEliteFloor() {
      label += " (ELITE)";
    }
    return label;
  }
}

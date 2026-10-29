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
  public let favorsEarned: Int32;
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

  // The four patrons working the city this run (Rewards/Patrons.reds), and
  // the effects V holds from them (Rewards/Boons.reds).
  public let patrons: array<CName>;
  public let boons: array<ref<RLBoonState>>;
  // Effects already offered this run: a NEW card is one that isn't here.
  public let seen: array<CName>;

  // Trauma Team cover: the run's lives. A lethal hit with cover left spends
  // one and V gets back up on the spot.
  public let cover: Int32;
  public let coverMax: Int32;
  public let coverSpent: Int32;

  // The weapon slots (Rewards/Weapons.reds): the main weapon takes every
  // weapon reward, the sidearm only steps up with the acts. The slot holds
  // the quality step, so a traded gun keeps it.
  public let mainWeapon: ItemID;
  public let mainStep: Int32;
  public let sidearm: ItemID;
  public let sidearmStep: Int32;
  // Arm chrome in the main slot (Rewards/ArmChrome.reds): its element (""
  // for the plain one), and whether it has evolved.
  public let mainElement: String;
  public let mainEvolved: Bool;
  // Chrome that has learned its evolution's signature (RLSignatures). Kept
  // apart from mainEvolved, which is the third effect slot: an iconic gun's
  // slot carries over to chrome that takes the main slot, its trick doesn't.
  public let mainSignature: Bool;
  // Arm mods (Rewards/ArmMods.reds), one per slot.
  public let armMods: array<ref<RLBoonState>>;

  // Trade-offs taken at events and deals: extra damage V takes (0.15 =
  // +15%), and stat modifiers that are removed when the run ends.
  public let damageTakenBonus: Float;
  public let appliedMods: array<ref<gameStatModifierData>>;
  // Max health those trade-offs took (0.15 = -15%); see RLBoons.HealthCut.
  public let healthCut: Float;
  // Loan Shark: fights left on the loan before it pays. Trophy Wall: kills
  // counted towards it this run.
  public let loanFights: Int32;
  public let trophyKills: Int32;
  // Every weapon the run handed out (kit and rewards): any other weapon V
  // carries was picked up in an arena and is taken away on the next trip.
  public let grantedWeapons: array<TweakDBID>;
  // Free reroll charges (refilled at the start of every act); the Afterlife's
  // favour adds one free reroll on every screen.
  public let rerolls: Int32;
  public let rerollsPerAct: Int32;
  public let screenRerollUsed: Bool;
  public let offerCount: Int32;
  // The fight in progress (or just cleared): its reward type and threat.
  public let door: ref<RLDoor>;

  // Reward director (Rewards/Director.reds): quality luck, and hot doors -
  // how many the act has left and the floor of the last one.
  public let pityOffset: Int32;
  public let flatStreak: Int32;
  public let magnificence: Int32;
  public let hotLeft: Int32;
  public let lastHotDepth: Int32;
  public let hotDecidedDepth: Int32;
  public let hotDecision: Bool;

  // Workshop doors (floors 4, 10 and 16; offered once more if passed over).
  public let workshopShown: Bool;
  public let workshopCarry: Bool;

  // Fixer stop after the elite floor, before the boss door.
  public let fixerPending: Bool;

  // Styles (Rewards/Styles.reds): points per style, recounted after picks.
  public let stylePoints: array<Int32>;
  // Cards banished for the rest of the run (RLRewards.OfferKey) and banishes
  // left (one per act).
  public let banished: array<String>;
  // Per door category (RLRewardCategory): door screens in a row that showed
  // it and V went elsewhere. The more often a door is passed over, the less
  // it comes back (RLRewards.RollCategory).
  public let doorsPassed: array<Int32>;
  // The act's route (Run/Routes.reds): where it goes, the landmark its boss
  // waits at, the routes the run has taken and the route arenas this act
  // has used.
  public let route: CName;
  public let routeBoss: CName;
  public let routesTaken: array<CName>;
  public let routeArenas: array<CName>;
  // Nemeses (Run/Nemesis.reds) met this run, so each shows up once.
  public let nemesesMet: array<Int32>;
  // Offered on a door of the screen being rolled (reset every screen).
  public let nemesesOffered: array<Int32>;
  public let banishes: Int32;
  public let banishesPerAct: Int32;
  // Terminal upgrades that fire once: the first patron screen (Open Line),
  // the floor whose free door reroll is spent (Inner Circle), the act whose
  // opening patron door is placed (Inside Man).
  public let firstPatronDealt: Bool;
  public let freeDoorRerollDepth: Int32;
  // The Operating System taken at the Act 1 boss, and Overdrive
  // (Run/Overdrive.reds): unlocked with it, charged 0..100.
  public let os: CName;
  public let overdriveUnlocked: Bool;
  public let overdrive: Float;
  // Capacity overclock: points of cyberware over capacity (each one raises
  // the odds of a cyberpsychosis episode in fights).
  public let overclock: Int32;
  // The gig taken at the start (Run/Gigs.reds): its style (-1 none), kills
  // needed and made, and how it ended.
  public let gigStyle: Int32;
  public let gigTarget: Int32;
  public let gigProgress: Int32;
  public let gigDone: Bool;
  public let gigFailed: Bool;

  // The floor was cleared and its reward is waiting: the run moves on to the
  // next floor once it has been picked.
  public let advancePending: Bool;

  public func Threat() -> Int32 = IsDefined(this.door) ? this.door.threat : 2

  public func IsHotFight() -> Bool = IsDefined(this.door) && this.door.hot

  public static func Create(token: Int32, kit: CName) -> ref<RLRunState> {
    let run = new RLRunState();
    run.token = token;
    run.kit = kit;
    run.act = 1;
    run.floor = 1;
    run.offerCount = 3;
    run.banishesPerAct = RLTerminal.Has(n"BurnNotice", 1) ? 2 : 1;
    run.banishes = run.banishesPerAct;
    run.pityOffset = RLTerminal.Has(n"LuckyStar", 1) ? 12 : 0;
    run.gigStyle = -1;
    run.hotLeft = RLRewardDirector.HotDoorsPerAct(1);
    run.lastHotDepth = -9;
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

  // Moves to the next floor; true when that starts a new act.
  public func Advance() -> Bool {
    this.floor += 1;
    if this.floor <= RLConfig.FloorsPerAct() {
      return false;
    }
    this.floor = 1;
    this.act += 1;
    // A new act picks its own route on its first floor.
    this.route = n"";
    this.routeBoss = n"";
    ArrayClear(this.routeArenas);
    this.rerolls = Max(this.rerolls, this.rerollsPerAct);
    this.banishes = Max(this.banishes, this.banishesPerAct);
    this.hotLeft = RLRewardDirector.HotDoorsPerAct(this.act);
    return true;
  }

  // Jumps to an overall floor (1-based), for test runs.
  public func SetDepth(depth: Int32) {
    let d = Clamp(depth, 1, this.TotalFloors()) - 1;
    this.act = d / RLConfig.FloorsPerAct() + 1;
    this.floor = d % RLConfig.FloorsPerAct() + 1;
    this.hotLeft = RLRewardDirector.HotDoorsPerAct(this.act);
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

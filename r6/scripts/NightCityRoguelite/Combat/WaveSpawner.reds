// -----------------------------------------------------------------------------
// Night City Roguelite - wave spawner
// -----------------------------------------------------------------------------
// Spawns waves with Codeware's DynamicEntitySystem around an arena center,
// forces each NPC hostile to V with a persistent threat, and polls once per
// second to count kills, refresh threat and clean up strays.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLTrackedEnemy {
  public let id: EntityID;
  public let record: TweakDBID;
  public let isBoss: Bool;
  public let spawnTime: Float;
  public let seen: Bool;
  public let hostile: Bool;
  public let lastThreat: Float;
  public let strayTime: Float;
  public let done: Bool;
}

public class RLEncounterPlan {
  // Flat list of records; waveStarts[i] is the index of wave i's first record.
  public let records: array<TweakDBID>;
  public let bossFlags: array<Bool>;
  public let waveStarts: array<Int32>;
  public let factionName: String;

  public func WaveCount() -> Int32 = ArraySize(this.waveStarts)

  public func WaveEnd(wave: Int32) -> Int32 {
    if wave + 1 < ArraySize(this.waveStarts) {
      return this.waveStarts[wave + 1];
    }
    return ArraySize(this.records);
  }

  public func BeginWave() {
    ArrayPush(this.waveStarts, ArraySize(this.records));
  }

  public func Add(record: TweakDBID, isBoss: Bool) {
    if TDBID.IsValid(record) {
      ArrayPush(this.records, record);
      ArrayPush(this.bossFlags, isBoss);
    }
  }
}

public class RLWaveSpawner extends IScriptable {
  private let m_system: wref<RogueliteSystem>;
  private let m_plan: ref<RLEncounterPlan>;
  private let m_center: Vector4;
  private let m_wave: Int32;
  private let m_tracked: array<ref<RLTrackedEnemy>>;
  private let m_time: Float;
  private let m_active: Bool;
  private let m_tickID: DelayID;
  private let m_waveID: DelayID;
  private let m_lastSpawnPoint: Vector4;
  private let m_hasLastSpawnPoint: Bool;
  private let m_waitingForWave: Bool;

  public static func Tag() -> CName = n"NightCityRoguelite.Enemy"

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLWaveSpawner> {
    let spawner = new RLWaveSpawner();
    spawner.m_system = system;
    return spawner;
  }

  // --- Public API ----------------------------------------------------------------------

  public func Start(center: Vector4, plan: ref<RLEncounterPlan>) {
    this.Abort();
    this.m_center = center;
    this.m_plan = plan;
    this.m_wave = -1;
    this.m_time = 0.0;
    this.m_active = true;
    this.m_hasLastSpawnPoint = false;
    this.m_waitingForWave = false;
    RLLog(s"Encounter: \(plan.WaveCount()) waves, \(ArraySize(plan.records)) enemies, faction \(plan.factionName)");
    this.NextWave();
    this.ScheduleTick();
  }

  // Stops tracking and deletes every spawned enemy (alive or dead).
  public func Abort() {
    let game = GetGameInstance();
    if this.m_active {
      RLCancel(game, this.m_tickID);
      RLCancel(game, this.m_waveID);
    }
    this.m_active = false;
    ArrayClear(this.m_tracked);
    this.DeleteAll();
  }

  // Deletes leftover bodies; used when moving on from a cleared arena.
  public func DeleteAll() {
    GameInstance.GetDynamicEntitySystem().DeleteTagged(RLWaveSpawner.Tag());
  }

  public func IsActive() -> Bool = this.m_active

  public func GetWave() -> Int32 = this.m_wave + 1

  public func GetWaveCount() -> Int32 = IsDefined(this.m_plan) ? this.m_plan.WaveCount() : 0

  public func GetAliveCount() -> Int32 {
    let count = 0;
    for enemy in this.m_tracked {
      if !enemy.done {
        count += 1;
      }
    }
    return count;
  }

  // --- Waves ---------------------------------------------------------------------------

  private func NextWave() {
    if !this.m_active {
      return;
    }
    this.m_waitingForWave = false;
    this.m_wave += 1;
    if this.m_wave >= this.m_plan.WaveCount() {
      this.m_active = false;
      RLCancel(GetGameInstance(), this.m_tickID);
      if IsDefined(this.m_system) {
        this.m_system.OnEncounterCleared();
      }
      return;
    }
    let first = this.m_plan.waveStarts[this.m_wave];
    let last = this.m_plan.WaveEnd(this.m_wave);
    let i = first;
    let spawned = 0;
    while i < last {
      if this.GetAliveCount() >= RLConfig.MaxAlive() {
        break;
      }
      if this.SpawnOne(this.m_plan.records[i], this.m_plan.bossFlags[i]) {
        spawned += 1;
      }
      i += 1;
    }
    RLDebug(s"Wave \(this.m_wave + 1): spawned \(spawned)");
    if IsDefined(this.m_system) {
      this.m_system.OnWaveStarted(this.m_wave + 1, this.m_plan.WaveCount(), this.m_plan.WaveEnd(this.m_wave) - first);
    }
    if spawned == 0 {
      // Nothing could spawn (bad records or no navmesh) - don't soft-lock.
      this.m_waitingForWave = true;
      this.m_waveID = RLDelay(GetGameInstance(), this, n"wave", RLConfig.WaveGap());
    }
  }

  private func SpawnOne(record: TweakDBID, isBoss: Bool) -> Bool {
    let position: Vector4;
    if !this.FindSpawnPoint(position) {
      return false;
    }
    let toCenter = this.m_center - position;
    let spec = new DynamicEntitySpec();
    spec.recordID = record;
    spec.position = position;
    spec.orientation = EulerAngles.ToQuat(Vector4.ToRotation(toCenter));
    spec.alwaysSpawned = true;
    spec.spawnInView = true;
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.tags = [RLWaveSpawner.Tag()];
    let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
    if !EntityID.IsDefined(id) {
      RLDebug(s"CreateEntity failed for \(TDBID.ToStringDEBUG(record))");
      return false;
    }
    let enemy = new RLTrackedEnemy();
    enemy.id = id;
    enemy.record = record;
    enemy.isBoss = isBoss;
    enemy.spawnTime = this.m_time;
    ArrayPush(this.m_tracked, enemy);
    return true;
  }

  private func FindSpawnPoint(out result: Vector4) -> Bool {
    let navigation = GameInstance.GetNavigationSystem(GetGameInstance());
    let attempt = 0;
    while attempt < 10 {
      let angle = RandRangeF(0.0, 6.2831853);
      let distance = RandRangeF(RLConfig.SpawnMinDistance(), RLConfig.SpawnMaxDistance());
      let probe = Vector4(
        this.m_center.X + CosF(angle) * distance,
        this.m_center.Y + SinF(angle) * distance,
        this.m_center.Z,
        1.0
      );
      let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 6.0, NavGenAgentSize.Human, false);
      if Equals(found.status, worldNavigationRequestStatus.OK) && AbsF(found.point.Z - this.m_center.Z) < 6.0 {
        result = found.point;
        this.m_lastSpawnPoint = found.point;
        this.m_hasLastSpawnPoint = true;
        return true;
      }
      attempt += 1;
    }
    // Fall back to the center's own navmesh point, then the last good point.
    let nearCenter = navigation.FindPointInSphereOnlyHumanNavmesh(this.m_center, 12.0, NavGenAgentSize.Human, false);
    if Equals(nearCenter.status, worldNavigationRequestStatus.OK) {
      result = nearCenter.point;
      return true;
    }
    if this.m_hasLastSpawnPoint {
      result = this.m_lastSpawnPoint;
      return true;
    }
    return false;
  }

  // --- Polling --------------------------------------------------------------------------

  private func ScheduleTick() {
    this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
  }

  public func OnDelayed(action: CName) {
    switch action {
      case n"tick":
        if this.m_active {
          this.Tick();
          if this.m_active {
            this.ScheduleTick();
          }
        }
        break;
      case n"wave":
        if this.m_active {
          this.NextWave();
        }
        break;
    }
  }

  private func Tick() {
    this.m_time += 1.0;
    let game = GetGameInstance();
    let player = GetPlayer(game);
    let entities = GameInstance.GetDynamicEntitySystem();
    let changed = false;

    for enemy in this.m_tracked {
      if enemy.done {
        continue;
      }
      let puppet = entities.GetEntity(enemy.id) as ScriptedPuppet;
      if !IsDefined(puppet) {
        if !enemy.seen && this.m_time - enemy.spawnTime > RLConfig.SpawnTimeout() {
          RLDebug(s"Enemy never spawned, dropping: \(TDBID.ToStringDEBUG(enemy.record))");
          enemy.done = true;
          entities.DeleteEntity(enemy.id);
          changed = true;
        } else if enemy.seen {
          // Spawned once, now gone (despawned or deleted by the game).
          enemy.done = true;
          changed = true;
        }
        continue;
      }
      enemy.seen = true;

      if puppet.IsDead() || ScriptedPuppet.IsDefeated(puppet) {
        enemy.done = true;
        changed = true;
        if IsDefined(this.m_system) {
          this.m_system.OnEnemyKilled(enemy.isBoss);
        }
        continue;
      }

      if !IsDefined(player) {
        continue;
      }
      if !enemy.hostile {
        RLWaveSpawner.MakeHostile(puppet, player);
        enemy.hostile = true;
        enemy.lastThreat = this.m_time;
      } else if this.m_time - enemy.lastThreat >= RLConfig.ThreatRefreshSeconds() {
        TargetTrackingExtension.InjectThreat(puppet, player);
        enemy.lastThreat = this.m_time;
      }

      if Vector4.Distance(puppet.GetWorldPosition(), player.GetWorldPosition()) > RLConfig.StrayDistance() {
        enemy.strayTime += 1.0;
        if enemy.strayTime >= RLConfig.StrayTimeout() {
          RLDebug("Removing stray enemy.");
          enemy.done = true;
          entities.DeleteEntity(enemy.id);
          changed = true;
        }
      } else {
        enemy.strayTime = 0.0;
      }
    }

    if changed && IsDefined(this.m_system) {
      this.m_system.OnEnemyCountChanged(this.GetAliveCount());
    }
    if this.GetAliveCount() == 0 && this.m_active && !this.m_waitingForWave {
      if this.m_wave + 1 >= this.m_plan.WaveCount() {
        this.NextWave(); // reports the encounter as cleared
      } else {
        this.m_waitingForWave = true;
        this.m_waveID = RLDelay(game, this, n"wave", RLConfig.WaveGap());
        if IsDefined(this.m_system) {
          this.m_system.OnWaveCleared(this.m_wave + 1, this.m_plan.WaveCount());
        }
      }
    }
  }

  public static func MakeHostile(puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
    GameObject.ChangeAttitudeToHostile(puppet, player);
    TargetTrackingExtension.InjectThreat(puppet, player);
    TargetTrackingExtension.SetThreatPersistence(puppet, player, true, 0u);
  }
}

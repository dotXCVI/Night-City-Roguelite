// -----------------------------------------------------------------------------
// Night City Roguelite - wave spawner
// -----------------------------------------------------------------------------
// Spawns waves with Codeware's DynamicEntitySystem inside the arena and keeps
// them in the fight. Once a second each enemy is checked:
//   - first sighting: god modes stripped, level set from the run's curve,
//     health refilled, made hostile with a persistent threat on V (the
//     roguelite variants in r6/tweaks are already hostile, alert and
//     level-scaled; this makes sure of it either way);
//   - an enemy that hasn't closed in on V for a few seconds is sent running at
//     V (then fights as normal);
//   - an enemy that ends up outside the arena is put back inside;
//   - dead enemies count as kills and their bodies are emptied (no looting);
//   - elites' affixes tick (Combat/Affixes.reds), and a boss calls in
//     reinforcements when hurt and enrages near death.
//
// Objective fights (Run/Objectives.reds) hold the encounter open: the waves
// cycle, the next one arriving when one enemy is left, until the run system
// releases the hold; then the fight ends with the last enemy.
//
// Spawn points are on the navmesh, inside the arena, near V's floor level and
// reachable from V on foot (a path is calculated before spawning).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLTrackedEnemy {
  public let id: EntityID;
  public let record: TweakDBID;
  public let isBoss: Bool;
  public let isElite: Bool;
  public let level: Int32;
  public let affixes: Int32;
  // Bosses: 0 fresh, 1 reinforcements called, 2 enraged.
  public let phase: Int32;
  public let name: String;
  public let spawnTime: Float;
  public let seen: Bool;
  public let prepared: Bool;
  public let lastThreat: Float;
  public let strayTime: Float;
  public let bestDistance: Float;
  public let idleTime: Float;
  public let outsideTime: Float;
  public let offFloorTime: Float;
  public let farTime: Float;
  public let done: Bool;
  public let dead: Bool;
  public let corpsePasses: Int32;
  // A recall is checked a few seconds later: an enemy that didn't move (the
  // teleport doesn't take behind some doors) is removed.
  public let recallFrom: Vector4;
  public let recallCheckAt: Float;
}

public class RLEncounterPlan {
  // Flat list of records; waveStarts[i] is the index of wave i's first record.
  public let records: array<TweakDBID>;
  public let bossFlags: array<Bool>;
  public let eliteFlags: array<Bool>;
  public let levels: array<Int32>;
  public let waveStarts: array<Int32>;
  public let factionName: String;
  // Boss fights: who answers the boss's call, and their level.
  public let reinforcements: array<TweakDBID>;
  public let reinforceLevel: Int32;

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

  public func Add(record: TweakDBID, isBoss: Bool, level: Int32, isElite: Bool) {
    if TDBID.IsValid(record) {
      ArrayPush(this.records, record);
      ArrayPush(this.bossFlags, isBoss);
      ArrayPush(this.eliteFlags, isElite);
      ArrayPush(this.levels, Max(1, level));
    }
  }
}

public class RLWaveSpawner extends RLDelayTarget {
  private let m_system: wref<RogueliteSystem>;
  private let m_plan: ref<RLEncounterPlan>;
  private let m_center: Vector4;
  private let m_radius: Float;
  private let m_avoid: array<Vector4>;
  private let m_wave: Int32;
  private let m_tracked: array<ref<RLTrackedEnemy>>;
  private let m_time: Float;
  // Last kill or wave start; long stretches without one mean an enemy is
  // stuck somewhere V can't reach (Unstick).
  private let m_lastProgress: Float;
  private let m_unstickRounds: Int32;
  private let m_active: Bool;
  private let m_tickID: DelayID;
  private let m_waveID: DelayID;
  private let m_lastSpawnPoint: Vector4;
  private let m_hasLastSpawnPoint: Bool;
  private let m_waitingForWave: Bool;
  // Enemies dropped from the next wave (pacing director's relax phase).
  private let m_trimNext: Int32;
  // Objective fights: waves cycle while held open; once released, the fight
  // ends with the last enemy.
  private let m_holdOpen: Bool;
  private let m_finishing: Bool;

  public static func Tag() -> CName = n"NightCityRoguelite.Enemy"

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLWaveSpawner> {
    let spawner = new RLWaveSpawner();
    spawner.m_system = system;
    return spawner;
  }

  // --- Public API ----------------------------------------------------------------------

  public func Start(arena: ref<RLArenaDef>, plan: ref<RLEncounterPlan>, holdOpen: Bool) {
    this.Abort();
    this.m_holdOpen = holdOpen;
    this.m_finishing = false;
    this.m_center = arena.position;
    this.m_radius = arena.radius;
    this.m_avoid = arena.avoid;
    this.m_plan = plan;
    this.m_wave = -1;
    this.m_time = 0.0;
    this.m_active = true;
    this.m_hasLastSpawnPoint = false;
    this.m_waitingForWave = false;
    this.m_trimNext = 0;
    RLLog(s"Encounter: \(plan.WaveCount()) waves, \(ArraySize(plan.records)) enemies, faction \(plan.factionName)");
    this.NextWave();
    this.ScheduleTick();
  }

  // Stops tracking and deletes every spawned enemy (alive or dead).
  public func Abort() {
    let game = GetGameInstance();
    if this.m_active {
      RLCancel(game, this.m_waveID);
    }
    RLCancel(game, this.m_tickID);
    this.m_active = false;
    ArrayClear(this.m_tracked);
    this.DeleteAll();
  }

  // Deletes leftover bodies; used when moving on from a cleared arena.
  public func DeleteAll() {
    GameInstance.GetDynamicEntitySystem().DeleteTagged(RLWaveSpawner.Tag());
  }

  public func IsActive() -> Bool = this.m_active

  // V went down: no more waves; tracking stops and the bodies stay.
  public func Halt() {
    if this.m_active {
      RLCancel(GetGameInstance(), this.m_waveID);
    }
    this.m_active = false;
    this.m_holdOpen = false;
    this.m_finishing = false;
  }

  // One line per enemy still counted as alive, for bug marks.
  public func Describe(player: ref<PlayerPuppet>) -> array<String> {
    let lines: array<String>;
    let entities = GameInstance.GetDynamicEntitySystem();
    ArrayPush(lines, s"Spawner: active \(this.m_active), wave \(this.m_wave + 1)/\(IsDefined(this.m_plan) ? this.m_plan.WaveCount() : 0), waiting \(this.m_waitingForWave), hold \(this.m_holdOpen), finishing \(this.m_finishing), \(RoundF(this.m_time - this.m_lastProgress))s since progress.");
    for enemy in this.m_tracked {
      if !enemy.done {
        let puppet = entities.GetEntity(enemy.id) as ScriptedPuppet;
        let where = "not spawned";
        if IsDefined(puppet) {
          let p = puppet.GetWorldPosition();
          let distance = IsDefined(player) ? Vector4.Distance(p, player.GetWorldPosition()) : 0.0;
          where = s"(\(p.X), \(p.Y), \(p.Z)), \(RoundF(distance)) m from V, dead \(puppet.IsDead())";
        }
        ArrayPush(lines, s"  \(TDBID.ToStringDEBUG(enemy.record)) boss \(enemy.isBoss) elite \(enemy.isElite) affixes \(RLAffixes.Names(enemy.affixes)): \(where); idle \(enemy.idleTime)s, outside \(enemy.outsideTime)s, off floor \(enemy.offFloorTime)s");
      }
    }
    return lines;
  }

  private func ReportLost(enemy: ref<RLTrackedEnemy>) {
    if IsDefined(this.m_system) {
      this.m_system.OnEnemyLost(enemy);
    }
  }

  // The objective is done: nobody else joins; the fight ends with the last
  // enemy standing.
  public func ReleaseHold() {
    if !this.m_holdOpen {
      return;
    }
    this.m_holdOpen = false;
    this.m_finishing = true;
    if this.m_waitingForWave {
      RLCancel(GetGameInstance(), this.m_waveID);
      this.m_waitingForWave = false;
    }
  }

  // Living enemies within `radius` of a spot (Overdrive, style signatures).
  public func LivingNear(position: Vector4, radius: Float) -> array<ref<ScriptedPuppet>> {
    let result: array<ref<ScriptedPuppet>>;
    let entities = GameInstance.GetDynamicEntitySystem();
    for enemy in this.m_tracked {
      if !enemy.done {
        let puppet = entities.GetEntity(enemy.id) as ScriptedPuppet;
        if IsDefined(puppet) && !puppet.IsDead() && Vector4.Distance(puppet.GetWorldPosition(), position) <= radius {
          ArrayPush(result, puppet);
        }
      }
    }
    return result;
  }

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
    this.m_lastProgress = this.m_time;
    this.m_unstickRounds = 0;
    this.m_wave += 1;
    if this.m_wave >= this.m_plan.WaveCount() && this.m_holdOpen {
      this.m_wave = 0;
    }
    if this.m_wave >= this.m_plan.WaveCount() {
      this.m_active = false;
      if IsDefined(this.m_system) {
        this.m_system.OnEncounterCleared();
      }
      return;
    }
    let player = GetPlayer(GetGameInstance());
    let first = this.m_plan.waveStarts[this.m_wave];
    let last = this.m_plan.WaveEnd(this.m_wave);
    // Relax phase: drop the last (never a boss) enemies of this wave.
    while this.m_trimNext > 0 && last - first > 1 && !this.m_plan.bossFlags[last - 1] {
      last -= 1;
      this.m_trimNext -= 1;
    }
    this.m_trimNext = 0;
    let i = first;
    let spawned = 0;
    while i < last {
      if this.GetAliveCount() >= RLConfig.MaxAlive() {
        break;
      }
      if this.SpawnRecord(player, this.m_plan.records[i], this.m_plan.bossFlags[i], this.m_plan.eliteFlags[i], this.m_plan.levels[i]) {
        spawned += 1;
      }
      i += 1;
    }
    RLLog(s"Wave \(this.m_wave + 1): spawned \(spawned) of \(last - first).");
    if IsDefined(this.m_system) {
      this.m_system.OnWaveStarted(this.m_wave + 1, this.m_plan.WaveCount(), last - first);
    }
    if spawned == 0 {
      // Nothing could spawn (bad records or no navmesh) - don't soft-lock.
      this.m_waitingForWave = true;
      this.m_waveID = RLDelay(GetGameInstance(), this, n"wave", RLConfig.WaveGap());
    }
  }

  private func SpawnRecord(player: ref<PlayerPuppet>, record: TweakDBID, isBoss: Bool, isElite: Bool, level: Int32) -> Bool {
    let position: Vector4;
    if !this.FindSpawnPoint(player, position) {
      RLLog("No spawn point found for an enemy.");
      return false;
    }
    let facing = IsDefined(player) ? player.GetWorldPosition() - position : this.m_center - position;
    let spec = new DynamicEntitySpec();
    spec.recordID = record;
    spec.position = position;
    spec.orientation = EulerAngles.ToQuat(Vector4.ToRotation(facing));
    spec.alwaysSpawned = true;
    spec.spawnInView = true;
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.tags = [RLWaveSpawner.Tag()];
    let id = GameInstance.GetDynamicEntitySystem().CreateEntity(spec);
    if !EntityID.IsDefined(id) {
      RLLog(s"CreateEntity failed for \(TDBID.ToStringDEBUG(record))");
      return false;
    }
    let enemy = new RLTrackedEnemy();
    enemy.id = id;
    enemy.record = record;
    enemy.isBoss = isBoss;
    enemy.isElite = isElite;
    enemy.level = level;
    enemy.spawnTime = this.m_time;
    enemy.bestDistance = 9999.0;
    ArrayPush(this.m_tracked, enemy);
    if IsDefined(this.m_system) {
      this.m_system.OnEnemySpawned(enemy);
    }
    RLDebug(s"Spawned \(TDBID.ToStringDEBUG(record)) at (\(position.X), \(position.Y), \(position.Z)).");
    return true;
  }

  // A navmesh point inside the arena, near V's floor level, that V can reach on
  // foot. Falls back to looser checks so a wave never fails to appear.
  private func FindSpawnPoint(player: ref<PlayerPuppet>, out result: Vector4) -> Bool {
    let hasPlayer = IsDefined(player);
    let reference = hasPlayer ? player.GetWorldPosition() : this.m_center;
    if Vector4.Distance2D(reference, this.m_center) > this.m_radius + 3.0 {
      reference = this.m_center;
    }
    let attempt = 0;
    while attempt < 24 {
      let strict = attempt < 16;
      let point: Vector4;
      if this.TryPoint(reference, hasPlayer, strict, point) {
        result = point;
        this.m_lastSpawnPoint = point;
        this.m_hasLastSpawnPoint = true;
        return true;
      }
      attempt += 1;
    }
    if this.m_hasLastSpawnPoint {
      result = this.m_lastSpawnPoint;
      return true;
    }
    let nearCenter = GameInstance.GetNavigationSystem(GetGameInstance())
      .FindPointInSphereOnlyHumanNavmesh(this.m_center, 8.0, NavGenAgentSize.Human, false);
    if Equals(nearCenter.status, worldNavigationRequestStatus.OK) {
      result = nearCenter.point;
      return true;
    }
    return false;
  }

  private func IsAvoided(point: Vector4) -> Bool {
    for spot in this.m_avoid {
      if Vector4.Distance(point, Vector4(spot.X, spot.Y, spot.Z, 1.0)) < spot.W {
        return true;
      }
    }
    return false;
  }

  private func TryPoint(reference: Vector4, hasPlayer: Bool, strict: Bool, out result: Vector4) -> Bool {
    let navigation = GameInstance.GetNavigationSystem(GetGameInstance());
    let usable = MaxF(8.0, this.m_radius - 4.0);
    let angle = RandRangeF(0.0, 6.2831853);
    let distance = SqrtF(RandRangeF(0.04, 1.0)) * usable;
    let probe = Vector4(
      this.m_center.X + CosF(angle) * distance,
      this.m_center.Y + SinF(angle) * distance,
      reference.Z,
      1.0
    );
    let found = navigation.FindPointInSphereOnlyHumanNavmesh(probe, 3.0, NavGenAgentSize.Human, false);
    if !Equals(found.status, worldNavigationRequestStatus.OK) {
      return false;
    }
    let point = found.point;
    if Vector4.Distance2D(point, this.m_center) > usable + 1.0 || this.IsAvoided(point) {
      return false;
    }
    if AbsF(point.Z - reference.Z) > (strict ? 4.0 : 8.0) {
      return false;
    }
    let toReference = Vector4.Distance(point, reference);
    if hasPlayer && toReference < (strict ? 12.0 : 7.0) {
      return false;
    }
    if strict {
      // Must be reachable on foot from V (rules out rooftops, sealed rooms and
      // spots inside buildings).
      let path = navigation.CalculatePathOnlyHumanNavmesh(point, reference, NavGenAgentSize.Human, 2.0);
      if !IsDefined(path) || ArraySize(path.path) < 2 {
        return false;
      }
      if path.CalculateLength() > toReference * 2.5 + 15.0 {
        return false;
      }
    }
    result = point;
    return true;
  }

  // --- Polling --------------------------------------------------------------------------

  private func ScheduleTick() {
    this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
  }

  public func OnDelayed(action: CName) {
    switch action {
      case n"tick":
        this.Tick();
        if this.m_active || this.HasCorpsesToStock() {
          this.ScheduleTick();
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
      if enemy.dead && enemy.corpsePasses < 2 {
        this.StockCorpse(enemy, player, entities);
      } else if !enemy.done && this.m_active && this.UpdateEnemy(enemy, player, entities) {
        changed = true;
      }
    }
    if !this.m_active {
      return;
    }
    if IsDefined(this.m_system) {
      this.m_system.OnFightTick();
    }
    if !this.m_active {
      return;
    }

    if this.m_finishing {
      if this.GetAliveCount() > 0 && this.m_time - this.m_lastProgress >= RLConfig.UnstickSeconds() {
        changed = this.Unstick(player, entities) || changed;
      }
      if changed && IsDefined(this.m_system) {
        this.m_system.OnEnemyCountChanged(this.GetAliveCount());
      }
      if this.GetAliveCount() == 0 {
        this.m_active = false;
        if IsDefined(this.m_system) {
          this.m_system.OnEncounterCleared();
        }
      }
      return;
    }
    // Objective fights: the next wave as soon as one enemy is left.
    if this.m_holdOpen && !this.m_waitingForWave && this.GetAliveCount() <= 1 {
      this.m_waitingForWave = true;
      if IsDefined(this.m_system) {
        this.m_system.OnHoldWave();
      }
      this.m_waveID = RLDelay(game, this, n"wave", RLConfig.WaveGap());
    }

    if this.GetAliveCount() > 0 && !this.m_waitingForWave && this.m_time - this.m_lastProgress >= RLConfig.UnstickSeconds() {
      changed = this.Unstick(player, entities) || changed;
    }
    if changed && IsDefined(this.m_system) {
      this.m_system.OnEnemyCountChanged(this.GetAliveCount());
    }
    if this.GetAliveCount() == 0 && !this.m_waitingForWave {
      if this.m_wave + 1 >= this.m_plan.WaveCount() {
        this.NextWave(); // reports the encounter as cleared
      } else {
        this.m_waitingForWave = true;
        let relax = IsDefined(this.m_system) && this.m_system.OnWaveCleared(this.m_wave + 1, this.m_plan.WaveCount());
        this.m_trimNext = relax ? 1 : 0;
        this.m_waveID = RLDelay(game, this, n"wave", relax ? RLConfig.RelaxWaveGap() : RLConfig.WaveGap());
      }
    }
  }

  private func HasCorpsesToStock() -> Bool {
    for enemy in this.m_tracked {
      if enemy.dead && enemy.corpsePasses < 2 {
        return true;
      }
    }
    return false;
  }

  // Two passes: right after death, and a second later (the game may still be
  // generating the body's loot on the first).
  private func StockCorpse(enemy: ref<RLTrackedEnemy>, player: ref<PlayerPuppet>, entities: ref<DynamicEntitySystem>) {
    enemy.corpsePasses += 1;
    RLLoot.EmptyCorpse(entities.GetEntity(enemy.id) as ScriptedPuppet);
  }

  // Updates one tracked enemy; returns true when it stopped counting as alive.
  private func UpdateEnemy(enemy: ref<RLTrackedEnemy>, player: ref<PlayerPuppet>, entities: ref<DynamicEntitySystem>) -> Bool {
    let puppet = entities.GetEntity(enemy.id) as ScriptedPuppet;
    if !IsDefined(puppet) {
      if !enemy.seen && this.m_time - enemy.spawnTime > RLConfig.SpawnTimeout() {
        RLLog(s"Enemy never spawned, dropping: \(TDBID.ToStringDEBUG(enemy.record))");
        enemy.done = true;
        entities.DeleteEntity(enemy.id);
        this.ReportLost(enemy);
        return true;
      }
      if enemy.seen {
        // Spawned once, now gone (despawned or deleted by the game).
        enemy.done = true;
        this.ReportLost(enemy);
        return true;
      }
      return false;
    }
    enemy.seen = true;

    if puppet.IsDead() || ScriptedPuppet.IsDefeated(puppet) {
      enemy.done = true;
      enemy.dead = true;
      this.m_lastProgress = this.m_time;
      this.m_unstickRounds = 0;
      this.StockCorpse(enemy, player, entities);
      if IsDefined(this.m_system) {
        this.m_system.OnEnemyKilled(enemy, puppet, false);
      }
      return true;
    }

    if !IsDefined(player) {
      return false;
    }
    if !enemy.prepared {
      enemy.prepared = true;
      RLWaveSpawner.Prepare(puppet, player, enemy.level);
      enemy.lastThreat = this.m_time;
      RLAffixes.OnSpawned(puppet, enemy.affixes);
      if IsDefined(this.m_system) {
        this.m_system.OnEnemySighted(enemy, puppet);
      }
    } else if this.m_time - enemy.lastThreat >= RLConfig.ThreatRefreshSeconds() {
      RLWaveSpawner.MakeHostile(puppet, player);
      enemy.lastThreat = this.m_time;
    }
    RLAffixes.OnTick(puppet, enemy.affixes);
    if enemy.isBoss {
      this.UpdateBoss(enemy, puppet, player);
    }

    // Not placed yet: right after spawning the position reads as the world
    // origin, and moving an enemy that is still being set up leaves it half
    // in the ground. Leave new enemies alone for a moment.
    let position = puppet.GetWorldPosition();
    if this.m_time - enemy.spawnTime < 2.0 || (position.X == 0.0 && position.Y == 0.0 && position.Z == 0.0) {
      return false;
    }
    let distance = Vector4.Distance(position, player.GetWorldPosition());

    // A recall that didn't take: the enemy can't be reached, so it goes (and
    // counts as killed).
    if enemy.recallCheckAt > 0.0 && this.m_time >= enemy.recallCheckAt {
      enemy.recallCheckAt = 0.0;
      if Vector4.Distance(position, enemy.recallFrom) < 2.0 {
        RLLog(s"An enemy couldn't be moved from (\(position.X), \(position.Y), \(position.Z)) - removed.");
        enemy.done = true;
        enemy.dead = true;
        enemy.corpsePasses = 2;
        entities.DeleteEntity(enemy.id);
        this.m_lastProgress = this.m_time;
        if IsDefined(this.m_system) {
          this.m_system.OnEnemyKilled(enemy, null, true);
        }
        return true;
      }
    }

    // Back inside if it wandered out of the arena.
    if Vector4.Distance2D(position, this.m_center) > this.m_radius + 2.0 {
      enemy.outsideTime += 1.0;
      if enemy.outsideTime >= 4.0 {
        enemy.outsideTime = 0.0;
        let point: Vector4;
        if this.FindSpawnPoint(player, point) {
          RLWaveSpawner.MoveEnemy(puppet, point, player.GetWorldPosition());
          RLDebug("Put an enemy back inside the arena.");
        }
      }
    } else {
      enemy.outsideTime = 0.0;
    }

    // Lost enemies are brought back to V's level, near V:
    //   - below the arena floor (fell through, spawned underground): at once;
    //   - on another level (roof, basement, inside a building) for 8 s;
    //   - with 2 or fewer left, one that hasn't come close in 20 s.
    let playerPosition = player.GetWorldPosition();
    if position.Z < this.m_center.Z - RLConfig.ArenaFloorDrop() {
      this.Recall(enemy, puppet, player, "below the arena");
      return false;
    }
    if AbsF(position.Z - playerPosition.Z) > 8.0 && distance > 12.0 {
      enemy.offFloorTime += 1.0;
      if enemy.offFloorTime >= 8.0 {
        this.Recall(enemy, puppet, player, "on another level");
        return false;
      }
    } else {
      enemy.offFloorTime = 0.0;
    }
    if distance > RLConfig.ChaseDistance() && this.GetAliveCount() <= 2 {
      enemy.farTime += 1.0;
      if enemy.farTime >= 20.0 {
        this.Recall(enemy, puppet, player, "straggling");
        return false;
      }
    } else {
      enemy.farTime = 0.0;
    }

    // Keep the pressure on: an enemy that stays back without closing in runs at V.
    if distance > RLConfig.ChaseDistance() {
      if distance < enemy.bestDistance - 1.5 {
        enemy.bestDistance = distance;
        enemy.idleTime = 0.0;
      } else {
        enemy.idleTime += 1.0;
        if enemy.idleTime >= RLConfig.ChaseAfterSeconds() {
          RLWaveSpawner.ChargeAt(puppet, player);
          enemy.idleTime = 0.0;
          enemy.bestDistance = distance;
        }
      }
    } else {
      enemy.idleTime = 0.0;
      enemy.bestDistance = distance;
    }

    if distance > RLConfig.StrayDistance() {
      enemy.strayTime += 1.0;
      if enemy.strayTime >= RLConfig.StrayTimeout() {
        RLLog("Removing stray enemy.");
        enemy.done = true;
        entities.DeleteEntity(enemy.id);
        this.ReportLost(enemy);
        return true;
      }
    } else {
      enemy.strayTime = 0.0;
    }
    return false;
  }

  // No kill for a while: twice, every enemy left is brought next to V (stuck
  // behind a locked door, in a doorway, on a roof); if that doesn't help
  // either, they are removed and count as killed, so a run can never softlock.
  // Returns true when enemies were removed.
  private func Unstick(player: ref<PlayerPuppet>, entities: ref<DynamicEntitySystem>) -> Bool {
    this.m_lastProgress = this.m_time;
    this.m_unstickRounds += 1;
    let removed = 0;
    for enemy in this.m_tracked {
      if !enemy.done {
        let puppet = entities.GetEntity(enemy.id) as ScriptedPuppet;
        if this.m_unstickRounds <= 2 {
          if IsDefined(puppet) && IsDefined(player) {
            this.Recall(enemy, puppet, player, "no progress");
          }
        } else {
          enemy.done = true;
          enemy.dead = true;
          enemy.corpsePasses = 2;
          entities.DeleteEntity(enemy.id);
          removed += 1;
          if IsDefined(this.m_system) {
            this.m_system.OnEnemyKilled(enemy, null, true);
          }
        }
      }
    }
    if removed > 0 {
      RLLog(s"Removed \(removed) enemies that couldn't be reached.");
      this.m_unstickRounds = 0;
    }
    return removed > 0;
  }

  // A boss's phases: reinforcements when hurt, enraged near death. Its health
  // goes to the HUD.
  private func UpdateBoss(enemy: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
    let health = GameInstance.GetStatPoolsSystem(puppet.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(puppet.GetEntityID()), gamedataStatPoolType.Health, true);
    if enemy.phase == 0 && health <= RLConfig.BossReinforceAt() {
      enemy.phase = 1;
      let called = 0;
      for record in this.m_plan.reinforcements {
        if this.GetAliveCount() < RLConfig.MaxAlive() && this.SpawnRecord(player, record, false, false, this.m_plan.reinforceLevel) {
          called += 1;
        }
      }
      ArrayClear(this.m_plan.reinforcements);
      if called > 0 && IsDefined(this.m_system) {
        this.m_system.OnBossPhase(enemy, 1);
      }
    }
    if enemy.phase <= 1 && health <= RLConfig.BossEnrageAt() {
      enemy.phase = 2;
      StatusEffectHelper.ApplyStatusEffect(puppet, t"BaseStatusEffect.BerserkNPCBuff");
      if IsDefined(this.m_system) {
        this.m_system.OnBossPhase(enemy, 2);
      }
    }
    if IsDefined(this.m_system) {
      this.m_system.OnBossHealth(enemy, health);
    }
  }

  private func Recall(enemy: ref<RLTrackedEnemy>, puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, const reason: String) {
    enemy.offFloorTime = 0.0;
    enemy.farTime = 0.0;
    enemy.idleTime = 0.0;
    let from = puppet.GetWorldPosition();
    let point: Vector4;
    if !this.FindSpawnPoint(player, point) {
      return;
    }
    RLWaveSpawner.MoveEnemy(puppet, point, player.GetWorldPosition());
    enemy.bestDistance = Vector4.Distance(point, player.GetWorldPosition());
    enemy.recallFrom = from;
    enemy.recallCheckAt = this.m_time + 3.0;
    RLLog(s"Brought an enemy back (\(reason)): (\(from.X), \(from.Y), \(from.Z)) -> (\(point.X), \(point.Y), \(point.Z)).");
    RLWaveSpawner.ChargeAt(puppet, player);
  }

  // Moves an enemy, facing V: the teleport facility, and the AI's own
  // teleport command (the facility alone doesn't always take on an NPC that
  // is fighting).
  public static func MoveEnemy(puppet: ref<ScriptedPuppet>, point: Vector4, facing: Vector4) {
    GameInstance.GetTeleportationFacility(puppet.GetGame()).Teleport(puppet, point, Vector4.ToRotation(facing - point));
    let command = new AITeleportCommand();
    command.position = point;
    command.rotation = Vector4.Heading(facing - point);
    command.doNavTest = false;
    AIComponent.SendCommand(puppet, command);
  }

  // First-sighting setup: no god modes, the planned level, full health, hostile.
  public static func Prepare(puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, level: Int32) {
    let game = puppet.GetGame();
    let id = puppet.GetEntityID();
    let godModes = GameInstance.GetGodModeSystem(game);
    let types = [gameGodModeType.Invulnerable, gameGodModeType.Immortal];
    for type in types {
      let sources = godModes.GetGodModeSources(id, type);
      for source in sources {
        godModes.RemoveGodMode(id, type, source);
      }
      if ArraySize(sources) > 0 {
        RLLog(s"Removed god mode from \(TDBID.ToStringDEBUG(puppet.GetRecordID())).");
      }
    }

    let stats = GameInstance.GetStatsSystem(game);
    let npcStats = Cast<StatsObjectID>(id);
    let playerLevel = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.PowerLevel);
    let target = Cast<Float>(Max(1, level));
    RLDebug(s"Enemy level \(stats.GetStatValue(npcStats, gamedataStatType.PowerLevel)) -> \(target) (V \(playerLevel)).");
    stats.RemoveAllModifiers(npcStats, gamedataStatType.PowerLevel);
    stats.AddModifier(npcStats, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, target));
    GameInstance.GetStatPoolsSystem(game).RequestSettingStatPoolValue(npcStats, gamedataStatPoolType.Health, 100.0, null, true);

    RLWaveSpawner.MakeHostile(puppet, player);
  }

  public static func MakeHostile(puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
    GameObject.ChangeAttitudeToHostile(puppet, player);
    TargetTrackingExtension.InjectThreat(puppet, player);
    TargetTrackingExtension.SetThreatPersistence(puppet, player, true, 0u);
  }

  // Sends the enemy sprinting towards V; it resumes fighting on arrival.
  public static func ChargeAt(puppet: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
    let ai = puppet.GetAIControllerComponent();
    if !IsDefined(ai) {
      return;
    }
    let command = new AIMoveToCommand();
    AIPositionSpec.SetEntity(command.movementTarget, player);
    AIPositionSpec.SetEntity(command.facingTarget, player);
    command.movementType = moveMovementType.Sprint;
    command.desiredDistanceFromTarget = 7.0;
    command.ignoreNavigation = false;
    command.finishWhenDestinationReached = true;
    ai.SendCommand(command);
    RLWaveSpawner.MakeHostile(puppet, player);
  }
}

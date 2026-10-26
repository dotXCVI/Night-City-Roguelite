// -----------------------------------------------------------------------------
// Night City Roguelite - arena cleaner
// -----------------------------------------------------------------------------
// Keeps arenas empty of everyone but V and the mod's enemies, for this
// character only (the world itself is untouched, so normal saves keep their
// pedestrians and vendors):
//   - a dynamic crowd null area over the arena plus crowd density 0 while a
//     fight is on: no pedestrians or crowd traffic;
//   - every other NPC that streams in inside the arena (vendors, ambient
//     workers, gang members standing around) is moved far away, where the game
//     despawns it;
//   - shops and other "safe zones" inside an arena don't force V's weapon
//     away (PlayerPuppet.OnEnterSafeZone below).
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLPendingNPC {
  public let npc: wref<NPCPuppet>;
  public let age: Float;
  public let tries: Int32;
}

public class RLArenaCleaner extends IScriptable {
  private let m_active: Bool;
  private let m_center: Vector4;
  private let m_radius: Float;
  private let m_nullArea: Uint64;
  private let m_hasNullArea: Bool;
  private let m_pending: array<ref<RLPendingNPC>>;
  private let m_removed: Int32;

  public func IsActive() -> Bool = this.m_active

  public func Start(arena: ref<RLArenaDef>) {
    this.Stop();
    this.m_active = true;
    this.m_center = arena.position;
    this.m_radius = arena.radius + 20.0;
    this.m_removed = 0;
    ArrayClear(this.m_pending);
    let community = GameInstance.GetCommunitySystem(GetGameInstance());
    if IsDefined(community) {
      let box: Box;
      box.Min = Vector4(-this.m_radius, -this.m_radius, -40.0, 1.0);
      box.Max = Vector4(this.m_radius, this.m_radius, 60.0, 1.0);
      let transform: WorldTransform;
      WorldTransform.SetPosition(transform, this.m_center);
      this.m_nullArea = community.EnableDynamicCrowdNullArea(box, transform, false, 3600.0);
      this.m_hasNullArea = true;
      community.ChangeDensityModifier(0.0);
    }
  }

  public func Stop() {
    if !this.m_active {
      return;
    }
    this.m_active = false;
    ArrayClear(this.m_pending);
    let community = GameInstance.GetCommunitySystem(GetGameInstance());
    if IsDefined(community) {
      if this.m_hasNullArea {
        community.DisableCrowdNullArea(this.m_nullArea);
      }
      community.ResetDensityModifier();
    }
    this.m_hasNullArea = false;
    if this.m_removed > 0 {
      RLLog(s"Arena cleaner: moved \(this.m_removed) bystander(s) out of the arena.");
    }
  }

  public func IsInArena(position: Vector4) -> Bool {
    return this.m_active && Vector4.Distance2D(position, this.m_center) <= this.m_radius
      && AbsF(position.Z - this.m_center.Z) < 40.0;
  }

  // From the Entity/AfterAttach callback (RogueliteService).
  public func OnNPCAttached(npc: ref<NPCPuppet>) {
    if !this.m_active || !IsDefined(npc) || npc.IsPlayer() {
      return;
    }
    if GameInstance.GetDynamicEntitySystem().IsTagged(npc.GetEntityID(), RLWaveSpawner.Tag()) {
      return;
    }
    let entry = new RLPendingNPC();
    entry.npc = npc;
    ArrayPush(this.m_pending, entry);
  }

  // Called by the arena director every 0.1 s.
  public func Tick(delta: Float) {
    if !this.m_active || ArraySize(this.m_pending) == 0 {
      return;
    }
    let keep: array<ref<RLPendingNPC>>;
    for entry in this.m_pending {
      entry.age += delta;
      let npc = entry.npc;
      if !IsDefined(npc) {
        // Gone already (despawned).
      } else if entry.age < 0.5 {
        ArrayPush(keep, entry);
      } else if !this.IsInArena(npc.GetWorldPosition()) {
        if entry.tries > 0 {
          this.m_removed += 1;
        }
      } else if entry.tries >= 5 {
        RLDebug("Arena cleaner: an NPC couldn't be moved (" + TDBID.ToStringDEBUG(npc.GetRecordID()) + ").");
      } else {
        entry.tries += 1;
        entry.age = 0.0;
        this.MoveAway(npc);
        ArrayPush(keep, entry);
      }
    }
    this.m_pending = keep;
  }

  // Far outside streaming range: the game despawns it there and restores it
  // normally once V has left.
  private func MoveAway(npc: ref<NPCPuppet>) {
    let target = Vector4(this.m_center.X + 900.0, this.m_center.Y + 900.0, this.m_center.Z + 5.0, 1.0);
    let rotation: EulerAngles;
    GameInstance.GetTeleportationFacility(npc.GetGame()).Teleport(npc, target, rotation);
  }
}

// Shops and other safe zones inside an arena don't take V's weapon away.
@wrapMethod(PlayerPuppet)
private final func OnEnterSafeZone() {
  let system = RogueliteSystem.Get(this.GetGame());
  if IsDefined(system) && system.IsInArenaFight() {
    return;
  }
  wrappedMethod();
}

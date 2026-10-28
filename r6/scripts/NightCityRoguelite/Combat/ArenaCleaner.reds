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
//     away (PlayerPuppet.OnEnterSafeZone below);
//   - every locked, sealed or keypad door in the arena is opened: the
//     navmesh sends enemies and objective markers through them, so V has to
//     be able to follow without knowing a code or passing a skill check;
//   - weapons knocked out of enemies' hands (a disarming shot, a finisher, a
//     boss losing its hammer) are emptied as they land, so no legendary sits
//     on the floor that the pickup filter would only take away again.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLPendingNPC {
  public let npc: wref<NPCPuppet>;
  public let age: Float;
  public let tries: Int32;
}

public class RLPendingDrop {
  public let drop: wref<gameItemDropObject>;
  public let age: Float;
}

public class RLArenaCleaner extends IScriptable {
  private let m_active: Bool;
  private let m_center: Vector4;
  private let m_radius: Float;
  private let m_nullArea: Uint64;
  private let m_hasNullArea: Bool;
  private let m_pending: array<ref<RLPendingNPC>>;
  private let m_removed: Int32;
  private let m_drops: array<ref<RLPendingDrop>>;
  private let m_dropsCleared: Int32;
  private let m_doorsOpened: Int32;

  public func IsActive() -> Bool = this.m_active

  public func Start(arena: ref<RLArenaDef>) {
    this.Stop();
    this.m_active = true;
    this.m_center = arena.position;
    this.m_radius = arena.radius + 20.0;
    this.m_removed = 0;
    this.m_dropsCleared = 0;
    this.m_doorsOpened = 0;
    ArrayClear(this.m_pending);
    ArrayClear(this.m_drops);
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
    ArrayClear(this.m_drops);
    if this.m_removed > 0 {
      RLLog(s"Arena cleaner: moved \(this.m_removed) bystander(s) out of the arena.");
    }
    if this.m_dropsCleared > 0 || this.m_doorsOpened > 0 {
      RLLog(s"Arena cleaner: \(this.m_dropsCleared) dropped weapon(s) cleared, \(this.m_doorsOpened) door(s) opened.");
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

  // From the Entity/AfterAttach callback: a door that streams in inside the
  // arena opens if V couldn't (locked, sealed, a keypad or a skill check).
  public func OnDoorAttached(door: ref<Door>) {
    if !IsDefined(door) || !this.IsInArena(door.GetWorldPosition()) {
      return;
    }
    let ps = door.GetDevicePS();
    if !IsDefined(ps) || ps.IsOpen() || (!ps.IsLocked() && !ps.IsSealed() && !ps.IsAuthorizationModuleOn()) {
      return;
    }
    let persistency = GameInstance.GetPersistencySystem(door.GetGame());
    for name in [n"AuthorizationDisable", n"ForceUnlock", n"ForceOpen"] {
      let action = ps.GetQuestActionByName(name);
      if IsDefined(action) {
        persistency.QueuePSDeviceEvent(action);
      }
    }
    this.m_doorsOpened += 1;
    RLDebug(s"Arena cleaner: opened a door at \(RLObjectives.Where(door.GetWorldPosition())).");
  }

  // From the Entity/AfterAttach callback: an item dropped on the floor. Its
  // contents are filled in after it attaches, so it's emptied a moment later.
  public func OnDropAttached(drop: ref<gameItemDropObject>) {
    if !this.m_active || !IsDefined(drop) {
      return;
    }
    let entry = new RLPendingDrop();
    entry.drop = drop;
    ArrayPush(this.m_drops, entry);
  }

  private func TickDrops(delta: Float) {
    let keep: array<ref<RLPendingDrop>>;
    for entry in this.m_drops {
      entry.age += delta;
      let drop = entry.drop;
      if !IsDefined(drop) {
        // Gone already.
      } else if entry.age < 0.3 {
        ArrayPush(keep, entry);
      } else if this.IsInArena(drop.GetWorldPosition()) {
        this.EmptyDrop(drop);
      }
    }
    this.m_drops = keep;
  }

  private func EmptyDrop(drop: ref<gameItemDropObject>) {
    let transactions = GameInstance.GetTransactionSystem(drop.GetGame());
    let items: array<wref<gameItemData>>;
    transactions.GetItemList(drop, items);
    for item in items {
      if IsDefined(item) && !item.HasTag(n"Quest") {
        RLDebug("Arena cleaner: cleared a dropped " + TDBID.ToStringDEBUG(ItemID.GetTDBID(item.GetID())) + ".");
        transactions.RemoveItem(drop, item.GetID(), item.GetQuantity());
        this.m_dropsCleared += 1;
      }
    }
  }

  // Called by the arena director every 0.1 s.
  public func Tick(delta: Float) {
    if !this.m_active {
      return;
    }
    if ArraySize(this.m_drops) > 0 {
      this.TickDrops(delta);
    }
    if ArraySize(this.m_pending) == 0 {
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

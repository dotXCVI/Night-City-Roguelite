// -----------------------------------------------------------------------------
// Night City Roguelite - arena walls
// -----------------------------------------------------------------------------
// A ring of wall segments around the arena. Each segment is one static entity
// placed on a chord of the arena circle, carrying:
//   - a box collider (preset "Player Blocker") that physically stops V;
//   - a stack of red NCPD holo-tape strips ("POLICE LINE - DO NOT CROSS"),
//     the game's own hologram from crime scenes.
//
// The strips are hidden until V comes within WallRevealDistance of a segment.
// From there more strips light up the closer V gets, starting at eye level and
// spreading up and down until the segment reads as a solid red barrier. The
// strip band follows V's height, so it's at eye level on slopes and stairs.
//
// The carrier entity is the game's Kabuki holo-tape prop. Its own tape meshes
// are switched off when it initializes and ours are added in their place.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLWallSegment extends IScriptable {
  public let id: EntityID;
  public let start: Vector4;
  public let end: Vector4;
  public let rows: array<wref<IComponent>>;
  public let hum: wref<IComponent>;
  public let resolved: Bool;
  public let shown: Int32;
  public let rowBase: Float;
}

public class RLArenaWalls extends IScriptable {
  private let m_segments: array<ref<RLWallSegment>>;
  private let m_chord: Float;
  private let m_baseZ: Float;
  private let m_callbackRegistered: Bool;
  private let m_initialized: Int32;
  private let m_rowOrder: array<Int32>;

  public static func Tag() -> CName = n"NightCityRoguelite.Wall"
  public static func Template() -> ResRef = r"base\\open_world\\street_stories\\watson\\kabuki\\sts_wat_kab_01\\entities\\sts_wat_kab_01_holotape.ent"
  public static func TapeMesh() -> ResRef = r"base\\fx\\environment\\holograms\\police\\holo_tape.w2mesh"

  // Strip layout. The vanilla tape is 4.25 m x 0.15 m; strips keep that
  // aspect ratio so the lettering isn't stretched.
  public static func RowCount() -> Int32 = 10
  public static func TapeAspect() -> Float = 28.33
  public static func RowSpacing(rowHeight: Float) -> Float = rowHeight * 1.12
  public static func FirstRowHeight() -> Float = 0.2

  public static func Create() -> ref<RLArenaWalls> {
    let walls = new RLArenaWalls();
    // Eye level first, then outwards.
    walls.m_rowOrder = [4, 5, 3, 6, 2, 7, 1, 8, 0, 9];
    return walls;
  }

  public func IsBuilt() -> Bool = ArraySize(this.m_segments) > 0

  public func OnSessionEnd() {
    ArrayClear(this.m_segments);
    this.m_callbackRegistered = false;
  }

  // --- Build / clear -----------------------------------------------------------------

  public func Build(arena: ref<RLArenaDef>) {
    this.Clear();
    if !IsDefined(arena) {
      return;
    }
    let entitySystem = GameInstance.GetStaticEntitySystem();
    if !IsDefined(entitySystem) || !entitySystem.IsReady() {
      RLLog("Static entity system not ready - arena walls fall back to the position check.");
      return;
    }
    if !this.m_callbackRegistered {
      // Session-scoped: removed by the callback system when the session ends.
      GameInstance.GetCallbackSystem()
        .RegisterCallback(n"Entity/Initialize", this, n"OnSegmentInitialize")
        .AddTarget(StaticEntityTarget.Tag(RLArenaWalls.Tag()));
      this.m_callbackRegistered = true;
    }

    let radius = arena.radius;
    let pi = Pi();
    let count = Max(12, CeilF(2.0 * pi * radius / RLConfig.WallSegmentLength()));
    let half = pi / Cast<Float>(count);
    this.m_chord = 2.0 * radius * SinF(half);
    let inner = radius * CosF(half);
    this.m_baseZ = arena.position.Z;
    this.m_initialized = 0;

    let i = 0;
    while i < count {
      let angle = 2.0 * pi * Cast<Float>(i) / Cast<Float>(count);
      let outward = Vector4(CosF(angle), SinF(angle), 0.0, 0.0);
      let tangent = Vector4(-SinF(angle), CosF(angle), 0.0, 0.0);
      let mid = Vector4(
        arena.position.X + outward.X * inner,
        arena.position.Y + outward.Y * inner,
        arena.position.Z,
        1.0
      );
      let halfChord = this.m_chord * 0.5;

      let spec = new StaticEntitySpec();
      spec.templatePath = RLArenaWalls.Template();
      spec.position = mid;
      // Entity forward (+Y) points out of the arena, so the tape faces V.
      spec.orientation = EulerAngles.ToQuat(Vector4.ToRotation(outward));
      spec.attached = true;
      spec.tags = [RLArenaWalls.Tag()];

      let segment = new RLWallSegment();
      segment.start = Vector4(mid.X - tangent.X * halfChord, mid.Y - tangent.Y * halfChord, mid.Z, 1.0);
      segment.end = Vector4(mid.X + tangent.X * halfChord, mid.Y + tangent.Y * halfChord, mid.Z, 1.0);
      segment.id = entitySystem.SpawnEntity(spec);
      segment.rowBase = RLArenaWalls.FirstRowHeight();
      ArrayPush(this.m_segments, segment);
      i += 1;
    }
    RLLog(s"Arena walls: \(count) segments, \(this.m_chord) m each, radius \(radius).");
  }

  public func Clear() {
    let entitySystem = GameInstance.GetStaticEntitySystem();
    if IsDefined(entitySystem) {
      entitySystem.DespawnTagged(RLArenaWalls.Tag());
    }
    ArrayClear(this.m_segments);
  }

  // --- Entity setup ------------------------------------------------------------------

  protected cb func OnSegmentInitialize(event: ref<EntityLifecycleEvent>) {
    let entity = event.GetEntity();
    if !IsDefined(entity) {
      return;
    }
    // Switch off the prop's own tape.
    for component in entity.GetComponents() {
      let mesh = component as MeshComponent;
      if IsDefined(mesh) {
        mesh.isEnabled = false;
      }
    }
    entity.AddComponent(this.MakeCollider());
    let rowHeight = this.RowHeight();
    let row = 0;
    while row < RLArenaWalls.RowCount() {
      entity.AddComponent(this.MakeRow(row, rowHeight));
      row += 1;
    }
    this.m_initialized += 1;
    if this.m_initialized == 1 || this.m_initialized == ArraySize(this.m_segments) {
      RLDebug(s"Arena wall segments set up: \(this.m_initialized)/\(ArraySize(this.m_segments)).");
    }
  }

  private func RowHeight() -> Float = this.m_chord / RLArenaWalls.TapeAspect()

  private func MakeCollider() -> ref<ColliderComponent> {
    let box = new physicsColliderBox();
    // Tall enough for uneven ground: 30 m below to 50 m above the arena centre.
    box.halfExtents = Vector3(this.m_chord * 0.5 + 0.3, 0.25, 40.0);
    box.localToBody = Transform.Create(Vector4(0.0, 0.25, 10.0, 0.0), Quaternion(0.0, 0.0, 0.0, 1.0));
    box.material = n"plexiglass.physmat";

    let filter = new physicsFilterData();
    filter.preset = n"Player Blocker";
    let simulation: SimulationFilter;
    SimulationFilter.SimulationFilter_BuildFromPreset(simulation, n"Player Blocker");
    filter.simulationFilter = simulation;
    filter.queryFilter = QueryFilter.ALL();

    let collider = new ColliderComponent();
    collider.name = n"rl_wall_collider";
    let shapes: array<ref<physicsICollider>>;
    ArrayPush(shapes, box);
    collider.colliders = shapes;
    collider.simulationType = physicsSimulationType.Static;
    collider.filterData = filter;
    collider.startInactive = false;
    collider.isEnabled = true;
    return collider;
  }

  private func MakeRow(row: Int32, rowHeight: Float) -> ref<MeshComponent> {
    let mesh = new MeshComponent();
    mesh.name = StringToName(s"rl_wall_row_\(row)");
    mesh.mesh *= RLArenaWalls.TapeMesh();
    mesh.meshAppearance = n"default_red";
    // The tape mesh is a 10 x 10 m plane; scale it to one strip.
    mesh.visualScale = Vector3(this.m_chord / 10.0, rowHeight / 10.0, 1.0);
    mesh.castShadows = shadowsShadowCastingMode.Never;
    mesh.castLocalShadows = shadowsShadowCastingMode.Never;
    mesh.castRayTracedGlobalShadows = shadowsShadowCastingMode.Never;
    mesh.castRayTracedLocalShadows = shadowsShadowCastingMode.Never;
    mesh.LODMode = entMeshComponentLODMode.AlwaysVisible;
    mesh.isEnabled = false;
    let transform: WorldTransform;
    WorldTransform.SetPosition(transform, Vector4(0.0, 0.0, RLArenaWalls.RowZ(RLArenaWalls.FirstRowHeight(), row, rowHeight), 1.0));
    // Same rotation as the vanilla tape: stand the plane up, lettering facing -Y.
    WorldTransform.SetOrientation(transform, Quaternion(0.70710678, 0.0, 0.0, 0.70710678));
    mesh.localTransform = transform;
    return mesh;
  }

  public static func RowZ(base: Float, row: Int32, rowHeight: Float) -> Float {
    return base + Cast<Float>(row) * RLArenaWalls.RowSpacing(rowHeight);
  }

  // --- Proximity reveal (called by the director's tick) -------------------------------

  public func Update(player: ref<PlayerPuppet>) {
    if ArraySize(this.m_segments) == 0 || !IsDefined(player) {
      return;
    }
    let entitySystem = GameInstance.GetStaticEntitySystem();
    let position = player.GetWorldPosition();
    let flat = Vector4(position.X, position.Y, this.m_baseZ, 1.0);
    // Strips start at V's feet, wherever V is standing.
    let base = position.Z - this.m_baseZ + RLArenaWalls.FirstRowHeight();
    for segment in this.m_segments {
      if segment.resolved || this.Resolve(entitySystem, segment) {
        this.UpdateSegment(segment, flat, base);
      }
    }
  }

  private func UpdateSegment(segment: ref<RLWallSegment>, flat: Vector4, base: Float) {
    let reveal = RLConfig.WallRevealDistance();
    let nearest = Vector4.NearestPointOnEdge(flat, segment.start, segment.end);
    let distance = Vector4.Distance2D(flat, nearest);
    let want = 0;
    if distance < reveal {
      // 1 strip at the edge of the reveal range, all of them at arm's length.
      let closeness = (reveal - distance) / MaxF(reveal - 1.5, 0.5);
      want = Clamp(CeilF(closeness * Cast<Float>(RLArenaWalls.RowCount())), 1, RLArenaWalls.RowCount());
    }
    let moved = want > 0 && AbsF(base - segment.rowBase) > 0.25;
    if want == segment.shown && !moved {
      return;
    }
    if moved {
      segment.rowBase = base;
    }
    let rowHeight = this.RowHeight();
    let rank = 0;
    for row in this.m_rowOrder {
      if row < ArraySize(segment.rows) {
        let component = segment.rows[row];
        if IsDefined(component) {
          let placed = component as IPlacedComponent;
          if moved && IsDefined(placed) {
            placed.SetLocalPosition(Vector4(0.0, 0.0, RLArenaWalls.RowZ(segment.rowBase, row, rowHeight), 1.0));
          }
          component.Toggle(rank < want);
        }
      }
      rank += 1;
    }
    // The tape's hologram hum only plays on lit segments.
    let lit = want > 0;
    let wasLit = segment.shown > 0;
    if IsDefined(segment.hum) && !Equals(lit, wasLit) {
      segment.hum.Toggle(lit);
    }
    segment.shown = want;
  }

  // Finds the segment's components once its entity is in the world.
  private func Resolve(entitySystem: ref<StaticEntitySystem>, segment: ref<RLWallSegment>) -> Bool {
    if !IsDefined(entitySystem) || !entitySystem.IsSpawned(segment.id) {
      return false;
    }
    let entity = entitySystem.GetEntity(segment.id);
    if !IsDefined(entity) {
      return false;
    }
    let found: array<wref<IComponent>>;
    let row = 0;
    while row < RLArenaWalls.RowCount() {
      ArrayPush(found, null);
      row += 1;
    }
    let any = false;
    for component in entity.GetComponents() {
      let name = NameToString(component.GetName());
      if StrBeginsWith(name, "rl_wall_row_") {
        let index = StringToInt(StrAfterFirst(name, "rl_wall_row_"));
        if index >= 0 && index < RLArenaWalls.RowCount() {
          found[index] = component;
          any = true;
        }
      } else {
        if Equals(component.GetName(), n"gameaudioSound8196") {
          segment.hum = component;
        }
      }
    }
    if !any {
      return false;
    }
    segment.rows = found;
    segment.resolved = true;
    // Start dark and silent.
    segment.shown = -1;
    if IsDefined(segment.hum) {
      segment.hum.Toggle(false);
    }
    return true;
  }
}

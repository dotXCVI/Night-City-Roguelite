// -----------------------------------------------------------------------------
// Night City Roguelite - apartment devices
// -----------------------------------------------------------------------------
// Two of the apartment's own devices are taken over for roguelite characters:
//
//   Front door  - sealed the way quests seal doors (QuestForceSeal), so the
//                 apartment is a real locked room. It's done when the door
//                 streams in, whenever V is sent home and every second while
//                 V is home; anything that would open, unlock or unseal it
//                 (V's own quests do, on approach) is ignored. The sealed
//                 state is saved with the character. The soft lock in
//                 ApartmentHub.reds stays on as a safety net.
//   Desk computer - its only prompt becomes "Roguelite Terminal" and using it
//                 opens the terminal (F7 still works anywhere at home).
//   Armory      - the weapon room at the back ("v_secret_room"). Its door is
//                 unlocked and opened, and its stash (a quest node from
//                 quest_5eb84e72f3942283, "pr_v_room_stash") becomes "Gear"
//                 and opens the kit picker (UI/ArmoryPopup.reds). During a run
//                 the stash stays shut (stashing gear between runs would carry
//                 it over). If the stash isn't there on some character, F7 in
//                 the room does the same and the HUD says so.
//
// All are identified by their world node IDs from the 2.5 sector data
// (exterior_-22_19_1_0.streamingsector), with their positions as a fallback.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLHomeDevices {
  public static func FrontDoorID() -> EntityID = EntityID.FromHash(6132383399567759307ul)
  public static func FrontDoorPosition() -> Vector4 = Vector4(-1388.562, 1271.937, 123.0695, 1.0)
  public static func ComputerID() -> EntityID = EntityID.FromHash(17553053729736241346ul)
  public static func ComputerPosition() -> Vector4 = Vector4(-1386.929, 1273.537, 124.4035, 1.0)
  public static func TerminalInteraction() -> TweakDBID = t"NCRoguelite.TerminalInteraction"
  public static func ArmoryInteraction() -> TweakDBID = t"NCRoguelite.ArmoryInteraction"
  public static func StashID() -> EntityID = EntityID.FromHash(16570246047455160070ul)
  public static func ArmoryDoorID() -> EntityID = EntityID.FromHash(6373481765164401677ul)
  public static func ArmoryDoorPosition() -> Vector4 = Vector4(-1382.88, 1266.31, 123.25, 1.0)
  // The weapon room and its doorway (the weapon displays line its walls).
  public static func ArmoryMin() -> Vector4 = Vector4(-1384.4, 1261.7, 121.8, 1.0)
  public static func ArmoryMax() -> Vector4 = Vector4(-1379.2, 1267.4, 126.8, 1.0)

  public static func InArmory(position: Vector4) -> Bool {
    return RLApartmentHub.InBox(position, RLHomeDevices.ArmoryMin(), RLHomeDevices.ArmoryMax());
  }

  // --- Front door ------------------------------------------------------------------------

  public static func ShouldSealDoor(game: GameInstance) -> Bool {
    let system = RogueliteSystem.Get(game);
    return IsDefined(system) && system.IsRoguelitePlaythrough() && RLConfig.UseApartmentHub();
  }

  // Seals the front door if its state is loaded; true when it is (or already
  // was) sealed.
  public static func SealFrontDoor(game: GameInstance, opt quiet: Bool) -> Bool {
    let psID = CreatePersistentID(RLHomeDevices.FrontDoorID(), n"controller");
    let door = GameInstance.GetPersistencySystem(game).GetConstAccessToPSObject(psID, n"DoorControllerPS") as DoorControllerPS;
    if !IsDefined(door) {
      let entity = GameInstance.FindEntityByID(game, RLHomeDevices.FrontDoorID()) as Door;
      if IsDefined(entity) {
        door = entity.GetDevicePS();
      }
    }
    if !IsDefined(door) {
      if !quiet {
        RLDebug("Front door not loaded yet - it is sealed when it streams in.");
      }
      return false;
    }
    if door.RL_Seal() {
      RLLog("Front door sealed.");
    }
    return true;
  }

  public static func OnDoorAttached(door: ref<Door>) {
    let game = door.GetGame();
    if door.GetEntityID() == RLHomeDevices.ArmoryDoorID() || Vector4.Distance(door.GetWorldPosition(), RLHomeDevices.ArmoryDoorPosition()) < 0.6 {
      if RLHomeDevices.ShouldSealDoor(game) {
        RLHomeDevices.OpenArmoryDoor(door.GetDevicePS());
      }
      return;
    }
    let byID = door.GetEntityID() == RLHomeDevices.FrontDoorID();
    if !byID && Vector4.Distance(door.GetWorldPosition(), RLHomeDevices.FrontDoorPosition()) > 0.6 {
      return;
    }
    if !RLHomeDevices.ShouldSealDoor(game) {
      return;
    }
    if !byID {
      RLLog("Front door found by position, id " + EntityID.ToDebugStringDecimal(door.GetEntityID()) + ".");
    }
    let ps = door.GetDevicePS();
    if IsDefined(ps) && ps.RL_Seal() {
      RLLog("Front door sealed.");
    }
  }

  // The front door, while the mod keeps it sealed.
  public static func IsHomeDoor(ps: ref<DoorControllerPS>) -> Bool {
    return PersistentID.ExtractEntityID(ps.GetID()) == RLHomeDevices.FrontDoorID()
      && RLHomeDevices.ShouldSealDoor(ps.GetGameInstance());
  }

  // Logged only for quest-side requests (V bumping the door would flood the log).
  public static func Refuse(ps: ref<DoorControllerPS>, const what: String) {
    if StrBeginsWith(what, "quest") {
      RLDebug("Front door: ignored " + what + ".");
    }
    ps.RL_Seal();
  }

  // --- Desk computer -----------------------------------------------------------------------

  public static func IsHubComputer(ps: ref<ScriptableDeviceComponentPS>) -> Bool {
    let game = ps.GetGameInstance();
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) || !system.IsHomeTerminalActive() {
      return false;
    }
    let id = PersistentID.ExtractEntityID(ps.GetID());
    if id == RLHomeDevices.ComputerID() {
      return true;
    }
    let entity = GameInstance.FindEntityByID(game, id) as GameObject;
    return IsDefined(entity) && Vector4.Distance(entity.GetWorldPosition(), RLHomeDevices.ComputerPosition()) < 0.6;
  }

  public static func UseComputer(game: GameInstance) {
    let system = RogueliteSystem.Get(game);
    if IsDefined(system) {
      system.OnTerminalKey();
    }
  }

  // --- Armory ------------------------------------------------------------------------------

  // The weapon room's door opens like it would once the story has shown it to
  // V; it stays open.
  public static func OpenArmoryDoor(ps: ref<DoorControllerPS>) -> Bool {
    if !IsDefined(ps) {
      return false;
    }
    let locked = ps.IsLocked();
    let sealed = ps.IsSealed();
    if ps.RL_OpenUp() {
      RLLog(s"Armory door opened (was locked \(locked), sealed \(sealed)).");
      return true;
    }
    return false;
  }

  // Called while V is home (the door may stream in late); true when the door
  // had to be opened.
  public static func KeepArmoryOpen(game: GameInstance) -> Bool {
    let psID = CreatePersistentID(RLHomeDevices.ArmoryDoorID(), n"controller");
    let door = GameInstance.GetPersistencySystem(game).GetConstAccessToPSObject(psID, n"DoorControllerPS") as DoorControllerPS;
    if !IsDefined(door) {
      let entity = GameInstance.FindEntityByID(game, RLHomeDevices.ArmoryDoorID()) as Door;
      if IsDefined(entity) {
        door = entity.GetDevicePS();
      }
    }
    return RLHomeDevices.OpenArmoryDoor(door);
  }

  public static func IsStashLoaded(game: GameInstance) -> Bool = IsDefined(GameInstance.FindEntityByID(game, RLHomeDevices.StashID()))

  // Open, or not there to be shut (not a scripted door on this character).
  public static func IsArmoryDoorOpen(game: GameInstance) -> Bool {
    let door = GameInstance.FindEntityByID(game, RLHomeDevices.ArmoryDoorID()) as Door;
    return !IsDefined(door) || !IsDefined(door.GetDevicePS()) || door.GetDevicePS().IsOpen();
  }

  // For the log: what the armory looks like on this character.
  public static func Report(game: GameInstance) {
    let door = GameInstance.FindEntityByID(game, RLHomeDevices.ArmoryDoorID()) as Door;
    let doorState = "not loaded";
    if IsDefined(door) && IsDefined(door.GetDevicePS()) {
      let ps = door.GetDevicePS();
      doorState = s"open \(ps.IsOpen()), locked \(ps.IsLocked()), sealed \(ps.IsSealed())";
    }
    RLLog("Armory: stash " + (RLHomeDevices.IsStashLoaded(game) ? "loaded" : "NOT loaded (F7 in the room instead)") + ", door " + doorState + ".");
  }

  public static func IsArmoryStash(ps: ref<ScriptableDeviceComponentPS>) -> Bool {
    let game = ps.GetGameInstance();
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) || !system.IsHomeTerminalActive() {
      return false;
    }
    let id = PersistentID.ExtractEntityID(ps.GetID());
    if id == RLHomeDevices.StashID() {
      return true;
    }
    let entity = GameInstance.FindEntityByID(game, id) as GameObject;
    return IsDefined(entity) && RLHomeDevices.InArmory(entity.GetWorldPosition());
  }

  public static func UseStash(game: GameInstance) {
    let system = RogueliteSystem.Get(game);
    if IsDefined(system) {
      system.OnArmoryUsed();
    }
  }
}

// Unseals, unlocks and opens; true when anything had to change.
@addMethod(DoorControllerPS)
public final func RL_OpenUp() -> Bool {
  let changed = false;
  if this.IsSealed() {
    this.GetPersistencySystem().QueuePSEvent(this.GetID(), this.GetClassName(), this.ActionQuestForceUnseal());
    changed = true;
  }
  if this.IsLocked() {
    this.GetPersistencySystem().QueuePSEvent(this.GetID(), this.GetClassName(), this.ActionQuestForceUnlock());
    changed = true;
  }
  if !this.IsOpen() {
    this.GetPersistencySystem().QueuePSEvent(this.GetID(), this.GetClassName(), this.ActionQuestForceOpen());
    changed = true;
  }
  return changed;
}

@addMethod(DoorControllerPS)
public final func RL_Seal() -> Bool {
  if this.IsSealed() {
    return false;
  }
  this.GetPersistencySystem().QueuePSEvent(this.GetID(), this.GetClassName(), this.ActionQuestForceSeal());
  return true;
}

// Nothing opens, unlocks or unseals the front door while it is the hub's.
@wrapMethod(DoorControllerPS)
public final func OnToggleOpen(evt: ref<ToggleOpen>) -> EntityNotificationType {
  if !this.IsOpen() && RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "open");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnSetOpened(evt: ref<SetOpened>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "set opened");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnForceOpen(evt: ref<ForceOpen>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "force open");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnQuestForceOpen(evt: ref<QuestForceOpen>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "quest open");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnQuestForceUnlock(evt: ref<QuestForceUnlock>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "quest unlock");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnQuestForceUnseal(evt: ref<QuestForceUnseal>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "quest unseal");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnToggleSeal(evt: ref<ToggleSeal>) -> EntityNotificationType {
  if this.IsSealed() && RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "unseal");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnToggleLock(evt: ref<ToggleLock>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "lock toggle");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(DoorControllerPS)
public final func OnQuickHackToggleOpen(evt: ref<QuickHackToggleOpen>) -> EntityNotificationType {
  if RLHomeDevices.IsHomeDoor(this) {
    RLHomeDevices.Refuse(this, "quickhack open");
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

@wrapMethod(Door)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  RLHomeDevices.OnDoorAttached(this);
  return result;
}

// While the computer is the terminal, its only prompt is "Roguelite Terminal".
@wrapMethod(ComputerControllerPS)
public func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  if Equals(context.requestType, gamedeviceRequestType.Direct) && RLHomeDevices.IsHubComputer(this)
    && IsDefined(TweakDBInterface.GetInteractionBaseRecord(RLHomeDevices.TerminalInteraction())) {
    ArrayClear(actions);
    let action = this.ActionToggleZoomInteraction();
    action.OverrideInteractionRecord(RLHomeDevices.TerminalInteraction(), RLHomeDevices.TerminalInteraction());
    ArrayPush(actions, action);
    return true;
  }
  return wrappedMethod(actions, context);
}

// Using it opens the terminal instead of zooming in on the screen.
@wrapMethod(ComputerControllerPS)
public func OnToggleZoomInteraction(evt: ref<ToggleZoomInteraction>) -> EntityNotificationType {
  if RLHomeDevices.IsHubComputer(this) {
    RLHomeDevices.UseComputer(this.GetGameInstance());
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

// The armory's stash opens the kit picker instead.
@wrapMethod(StashControllerPS)
public func GetActions(out outActions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  if Equals(context.requestType, gamedeviceRequestType.Direct) && RLHomeDevices.IsArmoryStash(this)
    && IsDefined(TweakDBInterface.GetInteractionBaseRecord(RLHomeDevices.ArmoryInteraction())) {
    ArrayClear(outActions);
    let action = this.ActionOpenStash();
    action.OverrideInteractionRecord(RLHomeDevices.ArmoryInteraction(), RLHomeDevices.ArmoryInteraction());
    ArrayPush(outActions, action);
    return true;
  }
  return wrappedMethod(outActions, context);
}

@wrapMethod(StashControllerPS)
private final func OnOpenStash(evt: ref<OpenStash>) -> EntityNotificationType {
  if RLHomeDevices.IsArmoryStash(this) {
    RLHomeDevices.UseStash(this.GetGameInstance());
    return EntityNotificationType.DoNotNotifyEntity;
  }
  return wrappedMethod(evt);
}

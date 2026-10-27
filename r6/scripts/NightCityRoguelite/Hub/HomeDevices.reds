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
//   Armory      - the weapon room at the back. Any stash in it becomes "Gear"
//                 and opens the kit picker (UI/ArmoryPopup.reds); F7 does the
//                 same while V stands in the room or its doorway. During a run
//                 the stash stays shut (stashing gear between runs would carry
//                 it over).
//
// Both are identified by their world node IDs from the 2.5 sector data
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

  // --- Armory stash ------------------------------------------------------------------------

  public static func IsArmoryStash(ps: ref<ScriptableDeviceComponentPS>) -> Bool {
    let game = ps.GetGameInstance();
    let system = RogueliteSystem.Get(game);
    if !IsDefined(system) || !system.IsHomeTerminalActive() {
      return false;
    }
    let entity = GameInstance.FindEntityByID(game, PersistentID.ExtractEntityID(ps.GetID())) as GameObject;
    return IsDefined(entity) && RLHomeDevices.InArmory(entity.GetWorldPosition());
  }

  public static func UseStash(game: GameInstance) {
    let system = RogueliteSystem.Get(game);
    if IsDefined(system) {
      system.OnArmoryUsed();
    }
  }
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

// -----------------------------------------------------------------------------
// Night City Roguelite - apartment devices
// -----------------------------------------------------------------------------
// Two of the apartment's own devices are taken over for roguelite characters:
//
//   Front door  - sealed the way quests seal doors (QuestForceSeal), so the
//                 apartment is a real locked room. It's done when the door
//                 streams in and again whenever V is sent home; the sealed
//                 state is saved with the character. The soft lock in
//                 ApartmentHub.reds stays on as a safety net.
//   Desk computer - its only prompt becomes "Roguelite Terminal" and using it
//                 opens the terminal (F7 still works anywhere at home).
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

  // --- Front door ------------------------------------------------------------------------

  public static func ShouldSealDoor(game: GameInstance) -> Bool {
    let system = RogueliteSystem.Get(game);
    return IsDefined(system) && system.IsRoguelitePlaythrough() && RLConfig.UseApartmentHub();
  }

  // Seals the front door if its state is loaded; true when it is (or already
  // was) sealed.
  public static func SealFrontDoor(game: GameInstance) -> Bool {
    let psID = CreatePersistentID(RLHomeDevices.FrontDoorID(), n"controller");
    let door = GameInstance.GetPersistencySystem(game).GetConstAccessToPSObject(psID, n"DoorControllerPS") as DoorControllerPS;
    if !IsDefined(door) {
      let entity = GameInstance.FindEntityByID(game, RLHomeDevices.FrontDoorID()) as Door;
      if IsDefined(entity) {
        door = entity.GetDevicePS();
      }
    }
    if !IsDefined(door) {
      RLDebug("Front door not loaded yet - it is sealed when it streams in.");
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
}

@addMethod(DoorControllerPS)
public final func RL_Seal() -> Bool {
  if this.IsSealed() {
    return false;
  }
  this.GetPersistencySystem().QueuePSEvent(this.GetID(), this.GetClassName(), this.ActionQuestForceSeal());
  return true;
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

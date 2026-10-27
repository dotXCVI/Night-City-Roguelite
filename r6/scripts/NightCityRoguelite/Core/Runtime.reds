// -----------------------------------------------------------------------------
// Night City Roguelite - runtime helpers
// -----------------------------------------------------------------------------
// Logging, on-screen messages and timers shared by every system.
//
// Timers: RLDelay(game, target, action, seconds) calls target.OnDelayed(action)
// later through the game's DelaySystem. Targets are RogueliteSystem or any
// RLDelayTarget subclass.
// -----------------------------------------------------------------------------

module NightCityRoguelite

// --- Logging ---------------------------------------------------------------------

public func RLLog(const msg: String) {
  FTLog("[NightCityRoguelite] " + msg);
  RLKeepLog(msg);
}

public func RLDebug(const msg: String) {
  if RLConfig.VerboseLogging() {
    FTLog("[NightCityRoguelite][debug] " + msg);
    RLKeepLog("(debug) " + msg);
  }
}

// FTLog output isn't written anywhere in release builds, so every line is
// also kept in the service's persistent log.
public func RLKeepLog(const msg: String) {
  let service = RogueliteService.Get();
  if IsDefined(service) {
    service.AppendLog(msg);
  }
}

// --- On-screen messages ----------------------------------------------------------

public func RLNotify(game: GameInstance, const msg: String, opt duration: Float) {
  let message: SimpleScreenMessage;
  message.isShown = true;
  message.isInstant = true;
  message.duration = duration > 0.0 ? duration : 5.0;
  message.message = msg;
  message.type = SimpleMessageType.Undefined;
  GameInstance.GetBlackboardSystem(game)
    .Get(GetAllBlackboardDefs().UI_Notifications)
    .SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(message), true);
}

// --- Timers ----------------------------------------------------------------------

public abstract class RLDelayTarget extends IScriptable {
  public func OnDelayed(action: CName) {}
}

public class RLDelayCallback extends DelayCallback {
  private let m_target: wref<IScriptable>;
  private let m_action: CName;

  public static func Create(target: ref<IScriptable>, action: CName) -> ref<RLDelayCallback> {
    let callback = new RLDelayCallback();
    callback.m_target = target;
    callback.m_action = action;
    return callback;
  }

  public func Call() {
    let system = this.m_target as RogueliteSystem;
    if IsDefined(system) {
      system.OnDelayed(this.m_action);
      return;
    }
    let target = this.m_target as RLDelayTarget;
    if IsDefined(target) {
      target.OnDelayed(this.m_action);
    }
  }
}

public func RLDelay(game: GameInstance, target: ref<IScriptable>, action: CName, seconds: Float) -> DelayID {
  return GameInstance.GetDelaySystem(game).DelayCallback(RLDelayCallback.Create(target, action), seconds, false);
}

public func RLCancel(game: GameInstance, id: DelayID) {
  GameInstance.GetDelaySystem(game).CancelCallback(id);
}

// -----------------------------------------------------------------------------
// Night City Roguelite - death guard
// -----------------------------------------------------------------------------
// During a run V gets the Immortal god mode, so health never reaches zero and
// the vanilla death/reload flow never starts. A health stat-pool listener
// turns "health dropped to the floor" into a flatline event for the run system.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLHealthListener extends CustomValueStatPoolsListener {
  public let guard: wref<RLDeathGuard>;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) {
    if IsDefined(this.guard) {
      this.guard.OnHealthChanged(oldValue, newValue);
    }
  }
}

public class RLDeathGuard extends IScriptable {
  private let m_system: wref<RogueliteSystem>;
  private let m_player: wref<PlayerPuppet>;
  private let m_listener: ref<RLHealthListener>;
  private let m_armed: Bool;
  private let m_triggered: Bool;

  public static func Create(system: ref<RogueliteSystem>) -> ref<RLDeathGuard> {
    let guard = new RLDeathGuard();
    guard.m_system = system;
    return guard;
  }

  public func Arm(player: ref<PlayerPuppet>) {
    if this.m_armed {
      this.Disarm();
    }
    this.m_player = player;
    this.m_triggered = false;
    let game = player.GetGame();
    GameInstance.GetGodModeSystem(game).AddGodMode(player.GetEntityID(), gameGodModeType.Immortal, n"NightCityRoguelite");
    this.m_listener = new RLHealthListener();
    this.m_listener.guard = this;
    GameInstance.GetStatPoolsSystem(game).RequestRegisteringListener(
      Cast<StatsObjectID>(player.GetEntityID()),
      gamedataStatPoolType.Health,
      this.m_listener
    );
    this.m_armed = true;
    RLDebug("Death guard armed.");
  }

  public func Disarm() {
    if !this.m_armed {
      return;
    }
    this.m_armed = false;
    let player = this.m_player;
    if IsDefined(player) {
      let game = player.GetGame();
      GameInstance.GetGodModeSystem(game).RemoveGodMode(player.GetEntityID(), gameGodModeType.Immortal, n"NightCityRoguelite");
      if IsDefined(this.m_listener) {
        GameInstance.GetStatPoolsSystem(game).RequestUnregisteringListener(
          Cast<StatsObjectID>(player.GetEntityID()),
          gamedataStatPoolType.Health,
          this.m_listener
        );
      }
    }
    this.m_listener = null;
    RLDebug("Death guard disarmed.");
  }

  // Allows the run to continue after a Second Wind save.
  public func Rearm() {
    this.m_triggered = false;
  }

  public func OnHealthChanged(oldValue: Float, newValue: Float) {
    if !this.m_armed {
      return;
    }
    if IsDefined(this.m_system) {
      this.m_system.OnHealthChanged(oldValue, newValue);
    }
    if this.m_triggered {
      return;
    }
    if newValue <= RLConfig.FlatlineThresholdPercent() && newValue < oldValue {
      this.m_triggered = true;
      if IsDefined(this.m_system) {
        this.m_system.OnLethalDamage();
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - pacing director
// -----------------------------------------------------------------------------
// After Left 4 Dead's AI Director: a hidden intensity score follows how hard
// the fight is hitting V, and the director paces around it.
//
//   Intensity  rises with damage taken (proportional), a dip below 25% Health
//              and using a health item; decays every second.
//   Relax      a wave cleared at high intensity buys a longer breather and a
//              smaller next wave (L4D's peak fade / relax).
//   Pressure   after each arena, the fight's peak intensity nudges a pressure
//              value (-1..1) towards a sweet spot: easy fights raise it, close
//              calls lower it. Pressure scales the next fight's size (+-15%),
//              its elite share and the damage V takes (+-8%). Boss units are
//              never scaled. Pressure resets with every run.
//
// Every arena logs a telemetry line (damage taken, lowest Health, heals, time,
// peak intensity, new pressure) for tuning.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLPacing extends RLDelayTarget {
  private let m_pressure: Float;
  private let m_active: Bool;
  private let m_intensity: Float;
  private let m_peak: Float;
  private let m_damage: Float;
  private let m_lowest: Float;
  private let m_heals: Int32;
  private let m_kills: Int32;
  private let m_seconds: Float;
  private let m_inDip: Bool;
  private let m_tickID: DelayID;

  public static func SweetSpot() -> Float = 0.5
  public static func RelaxThreshold() -> Float = 0.75

  public func GetPressure() -> Float = this.m_pressure

  // Multiplier on damage V takes from pressure.
  public func DamageScale() -> Float = 1.0 + 0.08 * this.m_pressure

  public func ResetRun() {
    this.Stop();
    this.m_pressure = 0.0;
  }

  public func BeginArena() {
    this.Stop();
    this.m_active = true;
    this.m_intensity = 0.0;
    this.m_peak = 0.0;
    this.m_damage = 0.0;
    this.m_lowest = 100.0;
    this.m_heals = 0;
    this.m_kills = 0;
    this.m_seconds = 0.0;
    this.m_inDip = false;
    this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
  }

  // Health in percent of max.
  public func OnHealthChanged(oldValue: Float, newValue: Float) {
    if !this.m_active {
      return;
    }
    if newValue < oldValue {
      let lost = oldValue - newValue;
      this.m_damage += lost;
      this.AddIntensity(lost / 100.0 * 1.2);
      if newValue < 25.0 && !this.m_inDip {
        this.m_inDip = true;
        this.AddIntensity(0.2);
      }
    } else if newValue - oldValue >= 8.0 {
      // A health item (regen comes in small steps).
      this.m_heals += 1;
      this.AddIntensity(0.1);
    }
    if newValue >= 50.0 {
      this.m_inDip = false;
    }
    this.m_lowest = MinF(this.m_lowest, newValue);
  }

  public func OnKill() {
    if this.m_active {
      this.m_kills += 1;
    }
  }

  // A wave was cleared: true when V needs a breather before the next one.
  public func WantsRelax() -> Bool {
    return this.m_active && this.m_intensity >= RLPacing.RelaxThreshold();
  }

  // The arena is over (cleared or lost): update pressure and log the fight.
  public func EndArena(cleared: Bool, run: ref<RLRunState>) {
    if !this.m_active {
      return;
    }
    this.Stop();
    let delta = ClampF((RLPacing.SweetSpot() - this.m_peak) * 0.8, -0.4, 0.3);
    if !cleared {
      delta = -0.4;
    }
    this.m_pressure = ClampF(this.m_pressure * 0.8 + delta, -1.0, 1.0);
    let floor = IsDefined(run) ? run.Depth() : 0;
    let threat = IsDefined(run) ? run.Threat() : 0;
    RLLog(s"Pacing: floor \(floor) threat \(threat) \(cleared ? "cleared" : "lost") in \(RoundF(this.m_seconds))s, "
      + s"damage taken \(RoundF(this.m_damage))%, lowest \(RoundF(this.m_lowest))%, heals \(this.m_heals), kills \(this.m_kills), "
      + s"peak intensity \(this.m_peak) -> pressure \(this.m_pressure).");
  }

  public func Stop() {
    if this.m_active {
      RLCancel(GetGameInstance(), this.m_tickID);
    }
    this.m_active = false;
  }

  public func OnDelayed(action: CName) {
    if !Equals(action, n"tick") || !this.m_active {
      return;
    }
    this.m_seconds += 1.0;
    this.m_intensity = MaxF(0.0, this.m_intensity - 0.03);
    this.m_tickID = RLDelay(GetGameInstance(), this, n"tick", 1.0);
  }

  private func AddIntensity(amount: Float) {
    this.m_intensity += amount;
    this.m_peak = MaxF(this.m_peak, this.m_intensity);
  }
}

// -----------------------------------------------------------------------------
// Night City Roguelite - time of day and weather
// -----------------------------------------------------------------------------
// Every arena rolls its own time and weather while the screen is black on the
// way in (RogueliteSystem.ArriveInArena), so no two fights look alike:
//
//   Light     mostly daytime, clear to cloudy skies
//   Standard  any time of day, now and then fog or rain
//   Heavy /   mostly night or dusk, rain, fog, heavy clouds or smog;
//   elite     sandstorms out in the Badlands
//   Boss      the most dramatic: night, storms (toxic rain, sandstorm), fog
//
// Weather is forced through Codeware's WeatherSystem.SetWeather (the
// standard "24h_weather_*" states) and released at the end of the run.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLAtmosphere {
  public static func Apply(game: GameInstance, arena: ref<RLArenaDef>, run: ref<RLRunState>) {
    let badlands = Equals(arena.area, "Badlands");
    let mood = RLAtmosphere.Mood(run);
    let hour = RLAtmosphere.PickHour(mood);
    GameInstance.GetTimeSystem(game).SetGameTimeByHMS(hour, RandRange(0, 60), 0);
    let weather = RLAtmosphere.PickWeather(mood, badlands);
    let applied = GameInstance.GetWeatherSystem(game).SetWeather(weather, 0.0, 9u);
    RLLog(s"Atmosphere: \(hour):00, \(NameToString(weather))" + (applied ? "." : " (not applied)."));
  }

  // Back to the world's own cycle (end of the run).
  public static func Reset(game: GameInstance) {
    GameInstance.GetWeatherSystem(game).ResetWeather(true);
  }

  // 0 light, 1 standard, 2 heavy or elite, 3 boss.
  private static func Mood(run: ref<RLRunState>) -> Int32 {
    if run.IsBossFloor() {
      return 3;
    }
    if run.IsEliteFloor() || run.Threat() >= 3 {
      return 2;
    }
    return run.Threat() <= 1 ? 0 : 1;
  }

  private static func PickHour(mood: Int32) -> Int32 {
    let day = RandRange(9, 17);
    let dusk = RandF() < 0.5 ? RandRange(5, 7) : RandRange(18, 21);
    let night = RandF() < 0.5 ? RandRange(22, 24) : RandRange(0, 4);
    let roll = RandF();
    switch mood {
      case 0: return roll < 0.6 ? day : (roll < 0.85 ? dusk : night);
      case 1: return roll < 0.4 ? day : (roll < 0.7 ? dusk : night);
      case 2: return roll < 0.2 ? day : (roll < 0.5 ? dusk : night);
    }
    return roll < 0.25 ? dusk : night;
  }

  private static func PickWeather(mood: Int32, badlands: Bool) -> CName {
    let options: array<CName>;
    switch mood {
      case 0:
        options = [n"24h_weather_sunny", n"24h_weather_sunny", n"24h_weather_light_clouds", n"24h_weather_cloudy"];
        break;
      case 1:
        options = [n"24h_weather_sunny", n"24h_weather_light_clouds", n"24h_weather_cloudy", n"24h_weather_heavy_clouds", n"24h_weather_fog", n"24h_weather_rain"];
        break;
      case 2:
        options = [n"24h_weather_rain", n"24h_weather_fog", n"24h_weather_heavy_clouds", n"24h_weather_pollution"];
        if badlands {
          ArrayPush(options, n"24h_weather_sandstorm");
        }
        break;
      default:
        options = [n"24h_weather_rain", n"24h_weather_toxic_rain", n"24h_weather_fog"];
        if badlands {
          ArrayPush(options, n"24h_weather_sandstorm");
          ArrayPush(options, n"24h_weather_sandstorm");
        }
    }
    return options[RandRange(0, ArraySize(options))];
  }
}

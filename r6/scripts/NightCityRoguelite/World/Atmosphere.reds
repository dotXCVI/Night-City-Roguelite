// -----------------------------------------------------------------------------
// Night City Roguelite - time of day and weather
// -----------------------------------------------------------------------------
// Every arena gets a look while the screen is black on the way in
// (RogueliteSystem.ArriveInArena): a time of day and a weather that read at a
// glance together. Random hours with random weather mostly landed on clouds
// at night, which look like a clear night - the weather was there and no one
// could see it. So there are eight looks instead:
//
//   HIGH NOON     midday sun
//   GOLDEN HOUR   low sun, light clouds
//   CLEAR NIGHT   stars and neon
//   FOG BANK      dawn fog
//   NEON RAIN     night rain
//   SMOG          afternoon pollution haze
//   TOXIC STORM   acid rain after dark
//   SANDSTORM     the Badlands only
//
// The mood picks from them: calm in Act 1, tenser later, the storms for hot
// doors, elites and bosses. The same look never comes twice in a row.
//
// Weather is forced through Codeware's WeatherSystem.SetWeather and released
// at the end of the run. A few seconds after arriving, Check reads back what
// the game is actually showing (and the rain), logs it, and asks again if
// something overrode it. The first check of a session also logs every weather
// state the game knows, so a bad name can't fail quietly.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLAtmosphere {
  public static func Looks() -> array<CName> {
    return [n"HighNoon", n"GoldenHour", n"ClearNight", n"FogBank", n"NeonRain", n"Smog", n"ToxicStorm", n"Sandstorm"];
  }

  // Sets the arena's look; returns the weather asked for (for Check).
  public static func Apply(game: GameInstance, arena: ref<RLArenaDef>, run: ref<RLRunState>, last: CName) -> CName {
    let look = RLAtmosphere.PickLook(run, Equals(arena.area, "Badlands"), last);
    let hour = RLAtmosphere.Hour(look);
    let weather = RLAtmosphere.Weather(look);
    GameInstance.GetTimeSystem(game).SetGameTimeByHMS(hour, RandRange(0, 60), 0);
    let applied = GameInstance.GetWeatherSystem(game).SetWeather(weather, 0.0, 9u);
    RLLog(s"Atmosphere: \(NameToString(look)), \(hour):00, \(NameToString(weather))" + (applied ? "." : " (not applied)."));
    return look;
  }

  // What the game is actually showing a few seconds in; the weather is asked
  // for again when it isn't the look's.
  public static func Check(game: GameInstance, look: CName, listStates: Bool) {
    let weatherSystem = GameInstance.GetWeatherSystem(game);
    let wanted = RLAtmosphere.Weather(look);
    let state = weatherSystem.GetWeatherState();
    let showing = IsDefined(state) ? state.name : n"";
    RLLog(s"Weather check: wanted \(NameToString(wanted)), showing \(NameToString(showing)), rain \(weatherSystem.GetRainIntensity()).");
    if listStates {
      let environment = weatherSystem.GetEnvironmentDefinition();
      if IsDefined(environment) {
        let names = "";
        for known in environment.weatherStates {
          if IsDefined(known) {
            names += (StrLen(names) > 0 ? ", " : "") + NameToString(known.name);
          }
        }
        RLLog("Weather states: " + names + ".");
      }
    }
    if NotEquals(showing, wanted) {
      let again = weatherSystem.SetWeather(wanted, 2.0, 10u);
      RLLog("Weather didn't take; asked again" + (again ? "." : " (refused)."));
    }
  }

  // Back to the world's own cycle (end of the run).
  public static func Reset(game: GameInstance) {
    GameInstance.GetWeatherSystem(game).ResetWeather(true);
  }

  // Calm, tense or dramatic, never the last look again.
  private static func PickLook(run: ref<RLRunState>, badlands: Bool, last: CName) -> CName {
    let options: array<CName>;
    if run.IsBossFloor() || run.IsEliteFloor() || run.IsHotFight() {
      options = [n"NeonRain", n"ToxicStorm", n"FogBank", n"Smog"];
      if badlands {
        ArrayPush(options, n"Sandstorm");
      }
    } else if run.act <= 1 {
      options = [n"HighNoon", n"GoldenHour", n"ClearNight", n"FogBank", n"NeonRain"];
    } else {
      options = [n"GoldenHour", n"ClearNight", n"FogBank", n"NeonRain", n"Smog"];
      if badlands {
        ArrayPush(options, n"Sandstorm");
      }
    }
    ArrayRemove(options, last);
    return options[RandRange(0, ArraySize(options))];
  }

  private static func Hour(look: CName) -> Int32 {
    switch look {
      case n"HighNoon": return RandRange(11, 15);
      case n"GoldenHour": return RandRange(18, 20);
      case n"ClearNight": return RandRange(0, 3);
      case n"FogBank": return RandRange(5, 7);
      case n"NeonRain": return RandRange(21, 24);
      case n"Smog": return RandRange(15, 18);
      case n"ToxicStorm": return RandRange(20, 23);
      case n"Sandstorm": return RandRange(13, 17);
    }
    return 12;
  }

  private static func Weather(look: CName) -> CName {
    switch look {
      case n"HighNoon": return n"24h_weather_sunny";
      case n"GoldenHour": return n"24h_weather_light_clouds";
      case n"ClearNight": return n"24h_weather_sunny";
      case n"FogBank": return n"24h_weather_fog";
      case n"NeonRain": return n"24h_weather_rain";
      case n"Smog": return n"24h_weather_pollution";
      case n"ToxicStorm": return n"24h_weather_toxic_rain";
      case n"Sandstorm": return n"24h_weather_sandstorm";
    }
    return n"24h_weather_sunny";
  }
}

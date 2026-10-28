// -----------------------------------------------------------------------------
// Night City Roguelite - arena music
// -----------------------------------------------------------------------------
// Drives the game's own interactive combat music (the Wwise "combo" sets the
// street stories and main jobs use). Every set works the same way: a start
// event, then state events (alerted, combat, cooldown, boss) and a stop event.
//
//   Light fight     the faction's set; tense "alerted" until the last wave
//   Standard fight  the faction's set; "combat" from the first wave
//   Heavy / elite   a story set with more drive (Konpeki heist, Kang Tao job)
//   Boss            Act 1 Royce (Maelstrom), Act 2 the mall fight,
//                   Act 3 Adam Smasher; the boss wave gets the boss cue
//
// Each set only uses events from its own Wwise combo (mixing combos started a
// second track that the set's stop event didn't end).
//
// Or a radio station instead of a score (never both, so nothing doubles up):
// the Edgerunners station, Morro Rock or the metal station through V's pocket
// radio - more likely the harder the fight (RLRadio below).
//
// Arrival plays the set's "alerted" state (or tunes the radio) over the
// countdown; clearing the arena plays its cooldown (the radio keeps going
// through the reward screens).
//
// Nothing carries over into the next arena. Every trip sends the stop event of
// every set the mod knows (the graceful end, over the glitch), and once the
// screen is black the tracks themselves are cut, so an outro still ringing
// can't play under the next fight. The states (alerted, combat, the boss cues)
// are switches on the set's one track, so only the start ever needs stopping.
//
// V's own pocket radio shares the emitter. The run takes it off the air at
// the first fight and gives it back at home; if V turns it on mid-run, their
// station plays instead of the score until they turn it off again.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLMusicSet {
  public let start: CName;
  public let stop: CName;
  public let alerted: CName;
  public let combat: CName;
  public let cooldown: CName;
  public let boss: CName;
  // Sent with the stop once the boss cue has played (Royce's outro, which ends
  // everything still on the music emitter).
  public let bossStop: CName;

  public static func Make(start: CName, stop: CName, alerted: CName, combat: CName, cooldown: CName, boss: CName) -> ref<RLMusicSet> {
    let set = new RLMusicSet();
    set.start = start;
    set.stop = stop;
    set.alerted = alerted;
    set.combat = combat;
    set.cooldown = cooldown;
    set.boss = boss;
    return set;
  }

  // The open-world street-story set for a faction (mus_ow_<name>_*).
  public static func OpenWorld(const name: String, hasCooldown: Bool, const cooldownSuffix: String) -> ref<RLMusicSet> {
    let prefix = "mus_ow_" + name + "_";
    return RLMusicSet.Make(
      StringToName(prefix + "START_silent"),
      StringToName(prefix + "STOP_silent"),
      StringToName(prefix + "alerted"),
      StringToName(prefix + "combat"),
      hasCooldown ? StringToName(prefix + cooldownSuffix) : n"",
      n""
    );
  }
}

// The game's radio stations, played through V's pocket radio emitter the way
// the pocket radio itself does (PocketRadio.TurnOn / TurnOff), with the
// radio's own state kept in step (RLTune) so it never brings back a station.
public abstract class RLRadio {
  public static func Play(player: ref<PlayerPuppet>, station: Int32) {
    GameObject.AudioSwitch(player, n"radio_port_station", RadioStationDataProvider.GetStationNameByIndex(station), n"pocket_radio_emitter");
    GameObject.AudioSwitch(player, n"radio_port_on", n"None", n"pocket_radio_emitter");
    RLRadio.Tune(player, station);
  }

  public static func Stop(player: ref<PlayerPuppet>) {
    GameObject.AudioSwitch(player, n"radio_port_station", RadioStationDataProvider.GetStationNameByIndex(-1, true), n"pocket_radio_emitter");
    GameObject.AudioSwitch(player, n"radio_port_off", n"None", n"pocket_radio_emitter");
    RLRadio.Tune(player, -1);
  }

  // The station V's pocket radio is on, or -1.
  public static func Station(player: ref<PlayerPuppet>) -> Int32 {
    let radio = IsDefined(player) ? player.GetPocketRadio() : null;
    return IsDefined(radio) ? radio.RLStation() : -1;
  }

  private static func Tune(player: ref<PlayerPuppet>, station: Int32) {
    let radio = player.GetPocketRadio();
    if IsDefined(radio) {
      radio.RLTune(station);
    }
  }

  // A station for the fight, or none (play the score): radio is likelier the
  // harder the fight, and the Edgerunners station leads on the big ones.
  public static func PickStation(threat: Int32, run: ref<RLRunState>, out station: ERadioStationList) -> Bool {
    let big = run.IsBossFloor() || run.IsEliteFloor() || threat >= 3;
    let chance = big ? 0.6 : (threat <= 1 ? 0.2 : 0.4);
    if RandF() >= chance {
      return false;
    }
    let roll = RandF();
    if big {
      station = roll < 0.55 ? ERadioStationList.EDGE_RUNNERS : (roll < 0.85 ? ERadioStationList.ATTITUDE_ROCK : ERadioStationList.METAL);
    } else {
      station = roll < 0.35 ? ERadioStationList.EDGE_RUNNERS : (roll < 0.7 ? ERadioStationList.ATTITUDE_ROCK : ERadioStationList.AGGRO_INDUSTRIAL);
    }
    return true;
  }
}

@addMethod(PocketRadio)
public final func RLStation() -> Int32 {
  return this.m_isOn ? this.m_station : -1;
}

@addMethod(PocketRadio)
public final func RLTune(station: Int32) {
  this.m_station = station;
  this.m_selectedStation = station;
  this.m_isOn = station != -1;
  this.HandleUIUpdate();
}

// V working the radio themselves (the station button, the station picker).
@wrapMethod(PocketRadio)
public final func HandleRadioToggleEvent(evt: ref<RadioToggleEvent>) {
  let before = this.RLStation();
  wrappedMethod(evt);
  RLMusic.Tuned(this.m_player, before, this.RLStation());
}

@wrapMethod(PocketRadio)
public final func HandleVehicleRadioStationChanged(evt: ref<VehicleRadioStationChanged>) {
  let before = this.RLStation();
  wrappedMethod(evt);
  RLMusic.Tuned(this.m_player, before, this.RLStation());
}

@wrapMethod(PocketRadio)
public final func HandleVehicleRadioEvent(evt: ref<VehicleRadioEvent>) {
  let before = this.RLStation();
  wrappedMethod(evt);
  RLMusic.Tuned(this.m_player, before, this.RLStation());
}

public class RLMusic extends IScriptable {
  private let m_player: wref<PlayerPuppet>;
  private let m_set: ref<RLMusicSet>;
  private let m_lightUntilLastWave: Bool;
  private let m_playing: Bool;
  // The run's own station is on V's pocket radio.
  private let m_radioOn: Bool;
  // A boss cue that the next stop must end (Royce's outro).
  private let m_pendingBossStop: CName;
  // Between the first fight and getting home.
  private let m_inRun: Bool;
  // V's own station when the run took the radio off the air (-1: it was off).
  private let m_ownStation: Int32;
  // V turned their radio on mid-run: it plays instead of the score.
  private let m_playerRadio: Bool;

  // --- Sets ------------------------------------------------------------------------------

  public static func FactionSet(faction: gamedataAffiliation) -> ref<RLMusicSet> {
    switch faction {
      case gamedataAffiliation.Animals: return RLMusicSet.OpenWorld("animals", true, "cooldown");
      case gamedataAffiliation.Maelstrom: return RLMusicSet.OpenWorld("maelstrom", true, "combat_cooldown");
      case gamedataAffiliation.Scavengers: return RLMusicSet.OpenWorld("scav", true, "combat_cooldown");
      case gamedataAffiliation.SixthStreet: return RLMusicSet.OpenWorld("6th_street", false, "");
      case gamedataAffiliation.TygerClaws: return RLMusicSet.OpenWorld("tygerclaws", false, "");
      case gamedataAffiliation.Valentinos: return RLMusicSet.OpenWorld("valentinos", false, "");
      case gamedataAffiliation.VoodooBoys: return RLMusicSet.OpenWorld("voo_doos", false, "");
      case gamedataAffiliation.Wraiths: return RLMusicSet.OpenWorld("badlands", true, "cooldown");
      case gamedataAffiliation.Militech: return RLMusicSet.OpenWorld("militech", false, "");
      case gamedataAffiliation.KangTao: return RLMusicSet.OpenWorld("kang_tao", true, "combat_cooldown");
      case gamedataAffiliation.Arasaka:
        return RLMusicSet.Make(n"mus_ow_arasaka_START", n"mus_ow_arasaka_STOP", n"mus_ow_arasaka_alerted", n"mus_ow_arasaka_combat", n"", n"");
    }
    return RLMusicSet.OpenWorld("generic", true, "combat_cooldown");
  }

  // Heavier story sets for heavy and elite fights.
  public static func HeavySet(faction: gamedataAffiliation) -> ref<RLMusicSet> {
    switch faction {
      case gamedataAffiliation.Arasaka: return RLMusic.Heist();
      case gamedataAffiliation.KangTao: return RLMusic.KangTaoJob();
    }
    return RandF() < 0.5 ? RLMusic.Heist() : RLMusic.KangTaoJob();
  }

  private static func Heist() -> ref<RLMusicSet> {
    return RLMusicSet.Make(n"mus_q005_the_heist_START_silent", n"mus_q005_the_heist_STOP_silent", n"mus_q005_the_heist_alerted", n"mus_q005_the_heist_combat", n"mus_q005_the_heist_combat_cooldown", n"");
  }

  private static func KangTaoJob() -> ref<RLMusicSet> {
    return RLMusicSet.Make(n"mus_q104_kang_tao_START_silent", n"mus_q104_kang_tao_STOP_silent", n"mus_q104_kang_tao_alerted", n"mus_q104_kang_tao_combat", n"mus_q104_kang_tao_combat_cooldown", n"");
  }

  public static func BossSet(act: Int32) -> ref<RLMusicSet> {
    if act <= 1 {
      // The Maelstrom combo, with Royce's boss loop for the boss wave (ended by
      // its own outro).
      let royce = RLMusicSet.Make(n"mus_q003_maelstrom_START_silent", n"mus_q003_maelstrom_STOP_silent", n"mus_q003_maelstrom_alerted", n"mus_q003_maelstrom_combat", n"mus_q003_maelstrom_combat_cooldown", n"mus_q003_royce_boss_loop");
      royce.bossStop = n"mus_q003_royce_boss_outro";
      return royce;
    }
    if act == 2 {
      return RLMusicSet.Make(n"mus_q110_mall_START_silent", n"mus_q110_mall_STOP_silent", n"mus_q110_mall_alerted", n"mus_q110_mall_combat", n"mus_q110_mall_cooldown", n"mus_q110_mall_02_boss_combat");
    }
    // One start, one stop: the stop ends both tracks the board meeting starts.
    return RLMusicSet.Make(n"mus_q113_board_meeting_START", n"mus_q113_tower_lockdown_adam_smasher_STOP", n"mus_q113_tower_lockdown_alerted", n"mus_q113_tower_lockdown_combat", n"", n"mus_q113_adam_smasher");
  }

  // Every set the mod can play.
  public static func AllSets() -> array<ref<RLMusicSet>> {
    let sets: array<ref<RLMusicSet>>;
    let factions = [gamedataAffiliation.Animals, gamedataAffiliation.Maelstrom, gamedataAffiliation.Scavengers, gamedataAffiliation.SixthStreet,
      gamedataAffiliation.TygerClaws, gamedataAffiliation.Valentinos, gamedataAffiliation.VoodooBoys, gamedataAffiliation.Wraiths,
      gamedataAffiliation.Militech, gamedataAffiliation.KangTao, gamedataAffiliation.Arasaka, gamedataAffiliation.Unaffiliated];
    for faction in factions {
      ArrayPush(sets, RLMusic.FactionSet(faction));
    }
    ArrayPush(sets, RLMusic.Heist());
    ArrayPush(sets, RLMusic.KangTaoJob());
    let act = 1;
    while act <= 3 {
      ArrayPush(sets, RLMusic.BossSet(act));
      act += 1;
    }
    return sets;
  }

  // --- Playback ---------------------------------------------------------------------------

  // Arrival in an arena: start the set for this fight and build tension.
  public func Prepare(player: ref<PlayerPuppet>, faction: gamedataAffiliation, threat: Int32, run: ref<RLRunState>) {
    this.Stop();
    this.m_player = player;
    if !this.m_inRun {
      this.m_inRun = true;
      this.m_ownStation = RLRadio.Station(player);
      this.m_playerRadio = false;
    }
    if this.m_playerRadio && RLRadio.Station(player) != -1 {
      RLDebug("Music: V's own radio");
      return;
    }
    this.m_playerRadio = false;
    if IsDefined(player) && RLRadio.Station(player) != -1 {
      RLRadio.Stop(player);
    }
    let station: ERadioStationList;
    if IsDefined(player) && RLRadio.PickStation(threat, run, station) {
      RLRadio.Play(player, EnumInt(station));
      this.m_radioOn = true;
      RLDebug("Music: radio " + ToString(station));
      return;
    }
    if run.IsBossFloor() {
      this.m_set = RLMusic.BossSet(run.act);
    } else if threat >= 3 || run.IsEliteFloor() {
      this.m_set = RLMusic.HeavySet(faction);
    } else {
      this.m_set = RLMusic.FactionSet(faction);
    }
    this.m_lightUntilLastWave = threat <= 1 && !run.IsBossFloor() && !run.IsEliteFloor();
    this.m_playing = true;
    this.Play(this.m_set.start);
    this.Play(this.m_set.alerted);
    RLDebug("Music: " + NameToString(this.m_set.start));
  }

  public func OnWaveStarted(wave: Int32, waves: Int32, isBossWave: Bool) {
    if !this.m_playing {
      return;
    }
    if isBossWave && IsNameValid(this.m_set.boss) {
      this.Play(this.m_set.boss);
      this.m_pendingBossStop = this.m_set.bossStop;
    } else if this.m_lightUntilLastWave && wave < waves {
      this.Play(this.m_set.alerted);
    } else {
      this.Play(this.m_set.combat);
    }
  }

  // Arena cleared: wind down (the caller stops it when V leaves).
  public func OnCleared() {
    if this.m_playing && IsNameValid(this.m_set.cooldown) {
      this.Play(this.m_set.cooldown);
    }
  }

  // The run's music ends: the stop event of every set (each ends its track over
  // its own outro) and the run's station off. V's own radio plays on.
  public func Stop() {
    if this.m_radioOn {
      this.m_radioOn = false;
      let player = this.m_player;
      if IsDefined(player) {
        RLRadio.Stop(player);
      }
    }
    this.EndScore();
  }

  private func EndScore() {
    for set in RLMusic.AllSets() {
      this.Play(set.stop);
    }
    this.Play(this.m_pendingBossStop);
    this.m_pendingBossStop = n"";
    this.m_playing = false;
  }

  // The screen is black between places: cut whatever is still ringing out.
  public func Silence() {
    let audio = GameInstance.GetAudioSystem(GetGameInstance());
    for set in RLMusic.AllSets() {
      audio.Stop(set.start);
    }
  }

  // V is home: the run's music is gone for good and V's own radio comes back.
  public func Release(player: ref<PlayerPuppet>) {
    this.Stop();
    this.Silence();
    if this.m_inRun && IsDefined(player) && !(this.m_playerRadio && RLRadio.Station(player) != -1) {
      RLRadio.Stop(player);
      if this.m_ownStation != -1 {
        RLRadio.Play(player, this.m_ownStation);
      }
    }
    this.m_inRun = false;
    this.m_playerRadio = false;
    this.m_ownStation = -1;
  }

  // V tuned the pocket radio themselves. A station takes over from the score
  // (and from the run's station) until V turns it off.
  public static func Tuned(player: wref<PlayerPuppet>, before: Int32, after: Int32) {
    if before == after || !IsDefined(player) {
      return;
    }
    let system = RogueliteSystem.Get(player.GetGame());
    if IsDefined(system) {
      system.GetMusic().OnTuned(after);
    }
  }

  public func OnTuned(station: Int32) {
    if !this.m_inRun {
      return;
    }
    // Whatever is on the radio now is V's choice, not the run's.
    this.m_radioOn = false;
    this.m_playerRadio = station != -1;
    if this.m_playerRadio && this.m_playing {
      this.EndScore();
      RLDebug("Music: V's own radio");
    }
  }

  private func Play(event: CName) {
    if IsNameValid(event) {
      GameInstance.GetAudioSystem(GetGameInstance()).Play(event);
    }
  }
}

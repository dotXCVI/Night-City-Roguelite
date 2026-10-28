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
// second track that the set's stop event didn't end), and stopping sends the
// stop event of every set played this session.
//
// Or a radio station instead of a score (never both, so nothing doubles up):
// the Edgerunners station, Morro Rock or the metal station through V's pocket
// radio emitter - more likely the harder the fight (RLRadio below).
//
// Arrival plays the set's "alerted" state (or tunes the radio) over the
// countdown; clearing the arena plays its cooldown (the radio keeps going
// through the reward screens); the next trip, a flatline or the end of the
// session stop it.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public class RLMusicSet {
  public let start: CName;
  public let stop: CName;
  public let alerted: CName;
  public let combat: CName;
  public let cooldown: CName;
  public let boss: CName;
  // Ends the boss cue when it comes from another combo than the set (Royce's
  // boss loop isn't stopped by the Maelstrom set's stop event).
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
// the pocket radio itself does (PocketRadio.TurnOn / TurnOff).
public abstract class RLRadio {
  public static func Play(player: ref<PlayerPuppet>, station: ERadioStationList) {
    GameObject.AudioSwitch(player, n"radio_port_station", RadioStationDataProvider.GetStationNameByIndex(EnumInt(station)), n"pocket_radio_emitter");
    GameObject.AudioSwitch(player, n"radio_port_on", n"None", n"pocket_radio_emitter");
  }

  public static func Stop(player: ref<PlayerPuppet>) {
    GameObject.AudioSwitch(player, n"radio_port_station", RadioStationDataProvider.GetStationNameByIndex(-1, true), n"pocket_radio_emitter");
    GameObject.AudioSwitch(player, n"radio_port_off", n"None", n"pocket_radio_emitter");
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

public class RLMusic extends IScriptable {
  private let m_player: wref<PlayerPuppet>;
  private let m_radioOn: Bool;
  private let m_set: ref<RLMusicSet>;
  private let m_lightUntilLastWave: Bool;
  private let m_playing: Bool;
  // Stop events of every set started this session: stopping sends them all,
  // so a set can never be left playing under the next one.
  private let m_stops: array<CName>;
  // A boss cue from another combo that the next stop must end.
  private let m_pendingBossStop: CName;

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
    let heist = RLMusicSet.Make(n"mus_q005_the_heist_START_silent", n"mus_q005_the_heist_STOP_silent", n"mus_q005_the_heist_alerted", n"mus_q005_the_heist_combat", n"mus_q005_the_heist_combat_cooldown", n"");
    let kangTao = RLMusicSet.Make(n"mus_q104_kang_tao_START_silent", n"mus_q104_kang_tao_STOP_silent", n"mus_q104_kang_tao_alerted", n"mus_q104_kang_tao_combat", n"mus_q104_kang_tao_combat_cooldown", n"");
    switch faction {
      case gamedataAffiliation.Arasaka: return heist;
      case gamedataAffiliation.KangTao: return kangTao;
    }
    return RandF() < 0.5 ? heist : kangTao;
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
    return RLMusicSet.Make(n"mus_q113_board_meeting_START", n"mus_q113_tower_lockdown_adam_smasher_STOP", n"mus_q113_tower_lockdown_alerted", n"mus_q113_tower_lockdown_combat", n"", n"mus_q113_adam_smasher");
  }

  // --- Playback ---------------------------------------------------------------------------

  // Arrival in an arena: start the set for this fight and build tension.
  public func Prepare(player: ref<PlayerPuppet>, faction: gamedataAffiliation, threat: Int32, run: ref<RLRunState>) {
    this.Stop();
    this.m_player = player;
    let station: ERadioStationList;
    if IsDefined(player) && RLRadio.PickStation(threat, run, station) {
      RLRadio.Play(player, station);
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
    if !ArrayContains(this.m_stops, this.m_set.stop) {
      ArrayPush(this.m_stops, this.m_set.stop);
    }
    this.Play(this.m_set.start);
    this.Play(this.m_set.alerted);
    RLDebug("Music: " + NameToString(this.m_set.start));
  }

  public func OnWaveStarted(wave: Int32, waves: Int32, isBossWave: Bool) {
    if !this.m_playing || this.m_radioOn {
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
    if this.m_playing && !this.m_radioOn && IsNameValid(this.m_set.cooldown) {
      this.Play(this.m_set.cooldown);
    }
  }

  public func Stop() {
    if this.m_radioOn {
      this.m_radioOn = false;
      let player = this.m_player;
      if IsDefined(player) {
        RLRadio.Stop(player);
      }
    }
    if this.m_playing {
      for stop in this.m_stops {
        this.Play(stop);
      }
      this.Play(this.m_pendingBossStop);
      this.m_pendingBossStop = n"";
    }
    this.m_playing = false;
  }

  private func Play(event: CName) {
    if IsNameValid(event) {
      GameInstance.GetAudioSystem(GetGameInstance()).Play(event);
    }
  }
}

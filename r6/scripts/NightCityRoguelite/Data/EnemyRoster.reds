// -----------------------------------------------------------------------------
// Night City Roguelite - enemy roster (generated)
// -----------------------------------------------------------------------------
// The game's standard open-world combat NPCs, by faction. Generated from the
// 2.5 TweakDB record list: only records named <faction>_<role>_<archetype>_
// <weapon>_<body>[_rare|_elite], without quest, test, drone or android
// variants. Every record is still validated at runtime before use.
// Tier from the name suffix: none = 0 (grunts), _rare = 1, _elite = 2.
//
// Names, not records: each name resolves to this mod's roguelite variant
// (NCRoguelite.<name>, from r6/tweaks/NightCityRoguelite/enemies.yaml) and
// falls back to the game's own Character.<name> when TweakXL didn't load it.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLRoster {
  public static func Factions() -> array<gamedataAffiliation> {
    return [gamedataAffiliation.Animals, gamedataAffiliation.Arasaka, gamedataAffiliation.Barghest, gamedataAffiliation.KangTao, gamedataAffiliation.Maelstrom, gamedataAffiliation.Militech, gamedataAffiliation.Scavengers, gamedataAffiliation.SixthStreet, gamedataAffiliation.TygerClaws, gamedataAffiliation.Valentinos, gamedataAffiliation.VoodooBoys, gamedataAffiliation.Wraiths];
  }

  public static func Records(faction: gamedataAffiliation, tier: Int32) -> array<String> {
    let none: array<String>;
    if Equals(faction, gamedataAffiliation.Animals) {
      if tier == 0 { return ["animals_bouncer1_melee1_baton_mb", "animals_bouncer1_ranged1_kenshin_mb", "animals_bouncer1_ranged1_omaha_mb", "animals_bouncer2_ranged2_burya_mb", "animals_bouncer2_ranged2_omaha_mb", "animals_grunt1_melee1_baseball_mb", "animals_grunt1_ranged1_nova_mb", "animals_grunt1_ranged1_pulsar_mb", "animals_grunt2_melee2_hammer_mb", "animals_grunt2_melee2_machete_mb", "animals_grunt2_ranged2_overture_mb", "animals_grunt2_ranged2_pulsar_mb"]; }
      if tier == 1 { return ["animals_bouncer2_hmelee2_hammer_mba_rare", "animals_elite2_hmelee2_hammer_mba_rare", "animals_elite2_ranged3_burya_mba_rare", "animals_grunt2_hmelee2_hammer_wba_rare", "animals_grunt2_shotgun2_igla_wba_rare", "animals_grunt2_shotgun2_testera_wba_rare", "animals_grunt3_gunner2_defender_mb_rare"]; }
      return ["animals_elite2_shotgun3_carnage_wba_elite", "animals_elite2_shotgun3_testera_wba_elite", "animals_elite3_gunner3_hmg_mba_elite", "animals_elite3_shotgun3_carnage_mba_elite"];
    }
    if Equals(faction, gamedataAffiliation.Arasaka) {
      if tier == 0 { return ["arasaka_guard2_melee1_baton_ma", "arasaka_guard2_melee1_baton_wa", "arasaka_guard2_ranged1_kenshin_ma", "arasaka_guard2_ranged1_shingen_ma", "arasaka_guard2_ranged1_yukimura_ma", "arasaka_guard2_ranged1_yukimura_wa", "arasaka_ranger1_melee2_knife_ma", "arasaka_ranger1_ranged2_masamune_ma", "arasaka_ranger1_ranged2_shingen_ma", "arasaka_ranger1_ranged2_shingen_wa", "arasaka_security1_melee1_baton_ma", "arasaka_security1_ranged1_kenshin_ma", "arasaka_security1_ranged1_shingen_ma", "arasaka_security1_ranged1_yukimura_ma"]; }
      if tier == 1 { return ["arasaka_agent_fmelee2rare_katana_ma_rare", "arasaka_agent_fmelee2rare_katana_wa_rare", "arasaka_agent_fmelee2rare_knife_ma_rare", "arasaka_agent_fmelee2rare_knife_wa_rare", "arasaka_agent_franged2_yukimura_wa_rare", "arasaka_agent_fshotgun2_tactician_ma_rare", "arasaka_agent_fshotgun2_tactician_wa_rare", "arasaka_bodyguard_ranged3_kenshin_mb_rare", "arasaka_bodyguard_ranged3_masamune_mb_rare", "arasaka_netrunner_netrunner2_yukimura_ma_rare", "arasaka_netrunner_netrunner2_yukimura_wa_rare", "arasaka_soldier1_ranged3_masamune_mah_rare", "arasaka_soldier2_shotgun2_tactician_mah_rare", "arasaka_sumo_hmelee2_hammer_mb_rare", "arasaka_tank2_gunner2_defender_mb_rare"]; }
      return ["arasaka_cyborg_franged3_shingen_ma_elite", "arasaka_cyborg_franged3_shingen_wa_elite", "arasaka_cyborg_fshotgun3_zhuo_ma_elite", "arasaka_cyborg_grenadier3_yukimura_ma_elite", "arasaka_ninja_fmelee3_katana_ma_elite", "arasaka_ninja_fmelee3_katana_wa_elite", "arasaka_ninja_fmelee3_mantis_ma_elite", "arasaka_ninja_fmelee3_mantis_wa_elite", "arasaka_sniper_sniper3_ashura_ma_elite", "arasaka_sniper_sniper3_nekomata_ma_elite", "arasaka_terminator_shotgun3_zhuo_mah_elite"];
    }
    if Equals(faction, gamedataAffiliation.Barghest) {
      if tier == 0 { return ["bou_kurtz_grunt1_ranged1_handgun_ma", "bou_kurtz_grunt1_ranged1_handgun_wa", "bou_kurtz_grunt1_ranged1_saratoga_ma", "bou_kurtz_grunt1_ranged1_saratoga_wa", "bou_kurtz_soldier1_ranged2_rifle_ma", "bou_kurtz_soldier1_ranged2_rifle_wa"]; }
      if tier == 1 { return ["bou_kurtz_elite2_shotgun2_shotgun_ma_rare", "bou_kurtz_netrunner2_netrunner2_lexington_ma_rare", "bou_kurtz_recon_sniper2_achilles_ma_rare", "bou_kurtz_tech_franged2_handgun_ma_rare", "bou_kurtz_tech_franged2_handgun_wa_rare"]; }
      return ["bou_kurtz_elite3_gunner3_HMG_mb_elite", "bou_kurtz_elite3_shotgun3_shotgun_ma_elite"];
    }
    if Equals(faction, gamedataAffiliation.KangTao) {
      if tier == 0 { return ["kangtao_ranger1_ranged2_dian_ma"]; }
      if tier == 1 { return ["kangtao_soldier2_shotgun2_zhuo_mah_rare"]; }
      return ["kangtao_officer_grenadier3_mah_elite", "kangtao_soldier2_shotgun3_zhuo_mah_elite"];
    }
    if Equals(faction, gamedataAffiliation.Maelstrom) {
      if tier == 0 { return ["maelstrom_fast_sniper2_grad_ma", "maelstrom_grunt1_melee1_knife_ma", "maelstrom_grunt1_melee1_wrench_ma", "maelstrom_grunt1_melee1_wrench_wa", "maelstrom_grunt1_ranged1_copperhead_ma", "maelstrom_grunt1_ranged1_copperhead_wa", "maelstrom_grunt1_ranged1_lexington_ma", "maelstrom_grunt1_ranged1_lexington_wa", "maelstrom_grunt2_melee2_hammer_ma", "maelstrom_grunt2_melee2_hammer_wa", "maelstrom_grunt2_melee2_machete_ma", "maelstrom_grunt2_melee2_machete_wa", "maelstrom_grunt2_ranged2_ajax_ma", "maelstrom_grunt2_ranged2_ajax_wa", "maelstrom_grunt2_ranged2_copperhead_ma", "maelstrom_grunt2_ranged2_copperhead_wa", "maelstrom_netrunner_netrunner2_lexington_ma", "maelstrom_officer_officer_lexington_ma", "maelstrom_techie_grenadier2_lexington_ma"]; }
      if tier == 1 { return ["maelstrom_fast2_fmelee2_knife_ma_rare", "maelstrom_fast_fmelee2_machete_ma_rare", "maelstrom_fast_franged2_pulsar_ma_rare", "maelstrom_strong_gunner2_defender_mb_rare"]; }
      return ["maelstrom_fast_fmelee3_mantis_wa_elite"];
    }
    if Equals(faction, gamedataAffiliation.Militech) {
      if tier == 0 { return ["militech_officer_officer_omaha_ma", "militech_ranger1_ranged1_lexington_ma", "militech_ranger1_ranged1_saratoga_ma", "militech_ranger2_ranged2_ajax_ma", "militech_ranger2_ranged2_omaha_ma"]; }
      if tier == 1 { return ["militech_enforcer2_shotgun2_tactician_mah_rare", "militech_recon_sniper2_achilles_ma_rare", "militech_tech_franged2_omaha_ma_rare", "militech_tech_grenadier2_omaha_ma_rare"]; }
      return ["militech_enforcer3_gunner3_HMG_mb_elite", "militech_soldier3_shotgun3_crusher_mah_elite"];
    }
    if Equals(faction, gamedataAffiliation.Scavengers) {
      if tier == 0 { return ["scavenger_elite2_shotgun_igla_ma", "scavenger_elite2_shotgun_tactician_ma", "scavenger_elite3_sniper2_grad_ma", "scavenger_grunt1_melee1_pipewrench_ma", "scavenger_grunt1_melee1_pipewrench_wa", "scavenger_grunt1_melee1_tireiron_ma", "scavenger_grunt1_melee1_tireiron_wa", "scavenger_grunt1_ranged1_nova_ma", "scavenger_grunt1_ranged1_nova_wa", "scavenger_grunt1_ranged1_pulsar_ma", "scavenger_grunt1_ranged1_pulsar_wa", "scavenger_grunt1_ranged1_slaughtomatic_ma", "scavenger_grunt1_ranged1_slaughtomatic_wa", "scavenger_grunt2_melee2_baseball_ma", "scavenger_grunt2_melee2_knife_ma", "scavenger_grunt2_melee2_knife_wa", "scavenger_grunt2_melee2_pipewrench_ma", "scavenger_grunt2_melee2_pipewrench_wa", "scavenger_grunt2_ranged2_copperhead_ma", "scavenger_grunt2_ranged2_copperhead_wa", "scavenger_grunt2_ranged2_pulsar_ma", "scavenger_grunt2_ranged2_pulsar_wa"]; }
      if tier == 1 { return ["scavenger_butcher3_hmelee2_machete_mb_rare", "scavenger_fast2_fmelee2rare_knife_ma_rare", "scavenger_grunt3_netrunner2_nova_ma_rare", "scavenger_netrunner2_netrunner2_nova_wa_rare", "scavenger_strong3_gunner2_defender_mb_rare"]; }
      return ["scavenger_fast3_fmelee3_machete_wa_elite"];
    }
    if Equals(faction, gamedataAffiliation.SixthStreet) {
      if tier == 0 { return ["sixthstreet_hooligan_melee1_ironpipe_ma", "sixthstreet_hooligan_melee1_ironpipe_wa", "sixthstreet_hooligan_melee1_knife_ma", "sixthstreet_hooligan_melee1_knife_wa", "sixthstreet_hooligan_ranged1_nova_ma", "sixthstreet_hooligan_ranged1_nova_wa", "sixthstreet_hooligan_ranged1_saratoga_ma", "sixthstreet_hooligan_ranged1_saratoga_wa", "sixthstreet_menace1_shotgun2_igla_ma", "sixthstreet_menace1_shotgun2_tactician_ma", "sixthstreet_officer_officer_overture_ma", "sixthstreet_veteran3_ranged2_ajax_ma"]; }
      if tier == 1 { return ["sixthstreet_menace1_fmelee2_baton_wa_rare", "sixthstreet_menace1_fshotgun2_tactician_wa_rare", "sixthstreet_prepers3_grenadier2_nova_ma_rare", "sixthstreet_prepers3_shotgun3_carnage_ma_rare", "sixthstreet_sniper2_sniper2_grad_ma_rare", "sixthstreet_sniper2_sniper2_sor22_ma_rare"]; }
      return none;
    }
    if Equals(faction, gamedataAffiliation.TygerClaws) {
      if tier == 0 { return ["tyger_claws_biker1_melee1_baseball_ma", "tyger_claws_biker1_melee1_baseball_wa", "tyger_claws_biker1_melee1_tireiron_ma", "tyger_claws_biker1_melee1_tireiron_wa", "tyger_claws_biker1_ranged1_nue_ma", "tyger_claws_biker1_ranged1_nue_wa", "tyger_claws_biker1_ranged1_saratoga_ma", "tyger_claws_biker1_ranged1_saratoga_wa", "tyger_claws_biker2_melee2_baseball_ma", "tyger_claws_biker2_melee2_baseball_wa", "tyger_claws_biker2_ranged2_copperhead_ma", "tyger_claws_biker2_ranged2_copperhead_wa", "tyger_claws_biker2_ranged2_shingen_ma", "tyger_claws_biker2_ranged2_shingen_wa", "tyger_claws_biker3_shotgun2_tactician_wa", "tyger_claws_gangster1_melee1_knife_ma", "tyger_claws_gangster1_melee1_knife_wa", "tyger_claws_gangster1_ranged1_copperhead_ma", "tyger_claws_gangster1_ranged1_copperhead_wa", "tyger_claws_gangster1_ranged1_nue_ma", "tyger_claws_gangster1_ranged1_nue_wa", "tyger_claws_gangster2_ranged2_copperhead_ma", "tyger_claws_gangster2_ranged2_copperhead_wa", "tyger_claws_gangster2_ranged2_shingen_ma", "tyger_claws_gangster2_ranged2_shingen_wa", "tyger_claws_gangster2_ranged2_sidewinder_ma", "tyger_claws_gangster2_ranged2_sidewinder_wa", "tyger_claws_gangster3_ranged3_sidewinder_ma", "tyger_claws_martial_hmelee2_StrongArms_ma", "tyger_claws_martial_hmelee2_hammer_mb", "tyger_claws_martial_hmelee3_StrongArms_mb", "tyger_claws_officerbiker_officer_nue_ma", "tyger_claws_officergangster_officer_nue_ma", "tyger_claws_ozeki_hmelee3_hammer_mb", "tyger_claws_ozeki_hmelee3_kanabo_mb"]; }
      if tier == 1 { return ["tyger_claws_martial_fmelee2_katana_ma_rare"]; }
      return ["tyger_claws_biker3_shotgun3_zhuo_ma_elite", "tyger_claws_kunoichi_fmelee3_katana_wa_elite"];
    }
    if Equals(faction, gamedataAffiliation.Valentinos) {
      if tier == 0 { return ["valentinos_grunt1_melee1_baseball_ma", "valentinos_grunt1_melee1_baseball_wa", "valentinos_grunt1_melee1_knife_ma", "valentinos_grunt1_melee1_knife_wa", "valentinos_grunt1_ranged1_nova_ma", "valentinos_grunt1_ranged1_nova_wa", "valentinos_grunt1_ranged1_nue_ma", "valentinos_grunt1_ranged1_nue_wa", "valentinos_grunt2_melee2_knife_ma", "valentinos_grunt2_melee2_knife_wa", "valentinos_grunt2_melee2_machete_ma", "valentinos_grunt2_melee2_machete_wa", "valentinos_grunt2_ranged2_ajax_ma", "valentinos_grunt2_ranged2_ajax_wa", "valentinos_grunt2_ranged2_nue_ma", "valentinos_grunt2_ranged2_nue_wa", "valentinos_grunt2_ranged2_overture_ma", "valentinos_grunt2_ranged2_overture_wa"]; }
      if tier == 1 { return ["valentinos_elite2_ranged3_dual_ma_rare", "valentinos_grunt3_fmelee2_knife_ma_rare", "valentinos_grunt3_fmelee2_machete_ma_rare", "valentinos_grunt4_hmelee2_knife_mb_rare", "valentinos_strong2_shotgun2_igla_ma_rare"]; }
      return ["valentinos_elite3_ranged3_dual_ma_elite", "valentinos_machete_hmelee3_machete_mb_elite", "valentinos_shotgun3_shotgun3_testera_ma_elite", "valentinos_sniper_sniper3_grad_wa_elite"];
    }
    if Equals(faction, gamedataAffiliation.VoodooBoys) {
      if tier == 0 { return ["voodooboys_grunt1_ranged2_saratoga_ma", "voodooboys_grunt1_ranged2_saratoga_wa", "voodooboys_grunt1_ranged2_sidewinder_ma", "voodooboys_grunt1_ranged2_sidewinder_wa", "voodooboys_grunt1coat_shotgun2_palica_ma", "voodooboys_grunt2coat_shotgun2_palica_wa"]; }
      if tier == 1 { return ["voodooboys_grunt1_fmelee2rare_baseball_ma_rare", "voodooboys_netrunner2_netrunner2_lexington_ma_rare", "voodooboys_netrunner2_netrunner2_lexington_wa_rare"]; }
      return ["voodooboys_grunt3coat_shotgun3_zhuo_ma_elite", "voodooboys_netrunner3_netrunner3_quasar_wa_elite"];
    }
    if Equals(faction, gamedataAffiliation.Wraiths) {
      if tier == 0 { return ["wraiths_grunt1_melee1_ironpipe_ma", "wraiths_grunt1_melee1_ironpipe_wa", "wraiths_grunt1_melee1_tireiron_ma", "wraiths_grunt1_melee1_tireiron_wa", "wraiths_grunt1_ranged1_nova_ma", "wraiths_grunt1_ranged1_nova_wa", "wraiths_grunt1_ranged1_pulsar_ma", "wraiths_grunt1_ranged1_pulsar_wa", "wraiths_grunt2_melee2_crowbar_ma", "wraiths_grunt2_melee2_crowbar_wa", "wraiths_grunt2_ranged2_copperhead_ma", "wraiths_grunt2_ranged2_copperhead_wa", "wraiths_grunt2_ranged2_pulsar_ma", "wraiths_grunt2_ranged2_pulsar_wa"]; }
      if tier == 1 { return ["wraiths_ghost2_sniper2_achilles_ma_rare", "wraiths_operator3_shotgun2_crusher_ma_rare", "wraiths_warrior3_melee3_hammer_wa_rare", "wraiths_warrior3_ranged3_quasar_wa_rare"]; }
      return ["wraiths_strong_gunner3_hmg_mb_elite", "wraiths_warrior3_shotgun3_palica_ma_elite", "wraiths_warrior3_shotgun3_satara_ma_elite"];
    }
    return none;
  }

  // Open-world MaxTac (not the quest-scripted AV squads): bosses in acts 2-3.
  public static func MaxTac() -> array<String> {
    return ["maxtac_gunner_mb_elite", "maxtac_melee_ma_elite", "maxtac_rifle_ma_elite", "maxtac_rifle_wa_elite", "maxtac_shotgun_ma_elite"];
  }

  // --- Bosses (Run/Encounters.reds) ------------------------------------------------

  // Gang leaders the game sends after V for wrecking a gang's turf: Act 1
  // bosses, by faction ("" when the faction has none).
  public static func GangBoss(faction: gamedataAffiliation) -> String {
    switch faction {
      case gamedataAffiliation.Animals: return "gang_retaliation_enemies_animals_elite3_hmelee3_fists_mba_elite_dtn_03_boss";
      case gamedataAffiliation.Maelstrom: return "gang_retaliation_enemies_maelstrom_fast_fmelee3_mantis_wa_elite_kab_02_boss";
      case gamedataAffiliation.SixthStreet: return "gang_retaliation_enemies_sixthstreet_prepers3_shotgun3_carnage_ma_arr_11_boss";
      case gamedataAffiliation.TygerClaws: return "gang_retaliation_enemies_tyger_claws_martial_hmelee3_StrongArms_mb_jpn_12_boss";
      case gamedataAffiliation.Valentinos: return "gang_retaliation_enemies_valentinos_shotgun3_shotgun3_testera_ma_elite_gle_04_boss";
    }
    return "";
  }

  // Leaders of the open-world gang outposts: Act 1 bosses for the rest.
  public static func OutpostBosses() -> array<String> {
    return ["ma_bls_ina_se1_17_outpost_miniboss", "ma_bls_se5_07_outpost_miniboss", "ma_hey_gle_02_outpost_miniboss", "ma_hey_rey_06_outpost_miniboss", "ma_hey_spr_11_outpost_miniboss", "ma_pac_cvi_12_outpost_miniboss", "ma_pac_wwd_02_outpost_miniboss", "ma_std_arr_03_outpost_miniboss", "ma_std_rcr_08_outpost_miniboss", "ma_std_rcr_18_outpost_miniboss", "ma_wat_lch_01_outpost_miniboss", "ma_wat_lch_08_outpost_miniboss", "ma_wat_nid_01_outpost_miniboss", "ma_wat_nid_02_outpost_miniboss", "ma_wat_nid_06_outpost_miniboss", "ma_wbr_jpn_20_outpost_miniboss", "ma_wbr_nok_05_outpost_miniboss"];
  }

  // Minotaur mechs: Act 3 bosses, the corp's own when it has one.
  public static func Mechs(faction: gamedataAffiliation) -> array<String> {
    switch faction {
      case gamedataAffiliation.Arasaka: return ["arasaka_minotaur"];
      case gamedataAffiliation.Militech: return ["militech_minotaur"];
      case gamedataAffiliation.Barghest: return ["kurtz_minotaur"];
    }
    return ["arasaka_minotaur", "militech_minotaur", "kurtz_minotaur"];
  }

  // The open world's cyberpsychos: bounty targets.
  public static func Cyberpsychos() -> array<String> {
    return ["ma_bls_ina_se1_08_cyberpsycho", "ma_cct_dtn_03_cyberpsycho", "ma_cct_dtn_07_cyberpsycho", "ma_hey_spr_04_cyberpsycho", "ma_hey_spr_06_cyberpsycho", "ma_pac_cvi_15_cyberpsycho", "ma_std_arr_06_cyberpsycho", "ma_std_rcr_11_cyberpsycho", "ma_wat_kab_02_cyberpsycho", "ma_wat_kab_08_cyberpsycho", "ma_wat_lch_06_cyberpsycho"];
  }

  // A random usable record from a list of names (none if none is usable).
  public static func PickUsable(names: array<String>) -> TweakDBID {
    let usable: array<TweakDBID>;
    for name in names {
      let id = RLRoster.Resolve(name);
      if IsDefined(TweakDBInterface.GetCharacterRecord(id)) {
        ArrayPush(usable, id);
      }
    }
    return ArraySize(usable) > 0 ? usable[RandRange(0, ArraySize(usable))] : TDBID.None();
  }

  // The roguelite variant of a roster NPC, or the game's own record.
  public static func Resolve(const name: String) -> TweakDBID {
    let variant = TDBID.Create("NCRoguelite." + name);
    if IsDefined(TweakDBInterface.GetCharacterRecord(variant)) {
      return variant;
    }
    return TDBID.Create("Character." + name);
  }

  // True for records from this mod's TweakXL data.
  public static func IsVariant(record: TweakDBID) -> Bool {
    let character = TweakDBInterface.GetCharacterRecord(record);
    return IsDefined(character) && IsDefined(character.LootDrop()) && character.LootDrop().GetID() == t"NCRoguelite.EnemyLoot";
  }
}

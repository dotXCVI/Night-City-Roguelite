// -----------------------------------------------------------------------------
// Night City Roguelite - card art
// -----------------------------------------------------------------------------
// Pictures for the menus, all from the game's own codex thumbnails
// (base\gameplay\gui\common\icons\codex\assets_preview1..6.inkatlas). Every
// part in those atlases is the same 16:9 shot (673 x 378), so a banner only
// has to keep that ratio.
//
//   arenas   the district the fight is in
//   patrons  the faction behind the boon
//   kits     the kit's signature weapon
//   fixers   the fixer offering the gig
// -----------------------------------------------------------------------------

module NightCityRoguelite

public struct RLArt {
  public let sheet: Int32;
  public let part: CName;
}

public abstract class RLArts {
  public static func Make(sheet: Int32, part: CName) -> RLArt {
    let art: RLArt;
    art.sheet = sheet;
    art.part = part;
    return art;
  }

  public static func IsValid(art: RLArt) -> Bool = art.sheet > 0 && IsNameValid(art.part)

  public static func Ratio() -> Float = 0.5625

  public static func Atlas(sheet: Int32) -> ResRef {
    switch sheet {
      case 1: return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview1.inkatlas";
      case 2: return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview2.inkatlas";
      case 3: return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview3.inkatlas";
      case 4: return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview4.inkatlas";
      case 5: return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview5.inkatlas";
    }
    return r"base\\gameplay\\gui\\common\\icons\\codex\\assets_preview6.inkatlas";
  }

  public static func Arena(id: CName) -> RLArt {
    switch id {
      case n"petrochem": return RLArts.Make(2, n"lore_petrochem");
      case n"industrial": return RLArts.Make(5, n"sms_q112_photo_industrial_park");
      case n"mall": return RLArts.Make(4, n"l_pacifica");
      case n"oilfields": return RLArts.Make(4, n"l_north_industrial_district");
      case n"drivein": return RLArts.Make(3, n"l_badlands");
      case n"junkyard": return RLArts.Make(3, n"l_arroyo");
      case n"windfarm": return RLArts.Make(2, n"l_windfarms");
      case n"crater": return RLArts.Make(5, n"l_rocky_ridge");
    }
    return RLArts.Make(1, n"l_night_city");
  }

  public static func Patron(id: CName) -> RLArt {
    switch id {
      case n"Arasaka": return RLArts.Make(3, n"lore_arasaka");
      case n"Militech": return RLArts.Make(1, n"lore_militech");
      case n"VoodooBoys": return RLArts.Make(4, n"lore_voodooboys");
      case n"Maelstrom": return RLArts.Make(5, n"c_royce");
      case n"Aldecaldos": return RLArts.Make(2, n"lore_aldecados");
      case n"Afterlife": return RLArts.Make(2, n"l_afterlife");
    }
    return RLArts.Make(4, n"lore_corporations");
  }

  public static func Kit(kit: CName) -> RLArt {
    switch kit {
      case n"Solo": return RLArts.Make(2, n"w_militech_m251s_ajax");
      case n"Blade": return RLArts.Make(6, n"w_borg_machete");
      case n"Netrunner": return RLArts.Make(5, n"lore_ice");
      case n"Marksman": return RLArts.Make(4, n"w_techtronika_spt32_grad");
      case n"Brawler": return RLArts.Make(5, n"w_budgetarms_carnage");
      case n"Gunslinger": return RLArts.Make(1, n"w_malorian_overture");
      case n"Demolitions": return RLArts.Make(5, n"w_arasaka_tki_20_shingen");
      case n"Juggernaut": return RLArts.Make(2, n"w_militech_mk31_hmg");
      case n"Wireman": return RLArts.Make(1, n"lore_netrunners");
    }
    return RLArts.Make(1, n"c_v_male");
  }

  // The fixer behind a gig (Run/Gigs.reds names them).
  public static func Fixer(style: Int32) -> RLArt {
    switch style % 6 {
      case 0: return RLArts.Make(1, n"c_wakako_okada");
      case 1: return RLArts.Make(4, n"c_padre_sebasitan_perez");
      case 2: return RLArts.Make(5, n"c_regina_jones");
      case 3: return RLArts.Make(4, n"c_dakota");
      case 4: return RLArts.Make(4, n"c_mrhands");
    }
    return RLArts.Make(5, n"c_rogue_old");
  }

  // Doors that aren't a patron's: what's behind them.
  public static func Category(category: RLRewardCategory) -> RLArt {
    switch category {
      case RLRewardCategory.Armory: return RLArts.Make(4, n"w_arasaka_hjsh_18_masamune");
      case RLRewardCategory.Chrome: return RLArts.Make(2, n"lore_ripperdoc");
      case RLRewardCategory.Daemons: return RLArts.Make(5, n"lore_ice");
      case RLRewardCategory.Training: return RLArts.Make(3, n"lore_solo");
      case RLRewardCategory.Cred: return RLArts.Make(2, n"l_afterlife");
      case RLRewardCategory.Workshop: return RLArts.Make(3, n"lore_techie");
      case RLRewardCategory.Event: return RLArts.Make(3, n"c_misty");
      case RLRewardCategory.Boons: return RLArts.Make(4, n"lore_corporations");
      case RLRewardCategory.Bounty: return RLArts.Make(4, n"lore_cyberpsychosis");
      case RLRewardCategory.System: return RLArts.Make(4, n"lore_blackwall");
      case RLRewardCategory.Gig: return RLArts.Make(5, n"lore_fixers");
    }
    return RLArts.Make(1, n"l_night_city");
  }

  // The face (or place) of a "?" stop.
  public static func Event(id: CName) -> RLArt {
    switch id {
      case n"Ripperdoc": return RLArts.Make(1, n"c_victor_vector");
      case n"Bookie": return RLArts.Make(1, n"l_jig_jig_street");
      case n"Tarot": return RLArts.Make(3, n"c_misty");
      case n"Stranger": return RLArts.Make(1, n"l_kabuki");
    }
    return RLArts.Make(1, n"l_night_city");
  }

  // A picture at the art's own ratio, `width` wide.
  public static func Image(art: RLArt, width: Float) -> ref<inkImage> {
    let image = new inkImage();
    image.SetAtlasResource(RLArts.Atlas(art.sheet));
    image.SetTexturePart(art.part);
    image.SetSize(Vector2(width, width * RLArts.Ratio()));
    image.SetFitToContent(false);
    return image;
  }

  // The guide's pages (UI/GuidePopup.reds).
  public static func Home() -> RLArt = RLArts.Make(1, n"l_vs_megabuilding")
  public static func Terminal() -> RLArt = RLArts.Make(5, n"lore_ice")
  public static func Armory() -> RLArt = RLArts.Make(1, n"w_malorian_overture")
  public static func City() -> RLArt = RLArts.Make(1, n"l_night_city")
  public static func Patrons() -> RLArt = RLArts.Make(4, n"lore_corporations")
  public static func Flatline() -> RLArt = RLArts.Make(4, n"lore_trauma_team")
}

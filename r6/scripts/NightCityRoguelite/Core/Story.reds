// -----------------------------------------------------------------------------
// Night City Roguelite - story handling
// -----------------------------------------------------------------------------
// The Phantom Liberty opening (book scene, Songbird's call) is skipped by the
// quest patch in NightCityRoguelite.archive: RogueliteService sets the fact
// nc_roguelite_start at Session/Start and the patched q301_hook phase takes
// over: it keeps the screen black (fact nc_roguelite_skipping), the takeover
// moves V into the apartment, and nc_roguelite_ready lets it fade in with V
// standing inside. Quests can't be stopped from scripts, and cutting a
// call or scene off mid-way leaves it running invisibly, so if the archive is
// missing (or the story starts something later) the mod works around it:
//   - the takeover waits until the opening call has finished;
//   - the quest is untracked so nothing shows on the HUD;
//   - teleports, the terminal and the reward screen wait while a call or a
//     conversation is going on (RogueliteSystem.BusyReason; a prompt on
//     screen is not a conversation);
//   - a caller card left on screen after its call has ended is cleared.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLStory {
  // Hides the quest from the HUD and clears a stale caller card.
  public static func Quiet(game: GameInstance) {
    let journal = GameInstance.GetJournalManager(game);
    if IsDefined(journal) {
      journal.UntrackEntry();
    }
    RLStory.ClearStaleCallCard(game);
  }

  public static func IsCallActive(game: GameInstance) -> Bool {
    let manager = GameInstance.GetPhoneManager(game);
    return IsDefined(manager) && manager.IsPhoneCallActive();
  }

  // The quest patch is holding the screen black while the mod sets V up
  // (between nc_roguelite_skipping and nc_roguelite_ready).
  public static func IsOpeningSkipInProgress(game: GameInstance) -> Bool {
    let quests = GameInstance.GetQuestsSystem(game);
    return quests.GetFact(n"nc_roguelite_skipping") > 0 && quests.GetFact(n"nc_roguelite_ready") <= 0;
  }

  // Lets the quest patch fade in.
  public static func FinishOpeningSkip(game: GameInstance) {
    GameInstance.GetQuestsSystem(game).SetFact(n"nc_roguelite_ready", 1);
  }

  // V is actually in a conversation (not just looking at something with a
  // prompt: those share the choice list with dialogue).
  public static func IsInDialogue(player: ref<PlayerPuppet>) -> Bool {
    let scenes = GameInstance.GetSceneSystem(player.GetGame());
    return IsDefined(scenes) && scenes.GetScriptInterface().IsEntityInDialogue(player.GetEntityID());
  }

  // Any list of choices on screen (dialogue or an interaction prompt).
  public static func IsDialogueOpen(game: GameInstance) -> Bool {
    let blackboard = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UIInteractions);
    if !IsDefined(blackboard) {
      return false;
    }
    let value = blackboard.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs);
    if !IsDefined(value) {
      return false;
    }
    let hubs = FromVariant<DialogChoiceHubs>(value);
    return ArraySize(hubs.choiceHubs) > 0;
  }

  // The phone UI still shows a call that the game says is over.
  public static func ClearStaleCallCard(game: GameInstance) {
    if RLStory.IsCallActive(game) {
      return;
    }
    let phone = GameInstance.GetScriptableSystemsContainer(game).Get(n"PhoneSystem") as PhoneSystem;
    if IsDefined(phone) && phone.RL_EndActiveCall() {
      RLLog("Cleared a caller card left on screen.");
    }
  }
}

@addMethod(PhoneSystem)
public final func RL_EndActiveCall() -> Bool {
  let info = this.m_LastCallInformation;
  if NotEquals(info.callPhase, questPhoneCallPhase.IncomingCall) && NotEquals(info.callPhase, questPhoneCallPhase.StartCall) {
    return false;
  }
  this.TriggerCall(
    info.callMode,
    info.isAudioCall,
    info.contactName,
    info.isPlayerCalling,
    questPhoneCallPhase.EndCall,
    info.isPlayerTriggered,
    info.isRejectable,
    info.showAvatar,
    info.visuals
  );
  return true;
}

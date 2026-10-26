// -----------------------------------------------------------------------------
// Night City Roguelite - story handling
// -----------------------------------------------------------------------------
// The Phantom Liberty start is a base-game save at the end of "Transmission"
// with Songbird's call queued. Quests can't be stopped from scripts, and
// cutting a call or scene off mid-way leaves it running invisibly (its lines
// keep playing, its choices pop up later, teleporting during it can freeze
// the game). So the mod works around the story instead of fighting it:
//   - the takeover waits until the opening call has finished;
//   - the quest is untracked so nothing shows on the HUD;
//   - teleports, the terminal and the reward screen wait while a call or a
//     conversation is going on (RogueliteSystem.IsStoryBusy);
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

  // A conversation with choices is on screen.
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

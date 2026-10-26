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

// --- Quiet world ---------------------------------------------------------------------------
// Roguelite characters get no story at all:
//   - the quest patch doesn't start the base-game quest graph for them (fact
//     nc_roguelite_quiet_world, set at Session/Start): no calls, texts,
//     side jobs or objectives from the base game;
//   - every active quest and message in the journal is set inactive on load,
//     and anything that becomes active later is set inactive straight away,
//     so nothing shows on the HUD, the map or the journal.

public class RLJournalGuard extends IScriptable {
  private let m_registered: Bool;
  private let m_cleared: Int32;

  public func Start(game: GameInstance) {
    let journal = GameInstance.GetJournalManager(game);
    if !IsDefined(journal) {
      return;
    }
    if !this.m_registered {
      journal.RegisterScriptCallback(this, n"OnJournalStateChanged", gameJournalListenerType.State);
      this.m_registered = true;
    }
    let count = RLJournalGuard.ClearAll(journal);
    if count > 0 {
      RLLog(s"Journal: set \(count) quest/message entr(ies) inactive.");
    }
  }

  public func Stop(game: GameInstance) {
    if this.m_registered {
      let journal = GameInstance.GetJournalManager(game);
      if IsDefined(journal) {
        journal.UnregisterScriptCallback(this, n"OnJournalStateChanged");
      }
      this.m_registered = false;
    }
  }

  public static func IsQuiet(className: CName) -> Bool {
    switch className {
      case n"gameJournalQuest":
      case n"gameJournalQuestPhase":
      case n"gameJournalQuestObjective":
      case n"gameJournalQuestSubObjective":
      case n"gameJournalQuestMapPin":
      case n"gameJournalPhoneMessage":
      case n"gameJournalPhoneConversation":
      case n"gameJournalPhoneChoiceEntry":
        return true;
    }
    return false;
  }

  protected cb func OnJournalStateChanged(entryHash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if !RLJournalGuard.IsQuiet(className) {
      return false;
    }
    let journal = GameInstance.GetJournalManager(GetGameInstance());
    let entry = journal.GetEntry(entryHash);
    if IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
      journal.ChangeEntryStateByHash(entryHash, gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
      this.m_cleared += 1;
    }
    return false;
  }

  // Every active quest (with its phases and objectives) to inactive.
  public static func ClearAll(journal: ref<JournalManager>) -> Int32 {
    let context: JournalRequestContext;
    context.stateFilter.active = true;
    let quests: array<wref<JournalEntry>>;
    journal.GetQuests(context, quests);
    let count = 0;
    for quest in quests {
      count += RLJournalGuard.ClearEntry(journal, quest, 0);
    }
    journal.UntrackEntry();
    return count;
  }

  private static func ClearEntry(journal: ref<JournalManager>, entry: wref<JournalEntry>, depth: Int32) -> Int32 {
    if !IsDefined(entry) {
      return 0;
    }
    let count = 0;
    if depth < 3 {
      let filter: JournalRequestStateFilter;
      filter.active = true;
      let children: array<wref<JournalEntry>>;
      journal.GetChildren(entry, filter, children);
      for child in children {
        count += RLJournalGuard.ClearEntry(journal, child, depth + 1);
      }
    }
    if Equals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
      journal.ChangeEntryStateByHash(Cast<Uint32>(journal.GetEntryHash(entry)), gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
      count += 1;
    }
    return count;
  }
}

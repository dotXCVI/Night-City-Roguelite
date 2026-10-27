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
// Roguelite characters get no story distractions (RLConfig.SilenceStory):
//   - every active quest and message in the journal is set inactive shortly
//     after load, and anything that becomes active later is set inactive a
//     moment after (RLJournalGuard), so nothing shows on the HUD, the map or
//     the journal;
//   - incoming calls are declined before they ring (PhoneSystem.OnTriggerCall),
//     so their scenes never start;
//   - the "new message" and quest pop-ups aren't shown.
// The base-game quest graph itself keeps running: gating it (v0.0.10) left new
// characters on a frozen black screen.

public abstract class RLQuiet {
  public static func IsOn(game: GameInstance) -> Bool {
    if !RLConfig.SilenceStory() {
      return false;
    }
    let system = RogueliteSystem.Get(game);
    return IsDefined(system) && system.IsRoguelitePlaythrough();
  }
}

// Journal state is never changed from inside a journal callback (the journal
// is mid-notification there; doing so in v0.0.10 is the likely cause of the
// new-game freeze). The callback only notes the entry; a sweep 0.25 s later,
// from the delay system, sets it inactive.
public class RLJournalGuard extends RLDelayTarget {
  private let m_registered: Bool;
  private let m_pending: array<Uint32>;
  private let m_sweepQueued: Bool;
  private let m_clearQueued: Bool;
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
    if !this.m_clearQueued {
      this.m_clearQueued = true;
      RLDelay(game, this, n"clearAll", 1.0);
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
    ArrayClear(this.m_pending);
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

  // Read-only: notes the entry and schedules a sweep.
  protected cb func OnJournalStateChanged(entryHash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    if !this.m_registered || !RLJournalGuard.IsQuiet(className) {
      return false;
    }
    if !ArrayContains(this.m_pending, entryHash) {
      ArrayPush(this.m_pending, entryHash);
    }
    if !this.m_sweepQueued {
      this.m_sweepQueued = true;
      RLDelay(GetGameInstance(), this, n"sweep", 0.25);
    }
    return false;
  }

  public func OnDelayed(action: CName) {
    let game = GetGameInstance();
    let journal = GameInstance.GetJournalManager(game);
    switch action {
      case n"sweep":
        this.m_sweepQueued = false;
        if !this.m_registered || !IsDefined(journal) {
          ArrayClear(this.m_pending);
          return;
        }
        let hashes = this.m_pending;
        ArrayClear(this.m_pending);
        let count = 0;
        for hash in hashes {
          let entry = journal.GetEntry(hash);
          if IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
            journal.ChangeEntryStateByHash(hash, gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
            count += 1;
            // Which story bits keep coming back (e.g. the quest behind a call).
            RLDebug("Journal: quieted " + entry.GetId());
          }
        }
        if count > 0 {
          journal.UntrackEntry();
          this.m_cleared += count;
          RLDebug(s"Journal: set \(count) new entr(ies) inactive.");
        }
        break;
      case n"clearAll":
        this.m_clearQueued = false;
        if !this.m_registered || !IsDefined(journal) {
          return;
        }
        let total = RLJournalGuard.ClearAll(journal);
        if total > 0 {
          RLLog(s"Journal: set \(total) quest/message entr(ies) inactive.");
        }
        break;
    }
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

// Incoming calls don't ring for roguelite characters: once the character is
// set up, a call is declined on the spot - the quest gets the same answer as
// when the player declines (phone fact "Rejected"), so it moves on instead of
// calling again. Before that (the opening) it is just not shown. Calls the
// quest starts or ends directly are logged and left alone: hiding those would
// leave their scene running unseen.
@wrapMethod(PhoneSystem)
private final func OnTriggerCall(request: ref<questTriggerCallRequest>) {
  let game = this.GetGameInstance();
  if RLQuiet.IsOn(game) {
    let caller = NameToString(request.caller);
    if Equals(request.callPhase, questPhoneCallPhase.IncomingCall) {
      let system = RogueliteSystem.Get(game);
      if IsDefined(system) && system.IsHomeTerminalActive() && IsNameValid(request.caller) {
        this.SetPhoneFact(false, request.caller, questPhoneTalkingState.Rejected);
        RLLog(s"Declined an incoming call (\(caller), rejectable \(request.isRejectable)).");
      } else {
        RLLog(s"Blocked an incoming call (\(caller)).");
      }
      return;
    }
    RLLog(s"Call from the story: \(caller) -> \(NameToString(request.addressee)), phase \(EnumInt(request.callPhase)).");
  }
  wrappedMethod(request);
}

// No "new message" / "new contact" pop-ups.
@wrapMethod(NewHudPhoneGameController)
protected cb func OnJournalUpdate(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
  if RLQuiet.IsOn(GetGameInstance()) {
    return false;
  }
  return wrappedMethod(hash, className, notifyOption, changeType);
}

// No quest pop-ups.
@wrapMethod(JournalNotificationQueue)
protected cb func OnJournalUpdate(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
  if Equals(className, n"gameJournalQuest") && RLQuiet.IsOn(GetGameInstance()) {
    return false;
  }
  return wrappedMethod(hash, className, notifyOption, changeType);
}

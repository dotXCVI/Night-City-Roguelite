// -----------------------------------------------------------------------------
// Night City Roguelite - story silencer
// -----------------------------------------------------------------------------
// Roguelite characters don't play the story. Once the takeover has happened:
//   - every active quest (Phantom Liberty's opening with Songbird included) is
//     set to inactive, so nothing shows in the journal or on the HUD;
//   - quest-triggered phone/holo calls are dropped before they ring.
// The opening call before the takeover is left alone so the opening can end
// normally and hand control to the player.
// -----------------------------------------------------------------------------

module NightCityRoguelite

public abstract class RLStory {
  public static func DeactivateQuests(game: GameInstance) {
    let journal = GameInstance.GetJournalManager(game);
    if !IsDefined(journal) {
      return;
    }
    journal.UntrackEntry();
    let context: JournalRequestContext;
    context.stateFilter.active = true;
    let entries: array<wref<JournalEntry>>;
    journal.GetQuests(context, entries);
    let count = 0;
    for entry in entries {
      if IsDefined(entry) {
        let hash = Cast<Uint32>(journal.GetEntryHash(entry));
        journal.ChangeEntryStateByHash(hash, gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
        count += 1;
      }
    }
    if count > 0 {
      RLLog(s"Deactivated \(count) story quest(s).");
    }
  }
}

@wrapMethod(PhoneSystem)
private final func OnTriggerCall(request: ref<questTriggerCallRequest>) {
  let system = RogueliteSystem.Get(this.GetGameInstance());
  if IsDefined(system) && system.SilencesStory() && !request.isPlayerTriggered {
    RLDebug(s"Blocked story call from '\(NameToString(request.caller))' to '\(NameToString(request.addressee))'.");
    return;
  }
  wrappedMethod(request);
}

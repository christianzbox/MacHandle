import ActionApprovals
import CoreDomain
import EventKit
import Foundation
import PermissionEngine

/// No production factory exposes this actor. No permission request, batching or external EventKit objects.
actor EventKitReminderMutationBackend: ReminderMutationBackend {
    private var store: EKEventStore?
    private func eventStore() -> EKEventStore {
        if let store { return store }
        let value = EKEventStore()
        store = value
        return value
    }
    private func access() throws {
        guard !Task.isCancelled, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        else { throw ActionFailure.denied }
    }
    private func reference(_ list: EKCalendar, store: EKEventStore) throws -> ReminderListReference
    {
        try ReminderListReference(
            account: AccountReference(
                provider: ProviderID("apple-eventkit"),
                store: StoreID(store.eventStoreIdentifier),
                account: AccountID(list.source.sourceIdentifier)),
            localID: DomainID(list.calendarIdentifier))
    }
    private func target(_ change: ReminderMutation, store: EKEventStore) throws -> EKCalendar {
        guard let list = store.calendar(withIdentifier: change.target.localID.rawValue),
            try reference(list, store: store) == change.target, list.allowsContentModifications,
            list.allowedEntityTypes.contains(.reminder)
        else { throw ActionFailure.denied }
        return list
    }
    private func item(_ change: ReminderMutation, store: EKEventStore) throws -> EKReminder? {
        guard let id = change.item else { return nil }
        guard let value = store.calendarItem(withIdentifier: id.item.rawValue) as? EKReminder,
            value.refresh(), let list = value.calendar
        else { throw ActionFailure.stale }
        try ReminderMutationScope.validate(
            id,
            actual: ReminderReference(
                list: reference(list, store: store), item: ReminderID(value.calendarItemIdentifier)),
            recurring: value.hasRecurrenceRules, alarms: value.hasAlarms)
        return value
    }
    private func snapshot(
        _ change: ReminderMutation, fields: Set<ReminderField>, store: EKEventStore,
        list: EKCalendar, item: EKReminder?
    ) throws -> ReminderActionSnapshot {
        let reminder: Reminder?
        if let item, let id = change.item {
            let revision = try ReminderMutationScope.revision(item.lastModifiedDate)
            if let expected = change.precondition, expected != .unknown, expected != revision {
                throw ActionFailure.stale
            }
            guard !fields.contains(.title) || (item.title?.utf8.count ?? 0) <= 512,
                !fields.contains(.notes) || (item.notes?.utf8.count ?? 0) <= 8192
            else { throw ActionFailure.capacity }
            reminder = Reminder(
                id: id,
                title: fields.contains(.title) ? .value(item.title ?? "") : .notFetched,
                notes: fields.contains(.notes) ? .value(item.notes) : .notFetched,
                due: fields.contains(.due)
                    ? .value(try ReminderMutationScope.due(item.dueDateComponents)) : .notFetched,
                completion: fields.contains(.completion)
                    ? .value(
                        item.isCompleted
                            ? .completed(at: try item.completionDate.map(Instant.init))
                            : .incomplete) : .notFetched,
                recurrence: fields.contains(.recurrence) ? .value(.notRecurring) : .notFetched,
                revision: revision)
        } else {
            reminder = nil
        }
        return ReminderActionSnapshot(
            list: try reference(list, store: store), accountLabel: list.source.title,
            listLabel: list.title, writable: true, reminder: reminder)
    }
    func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) throws
        -> ReminderActionSnapshot
    {
        try access()
        let store = eventStore()
        // Discard cached pending state before a fresh exact observation.
        store.reset()
        let list = try target(change, store: store)
        let result = try snapshot(
            change, fields: fields, store: store, list: list, item: item(change, store: store))
        try access()
        return result
    }
    func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt {
        guard await action.revalidate() else { return .notApplied }
        do { try access() } catch { return .notApplied }
        let store = eventStore()
        store.reset()
        let change = action.proposal.change
        let list: EKCalendar
        let existing: EKReminder?
        do {
            try ReminderActionReview.validate(change)
            guard change.item == nil || change.precondition != .unknown else { return .notApplied }
            list = try target(change, store: store)
            existing = try item(change, store: store)
            guard
                try snapshot(
                    change, fields: action.fields, store: store, list: list, item: existing)
                    == action.expected
            else { return .notApplied }
        } catch { return .notApplied }
        let reminder: EKReminder
        switch change {
        case .create(_, let draft):
            reminder = EKReminder(eventStore: store)
            reminder.calendar = list
            reminder.title = draft.title
            reminder.notes = draft.notes
            reminder.dueDateComponents = ReminderMutationScope.components(draft.due)
        default:
            guard let existing else { return .notApplied }
            reminder = existing
        }
        switch change {
        case .create, .delete: break
        case .update(_, let patch, _):
            if case .set(let value) = patch.title { reminder.title = value }
            if case .set(let value) = patch.notes { reminder.notes = value }
        case .setDue(_, let due, _):
            reminder.dueDateComponents = ReminderMutationScope.components(due)
        case .complete: reminder.isCompleted = true
        case .uncomplete: reminder.completionDate = nil
        }
        do {
            try access()
            guard list.allowsContentModifications,
                try reference(list, store: store) == change.target
            else { throw ActionFailure.denied }
        } catch {
            store.reset()
            return .notApplied
        }
        // No suspension between final observation and save, but other apps/cloud are NOT serialized.
        do {
            if case .delete = change {
                try store.remove(reminder, commit: true)
            } else {
                try store.save(reminder, commit: true)
            }
            return .applied(action.proposal.id)  // Local acceptance, not upstream confirmation.
        } catch {
            store.reset()
            return .unknown
        }
    }
}

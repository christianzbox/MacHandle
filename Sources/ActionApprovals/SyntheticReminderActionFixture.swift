import CoreDomain
import Foundation
import PermissionEngine

/// Fixed in-memory data only. Never a live factory or a caller-supplied permission issuer.
package struct SyntheticReminderActionFixture: Sendable {
    package let authority: PolicyAuthority
    package let session: PolicySession
    package let provider: SyntheticReminderActionProvider
    package let list: ReminderListReference
    package let reminder: Reminder
    package static func make(completed: Bool = false) async throws -> Self {
        let list = try ReminderListReference(
            account: AccountReference(
                provider: ProviderID("synthetic"),
                store: StoreID("synthetic-store"), account: AccountID("synthetic-account")),
            localID: DomainID("synthetic-list"))
        let reminder = try Reminder(
            id: ReminderReference(list: list, item: ReminderID("synthetic-reminder")),
            title: .value("Sample groceries"), notes: .value("Sample notes"),
            due: .value(.date(LocalDate(year: 2027, month: 1, day: 15))),
            completion: .value(completed ? .completed(at: nil) : .incomplete),
            recurrence: .value(.notRecurring),
            revision: .revision(ObservedRevision("synthetic-v1")))
        let authority = PolicyAuthority()
        let id = try ConnectionID(UUID().uuidString)
        let fields: Set<ReminderField> = [.title, .notes, .due, .completion, .recurrence]
        await authority.setConnection(
            Connection(id: id, kind: .localMCP, state: .enabled),
            policy: ConnectionPolicy(reminderLists: [
                list: ReminderGrant(
                    operations: [
                        .readDetails, .create, .update, .changeDueDate, .complete, .uncomplete,
                        .delete,
                    ],
                    readableFields: fields, writableFields: [.title, .notes, .due, .completion])
            ]))
        await authority.observeOSPermissions(OSPermissions(reminders: .fullAccess))
        return Self(
            authority: authority, session: try await authority.bindTrustedConnection(id),
            provider: SyntheticReminderActionProvider(list: list, reminder: reminder), list: list,
            reminder: reminder)
    }
    package func change(_ kind: ReminderActionKind) throws -> ReminderMutation {
        switch kind {
        case .create: .create(in: list, reminder: ReminderDraft(title: "Sample new reminder"))
        case .update:
            .update(
                reminder.id, changes: try ReminderChanges(title: .set("Sample revised groceries")),
                precondition: .unknown)
        case .setDue: .setDue(reminder.id, due: nil, precondition: .unknown)
        case .complete: .complete(reminder.id, precondition: .unknown)
        case .uncomplete: .uncomplete(reminder.id, precondition: .unknown)
        case .delete: .delete(reminder.id, precondition: .unknown)
        }
    }
}
package actor SyntheticReminderActionProvider: ReminderActionProvider {
    private let list: ReminderListReference
    private var reminders: [ReminderReference: Reminder]
    private var applied: Set<OperationID> = []
    package init(list: ReminderListReference, reminder: Reminder) {
        self.list = list
        reminders = [reminder.id: reminder]
    }
    package func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) throws
        -> ReminderActionSnapshot
    {
        guard change.target == list else { throw ActionFailure.denied }
        return ReminderActionReview.project(
            ReminderActionSnapshot(
                list: list,
                accountLabel: "Sample local account", listLabel: "Sample list", writable: true,
                reminder: change.item.flatMap { reminders[$0] }), fields: fields)
    }
    package func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt {
        guard await action.revalidate(), !Task.isCancelled, !applied.contains(action.proposal.id),
            try inspect(action.proposal.change, fields: action.fields) == action.expected
        else { return .notApplied }
        // Deterministic atomic mock; never evidence of EventKit's cross-process conflict behavior.
        let revision = MutationPrecondition.revision(try ObservedRevision(UUID().uuidString))
        let change = action.proposal.change
        if case .create(_, let draft) = change {
            let value = try Reminder(
                id: ReminderReference(list: list, item: ReminderID(UUID().uuidString)),
                title: .value(draft.title), notes: .value(draft.notes), due: .value(draft.due),
                completion: .value(.incomplete), recurrence: .value(.notRecurring),
                revision: revision)
            reminders[value.id] = value
        } else {
            guard let id = change.item, let old = reminders[id] else { return .notApplied }
            if case .delete = change {
                reminders.removeValue(forKey: id)
            } else {
                var title = old.title
                var notes = old.notes
                var due = old.due
                var completion = old.completion
                switch change {
                case .update(_, let patch, _):
                    if case .set(let v) = patch.title { title = .value(v) }
                    if case .set(let v) = patch.notes { notes = .value(v) }
                case .setDue(_, let value, _): due = .value(value)
                case .complete:
                    completion = .value(
                        .completed(at: try Instant(Date(timeIntervalSince1970: 1_800_000_000))))
                case .uncomplete: completion = .value(.incomplete)
                default: throw ActionFailure.invalid
                }
                reminders[id] = Reminder(
                    id: id, title: title, notes: notes, due: due,
                    completion: completion, recurrence: old.recurrence, revision: revision)
            }
        }
        applied.insert(action.proposal.id)
        return .applied(action.proposal.id)
    }
}

import CoreDomain
import Foundation
import PermissionEngine

public enum ReminderActionKind: String, CaseIterable, Identifiable, Sendable {
    case create, update, setDue, complete, uncomplete, delete
    public var id: String { rawValue }
    public var title: String { self == .setDue ? "Change due date" : rawValue.capitalized }
}

/// Inert local display; cannot be decoded or constructed by an external caller.
public struct ReminderReviewDisplay: Sendable, Identifiable {
    public let id: UUID
    public let kind: ReminderActionKind
    public let account: String
    public let list: String
    public let rows: [ActionReviewDisplay.Row]
    public let scope: String
}

package struct ReminderActionSnapshot: Equatable, Sendable {
    package let list: ReminderListReference
    package let accountLabel: String
    package let listLabel: String
    package let writable: Bool
    package let reminder: Reminder?
    package init(
        list: ReminderListReference, accountLabel: String, listLabel: String,
        writable: Bool, reminder: Reminder? = nil
    ) {
        self.list = list
        self.accountLabel = accountLabel
        self.listLabel = listLabel
        self.writable = writable
        self.reminder = reminder
    }
}

package protocol ReminderActionProvider: Sendable {
    /// Exact scoped observation. Unknown input revision is not execution authority.
    func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) async throws
        -> ReminderActionSnapshot
    func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt
}
package struct AuthorizedReminderAction: Sendable {
    package let proposal: ProposedChange<ReminderMutation>
    package let expected: ReminderActionSnapshot
    package let fields: Set<ReminderField>
    private let authorization: @Sendable () async -> Bool
    init(
        proposal: ProposedChange<ReminderMutation>, expected: ReminderActionSnapshot,
        fields: Set<ReminderField>, authorization: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.proposal = proposal
        self.expected = expected
        self.fields = fields
        self.authorization = authorization
    }
    package func revalidate() async -> Bool { await authorization() }
}
package enum ReminderActionReceipt: Sendable {
    case applied(OperationID)
    case notApplied, unknown
}

extension ReminderMutation {
    package var target: ReminderListReference {
        switch self {
        case .create(let list, _): list
        case .update(let r, _, _), .setDue(let r, _, _), .complete(let r, _),
            .uncomplete(let r, _), .delete(let r, _):
            r.list
        }
    }
    package var item: ReminderReference? {
        switch self {
        case .create: nil
        case .update(let r, _, _), .setDue(let r, _, _), .complete(let r, _),
            .uncomplete(let r, _), .delete(let r, _):
            r
        }
    }
    package var precondition: MutationPrecondition? {
        switch self {
        case .create: nil
        case .update(_, _, let p), .setDue(_, _, let p), .complete(_, let p),
            .uncomplete(_, let p), .delete(_, let p):
            p
        }
    }
    package func observed(_ revision: MutationPrecondition) -> ReminderMutation {
        switch self {
        case .create: self
        case .update(let r, let p, _): .update(r, changes: p, precondition: revision)
        case .setDue(let r, let due, _): .setDue(r, due: due, precondition: revision)
        case .complete(let r, _): .complete(r, precondition: revision)
        case .uncomplete(let r, _): .uncomplete(r, precondition: revision)
        case .delete(let r, _): .delete(r, precondition: revision)
        }
    }
    package var kind: ReminderActionKind {
        switch self {
        case .create: .create
        case .update: .update
        case .setDue: .setDue
        case .complete: .complete
        case .uncomplete: .uncomplete
        case .delete: .delete
        }
    }
    package var reviewFields: Set<ReminderField> {
        if case .create = self { return [] }
        var result: Set<ReminderField> = [.title, .due, .completion, .recurrence]
        if case .update(_, let changes, _) = self, changes.notes.isChanged { result.insert(.notes) }
        return result
    }
}

import CoreDomain
import Foundation
import PermissionEngine

package enum ActionFailure: Error {
    case denied, invalid, stale, expired, busy, capacity, unresolved
}

public enum ActionKind: String, CaseIterable, Identifiable, Sendable {
    case create, update, delete
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Display values are inert text. No public constructor, decoder or executable payload.
public struct ActionReviewDisplay: Sendable, Identifiable {
    public struct Row: Sendable, Equatable {
        public let field: String
        public let before: String?
        public let after: String?
        package init(_ field: String, _ before: String?, _ after: String?) {
            self.field = field
            self.before = before
            self.after = after
        }
    }
    public let id: UUID
    public let kind: ActionKind
    public let account: String
    public let calendar: String
    public let rows: [Row]
    public let scope: String
}

package struct CalendarActionSnapshot: Equatable, Sendable {
    package let calendar: CalendarReference
    package let accountLabel: String
    package let calendarLabel: String
    package let writable: Bool
    package let event: CalendarOccurrence?
    package init(
        calendar: CalendarReference, accountLabel: String, calendarLabel: String,
        writable: Bool, event: CalendarOccurrence? = nil
    ) {
        self.calendar = calendar
        self.accountLabel = accountLabel
        self.calendarLabel = calendarLabel
        self.writable = writable
        self.event = event
    }
}

/// Trusted adapter contract. Inspect exact references, fetch only requested fields, and never infer absence.
/// Recheck expected state at dispatch. Providers must document their actual conflict semantics;
/// a local comparison does not imply an atomic conditional write in an external store.
package protocol CalendarActionProvider: Sendable {
    func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) async throws
        -> CalendarActionSnapshot
    func apply(_ action: AuthorizedCalendarAction) async throws -> CalendarActionReceipt
}

package struct AuthorizedCalendarAction: Sendable {
    package let proposal: ProposedChange<CalendarMutation>
    package let expected: CalendarActionSnapshot
    package let fields: Set<CalendarField>
    private let authorization: @Sendable () async -> Bool
    // Internal construction only. Adapters must recheck after durable preparation and before acceptance.
    init(
        proposal: ProposedChange<CalendarMutation>, expected: CalendarActionSnapshot,
        fields: Set<CalendarField>, authorization: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.proposal = proposal
        self.expected = expected
        self.fields = fields
        self.authorization = authorization
    }
    package func revalidate() async -> Bool { await authorization() }
}
package enum CalendarActionReceipt: Sendable {
    case applied(OperationID)
    case notApplied
    case unknown
}
public enum ActionOutcome: String, Sendable {
    case applied, notApplied, unknown
    public var message: String {
        switch self {
        case .applied: "Sample action completed. No real calendar was changed."
        case .notApplied:
            "The sample action was not applied. Prepare a new review before trying again."
        case .unknown:
            "The outcome needs verification. Further actions are blocked; do not retry the change."
        }
    }
}
package struct ActionAudit: Sendable {
    package enum Phase: Sendable {
        case prepared, confirmed, rejected, invalidated, dispatched, applied, notApplied, unknown
    }
    package let sequence: UInt64
    package let operation: OperationID?
    package let connection: ConnectionID
    package let phase: Phase
}

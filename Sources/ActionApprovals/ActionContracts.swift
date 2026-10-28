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
/// apply must compare expected state and mutate atomically at its supported provider boundary.
/// No live provider implements this contract in work package 20.
package protocol CalendarActionProvider: Sendable {
    func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) async throws
        -> CalendarActionSnapshot
    func apply(_ action: AuthorizedCalendarAction) async throws -> CalendarActionReceipt
}

package struct AuthorizedCalendarAction: Sendable {
    package let proposal: ProposedChange<CalendarMutation>
    package let expected: CalendarActionSnapshot
    package let fields: Set<CalendarField>
    // Internal synthesized initializer keeps dispatch construction inside this trusted module.
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

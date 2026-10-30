import Foundation
import SyncPersistence

/// Read-only, content-free evidence. No status in this view authorizes a replay or changes a receipt.
public struct SampleRecoverySummary: Sendable, Equatable {
    public struct Entry: Identifiable, Sendable, Equatable {
        public let id: UUID
        public let outcome: String
    }
    public let applied: Int
    public let notApplied: Int
    public let unresolved: Int
    public let entries: [Entry]
    public var permitsFreshSession: Bool { unresolved == 0 }
    public var status: String {
        "Journal: \(applied) applied; \(notApplied) not applied; \(unresolved) unresolved."
    }
    public var guidance: String {
        permitsFreshSession
            ? "Recorded outcomes are final. A fresh session starts with new sample contents, selection and approvals. Never resend an old change."
            : "Outcome uncertain. Writes stay blocked. Do not retry, delete the journal or rebuild to bypass it. No automatic reconciliation is possible without evidence."
    }
    package init(records: [ReminderMutationRecord]) {
        applied = records.filter { $0.state == .applied }.count
        notApplied = records.filter { $0.state == .notApplied }.count
        unresolved = records.filter { $0.state == .pending || $0.state == .unknown }.count
        // UUID ordering is not chronology. All unresolved entries come first; bound the native list.
        let ordered = records.sorted {
            let a = $0.state == .pending || $0.state == .unknown
            let b = $1.state == .pending || $1.state == .unknown
            return a != b ? a : $0.operation.uuidString < $1.operation.uuidString
        }
        entries = ordered.prefix(20).map {
            Entry(
                id: $0.operation,
                outcome: $0.state == .pending
                    ? "Uncertain — interrupted before a durable receipt"
                    : $0.state == .unknown
                        ? "Uncertain — no matching confirmed receipt"
                        : $0.state == .applied ? "Applied" : "Not applied")
        }
    }
}

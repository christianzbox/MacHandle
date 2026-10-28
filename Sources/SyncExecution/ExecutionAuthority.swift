import CoreDomain
import SyncPersistence
import SyncPlanning

// Internal until trusted live composition can prove all activation gates. Never consumes caller booleans from UI/MCP.
enum ExecutionFailure: Error, Equatable {
    case blocked, stalePreview, conflict, recoveryRequired, busy, storage, invalidTime
}
enum ExecutionPhase: Sendable { case read, write, commit }
struct ExecutionRequest: Sendable {
    let binding: PersistenceBinding
    let plan: ReconciliationPlan
    let proposal: ReconciliationProposal?
    let phase: ExecutionPhase
}
protocol ExecutionAuthorizing: Sendable {
    /// Trusted source-read/remote observation adapter; never an Apple writer.
    func currentInput() async throws -> ReconciliationInput
    /// Recheck account, policy generation/fields, selection, OS access, privacy, writer lease and exact confirmation.
    func check(_ request: ExecutionRequest) async throws
    func checkDeletions(_ plan: ReconciliationPlan) async throws
}
/// A default-deny composition latch. No live authority implementation is installed by this package.
struct InactiveExecutionAuthority: ExecutionAuthorizing {
    func currentInput() async throws -> ReconciliationInput { throw ExecutionFailure.blocked }
    func check(_ request: ExecutionRequest) async throws { throw ExecutionFailure.blocked }
}
struct ExecutionReport: Equatable {
    enum Status: Equatable {
        case completed, recovered, blocked, conflict, recoveryRequired, cancelled, storageFailure,
            busy
    }
    let status: Status
    let completedOperations: Int
}

extension ExecutionAuthorizing {
    /// Every destructive batch, including one deletion, requires independent trusted
    /// approval bound to the full reviewed plan. Per-item write permission is insufficient.
    func checkDeletions(_ plan: ReconciliationPlan) async throws { throw ExecutionFailure.blocked }
}

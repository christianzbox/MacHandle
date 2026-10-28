import Foundation
import GoogleAuthorization
import SyncPersistence
import SyncPlanning

/// Observation adapters may classify a retry only before any executor mutation is dispatched.
enum BackgroundPreparationFailure: Error { case retry(after: Double) }

struct ScheduledSynchronizationJob: BackgroundSyncRunning {
    let store: SQLiteSyncStore
    let binding: PersistenceBinding
    let destination: GoogleDurableDestination
    let authority: any ExecutionAuthorizing

    func run(check: @escaping @Sendable () async throws -> Void) async -> BackgroundRunResult {
        let guarded = ScheduledAuthority(base: authority, gate: check)
        let plan: ReconciliationPlan
        do {
            try await check()
            // Unknown or prepared intents must use explicit recovery, never automatic retries.
            guard try await store.snapshot().operations.allSatisfy({ $0.state == .completed })
            else {
                return .needsAttention
            }
            plan = try ReconciliationPlanner.plan(await guarded.currentInput())
        } catch BackgroundPreparationFailure.retry(let delay) {
            return .retry(after: delay)
        } catch { return .needsAttention }
        let executor = SynchronizationExecutor(
            store: store, binding: binding, destination: destination, authority: guarded)
        let result = await executor.run(preview: plan)
        // After dispatch every non-completed outcome requires a fresh reviewed recovery decision.
        return result.status == .completed ? .completed : .needsAttention
    }
}

private struct ScheduledAuthority: ExecutionAuthorizing {
    let base: any ExecutionAuthorizing
    let gate: @Sendable () async throws -> Void
    func currentInput() async throws -> ReconciliationInput {
        try await gate()
        let input = try await base.currentInput()
        try await gate()
        return input
    }
    func check(_ request: ExecutionRequest) async throws {
        try await gate()
        try await base.check(request)
        try await gate()
    }
    func checkDeletions(_ plan: ReconciliationPlan) async throws {
        try await gate()
        try await base.checkDeletions(plan)
        try await gate()
    }
}

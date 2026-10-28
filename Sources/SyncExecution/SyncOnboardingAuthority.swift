import CoreDomain
import Foundation
import GoogleAuthorization
import SyncPersistence
import SyncPlanning

/// Trusted host establishes account, selected sources, sharing privacy and OS/policy access.
/// No production factory is exposed while those live proofs remain unavailable.
struct SyncOnboardingLane: Sendable {
    let scope: PlanningScope
    let binding: PersistenceBinding
    let store: SQLiteSyncStore
    let destination: GoogleDurableDestination
    let authority: any ExecutionAuthorizing
}

actor SyncOnboardingPermit {
    private var generation = UUID()
    private var configuration: CalendarSyncConfiguration?
    private var approved: [ReconciliationPlan] = []
    private var ongoing = false
    private(set) var lastSuccess: Date?

    func issue(_ value: CalendarSyncConfiguration, plans: [ReconciliationPlan]) -> UUID {
        generation = UUID()
        configuration = value
        approved = plans
        ongoing = false
        return generation
    }
    func revoke() {
        generation = UUID()
        configuration = nil
        approved = []
        ongoing = false
    }
    func check(_ token: UUID, plan: ReconciliationPlan) throws {
        try Task.checkCancellation()
        guard token == generation, let configuration,
            configuration.sources.contains(plan.scope.source),
            ongoing || approved.contains(plan)
        else { throw ExecutionFailure.blocked }
    }
    func checkDeletions(_ token: UUID, plan: ReconciliationPlan) throws {
        try check(token, plan: plan)
        guard !ongoing, approved.contains(plan) else { throw ExecutionFailure.blocked }
    }
    func complete(_ token: UUID, at date: Date) throws {
        guard token == generation, configuration != nil else { throw ExecutionFailure.blocked }
        ongoing = true
        approved = []
        lastSuccess = date
    }
    func forgetSuccess() { lastSuccess = nil }
}

struct OnboardingExecutionAuthority: ExecutionAuthorizing {
    let lane: SyncOnboardingLane
    let configuration: CalendarSyncConfiguration
    let permit: SyncOnboardingPermit
    let token: UUID
    let checkSession: @Sendable () async throws -> Void

    func currentInput() async throws -> ReconciliationInput {
        try await checkSession()
        let input = try await lane.authority.currentInput()
        guard input.scope == lane.scope, configuration.sources.contains(input.scope.source),
            input.policy.fields == configuration.fields, input.policy.enabled
        else {
            throw ExecutionFailure.blocked
        }
        try await permit.check(token, plan: ReconciliationPlanner.plan(input))
        try await checkSession()
        return input
    }
    func check(_ request: ExecutionRequest) async throws {
        try await checkSession()
        guard request.binding == lane.binding, request.plan.scope == lane.scope else {
            throw ExecutionFailure.blocked
        }
        try await permit.check(token, plan: request.plan)
        try await lane.authority.check(request)
        try await permit.check(token, plan: request.plan)
        try await checkSession()
    }
    func checkDeletions(_ plan: ReconciliationPlan) async throws {
        try await checkSession()
        try await permit.checkDeletions(token, plan: plan)
        // Keep the existing independently trusted per-resource deletion checks as well.
        try await lane.authority.checkDeletions(plan)
    }
}

struct OnboardingScheduledJob: BackgroundSyncRunning {
    let lanes: [SyncOnboardingLane]
    let configuration: CalendarSyncConfiguration
    let permit: SyncOnboardingPermit
    let token: UUID
    let checkSession: @Sendable () async throws -> Void
    let now: @Sendable () -> Date
    func run(check: @escaping @Sendable () async throws -> Void) async -> BackgroundRunResult {
        for lane in lanes {
            let authority = OnboardingExecutionAuthority(
                lane: lane, configuration: configuration, permit: permit, token: token,
                checkSession: {
                    try await check()
                    try await checkSession()
                })
            let result = await ScheduledSynchronizationJob(
                store: lane.store, binding: lane.binding, destination: lane.destination,
                authority: authority
            ).run(check: check)
            guard result == .completed else { return .needsAttention }
        }
        do {
            try await check()
            try await permit.complete(token, at: now())
        } catch { return .needsAttention }
        return .completed
    }
}

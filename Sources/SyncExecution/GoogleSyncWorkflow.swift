import CoreDomain
import Foundation
import SyncPersistence
import SyncPlanning

/// Trusted local composition only. No public activation path or provider authority is minted here.
/// One instance owns the canonical store and all selected per-source destination lanes.
actor GoogleSyncWorkflow: CalendarSyncManaging {
    typealias Factory = @Sendable (CalendarSyncConfiguration) async throws -> [SyncOnboardingLane]
    private struct Review: Sendable {
        let display: CalendarSyncPreview
        let deadline: Double
        let lanes: [SyncOnboardingLane]
        let plans: [ReconciliationPlan]
    }
    private let store: SQLiteSyncStore
    private let binding: PersistenceBinding
    private let factory: Factory
    private let connectAccount: @Sendable () async throws -> Void
    private let checkAccount: @Sendable () async throws -> Void
    private let disconnectAccount: @Sendable (Bool) async throws -> Void
    private let now: @Sendable () -> Date
    private let uptime: @Sendable () -> Double
    private let permit = SyncOnboardingPermit()
    private var configuration = CalendarSyncConfiguration()
    private var phase: CalendarSyncPhase = .disconnected
    private var failure: CalendarSyncFailure?
    private var generation = UUID()
    private var review: Review?
    private var connecting: Task<Void, Error>?
    private var preparing: Task<Review, Error>?
    private var executing: Task<Bool, Error>?
    private var background: BackgroundSynchronization?
    private var changes: Task<Void, Never>?
    private var drains = 0
    private var awake = false
    private var online = false
    private var writer = false
    private var busy: Bool {
        drains > 0 || connecting != nil || preparing != nil || executing != nil
    }

    init(
        store: SQLiteSyncStore, binding: PersistenceBinding,
        factory: @escaping Factory = { _ in throw CalendarSyncFailure.notConfigured },
        connect: @escaping @Sendable () async throws -> Void = {
            throw CalendarSyncFailure.notConfigured
        },
        check: @escaping @Sendable () async throws -> Void = {
            throw CalendarSyncFailure.notConfigured
        },
        disconnect: @escaping @Sendable (Bool) async throws -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() },
        uptime: @escaping @Sendable () -> Double = BackgroundClock.continuous().now
    ) {
        self.store = store
        self.binding = binding
        self.factory = factory
        connectAccount = connect
        checkAccount = check
        disconnectAccount = disconnect
        self.now = now
        self.uptime = uptime
    }

    func status() async -> CalendarSyncStatus {
        let token = generation
        let success = await permit.lastSuccess
        if let background {
            let state = await background.status()
            if token == generation {
                switch state.phase {
                case .running: phase = .running
                case .waiting: phase = .waiting
                case .suspended: phase = .suspended
                case .standby: phase = .standby
                case .needsAttention:
                    phase = .recoveryRequired
                    failure = .recoveryRequired
                case .paused, .disabled: break
                }
            }
        }
        return .init(
            phase: phase, configuration: configuration, lastSuccess: success, failure: failure)
    }

    func connect() async -> CalendarSyncStatus {
        guard !busy, background == nil, review == nil else { return await status() }
        let token = generation
        phase = .connecting
        failure = nil
        let task = Task {
            try await connectAccount()
            try Task.checkCancellation()
            try await checkAccount()
        }
        connecting = task
        do {
            try await task.value
            if token == generation { phase = .ready }
        } catch { if token == generation { record(error) } }
        if token == generation { connecting = nil }
        return await status()
    }

    /// Candidate preferences require a freshly authorized catalog; restoring never enables sync.
    func restoreCandidates(from authorizedCatalog: Set<CalendarReference>) async throws {
        guard !busy, phase == .ready else { throw CalendarSyncFailure.busy }
        let token = generation
        try await checkAccount()
        let snapshot = try await store.snapshot()
        guard token == generation, snapshot.binding == binding else {
            throw CalendarSyncFailure.staleReview
        }
        guard let preferences = snapshot.preferences else { return }
        let sources = Set(
            authorizedCatalog.filter { source in
                preferences.sources.contains {
                    $0.value == PlanningFingerprint.calendar(source).value
                }
            })
        // A missing/reidentified source needs explicit selection, not a fuzzy match.
        guard sources.count == preferences.sources.count else {
            throw CalendarSyncFailure.sourceUnavailable
        }
        configuration = .init(sources: sources, fields: Self.fields(preferences.fieldMask))
        phase = .paused
    }

    func preview(_ value: CalendarSyncConfiguration) async throws -> CalendarSyncPreview {
        guard !busy else { throw CalendarSyncFailure.busy }
        let stopped = await stop()
        guard stopped == generation, drains == 0 else { throw CalendarSyncFailure.cancelled }
        guard !value.sources.isEmpty, value.sources.count <= 32 else {
            throw CalendarSyncFailure.invalidSelection
        }
        let token = generation
        configuration = value
        failure = nil
        phase = .ready
        let task = Task { [factory, checkAccount, binding, store, now, uptime] in
            try await checkAccount()
            let lanes = try await factory(value)
            try Task.checkCancellation()
            guard Set(lanes.map { $0.scope.source }) == value.sources,
                lanes.count == value.sources.count,
                Set(lanes.map { $0.scope.destination }).count == lanes.count,
                lanes.allSatisfy({ $0.binding == binding && $0.store === store })
            else { throw CalendarSyncFailure.invalidSelection }
            var plans: [ReconciliationPlan] = []
            var items: [CalendarSyncPreviewItem] = []
            for lane in lanes {
                let snapshot = try await lane.store.snapshot()
                guard snapshot.binding == binding,
                    snapshot.operations.allSatisfy({ $0.state == .completed })
                else {
                    throw CalendarSyncFailure.recoveryRequired
                }
                let input = try await lane.authority.currentInput()
                guard input.scope == lane.scope, input.policy.enabled,
                    input.policy.fields == value.fields
                else {
                    throw CalendarSyncFailure.staleReview
                }
                let plan = ReconciliationPlanner.plan(input)
                guard plan.issues.isEmpty else { throw CalendarSyncFailure.sourceUnavailable }
                plans.append(plan)
                items += try Self.items(plan, input: input)
            }
            try await checkAccount()
            try Task.checkCancellation()
            return Review(
                display: .init(
                    id: UUID(), configuration: value, items: items,
                    expiresAt: now().addingTimeInterval(300)), deadline: uptime() + 300,
                lanes: lanes, plans: plans)
        }
        preparing = task
        do {
            let result = try await task.value
            guard token == generation else { throw CalendarSyncFailure.staleReview }
            preparing = nil
            review = result
            phase = .reviewing
            return result.display
        } catch {
            if token == generation {
                preparing = nil
                record(error)
            }
            throw error as? CalendarSyncFailure ?? .unavailable
        }
    }

    func confirm(_ reviewID: UUID, approveDeletions: Bool) async -> CalendarSyncStatus {
        guard !busy else { return await status() }
        guard awake, online, writer else {
            failure = .unavailable
            return await status()
        }
        guard let receipt = review, receipt.display.id == reviewID,
            receipt.display.configuration == configuration, now() < receipt.display.expiresAt,
            uptime() < receipt.deadline
        else {
            review = nil
            record(CalendarSyncFailure.staleReview)
            return await status()
        }
        guard receipt.display.deletionCount == 0 || approveDeletions else {
            failure = .approvalRequired
            return await status()
        }
        review = nil
        phase = .running
        failure = nil
        let token = generation
        drains += 1
        let permitToken = await permit.issue(configuration, plans: receipt.plans)
        drains -= 1
        guard token == generation else { return await status() }
        let checkSession: @Sendable () async throws -> Void = { [weak self] in
            guard let self else { throw CalendarSyncFailure.cancelled }
            try await self.checkRuntime(token)
        }
        let task = Task { [store, configuration, permit, now] in
            // Revalidate every selected source before the first mutation, then again in the executor.
            for (lane, plan) in zip(receipt.lanes, receipt.plans) {
                try Task.checkCancellation()
                try await checkSession()
                let input = try await lane.authority.currentInput()
                guard input.policy.fields == configuration.fields,
                    ReconciliationPlanner.plan(input) == plan
                else { throw CalendarSyncFailure.staleReview }
            }
            try await permit.check(permitToken, plan: receipt.plans[0])
            try await store.savePreferences(
                StoredSyncPreferences(
                    sources: Set(
                        try configuration.sources.map {
                            try PersistenceDigest(PlanningFingerprint.calendar($0).value)
                        }),
                    fieldMask: Self.mask(configuration.fields)))
            for (lane, plan) in zip(receipt.lanes, receipt.plans) {
                let authority = OnboardingExecutionAuthority(
                    lane: lane, configuration: configuration,
                    permit: permit, token: permitToken, checkSession: checkSession)
                let result = await SynchronizationExecutor(
                    store: lane.store, binding: lane.binding,
                    destination: lane.destination, authority: authority
                ).run(preview: plan)
                guard result.status == .completed else { return false }
            }
            try Task.checkCancellation()
            try await permit.complete(permitToken, at: now())
            return true
        }
        executing = task
        do {
            let completed = try await task.value
            guard token == generation else { return await status() }
            executing = nil
            guard completed else { throw CalendarSyncFailure.recoveryRequired }
            let scheduler = BackgroundSynchronization(
                job: OnboardingScheduledJob(
                    lanes: receipt.lanes, configuration: configuration, permit: permit,
                    token: permitToken,
                    checkSession: checkSession, now: now))
            background = scheduler
            if token == generation {
                await scheduler.startAfterInitialRun(awake: awake, online: online, writer: writer)
            }
        } catch {
            if token == generation {
                executing = nil
                await permit.revoke()
                if token == generation { record(error) }
            }
        }
        return await status()
    }

    func pause() async -> CalendarSyncStatus {
        phase = .paused
        failure = nil
        await stop()
        return await status()
    }
    func disconnect(revokeGrant: Bool) async -> CalendarSyncStatus {
        phase = .disconnected
        configuration = .init()
        failure = nil
        await stop()
        drains += 1
        do { try await disconnectAccount(revokeGrant) } catch { failure = .disconnectIncomplete }
        do { try await store.savePreferences(nil) } catch {
            if failure == nil { failure = .unavailable }
        }
        await permit.forgetSuccess()
        drains -= 1
        return await status()
    }
    func shutdown() async {
        let observer = changes
        changes = nil
        observer?.cancel()
        _ = await pause()
        await observer?.value
    }
    func observeChanges(_ stream: AsyncStream<Void>) {
        guard changes == nil else { return }
        changes = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.sourceChanged()
            }
        }
    }

    /// Trusted host signals only; these never grant source, account or mutation authority.
    func setEnvironment(awake: Bool, sessionActive: Bool, online: Bool) async {
        self.awake = awake && sessionActive
        self.online = online
        if !self.awake || !online,
            connecting != nil || preparing != nil || executing != nil || review != nil
        {
            _ = await pause()
        }
        await background?.setEnvironment(awake: self.awake, online: online)
    }
    func setWriterActive(_ active: Bool) async {
        writer = active
        if !active { _ = await pause() } else { await background?.setWriterActive(true) }
    }
    func sourceChanged() async {
        if review != nil || preparing != nil || executing != nil || connecting != nil {
            _ = await pause()
        } else {
            await background?.request()
        }
    }

    @discardableResult
    private func stop() async -> UUID {
        generation = UUID()
        let token = generation
        review = nil
        drains += 1
        let connect = connecting
        let prepare = preparing
        let execute = executing
        let scheduler = background
        background = nil
        connect?.cancel()
        prepare?.cancel()
        execute?.cancel()
        await permit.revoke()
        await scheduler?.shutdown()
        _ = await connect?.result
        _ = await prepare?.result
        _ = await execute?.result
        connecting = nil
        preparing = nil
        executing = nil
        background = nil
        drains -= 1
        return token
    }
    private func checkRuntime(_ token: UUID) async throws {
        try Task.checkCancellation()
        guard generation == token, awake, online, writer else {
            throw CalendarSyncFailure.cancelled
        }
        try await checkAccount()
        try Task.checkCancellation()
        guard generation == token, awake, online, writer else {
            throw CalendarSyncFailure.cancelled
        }
    }
    private func record(_ error: any Error) {
        failure = error as? CalendarSyncFailure ?? .unavailable
        switch failure {
        case .notConfigured: phase = .unconfigured
        case .signInRequired: phase = .signInRequired
        case .recoveryRequired: phase = .recoveryRequired
        default: phase = .paused
        }
    }
    private static func mask(_ fields: Set<CalendarDetailField>) -> Int {
        (fields.contains(.title) ? 1 : 0) | (fields.contains(.location) ? 2 : 0)
            | (fields.contains(.notes) ? 4 : 0)
    }
    private static func fields(_ mask: Int) -> Set<CalendarDetailField> {
        var fields: Set<CalendarDetailField> = []
        if mask & 1 != 0 { fields.insert(.title) }
        if mask & 2 != 0 { fields.insert(.location) }
        if mask & 4 != 0 { fields.insert(.notes) }
        return fields
    }
    private static func items(_ plan: ReconciliationPlan, input: ReconciliationInput) throws
        -> [CalendarSyncPreviewItem]
    {
        let previous = Dictionary(
            input.mappings.records.map { ($0.source, $0.lastSourceInterval) },
            uniquingKeysWith: { first, _ in first })
        return try plan.proposals.map { proposal in
            let action: CalendarSyncPreviewItem.Action
            var title = "Existing mirrored event"
            var time: EventTime?
            var location = ""
            var notes = ""
            if let interval = previous[proposal.source] {
                time = .timed(interval, timeZone: try TimeZoneID("UTC"))
            }
            switch proposal.action {
            case .create(let content):
                action = .create
                title = content.title
                location = content.location
                notes = content.notes
                time = content.time
            case .update(_, let content, _):
                action = .update
                title = content.title
                location = content.location
                notes = content.notes
                time = content.time
            case .delete: action = .delete
            case .noChange: action = .unchanged
            case .conflict, .manualIntervention: throw CalendarSyncFailure.recoveryRequired
            }
            return .init(
                id: proposal.id.value, source: plan.scope.source, action: action,
                contentTitle: title, time: time, location: location, notes: notes)
        }
    }
}

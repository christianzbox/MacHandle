import ActionApprovals
import Foundation
import LocalBridgeTransport
import MCPConnections
import NativeMCPBridge
import Observation
import SyncPersistence

public typealias PrivateWriteReview = ReminderReviewDisplay

@Observable @MainActor
public final class PrivateWriteModel {
    public enum Phase: Sendable {
        case idle, inspecting, starting, listening, connectionReview, connected, stopping, closed,
            unavailable
    }
    public private(set) var phase: Phase = .idle
    public private(set) var review: PrivateWriteReview?
    public private(set) var message = "Sample changes are off. No personal Reminders are connected."
    public private(set) var journalStatus = "Journal not opened."
    public private(set) var busy = false
    public private(set) var recovery: SampleRecoverySummary?
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var listener: SignedLocalListener?
    private var composition: SampleWriteComposition?
    private var broker: NativeReadBroker?
    private var journal: ReminderMutationJournal?
    private var connectionReview: UUID?
    private var token: String?
    private var generation = UUID()
    private var outcomeVersion: UInt64 = 0
    public init() {}
    public func start() async {
        guard phase == .idle else { return }
        phase = .starting
        let expected = generation
        do {
            let config = try configuration()
            let journal = try openJournal(config)
            let composition = try await SampleWriteComposition.make(
                journal: journal,
                onReview: { [weak self] token, review in
                    await self?.display(token, review: review, generation: expected)
                },
                onOutcome: { [weak self] outcome in
                    await self?.outcome(outcome, generation: expected)
                })
            guard generation == expected, !Task.isCancelled else {
                await composition.actions.close()
                if generation == expected { throw CancellationError() }
                return
            }
            self.composition = composition
            listener = SignedLocalListener(service: config.service, peer: config.peer) {
                [weak self] gate in
                guard let self else { throw LocalBridgeFailure.unavailable }
                return try await self.bind(gate, generation: expected)
            }
            phase = .listening
            message = "Waiting for the sample helper. Each change needs its own native review."
            await updateJournal()
        } catch {
            if generation == expected {
                phase = .unavailable
                message =
                    "Sample session unavailable. A missing, busy or unresolved journal is never reset automatically."
                if journal != nil { await updateJournal() }
            }
        }
    }
    private func bind(_ gate: LocalPeerGate, generation expected: UUID) async throws
        -> LocalReadHandler
    {
        guard generation == expected, phase == .listening, broker == nil, gate.isAuthenticated,
            let composition
        else {
            throw LocalBridgeFailure.unavailable
        }
        let channel = ConnectionChannel(verify: { gate.isAuthenticated })
        let candidate = try await composition.broker(channel: channel)
        guard expected == generation, phase == .listening, broker == nil, gate.isAuthenticated
        else {
            await candidate.close()
            throw LocalBridgeFailure.unavailable
        }
        broker = candidate
        do {
            let pending = try await candidate.prepareReview()
            guard expected == generation, gate.isAuthenticated else {
                throw LocalBridgeFailure.unavailable
            }
            connectionReview = pending.id
            phase = .connectionReview
            return LocalReadHandler(
                request: { await candidate.request($0) },
                close: { [weak self] in
                    await candidate.close()
                    await self?.stop(generation: expected)
                })
        } catch {
            await stop(generation: expected)
            throw error
        }
    }
    public func approveConnection() async {
        guard phase == .connectionReview, let id = connectionReview, let broker else { return }
        connectionReview = nil
        let expected = generation
        do {
            try await broker.approve(id)
            guard generation == expected else { return }
            phase = .connected
            message =
                "Sample connection approved. Proposals cannot execute without exact native approval."
        } catch { await stop(generation: expected) }
    }
    private func display(_ token: String?, review: PrivateWriteReview?, generation expected: UUID) {
        guard generation == expected, phase == .connected || phase == .connectionReview else {
            return
        }
        self.token = token
        self.review = review
        if review != nil {
            message = "Review the exact proposed sample change. Nothing has executed."
        }
    }
    public func confirm(_ id: UUID, acknowledgeDeletion: Bool) async {
        guard !busy, phase == .connected, review?.id == id, let token, let composition else {
            return
        }
        busy = true
        self.token = nil
        review = nil
        let expected = generation
        defer { if generation == expected { busy = false } }
        let previousOutcome = outcomeVersion
        do {
            try await composition.actions.confirm(token, deletion: acknowledgeDeletion)
            if generation == expected, previousOutcome == outcomeVersion {
                message =
                    "Exact change approved for one commit within 30 seconds. No effect until the client commits."
            }
        } catch {
            await composition.actions.reject(token)
            if generation == expected {
                message = "Approval rejected or expired. No change authorized."
            }
        }
    }
    public func reject(_ id: UUID) async {
        guard !busy, review?.id == id, let token else { return }
        self.token = nil
        review = nil
        let expected = generation
        await composition?.actions.reject(token)
        if generation == expected { message = "Proposal rejected. No change approved." }
    }
    private func outcome(_ value: ActionOutcome, generation expected: UUID) async {
        // A stopped session still drains its receipt; stop reads the journal after that drain.
        guard generation == expected else { return }
        outcomeVersion &+= 1
        message =
            value == .unknown
            ? "Outcome unknown. Further changes blocked; do not retry."
            : "Last dispatched sample outcome: " + value.rawValue + "."
        await updateJournal()
    }
    private func configuration() throws -> PrivateBridgeConfiguration {
        let config = try PrivateBridgeConfiguration.load(helper: false)
        guard config.mode == .sampleWrites, config.installation != nil else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        if let canary = config.sandboxCanary, (try? Data(contentsOf: canary)) != nil {
            throw LocalBridgeFailure.unavailable
        }
        return config
    }
    private func openJournal(_ config: PrivateBridgeConfiguration) throws -> ReminderMutationJournal
    {
        if let journal { return journal }
        guard let installation = config.installation else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true
        ).resolvingSymlinksInPath()
        let directory = support.appendingPathComponent(
            "MacHandleSampleActions-" + installation.uuidString, isDirectory: true)
        let mode: PersistenceOpenMode =
            FileManager.default.fileExists(atPath: directory.path) ? .resume : .createNew
        let opened = try ReminderMutationJournal(
            directory: directory, installation: installation, mode: mode)
        journal = opened
        return opened
    }
    /// Native-only inspection. Opens the same sealed store; never starts transport or a provider.
    public func inspectRecovery() async {
        guard phase == .idle || phase == .closed || phase == .unavailable else { return }
        let previous = phase
        let expected = generation
        phase = .inspecting
        do {
            _ = try openJournal(configuration())
            await updateJournal()
            guard generation == expected else { return }
            phase = previous
            message = recovery?.guidance ?? "Recovery unavailable. No changes authorized."
        } catch {
            guard generation == expected else { return }
            recovery = nil
            journalStatus = "Journal unavailable; do not retry uncertain work."
            phase = .unavailable
            message = "Recovery unavailable. Missing, busy or invalid storage is never replaced."
        }
    }
    private func updateJournal() async {
        let expected = generation
        guard let journal, let records = try? await journal.records() else {
            if generation == expected {
                recovery = nil
                journalStatus = "Journal unavailable; do not retry uncertain work."
            }
            return
        }
        guard generation == expected else { return }
        let summary = SampleRecoverySummary(records: records)
        recovery = summary
        journalStatus = summary.status
    }
    /// Explicit opt-in after a completed shutdown; no listener, selection or approval is reused.
    public func prepareFreshSession() async {
        guard phase == .closed, !busy else { return }
        let expected = generation
        phase = .inspecting
        await updateJournal()
        guard generation == expected else { return }
        guard recovery?.permitsFreshSession == true else {
            phase = .closed
            message = recovery?.guidance ?? "Journal unavailable; new sessions stay blocked."
            return
        }
        generation = UUID()
        phase = .idle
        message =
            "Choose the Sample list again. New sample contents and fresh approvals are required."
    }
    private func stop(generation expected: UUID) async {
        guard generation == expected else { return }
        await stop()
    }
    public func stop() async {
        if phase == .stopping {
            await withCheckedContinuation { stopWaiters.append($0) }
            return
        }
        guard phase != .closed else { return }
        generation = UUID()
        phase = .stopping
        listener?.close()
        listener = nil
        connectionReview = nil
        token = nil
        review = nil
        message =
            "Connection closed. Waiting for accepted work to record its outcome. Do not retry."
        await broker?.close(revoke: true)
        await composition?.actions.close()
        broker = nil
        composition = nil
        busy = false
        await updateJournal()
        phase = .closed
        message =
            "Session stopped. Old approvals cannot be reused. Inspect recovery before starting fresh."
        let waiters = stopWaiters
        stopWaiters = []
        for waiter in waiters { waiter.resume() }
        // Journal stays open for read-only recovery; neither stop nor restart resets its evidence.
    }
    deinit { listener?.close() }
}

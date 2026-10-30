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
        case idle, starting, listening, connectionReview, connected, closed, unavailable
    }
    public private(set) var phase: Phase = .idle
    public private(set) var review: PrivateWriteReview?
    public private(set) var message = "Sample changes are off. No personal Reminders are connected."
    public private(set) var journalStatus = "Journal not opened."
    public private(set) var busy = false
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
            let config = try PrivateBridgeConfiguration.load(helper: false)
            guard config.mode == .sampleWrites, let installation = config.installation else {
                throw LocalBridgeFailure.invalidConfiguration
            }
            if let canary = config.sandboxCanary, (try? Data(contentsOf: canary)) != nil {
                throw LocalBridgeFailure.unavailable
            }
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true
            ).resolvingSymlinksInPath()
            let directory = support.appendingPathComponent(
                "MacHandleSampleActions-" + installation.uuidString, isDirectory: true)
            let mode: PersistenceOpenMode =
                FileManager.default.fileExists(atPath: directory.path) ? .resume : .createNew
            let journal = try ReminderMutationJournal(
                directory: directory, installation: installation, mode: mode)
            self.journal = journal
            let composition = try await SampleWriteComposition.make(
                journal: journal,
                onReview: { [weak self] token, review in await self?.display(token, review: review)
                },
                onOutcome: { [weak self] outcome in await self?.outcome(outcome) })
            guard generation == expected, !Task.isCancelled else {
                await composition.actions.close()
                return
            }
            self.composition = composition
            listener = SignedLocalListener(service: config.service, peer: config.peer) {
                [weak self] gate in
                guard let self else { throw LocalBridgeFailure.unavailable }
                return try await self.bind(gate)
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
    private func bind(_ gate: LocalPeerGate) async throws -> LocalReadHandler {
        guard phase == .listening, broker == nil, gate.isAuthenticated, let composition else {
            throw LocalBridgeFailure.unavailable
        }
        let expected = generation
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
                    await self?.stop()
                })
        } catch {
            await stop()
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
        } catch { await stop() }
    }
    private func display(_ token: String?, review: PrivateWriteReview?) {
        guard phase == .connected || phase == .connectionReview else { return }
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
        defer { busy = false }
        let expected = generation
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
    private func outcome(_ value: ActionOutcome) async {
        outcomeVersion &+= 1
        message =
            value == .unknown
            ? "Outcome unknown. Further changes blocked; do not retry."
            : "Last dispatched sample outcome: " + value.rawValue + "."
        await updateJournal()
    }
    private func updateJournal() async {
        guard let journal, let records = try? await journal.records() else {
            journalStatus = "Journal unavailable; do not retry uncertain work."
            return
        }
        journalStatus =
            "Journal: \(records.filter { $0.state == .applied }.count) applied; \(records.filter { $0.state == .notApplied }.count) not applied; \(records.filter { $0.state == .pending || $0.state == .unknown }.count) unresolved."
    }
    public func stop() async {
        guard phase != .closed else { return }
        generation = UUID()
        listener?.close()
        listener = nil
        connectionReview = nil
        token = nil
        review = nil
        phase = .closed
        message =
            "Connection closed. Already dispatched work may finish; journal records its actual outcome."
        await broker?.close(revoke: true)
        await composition?.actions.close()
        await updateJournal()
        // Do not close storage beneath accepted work. Its owner outlives any in-flight dispatch.
    }
    deinit { listener?.close() }
}

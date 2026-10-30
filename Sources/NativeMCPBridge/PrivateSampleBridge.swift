import CoreDomain
import Foundation
import LocalBridgeTransport
import MCPConnections
import MCPRemindersAdapter
import PermissionEngine

package enum PrivateConnectionState: Sendable {
    case listening
    case review(UUID)
    case connected, closed, unavailable
}

/// Native authority for the private read apps. Approval is never part of the helper wire.
@MainActor
package final class PrivateSampleBridge {
    private let source: any ReminderDiscovering & ReminderReading
    private let selection: PrivateReminderSelection
    private let selectedWorkflow: Bool
    nonisolated package static func sampleSource() throws -> any ReminderDiscovering
        & ReminderReading
    {
        try SyntheticReminderSource()
    }
    nonisolated package static func validSelectedPackage(isolated: Bool) -> Bool {
        guard let config = try? PrivateBridgeConfiguration.load(helper: false) else { return false }
        return config.mode == (isolated ? .isolated : .selectedSample)
    }
    private var listener: SignedLocalListener?
    private var broker: NativeReadBroker?
    private var reviewID: UUID?
    private var stopped = false
    private let changed: @MainActor @Sendable (PrivateConnectionState) -> Void

    package convenience init(
        changed: @escaping @MainActor @Sendable (PrivateConnectionState) -> Void
    ) throws {
        let sample = try SyntheticReminderSource()
        try self.init(
            source: sample,
            selection: PrivateReminderSelection(
                lists: [sample.list], fields: [.title, .completion]), mode: .sample,
            changed: changed)
    }
    package convenience init(
        source: any ReminderDiscovering & ReminderReading, selection: PrivateReminderSelection,
        isolated: Bool, changed: @escaping @MainActor @Sendable (PrivateConnectionState) -> Void
    ) throws {
        try self.init(
            source: source, selection: selection, mode: isolated ? .isolated : .selectedSample,
            changed: changed)
    }
    private init(
        source: any ReminderDiscovering & ReminderReading, selection: PrivateReminderSelection,
        mode: PrivateBridgeConfiguration.Mode,
        changed: @escaping @MainActor @Sendable (PrivateConnectionState) -> Void
    ) throws {
        self.changed = changed
        self.source = SelectedReminderReader(source: source, selection: selection)
        self.selection = selection
        selectedWorkflow = mode != .sample
        let config = try PrivateBridgeConfiguration.load(helper: false)
        guard config.mode == mode else { throw LocalBridgeFailure.invalidConfiguration }
        if let canary = config.sandboxCanary {
            // Acceptance-only sealed configuration: the harness creates this synthetic file first.
            // No content is logged. Successful access refuses activation instead of claiming isolation.
            guard (try? Data(contentsOf: canary)) == nil else {
                throw LocalBridgeFailure.unavailable
            }
        }
        listener = SignedLocalListener(service: config.service, peer: config.peer) {
            [weak self] gate in
            guard let self else { throw LocalBridgeFailure.unavailable }
            return try await self.bind(gate)
        }
        changed(.listening)
    }
    private func bind(_ gate: LocalPeerGate) async throws -> LocalReadHandler {
        guard !stopped, broker == nil, gate.isAuthenticated else {
            throw LocalBridgeFailure.unavailable
        }
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        guard case .observed = await source.discoverReminderLists(), !stopped else {
            throw LocalBridgeFailure.unavailable
        }
        await controller.observePermissions(OSPermissions(reminders: await source.authorization()))
        let grants = try selection.lists.map { list in
            try SavedReminderGrant(
                reference: list,
                operations: selectedWorkflow
                    ? [.discover, .summary, .details] : [.discover, .summary],
                fields: selection.fields.map { field in
                    switch field {
                    case .title: .title
                    case .notes: .notes
                    case .due: .due
                    case .completion: .completion
                    case .recurrence: .recurrence
                    }
                })
        }
        let record = try await controller.configure(
            label: selectedWorkflow
                ? "Selected Reminders helper launch" : "Private sample helper launch", grants: [],
            reminderGrants: grants)
        let channel = ConnectionChannel(verify: { gate.isAuthenticated })
        let candidate = NativeReadBroker(
            controller: controller, channel: channel, record: record, reader: source,
            authorization: { [source] in await source.authorization() })
        guard !stopped, broker == nil, gate.isAuthenticated else {
            await candidate.close()
            throw LocalBridgeFailure.unavailable
        }
        broker = candidate
        do {
            let review = try await candidate.prepareReview()
            guard !stopped, gate.isAuthenticated else { throw LocalBridgeFailure.unavailable }
            reviewID = review.id
            changed(.review(review.id))
            return LocalReadHandler(
                request: { await candidate.request($0) },
                close: { [weak self] in
                    await candidate.close()
                    await self?.channelClosed()
                })
        } catch {
            await stop()
            throw error
        }
    }
    package func approve(_ id: UUID) async {
        guard !stopped, reviewID == id, let broker else { return }
        reviewID = nil
        do {
            guard case .observed = await source.discoverReminderLists(), !stopped else {
                throw LocalBridgeFailure.unavailable
            }
            try await broker.approve(id)
            guard !stopped else { return }
            changed(.connected)
        } catch { await stop() }
    }
    package func stop() async {
        guard !stopped else { return }
        stopped = true
        reviewID = nil
        listener?.close()
        listener = nil
        let old = broker
        broker = nil
        changed(.closed)
        await old?.close(revoke: true)
    }
    private func channelClosed() async { await stop() }
    deinit { listener?.close() }
}

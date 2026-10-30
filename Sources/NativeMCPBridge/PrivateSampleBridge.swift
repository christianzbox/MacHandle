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

/// Native authority for the private sample app. Approval is never part of the helper wire.
@MainActor
package final class PrivateSampleBridge {
    private var listener: SignedLocalListener?
    private var broker: NativeReadBroker?
    private var reviewID: UUID?
    private var stopped = false
    private let changed: @MainActor @Sendable (PrivateConnectionState) -> Void

    package init(changed: @escaping @MainActor @Sendable (PrivateConnectionState) -> Void) throws {
        self.changed = changed
        let config = try PrivateBridgeConfiguration.load(helper: false)
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
        let source = try SyntheticReminderSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: source.list, operations: [.discover, .summary],
            fields: [.title, .completion])
        let record = try await controller.configure(
            label: "Private sample helper launch", grants: [], reminderGrants: [grant])
        let channel = ConnectionChannel(verify: { gate.isAuthenticated })
        let candidate = NativeReadBroker(
            controller: controller, channel: channel, record: record, reader: source,
            authorization: { .fullAccess })
        guard !stopped, gate.isAuthenticated else {
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

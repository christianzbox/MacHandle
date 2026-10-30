import CoreDomain
import Foundation
import LocalBridgeTransport
import MCPConnections
import MCPRemindersAdapter
import PermissionEngine

/// Isolated executable fixture only. The native app has no factory that selects this composition.
package enum ExternalSampleBroker {
    package static func make(gate: LocalPeerGate, approved: Bool) async throws -> LocalReadHandler {
        let source = try SyntheticReminderSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: source.list, operations: [.discover, .summary],
            fields: [.title, .completion])
        let record = try await controller.configure(
            label: "External sample helper", grants: [], reminderGrants: [grant])
        // The transport opens this exact channel's gate only after kernel-enforced peer checking.
        let channel = ConnectionChannel(verify: { gate.isAuthenticated })
        let broker = NativeReadBroker(
            controller: controller, channel: channel, record: record, reader: source,
            authorization: { .fullAccess })
        do {
            let review = try await broker.prepareReview()
            // Harness-local fixture decision, never helper input or an exported approval operation.
            if approved { try await broker.approve(review.id) }
            return LocalReadHandler(
                request: { await broker.request($0) }, close: { await broker.close() })
        } catch {
            await broker.close()
            throw error
        }
    }
}

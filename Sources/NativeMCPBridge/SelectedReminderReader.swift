import CoreDomain
import Foundation

/// Immutable native selection. The helper cannot expand lists or requested fields.
package struct PrivateReminderSelection: Sendable {
    package let lists: Set<ReminderListReference>
    package let fields: Set<ReminderReadField>
    package init(lists: Set<ReminderListReference>, fields: Set<ReminderReadField>) throws {
        guard !lists.isEmpty, lists.count <= 32, !fields.isEmpty else {
            throw ProviderFailure.invalidData
        }
        self.lists = lists
        self.fields = fields
    }
}

/// Defense in depth before the public provider, independently of MCP policy projection.
package struct SelectedReminderReader: ReminderDiscovering, ReminderReading {
    package let source: any ReminderDiscovering & ReminderReading
    package let selection: PrivateReminderSelection
    package init(
        source: any ReminderDiscovering & ReminderReading, selection: PrivateReminderSelection
    ) {
        self.source = source
        self.selection = selection
    }
    package func authorization() async -> OSAuthorization { await source.authorization() }
    // Only the native setup model may request permission; a broker cannot do so.
    package func requestAccess() async -> OSAuthorization { await authorization() }
    package func changes() async -> AsyncStream<Void> { await source.changes() }
    package func discoverReminderLists() async -> ProviderReadResult<
        ResourceDiscovery<ReminderList>
    > {
        guard !Task.isCancelled, await authorization() == .fullAccess else {
            return .failed(.denied)
        }
        let result = await source.discoverReminderLists()
        guard !Task.isCancelled, await authorization() == .fullAccess else {
            return .failed(.revoked)
        }
        guard case .observed(let inventory) = result,
            inventory.observation.completeness == .complete,
            inventory.resources.count <= 1000,
            Set(inventory.resources.map(\.id)).count == inventory.resources.count,
            selection.lists.isSubset(of: Set(inventory.resources.map(\.id)))
        else { return .failed(.unavailable) }
        return .observed(
            ResourceDiscovery(
                resources: inventory.resources.filter { selection.lists.contains($0.id) },
                observation: inventory.observation))
    }
    package func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        guard request.lists.isSubset(of: selection.lists), fields.isSubset(of: selection.fields),
            !fields.isEmpty
        else { return .failed(.denied) }
        guard case .observed = await discoverReminderLists() else { return .failed(.unavailable) }
        let result = await source.readReminders(request, fields: fields)
        guard !Task.isCancelled, await authorization() == .fullAccess else {
            return .failed(.revoked)
        }
        guard case .observed(let snapshot) = result, snapshot.coverage == request else {
            return .failed(.unavailable)
        }
        return result
    }
}

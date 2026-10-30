import CoreDomain
import Foundation
import MCPConnections
import MCPRemindersAdapter
import MCPServer
import PermissionEngine

/// The only app composition is fixed fixtures, memory settings and an unpublished anonymous endpoint.
package struct SampleBridgeSession: Sendable {
    package let broker: NativeReadBroker
    let transport: SampleXPCTransport

    package static func make() async throws -> Self {
        let source = try SyntheticReminderSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        // Fixture OS observation only. This never calls EventKit or requests permission.
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: source.list, operations: [.discover, .summary],
            fields: [.title, .completion])
        let record = try await controller.configure(
            label: "Sample helper launch", grants: [], reminderGrants: [grant])
        // Explicit synthetic peer, not signing proof.
        let channel = ConnectionChannel(verify: { true })
        let broker = NativeReadBroker(
            controller: controller, channel: channel, record: record, reader: source,
            authorization: { .fullAccess })
        return Self(broker: broker, transport: SampleXPCTransport(broker: broker, channel: channel))
    }
    package func readSampleTitles() async throws -> [String] {
        let discovery = try await call("list_reminder_lists", arguments: [:])
        guard let lists = discovery["lists"]?.array, lists.count == 1,
            let id = lists.first?["listId"]?.string
        else { throw SampleBridgeFailure.unavailable }
        let found = try await call(
            "search_reminders",
            arguments: [
                "listIds": .array([.string(id)]), "query": .string(""),
                "fields": .array([.string("title"), .string("completion")]), "limit": .number(5),
            ])
        guard let items = found["reminders"]?.array else { throw SampleBridgeFailure.unavailable }
        return try items.map {
            guard let title = $0["fields"]?["title"]?["value"]?.string else {
                throw SampleBridgeFailure.unavailable
            }
            return title
        }
    }
    package func call(_ tool: String, arguments: [String: MCPJSON]) async throws -> MCPJSON {
        let request = try MCPJSON.object([
            "version": .number(1), "tool": .string(tool), "arguments": .object(arguments),
        ]).encoded()
        let data = await transport.send(request)
        var parser = try MCPJSONParser(data)
        guard let result = try parser.parse()["result"] else {
            throw SampleBridgeFailure.unavailable
        }
        return result
    }
    package func close(revoke: Bool = false) async {
        transport.close()
        await broker.close(revoke: revoke)
    }
}
package enum SampleBridgeFailure: Error { case unavailable }

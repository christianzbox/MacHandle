import CoreDomain
import Foundation
import MCPConnections
import MCPRemindersAdapter
import MCPServer
import PermissionEngine

/// App-owned administration. None of these pairing methods is exported through XPC.
package actor NativeReadBroker {
    package struct Review: Sendable {
        package let id: UUID
        package let label: String
    }
    private let controller: ConnectionController
    private let channel: ConnectionChannel
    private let record: SavedConnection
    private let reader: any ReminderReading & ReminderDiscovering
    private let authorization: @Sendable () async -> OSAuthorization
    private var pending: PendingConnection?
    private var review: (UUID, PairingReview)?
    private var lease: ConnectionReadLease?
    private var tools: [MCPTool] = []
    private var closed = false
    private var preparing = false

    package init(
        controller: ConnectionController, channel: ConnectionChannel, record: SavedConnection,
        reader: any ReminderReading & ReminderDiscovering,
        authorization: @escaping @Sendable () async -> OSAuthorization
    ) {
        self.controller = controller
        self.channel = channel
        self.record = record
        self.reader = reader
        self.authorization = authorization
    }

    package func prepareReview() async throws -> Review {
        guard !closed, !preparing, pending == nil else { throw ConnectionFailure.denied }
        preparing = true
        defer { preparing = false }
        let request = try await controller.requestPairing(channel)
        guard !closed, channel.isOpen else {
            await controller.close(request)
            throw ConnectionFailure.closed
        }
        pending = request
        let value = try await controller.review(request, connection: record.id)
        guard !closed else { throw ConnectionFailure.closed }
        let id = UUID()
        review = (id, value)
        return Review(id: id, label: value.connection.label)
    }

    package func approve(_ id: UUID) async throws {
        guard !closed, let current = review, current.0 == id else {
            throw ConnectionFailure.denied
        }
        review = nil
        let approved = try await controller.approve(current.1)
        guard !closed, approved.isOpen else { throw ConnectionFailure.closed }
        let adapter = try ReminderReadAdapter(
            lease: approved, reader: reader, authorization: authorization)
        lease = approved
        tools = adapter.tools()
    }

    /// One channel-bound read envelope; no caller identity, grants, approvals or mutations.
    package func request(_ data: Data) async -> Data {
        guard !closed, let lease, lease.isOpen else { return Self.unavailable }
        do {
            guard data.count <= 16_384 else { return Self.invalid }
            var parser = try MCPJSONParser(data)
            let envelope = try parser.parse()
            guard let object = envelope.object,
                Set(object.keys) == ["version", "tool", "arguments"],
                envelope["version"]?.integer == 1, let name = envelope["tool"]?.string,
                let arguments = envelope["arguments"],
                let tool = tools.first(where: { $0.name == name })
            else { return Self.invalid }
            let result = try await tool.invoke(arguments)
            let encoded = try MCPJSON.object(["result": result.value]).encoded()
            guard encoded.count <= 32_768 else { return Self.unavailable }
            try await result.validate()
            guard !closed, lease.isOpen, !Task.isCancelled else { return Self.unavailable }
            return encoded
        } catch { return Self.unavailable }
    }

    package func close(revoke: Bool = false) async {
        // Close admission synchronously before any controller suspension.
        closed = true
        channel.close()
        tools = []
        lease = nil
        review = nil
        if revoke { try? await controller.revoke(record.id) }
        if let pending { await controller.close(pending) }
        pending = nil
    }
    package static let unavailable = Data(#"{"error":"unavailable"}"#.utf8)
    package static let invalid = Data(#"{"error":"invalidRequest"}"#.utf8)
}

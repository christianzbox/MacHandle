import CoreDomain
import Foundation
import MCPConnections
import MCPServer
import PermissionEngine
import ReminderMCPContract

/// Only a trusted, paired lease supplies identity and list selection. No caller-selected account.
package actor ReminderReadAdapter {
    private struct Handle {
        let reference: ReminderReference
        let expires: TimeInterval
    }
    private let lease: ConnectionReadLease
    private let reader: any ReminderReading & ReminderDiscovering
    private let authorization: @Sendable () async -> OSAuthorization
    private let uptime: @Sendable () -> TimeInterval
    private let lists: [String: ReminderListReference]
    private var handles: [String: Handle] = [:]
    package init(
        lease: ConnectionReadLease, reader: any ReminderReading & ReminderDiscovering,
        authorization: @escaping @Sendable () async -> OSAuthorization = { .unknown },
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) throws {
        guard lease.reminderSelection.count <= 32 else { throw ReminderReadFailure.unavailable }
        self.lease = lease
        self.reader = reader
        self.authorization = authorization
        self.uptime = uptime
        lists = Dictionary(
            uniqueKeysWithValues: lease.reminderSelection.map { (UUID().uuidString, $0) })
    }
    package nonisolated func tools() -> [MCPTool] {
        ReminderReadTools.make { name, args in
            switch name {
            case "list_reminder_lists":
                try await self.lease.perform(.reminderDiscovery) { try await self.discover() }
            case "search_reminders":
                try await self.lease.perform(.reminderSearch) { try await self.search(args) }
            case "get_reminder":
                try await self.lease.perform(.reminderDetail) { try await self.detail(args) }
            default: throw ReminderReadFailure.unavailable
            }
        }
    }
    package func resolveForMutation(_ token: String, create: Bool) async throws -> (
        ReminderListReference, ReminderReference?
    ) {
        try await access()
        if create, let list = lists[token] { return (list, nil) }
        guard !create, let handle = handles[token], handle.expires > uptime(),
            lease.reminderSelection.contains(handle.reference.list)
        else { throw ReminderReadFailure.unavailable }
        return (handle.reference.list, handle.reference)
    }
    private func access() async throws {
        try Task.checkCancellation()
        guard lease.isOpen, await authorization() == .fullAccess, lease.isOpen else {
            throw ReminderReadFailure.unavailable
        }
        try Task.checkCancellation()
    }
    private func permit(_ request: PolicyRequest) async throws -> PolicyPermit {
        try await access()
        guard case .allowed(let value) = await lease.session.evaluate(request) else {
            throw ReminderReadFailure.unavailable
        }
        return value
    }
    private func reply(_ value: MCPJSON, permits: [PolicyPermit], expires: TimeInterval? = nil)
        async throws -> MCPToolResult
    {
        guard try value.encoded().count <= 16_384 else { throw ReminderReadFailure.unavailable }
        let validate: @Sendable () async throws -> Void = { [lease, authorization, uptime] in
            try Task.checkCancellation()
            guard lease.isOpen, await authorization() == .fullAccess else {
                throw ReminderReadFailure.unavailable
            }
            for permit in permits {
                guard case .allowed = await lease.session.revalidate(permit) else {
                    throw ReminderReadFailure.unavailable
                }
            }
            guard lease.isOpen, expires == nil || uptime() < expires! else {
                throw ReminderReadFailure.unavailable
            }
            try Task.checkCancellation()
        }
        try await validate()
        return MCPToolResult(value: value, validate: validate)
    }
    private func fields(_ args: [String: MCPJSON]) throws -> Set<ReminderField> {
        guard let values = args["fields"]?.array else { throw ReminderReadFailure.unavailable }
        return try Set(
            values.map { value in
                switch value.string {
                case "title": .title
                case "notes": .notes
                case "due": .due
                case "completion": .completion
                case "recurrence": .recurrence
                default: throw ReminderReadFailure.unavailable
                }
            })
    }
    private func read(
        _ request: ReminderReadRequest, operation: ReminderOperation, fields: Set<ReminderField>
    ) async throws -> (ReminderSnapshot, PolicyPermit) {
        let permit = try await permit(
            .reminderRead(request.lists, operation: operation, fields: fields))
        let fetch: Set<ReminderReadField> = Set(
            fields.map {
                switch $0 {
                case .title: .title
                case .notes: .notes
                case .due: .due
                case .completion: .completion
                case .recurrence: .recurrence
                }
            })
        let result = await reader.readReminders(request, fields: fetch)
        try await access()
        guard case .observed(let snapshot) = result, snapshot.coverage == request,
            case .value(let filtered) = await lease.session.filterReminders(
                snapshot.reminders, using: permit)
        else { throw ReminderReadFailure.unavailable }
        return (
            try ReminderSnapshot(
                coverage: request, reminders: filtered, observation: snapshot.observation), permit
        )
    }
    func discover() async throws -> MCPToolResult {
        try await access()
        var permits: [PolicyPermit] = []
        for ref in lists.values {
            if case .allowed(let permit) = await lease.session.evaluate(.reminderDiscovery([ref])) {
                permits.append(permit)
            }
        }
        guard !permits.isEmpty else { throw ReminderReadFailure.unavailable }
        let result = await reader.discoverReminderLists()
        try await access()
        guard case .observed(let inventory) = result, inventory.resources.count <= 1000 else {
            throw ReminderReadFailure.unavailable
        }
        var visible: [ReminderList] = []
        for permit in permits {
            guard
                case .value(let value) = await lease.session.filterReminderDiscovery(
                    inventory, using: permit)
            else { throw ReminderReadFailure.unavailable }
            visible += value.resources
        }
        guard Set(visible.map(\.id)).count == visible.count else {
            throw ReminderReadFailure.unavailable
        }
        let items = try visible.map { list -> MCPJSON in
            guard let token = lists.first(where: { $0.value == list.id })?.key,
                list.name.utf8.count <= 1024
            else { throw ReminderReadFailure.unavailable }
            return .object(["listId": .string(token), "name": .string(list.name)])
        }.sorted { $0["listId"]!.string! < $1["listId"]!.string! }
        return try await reply(
            .object([
                "lists": .array(items),
                "observation": ReminderJSON.observation(inventory.observation),
            ]), permits: permits)
    }
    func search(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        guard let tokens = args["listIds"]?.array, let query = args["query"]?.string,
            query.utf8.count <= 256, let limit = args["limit"]?.integer, (1...100).contains(limit)
        else { throw ReminderReadFailure.unavailable }
        let selected = try Set(
            tokens.map { value -> ReminderListReference in
                guard let token = value.string, let ref = lists[token] else {
                    throw ReminderReadFailure.unavailable
                }
                return ref
            })
        let fields = try fields(args)
        guard !fields.contains(.notes), query.isEmpty || fields.contains(.title) else {
            throw ReminderReadFailure.unavailable
        }
        let (snapshot, permit) = try await read(
            ReminderReadRequest(lists: selected), operation: .readSummary, fields: fields)
        if !query.isEmpty {
            guard
                snapshot.reminders.allSatisfy({
                    if case .value = $0.title { return true }
                    return false
                })
            else { throw ReminderReadFailure.unavailable }
        }
        let matches = snapshot.reminders.filter {
            guard !query.isEmpty else { return true }
            guard case .value(let title) = $0.title else { return false }
            return title.range(
                of: query, options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
                != nil
        }.sorted { String(describing: $0.id) < String(describing: $1.id) }
        handles = handles.filter { $0.value.expires > uptime() }
        let subset = Array(matches.prefix(limit))
        guard handles.count + subset.count <= 512 else { throw ReminderReadFailure.unavailable }
        let items = try subset.map { value -> MCPJSON in
            let token = UUID().uuidString
            handles[token] = Handle(reference: value.id, expires: uptime() + 300)
            return try encode(value, token: token, fields: fields)
        }
        let truncated = matches.count > limit
        return try await reply(
            .object([
                "reminders": .array(items), "truncated": .bool(truncated),
                "observation": ReminderJSON.observation(snapshot.observation, truncated: truncated),
            ]), permits: [permit])
    }
    func detail(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        guard let token = args["reminderId"]?.string, let handle = handles[token],
            handle.expires > uptime()
        else { throw ReminderReadFailure.unavailable }
        let fields = try fields(args)
        let (snapshot, permit) = try await read(
            ReminderReadRequest(lists: [handle.reference.list], item: handle.reference),
            operation: .readDetails, fields: fields)
        let reminder = snapshot.reminders.first
        return try await reply(
            .object([
                "reminder": try reminder.map { try encode($0, token: token, fields: fields) }
                    ?? .null,
                "status": .string(reminder == nil ? "notObserved" : "found"),
                "absenceProvesDeletion": .bool(false),
                "observation": ReminderJSON.observation(snapshot.observation),
            ]), permits: [permit], expires: handle.expires)
    }
    private func encode(_ value: Reminder, token: String, fields: Set<ReminderField>) throws
        -> MCPJSON
    {
        guard let list = lists.first(where: { $0.value == value.id.list })?.key else {
            throw ReminderReadFailure.unavailable
        }
        return try ReminderJSON.reminder(value, token: token, list: list, fields: fields)
    }
}

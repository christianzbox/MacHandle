import ActionApprovals
import CoreDomain
import Foundation
import MCPServer
import ReminderMCPContract

/// Trusted composition supplies a bound engine and target resolver. No live factory or wire approval.
actor ReminderMutationAdapter {
    private struct Entry {
        let review: ReminderReview
        let expires: TimeInterval
        var confirmation: ReminderConfirmation?
    }
    private let engine: ReminderApprovalEngine
    private let resolve:
        @Sendable (String, Bool) async throws -> (ReminderListReference, ReminderReference?)
    private let authorized: @Sendable () async -> Bool
    private let uptime: @Sendable () -> TimeInterval
    private var entries: [String: Entry] = [:]
    private var preparing = 0
    init(
        engine: ReminderApprovalEngine,
        resolve:
            @escaping @Sendable (String, Bool) async throws -> (
                ReminderListReference, ReminderReference?
            ),
        authorized: @escaping @Sendable () async -> Bool = { false },
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.engine = engine
        self.resolve = resolve
        self.authorized = authorized
        self.uptime = uptime
    }
    nonisolated func tools() -> [MCPTool] {
        [
            MCPTool(
                name: "propose_reminder_change",
                description:
                    "Prepare a Reminder create/update/setDue/complete/uncomplete/delete for local review. Does not execute or approve. This synthetic helper uses a separate sample connection: targetId sample-list for create or sample-reminder otherwise. No real data. Empty notes clears notes; empty dueDate clears due. No alarms, recurrence or list moves.",
                parameters: [
                    .init("operation", kind: .string(maximum: 10)),
                    .init("targetId", kind: .string(maximum: 36)),
                    .init("title", kind: .string(maximum: 512), required: false),
                    .init("notes", kind: .string(maximum: 4096), required: false),
                    .init("dueDate", kind: .string(maximum: 10), required: false),
                    .init("dueTime", kind: .string(maximum: 8), required: false),
                    .init("timeZone", kind: .string(maximum: 128), required: false),
                ],
                outputSchema: ReminderReadSchema.object([
                    "actionId": ReminderReadSchema.string,
                    "status": ReminderReadSchema.choice(["pendingLocalApproval"]),
                ]),
                execute: { try await self.propose($0) }),
            MCPTool(
                name: "commit_reminder_change",
                description:
                    "Execute exactly one previously locally confirmed Reminder action. An action ID is not approval. The standalone synthetic helper has no native approval channel, so its proposals cannot execute. Never retry an unknown result.",
                parameters: [.init("actionId", kind: .string(maximum: 36))],
                outputSchema: ReminderReadSchema.object([
                    "status": ReminderReadSchema.choice([
                        "notApproved", "applied", "notApplied", "unknown",
                    ])
                ]),
                execute: { try await self.commit($0) }),
        ]
    }
    private func access() async throws {
        try Task.checkCancellation()
        guard await authorized() else { throw ReminderReadFailure.unavailable }
        try Task.checkCancellation()
    }
    private func reply(_ value: MCPJSON) async throws -> MCPToolResult {
        try await access()
        return MCPToolResult(value: value, validate: { try await self.access() })
    }
    func propose(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        entries = entries.filter { $0.value.expires > uptime() }
        guard preparing < 4, entries.count + preparing < 16,
            let raw = args["operation"]?.string, let kind = ReminderActionKind(rawValue: raw),
            let token = args["targetId"]?.string
        else { throw ReminderReadFailure.unavailable }
        preparing += 1
        defer { preparing -= 1 }
        let allowed: Set<String>
        switch kind {
        case .create:
            allowed = ["operation", "targetId", "title", "notes", "dueDate", "dueTime", "timeZone"]
        case .update: allowed = ["operation", "targetId", "title", "notes"]
        case .setDue: allowed = ["operation", "targetId", "dueDate", "dueTime", "timeZone"]
        default: allowed = ["operation", "targetId"]
        }
        guard Set(args.keys).isSubset(of: allowed) else { throw ReminderReadFailure.unavailable }
        let (list, item) = try await resolve(token, kind == .create)
        try await access()
        let change: ReminderMutation
        if kind == .create {
            guard item == nil, let title = args["title"]?.string else {
                throw ReminderReadFailure.unavailable
            }
            change = .create(
                in: list,
                reminder: ReminderDraft(
                    title: title, notes: args["notes"]?.string,
                    due: try Self.due(args)))
        } else {
            guard let item, item.list == list else { throw ReminderReadFailure.unavailable }
            switch kind {
            case .create: throw ReminderReadFailure.unavailable
            case .update:
                let title: ValueChange<String> =
                    args["title"]?.string.map { .set($0) } ?? .unchanged
                let notes: ValueChange<String?> =
                    args["notes"]?.string.map { .set($0.isEmpty ? nil : $0) } ?? .unchanged
                change = .update(
                    item, changes: try ReminderChanges(title: title, notes: notes),
                    precondition: .unknown)
            case .setDue:
                guard args["dueDate"] != nil else { throw ReminderReadFailure.unavailable }
                change = .setDue(item, due: try Self.due(args), precondition: .unknown)
            case .complete: change = .complete(item, precondition: .unknown)
            case .uncomplete: change = .uncomplete(item, precondition: .unknown)
            case .delete: change = .delete(item, precondition: .unknown)
            }
        }
        let review = try await engine.prepare(change)
        do { try await access() } catch {
            await engine.reject(review)
            throw error
        }
        let id = UUID().uuidString
        entries[id] = Entry(review: review, expires: uptime() + 120)
        return try await reply(
            .object(["actionId": .string(id), "status": .string("pendingLocalApproval")]))
    }
    /// Trusted native surface only. Intentionally absent from the tool registry and all decoded inputs.
    func reviewForLocalDisplay(_ id: String) async throws -> ReminderReviewDisplay {
        try await access()
        guard let entry = entries[id], entry.expires > uptime() else {
            throw ReminderReadFailure.unavailable
        }
        return entry.review.display
    }
    func confirmLocally(_ id: String, acknowledgeDeletion: Bool = false) async throws {
        try await access()
        guard let entry = entries[id], entry.expires > uptime(), entry.confirmation == nil
        else { throw ReminderReadFailure.unavailable }
        let confirmation = try await engine.confirm(
            entry.review, acknowledgeDeletion: acknowledgeDeletion)
        guard entries[id] != nil else { throw ReminderReadFailure.unavailable }
        entries[id]?.confirmation = confirmation
    }
    func commit(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        guard Set(args.keys) == ["actionId"], let id = args["actionId"]?.string,
            let entry = entries[id], entry.expires > uptime(), let confirmation = entry.confirmation
        else { return try await reply(.object(["status": .string("notApproved")])) }
        entries.removeValue(forKey: id)
        let outcome = await engine.commit(confirmation)
        return try await reply(.object(["status": .string(outcome.rawValue)]))
    }
    static func due(_ args: [String: MCPJSON]) throws -> ReminderDue? {
        guard let raw = args["dueDate"]?.string, !raw.isEmpty else {
            guard args["dueTime"] == nil, args["timeZone"] == nil else {
                throw ReminderReadFailure.unavailable
            }
            return nil
        }
        func parts(_ raw: String, separator: Character, sizes: [Int]) throws -> [Int] {
            let components = raw.split(separator: separator, omittingEmptySubsequences: false)
            guard components.count == sizes.count else { throw ReminderReadFailure.unavailable }
            return try zip(components, sizes).map { value, size in
                guard value.count == size, value.utf8.allSatisfy({ (48...57).contains($0) }),
                    let number = Int(value)
                else { throw ReminderReadFailure.unavailable }
                return number
            }
        }
        let d = try parts(raw, separator: "-", sizes: [4, 2, 2])
        let date = try LocalDate(year: d[0], month: d[1], day: d[2])
        guard let time = args["dueTime"]?.string else {
            guard args["timeZone"] == nil else { throw ReminderReadFailure.unavailable }
            return .date(date)
        }
        let t = try parts(time, separator: ":", sizes: [2, 2, 2])
        return .localDateTime(
            date, try LocalTime(hour: t[0], minute: t[1], second: t[2]),
            timeZone: try args["timeZone"]?.string.map(TimeZoneID.init))
    }
}

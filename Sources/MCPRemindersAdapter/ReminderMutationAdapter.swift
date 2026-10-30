import ActionApprovals
import CoreDomain
import Foundation
import MCPServer
import ReminderMCPContract

/// Trusted composition supplies a bound engine and target resolver. No live factory or wire approval.
package actor ReminderMutationAdapter {
    private struct Entry {
        let review: ReminderReview
        let expires: TimeInterval
        var confirmation: ReminderConfirmation?
    }
    private let privateSession: Bool
    private let onReview: @Sendable (String?, ReminderReviewDisplay?) async -> Void
    private let onOutcome: @Sendable (ActionOutcome) async -> Void
    private var closed = false
    private let engine: ReminderApprovalEngine
    private let resolve:
        @Sendable (String, Bool) async throws -> (ReminderListReference, ReminderReference?)
    private let authorized: @Sendable () async -> Bool
    private let uptime: @Sendable () -> TimeInterval
    private var entries: [String: Entry] = [:]
    private var preparing = 0
    private var committing = 0
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    package init(
        engine: ReminderApprovalEngine,
        privateSession: Bool = false,
        onReview: @escaping @Sendable (String?, ReminderReviewDisplay?) async -> Void = { _, _ in },
        onOutcome: @escaping @Sendable (ActionOutcome) async -> Void = { _ in },
        resolve:
            @escaping @Sendable (String, Bool) async throws -> (
                ReminderListReference, ReminderReference?
            ),
        authorized: @escaping @Sendable () async -> Bool = { false },
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.engine = engine
        self.privateSession = privateSession
        self.onReview = onReview
        self.onOutcome = onOutcome
        self.resolve = resolve
        self.authorized = authorized
        self.uptime = uptime
    }
    package nonisolated func tools() -> [MCPTool] {
        ReminderMutationTools.make(privateSession: privateSession) { name, args in
            if name == "propose_reminder_change" { return try await self.propose(args) }
            return try await self.commit(args)
        }
    }
    private func access() async throws {
        try Task.checkCancellation()
        guard !closed, await authorized(), !closed else { throw ReminderReadFailure.unavailable }
        try Task.checkCancellation()
    }
    private func reply(_ value: MCPJSON) async throws -> MCPToolResult {
        try await access()
        return MCPToolResult(value: value, validate: { try await self.access() })
    }
    func propose(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        entries = entries.filter { $0.value.expires > uptime() }
        guard !privateSession || (entries.isEmpty && preparing == 0),
            preparing < 4, entries.count + preparing < 16,
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
        await onReview(id, review.display)
        return try await reply(
            .object(["actionId": .string(id), "status": .string("pendingLocalApproval")]))
    }
    /// Trusted native surface only. Intentionally absent from the tool registry and all decoded inputs.
    package func reviewForLocalDisplay(_ id: String) async throws -> ReminderReviewDisplay {
        try await access()
        guard let entry = entries[id], entry.expires > uptime() else {
            throw ReminderReadFailure.unavailable
        }
        return entry.review.display
    }
    package func confirmLocally(_ id: String, acknowledgeDeletion: Bool = false) async throws {
        try await access()
        guard let entry = entries[id], entry.expires > uptime(), entry.confirmation == nil
        else { throw ReminderReadFailure.unavailable }
        let confirmation = try await engine.confirm(
            entry.review, acknowledgeDeletion: acknowledgeDeletion)
        guard entries[id] != nil else { throw ReminderReadFailure.unavailable }
        entries[id]?.confirmation = confirmation
        await onReview(nil, nil)
    }
    func commit(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        guard Set(args.keys) == ["actionId"], let id = args["actionId"]?.string,
            let entry = entries[id], entry.expires > uptime(), let confirmation = entry.confirmation
        else { return try await reply(.object(["status": .string("notApproved")])) }
        entries.removeValue(forKey: id)
        committing += 1
        defer {
            committing -= 1
            if committing == 0 {
                let waiters = drainWaiters
                drainWaiters = []
                for waiter in waiters { waiter.resume() }
            }
        }
        await onReview(nil, nil)
        let outcome = await engine.commit(confirmation)
        await onOutcome(outcome)
        return try await reply(.object(["status": .string(outcome.rawValue)]))
    }
    package func rejectLocally(_ id: String) async {
        guard let entry = entries.removeValue(forKey: id) else { return }
        await engine.reject(entry.review)
        await onReview(nil, nil)
    }
    package func close() async {
        closed = true
        entries.removeAll()
        await engine.invalidate()
        await onReview(nil, nil)
        // Admission is closed, but accepted effects must finish recording their actual outcome.
        // Awaiting is reentrant: commit can deliver its native outcome and release these waiters.
        if committing > 0 { await withCheckedContinuation { drainWaiters.append($0) } }
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

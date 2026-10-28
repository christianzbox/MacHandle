import CoreDomain
import Foundation
import MCPConnections
import PermissionEngine
import Testing

@testable import MCPRemindersAdapter
@testable import MCPServer

private actor Gate {
    var entered = false
    var waiting: CheckedContinuation<Void, Never>?
    var held: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiting?.resume()
        waiting = nil
        await withCheckedContinuation { held = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { waiting = $0 } } }
    func release() {
        held?.resume()
        held = nil
    }
}
private actor Source: ReminderReading, ReminderDiscovering {
    let base: SyntheticReminderSource
    var gate: Gate?
    var empty = false
    var partial = false
    var access: OSAuthorization = .fullAccess
    var reads = 0
    var cancelled = false
    var fetched: Set<ReminderReadField> = []
    init(_ base: SyntheticReminderSource) { self.base = base }
    func configure(
        gate: Gate? = nil, empty: Bool = false, partial: Bool = false,
        access: OSAuthorization = .fullAccess
    ) {
        self.gate = gate
        self.empty = empty
        self.partial = partial
        self.access = access
    }
    func authorization() -> OSAuthorization { access }
    func requestAccess() -> OSAuthorization { access }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverReminderLists() async -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        base.discoverReminderLists()
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        reads += 1
        fetched = fields
        if let gate { await gate.enter() }
        cancelled = Task.isCancelled
        do {
            return .observed(
                try ReminderSnapshot(
                    coverage: request, reminders: empty ? [] : [base.reminder],
                    observation: ObservationState(
                        observedAt: base.observation.observedAt,
                        completeness: partial ? .partial(.providerLimit) : .complete,
                        freshness: .localCache)))
        } catch { return .failed(.invalidData) }
    }
}
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 0
    func now() -> TimeInterval { lock.withLock { time } }
    func expire() { lock.withLock { time += 301 } }
}
private func args(
    _ adapter: ReminderReadAdapter, query: String = "grocery", fields: [String] = ["title"]
) async throws -> [String: MCPJSON] {
    let result = try await adapter.discover()
    let id = try #require(result.value["lists"]?.array?.first?["listId"]?.string)
    return [
        "listIds": .array([.string(id)]), "query": .string(query),
        "fields": .array(fields.map(MCPJSON.string)), "limit": .number(10),
    ]
}
private func token(_ result: MCPToolResult) throws -> String {
    try #require(result.value["reminders"]?.array?.first?["reminderId"]?.string)
}
struct ReminderReadTests {
    @Test func discoverySearchAndExactDetailProjectOnlyRequestedPermittedFields() async throws {
        let f = try await SyntheticReminderFixture.make()
        let input = try await args(f.adapter, fields: ["title", "due", "recurrence"])
        let search = try await f.adapter.search(input)
        #expect(search.value["reminders"]?.array?.count == 1)
        let detail = try await f.adapter.detail([
            "reminderId": .string(token(search)), "fields": .array([.string("completion")]),
        ])
        #expect(detail.value["status"]?.string == "found")
        #expect(
            detail.value["reminder"]?["fields"]?["completion"]?["value"]?["completed"]
                == .bool(false))
        for result in [try await f.adapter.discover(), search, detail] {
            let text = String(decoding: try result.value.encoded(), as: UTF8.self)
            #expect(
                !text.contains("private") && !text.contains("canary")
                    && !text.contains("Hidden list"))
        }
    }
    @Test func notesAndTitleQueriesRequireIndependentFieldPermissionBeforeFetch() async throws {
        let f = try await SyntheticReminderFixture.make(fields: [.due, .completion])
        let source = Source(f.source)
        let adapter = try ReminderReadAdapter(
            lease: f.lease, reader: source, authorization: { .fullAccess })
        let input = try await args(adapter)
        await #expect(throws: (any Error).self) { try await adapter.search(input) }
        #expect(await source.reads == 0)
        var blank = input
        blank["query"] = .string("")
        blank["fields"] = .array([.string("due")])
        let search = try await adapter.search(blank)
        #expect(search.value["reminders"]?.array?.first?["fields"]?["title"] == nil)
        await #expect(throws: (any Error).self) {
            try await adapter.detail([
                "reminderId": .string(token(search)), "fields": .array([.string("notes")]),
            ])
        }
        #expect(await source.reads == 1)
    }
    @Test func hiddenNotesCannotAffectSearchMatches() async throws {
        let f = try await SyntheticReminderFixture.make()
        let result = try await f.adapter.search(
            args(f.adapter, query: "synthetic-hidden-reminder-canary"))
        #expect(result.value["reminders"]?.array?.isEmpty == true)
    }
    @Test func foreignHandlesDefaultAuthorityAndIndependentOSFailClosed() async throws {
        let f = try await SyntheticReminderFixture.make()
        let other = try await SyntheticReminderFixture.make()
        let input = try await args(f.adapter)
        await #expect(throws: (any Error).self) { try await other.adapter.search(input) }
        let disabled = try ReminderReadAdapter(lease: f.lease, reader: f.source)
        await #expect(throws: (any Error).self) { try await disabled.discover() }
        await f.controller.observePermissions(
            OSPermissions(calendars: .fullAccess, reminders: .denied))
        await #expect(throws: (any Error).self) { try await f.adapter.search(input) }
    }
    @Test func partialEmptyDetailDoesNotClaimDeletion() async throws {
        let f = try await SyntheticReminderFixture.make()
        let source = Source(f.source)
        let adapter = try ReminderReadAdapter(
            lease: f.lease, reader: source, authorization: { await source.authorization() })
        let found = try await adapter.search(args(adapter))
        await source.configure(empty: true, partial: true)
        let result = try await adapter.detail([
            "reminderId": .string(token(found)), "fields": .array([.string("completion")]),
        ])
        #expect(result.value["status"]?.string == "notObserved")
        #expect(result.value["absenceProvesDeletion"] == .bool(false))
        #expect(result.value["observation"]?["completeness"]?.string == "partial")
    }
    @Test func revocationCancelsLeasedReadAndDiscardsLateProviderResult() async throws {
        let f = try await SyntheticReminderFixture.make()
        let source = Source(f.source)
        let adapter = try ReminderReadAdapter(
            lease: f.lease, reader: source, authorization: { .fullAccess })
        let input = try await args(adapter)
        let gate = Gate()
        await source.configure(gate: gate)
        let tool = try #require(adapter.tools().first { $0.name == "search_reminders" })
        let task = Task { try await tool.execute(input) }
        await gate.wait()
        try await f.controller.revoke(f.record.id)
        await gate.release()
        await #expect(throws: (any Error).self) { try await task.value }
        #expect(await source.cancelled)
    }
    @Test func outputQueueRechecksRevocationAndHandleExpiry() async throws {
        let f = try await SyntheticReminderFixture.make()
        let clock = Clock()
        let adapter = try ReminderReadAdapter(
            lease: f.lease, reader: f.source, authorization: { .fullAccess },
            uptime: { clock.now() })
        let result = try await adapter.search(args(adapter))
        let detail = try await adapter.detail([
            "reminderId": .string(token(result)), "fields": .array([.string("completion")]),
        ])
        clock.expire()
        await #expect(throws: (any Error).self) { try await detail.validate() }
        await #expect(throws: (any Error).self) {
            try await adapter.detail([
                "reminderId": .string(token(result)), "fields": .array([.string("completion")]),
            ])
        }
        try await f.controller.disable(f.record.id)
        await #expect(throws: (any Error).self) { try await result.validate() }
    }
    @Test func currentOSRevocationAfterFetchPreventsOutput() async throws {
        let f = try await SyntheticReminderFixture.make()
        let source = Source(f.source)
        let adapter = try ReminderReadAdapter(
            lease: f.lease, reader: source, authorization: { await source.authorization() })
        let input = try await args(adapter)
        let gate = Gate()
        await source.configure(gate: gate)
        let task = Task { try await adapter.search(input) }
        await gate.wait()
        await source.configure(access: .denied)
        await gate.release()
        await #expect(throws: (any Error).self) { try await task.value }
    }
    @Test func dueAndRecurrenceJSONDoNotInventInstantsOrOccurrenceSchedules() throws {
        let date = try LocalDate(year: 2027, month: 11, day: 7)
        let value = ReminderJSON.due(
            .localDateTime(date, try LocalTime(hour: 1, minute: 30), timeZone: nil))
        #expect(value["timeZone"] == .null)
        #expect(value["time"]?.string == "01:30:00")
        #expect(ReminderJSON.due(.date(date))["kind"]?.string == "date")
    }
}

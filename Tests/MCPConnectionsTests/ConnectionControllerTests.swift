import CoreDomain
import Foundation
import PermissionEngine
import Testing

@testable import MCPCalendarAdapter
@testable import MCPConnections
@testable import MCPServer

private actor Barrier {
    var entered = false
    var waiter: CheckedContinuation<Void, Never>?
    var suspended: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiter?.resume()
        waiter = nil
        await withCheckedContinuation { suspended = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { waiter = $0 } } }
    func release() {
        suspended?.resume()
        suspended = nil
    }
}
private final class State: @unchecked Sendable {
    private let lock = NSLock()
    private var seconds: TimeInterval = 0
    private var accepted = true
    private var closedCount = 0
    func now() -> TimeInterval { lock.withLock { seconds } }
    func advance() { lock.withLock { seconds += 61 } }
    func rejects() { lock.withLock { accepted = false } }
    func verify() -> Bool { lock.withLock { accepted } }
    func close() { lock.withLock { closedCount += 1 } }
    var closures: Int { lock.withLock { closedCount } }
}
private actor Source: CalendarReading {
    let seed: SyntheticCalendarSource
    var gate: Barrier?
    var reads = 0
    init(_ seed: SyntheticCalendarSource) { self.seed = seed }
    func hold(_ gate: Barrier) { self.gate = gate }
    func discoverCalendars() async -> ProviderReadResult<ResourceDiscovery<CalendarResource>> {
        await seed.discoverCalendars()
    }
    func readOccurrences(_ request: CalendarReadRequest, fields: Set<CalendarDetailField>) async
        -> ProviderReadResult<CalendarSnapshot>
    {
        reads += 1
        if let gate { await gate.enter() }
        return await seed.readOccurrences(request, fields: fields)
    }
}
private struct Fixture {
    let seed: SyntheticCalendarSource
    let source: Source
    let controller: ConnectionController
    let store: MemoryConnectionSettings
    let record: SavedConnection
    let clock: State
    static func make(fields: [SavedCalendarGrant.Field] = [.time, .occupancy, .status, .title])
        async throws -> Fixture
    {
        let seed = try SyntheticCalendarSource()
        let source = Source(seed)
        let store = MemoryConnectionSettings()
        let clock = State()
        let controller = try ConnectionController(store: store, uptime: { clock.now() })
        await controller.observePermissions(OSPermissions(calendars: .fullAccess))
        let record = try await controller.configure(
            label: "Synthetic local connection",
            grants: [
                SavedCalendarGrant(
                    reference: seed.calendar,
                    operations: [.discover, .availability, .summary, .details], fields: fields)
            ])
        return Fixture(
            seed: seed, source: source, controller: controller, store: store, record: record,
            clock: clock)
    }
    func pair(channel: ConnectionChannel? = nil) async throws -> (
        PendingConnection, ConnectionReadLease, CalendarReadAdapter
    ) {
        let request = try await controller.requestPairing(
            channel ?? ConnectionChannel(verify: { true }))
        let review = try await controller.review(request, connection: record.id)
        let lease = try await controller.approve(review)
        let adapter = try CalendarReadAdapter(
            session: lease.session, reader: source, selected: lease.selection,
            authorization: { .fullAccess }, lease: lease)
        return (request, lease, adapter)
    }
}
private func call(_ adapter: CalendarReadAdapter, _ name: String, _ arguments: [String: MCPJSON])
    async throws -> MCPToolResult
{
    let tool = try #require(adapter.tools().first { $0.name == name })
    return try await tool.execute(tool.arguments(.object(arguments)))
}
private func window(_ adapter: CalendarReadAdapter) async throws -> [String: MCPJSON] {
    let catalog = try await call(adapter, "list_calendars", [:]).value
    let id = try #require(catalog["calendars"]?.array?.first?["calendarId"])
    return [
        "calendarIds": .array([id]), "startMs": .number(1_799_999_000_000),
        "endMs": .number(1_800_004_000_000),
    ]
}

@Test func connectionDefaultPeerAndUnknownConfigurationAreDenied() async throws {
    let f = try await Fixture.make()
    let state = State()
    let denied = ConnectionChannel(close: { state.close() })
    await #expect(throws: (any Error).self) { try await f.controller.requestPairing(denied) }
    #expect(state.closures == 1)
    let request = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    await #expect(throws: (any Error).self) {
        try await f.controller.review(request, connection: UUID())
    }
    #expect(await f.source.reads == 0)
    await f.controller.shutdown()
}
@Test func connectionReviewIsSingleUseForeignAndLaunchBound() async throws {
    let f = try await Fixture.make()
    let request = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    let review = try await f.controller.review(request, connection: f.record.id)
    let other = try await Fixture.make()
    await #expect(throws: (any Error).self) { try await other.controller.approve(review) }
    let lease = try await f.controller.approve(review)
    #expect(lease.isOpen)
    await #expect(throws: (any Error).self) { try await f.controller.approve(review) }
    let replacement = try await f.pair()
    #expect(!lease.isOpen && replacement.1.isOpen)
    await f.controller.close(request)  // An old disconnect must not revoke the replacement.
    #expect(replacement.1.isOpen)
    _ = try await call(replacement.2, "list_calendars", [:])
}
@Test func connectionExpirationAndChangedReviewInvalidateApproval() async throws {
    let f = try await Fixture.make()
    let request = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    let review = try await f.controller.review(request, connection: f.record.id)
    f.clock.advance()
    await #expect(throws: (any Error).self) { try await f.controller.approve(review) }
    let request2 = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    let stale = try await f.controller.review(request2, connection: f.record.id)
    _ = try await f.controller.configure(id: f.record.id, label: "Synthetic narrowed", grants: [])
    await #expect(throws: (any Error).self) { try await f.controller.approve(stale) }
}
@Test func connectionPeerIsRecheckedAtApprovalAndRaceCannotResurrect() async throws {
    let f = try await Fixture.make()
    let peer = State()
    let request = try await f.controller.requestPairing(
        ConnectionChannel(verify: { peer.verify() }))
    let review = try await f.controller.review(request, connection: f.record.id)
    peer.rejects()
    await #expect(throws: (any Error).self) { try await f.controller.approve(review) }

    let gate = Barrier()
    let verifier = ApprovalVerifier(gate)
    let request2 = try await f.controller.requestPairing(
        ConnectionChannel(verify: { await verifier.verify() }))
    let review2 = try await f.controller.review(request2, connection: f.record.id)
    let task = Task { try await f.controller.approve(review2) }
    await gate.wait()
    try await f.controller.revoke(f.record.id)
    await gate.release()
    await #expect(throws: (any Error).self) { try await task.value }
}
private actor ApprovalVerifier {
    let gate: Barrier
    var calls = 0
    init(_ gate: Barrier) { self.gate = gate }
    func verify() async -> Bool {
        calls += 1
        if calls == 2 { await gate.enter() }
        return true
    }
}
@Test func connectionRevocationCancelsReadAndWithholdsLateContent() async throws {
    let f = try await Fixture.make()
    let state = State()
    let (_, lease, adapter) = try await f.pair(
        channel: ConnectionChannel(verify: { true }, close: { state.close() }))
    let args = try await window(adapter)
    let gate = Barrier()
    await f.source.hold(gate)
    let task = Task { try await call(adapter, "get_availability", args) }
    await gate.wait()
    try await f.controller.revoke(f.record.id)
    #expect(!lease.isOpen && state.closures == 1)
    await gate.release()
    await #expect(throws: (any Error).self) { try await task.value }
    let count = await f.source.reads
    await #expect(throws: (any Error).self) { try await call(adapter, "get_availability", args) }
    #expect(await f.source.reads == count)
    await #expect(throws: (any Error).self) { try await f.pair() }
    #expect(try f.store.load().first?.revoked == true)
}
@Test func connectionDisableAndOSChangesInvalidatePreparedResponses() async throws {
    for os in [false, true] {
        let f = try await Fixture.make()
        let (_, lease, adapter) = try await f.pair()
        let response = try await call(adapter, "get_availability", window(adapter))
        if os {
            await f.controller.observePermissions(OSPermissions(calendars: .denied))
        } else {
            try await f.controller.disable(f.record.id)
        }
        #expect(!lease.isOpen)
        await #expect(throws: (any Error).self) { try await response.validate() }
    }
}
@Test func connectionRestartRestoresOnlyCandidatesAndNoOldProof() async throws {
    let f = try await Fixture.make()
    let (request, lease, _) = try await f.pair()
    await f.controller.shutdown()
    let resumed = try ConnectionController(store: f.store)
    #expect(!lease.isOpen)
    #expect(try await resumed.settings().count == 1)
    await #expect(throws: (any Error).self) {
        try await resumed.review(request, connection: f.record.id)
    }
    let fresh = try await resumed.requestPairing(ConnectionChannel(verify: { true }))
    let review = try await resumed.review(fresh, connection: f.record.id)
    // OS observation also defaults denied.
    await #expect(throws: (any Error).self) { try await resumed.approve(review) }
}
@Test func connectionPolicyIsNotInferredFromPairingAndMutationsStayDenied() async throws {
    let f = try await Fixture.make(fields: [.time, .occupancy])
    let (_, lease, adapter) = try await f.pair()
    let args = try await window(adapter)
    _ = try await call(adapter, "get_availability", args)
    let search = args.merging([
        "query": .string("planning"), "fields": .array([.string("title")]), "limit": .number(10),
    ]) { _, new in new }
    await #expect(throws: (any Error).self) {
        try await call(adapter, "search_calendar_events", search)
    }
    #expect(!lease.selection.contains(f.seed.hidden))
    #expect(adapter.tools().allSatisfy { !$0.name.contains("propose") })
    await #expect(throws: (any Error).self) {
        try await call(adapter, "list_calendars", ["connectionId": .string(f.record.id.uuidString)])
    }
}
@Test func connectionQueueCapacityAndAuditRemainBoundedAndContentFree() async throws {
    let f = try await Fixture.make()
    let (_, lease, adapter) = try await f.pair()
    let gate = Barrier()
    let held = Task {
        try await lease.perform(.search) {
            await gate.enter()
            return 1
        }
    }
    await gate.wait()
    for _ in 0..<300 { _ = try await call(adapter, "list_calendars", [:]) }
    let activity = await f.controller.activity()
    #expect(activity.count == 256)
    #expect(activity.allSatisfy { $0.action == .readPrepared && $0.operation == .discovery })
    #expect(activity.first!.sequence < activity.last!.sequence)
    await f.controller.shutdown()
    await gate.release()
    await #expect(throws: (any Error).self) { try await held.value }
}

@Test func connectionPendingAndRunningWorkLimitsFailClosed() async throws {
    let f = try await Fixture.make()
    let (_, lease, _) = try await f.pair()
    let gates = (0..<4).map { _ in Barrier() }
    var tasks: [Task<Int, any Error>] = []
    for gate in gates {
        tasks.append(
            Task {
                try await lease.perform(.search) {
                    await gate.enter()
                    return 1
                }
            })
        await gate.wait()
    }
    await #expect(throws: (any Error).self) { try await lease.perform(.search) { 2 } }
    for _ in 0..<8 {
        _ = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    }
    await #expect(throws: (any Error).self) {
        try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    }
    await f.controller.shutdown()
    for gate in gates { await gate.release() }
    for task in tasks { await #expect(throws: (any Error).self) { try await task.value } }
}

@Test func connectionEmptyGrantsAndIndependentChannelsDoNotInheritAuthority() async throws {
    let f = try await Fixture.make()
    let (request, lease, adapter) = try await f.pair()
    let empty = try await f.controller.configure(label: f.record.label, grants: [])
    let pending = try await f.controller.requestPairing(ConnectionChannel(verify: { true }))
    let review = try await f.controller.review(pending, connection: empty.id)
    let limited = try await f.controller.approve(review)
    #expect(limited.selection.isEmpty)
    #expect(lease.isOpen)
    try await f.controller.revoke(empty.id)
    #expect(!limited.isOpen && lease.isOpen)
    _ = try await call(adapter, "list_calendars", [:])
    await f.controller.close(request)
    #expect(!lease.isOpen)
    await #expect(throws: (any Error).self) { try await call(adapter, "list_calendars", [:]) }
}

@Test func connectionDuplicateChannelClosesAndCancelsItsRunningWork() async throws {
    let f = try await Fixture.make()
    let channel = ConnectionChannel(verify: { true })
    let (_, lease, _) = try await f.pair(channel: channel)
    let barrier = Barrier()
    let task = Task {
        try await lease.perform(.search) {
            await barrier.enter()
            #expect(Task.isCancelled)
            return 1
        }
    }
    await barrier.wait()
    await #expect(throws: (any Error).self) { try await f.controller.requestPairing(channel) }
    #expect(!lease.isOpen)
    await barrier.release()
    await #expect(throws: (any Error).self) { try await task.value }
}

@Test func connectionCancelledProvidersRetainSharedCapacityAcrossLaunches() async throws {
    let f = try await Fixture.make()
    var gates: [Barrier] = []
    var tasks: [Task<Int, any Error>] = []
    for _ in 0..<4 {
        let (request, lease, _) = try await f.pair()
        for _ in 0..<4 {
            let gate = Barrier()
            gates.append(gate)
            tasks.append(
                Task {
                    try await lease.perform(.search) {
                        await gate.enter()
                        return 1
                    }
                })
            await gate.wait()
        }
        await f.controller.close(request)
    }
    let (_, lease, _) = try await f.pair()
    await #expect(throws: (any Error).self) { try await lease.perform(.search) { 2 } }
    for gate in gates { await gate.release() }
    for task in tasks { await #expect(throws: (any Error).self) { try await task.value } }
    #expect(try await lease.perform(.search) { 2 } == 2)
    await f.controller.shutdown()
}

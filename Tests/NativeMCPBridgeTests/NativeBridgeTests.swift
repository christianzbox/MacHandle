import CoreDomain
import Foundation
import MCPConnections
import MCPRemindersAdapter
import MCPServer
import PermissionEngine
import Testing

@testable import NativeMCPBridge

@Test func sampleXPCRequiresNativePairingAndProjectsOnlyGrantedFields() async throws {
    let sample = try await SampleBridgeSession.make()
    await #expect(throws: (any Error).self) { try await sample.readSampleTitles() }
    let review = try await sample.broker.prepareReview()
    await #expect(throws: (any Error).self) { try await sample.broker.approve(UUID()) }
    try await sample.broker.approve(review.id)
    await #expect(throws: (any Error).self) { try await sample.broker.approve(review.id) }
    #expect(try await sample.readSampleTitles() == ["Synthetic grocery reminder"])
    let lists = try await sample.call("list_reminder_lists", arguments: [:])
    let bytes = try lists.encoded()
    #expect(!String(decoding: bytes, as: UTF8.self).contains("Hidden list"))
    let list = try #require(lists["lists"]?.array?.first?["listId"]?.string)
    let projected = try await sample.call(
        "search_reminders",
        arguments: [
            "listIds": .array([.string(list)]), "query": .string(""),
            "fields": .array([.string("title"), .string("completion")]), "limit": .number(5),
        ])
    #expect(
        !String(decoding: try projected.encoded(), as: UTF8.self).contains(
            "synthetic-hidden-reminder-canary"))
    #expect(projected["reminders"]?.array?.first?["fields"]?["notes"] == nil)
    await #expect(throws: (any Error).self) {
        try await sample.call(
            "search_reminders",
            arguments: [
                "listIds": .array([.string(list)]), "query": .string(""),
                "fields": .array([.string("notes")]), "limit": .number(5),
            ])
    }
    await #expect(throws: (any Error).self) {
        try await sample.call("approve", arguments: ["connection": .string(review.id.uuidString)])
    }
    await sample.close(revoke: true)
    await #expect(throws: (any Error).self) { try await sample.readSampleTitles() }
}

@Test func wireRejectsUnknownDuplicateOversizedAndMutatingRequests() async throws {
    let sample = try await SampleBridgeSession.make()
    try await sample.broker.approve(sample.broker.prepareReview().id)
    for raw in [
        #"{"version":1,"version":1,"tool":"list_reminder_lists","arguments":{}}"#,
        #"{"version":2,"tool":"list_reminder_lists","arguments":{}}"#,
        #"{"version":1,"tool":"list_reminder_lists","arguments":{},"identity":"trusted"}"#,
        #"{"version":1,"tool":"commit_reminder_action","arguments":{}}"#,
        String(repeating: " ", count: 16_385), String(repeating: "[", count: 100),
    ] {
        let reply = await sample.transport.send(Data(raw.utf8))
        #expect(!String(decoding: reply, as: UTF8.self).contains("result"))
    }
    #expect(try await sample.readSampleTitles().count == 1)
    await sample.close()
}

@Test func closedOrForeignReviewCannotPairANewLaunch() async throws {
    let old = try await SampleBridgeSession.make()
    let oldReview = try await old.broker.prepareReview()
    await old.close()
    await #expect(throws: (any Error).self) { try await old.broker.approve(oldReview.id) }
    let new = try await SampleBridgeSession.make()
    let newReview = try await new.broker.prepareReview()
    await #expect(throws: (any Error).self) { try await new.broker.approve(oldReview.id) }
    try await new.broker.approve(newReview.id)
    await old.close(revoke: true)
    #expect(try await new.readSampleTitles().count == 1)
    await new.close()
}

@Test func brokerRejectsUnverifiedPeerAndExpiredNativeReview() async throws {
    let denied = try await BrokerRig.make(channel: ConnectionChannel())
    await #expect(throws: (any Error).self) { try await denied.broker.prepareReview() }
    await denied.broker.close()
    let clock = BridgeClock()
    let rig = try await BrokerRig.make(uptime: { clock.now })
    let review = try await rig.broker.prepareReview()
    clock.advance()
    await #expect(throws: (any Error).self) { try await rig.broker.approve(review.id) }
    #expect(await rig.broker.request(discoveryRequest) == NativeReadBroker.unavailable)
    await rig.broker.close()
}

@Test func brokerRevocationDropsSuspendedProviderResults() async throws {
    let source = try PausedReminderSource()
    let rig = try await BrokerRig.make(reader: source)
    let review = try await rig.broker.prepareReview()
    try await rig.broker.approve(review.id)
    let request = Task { await rig.broker.request(discoveryRequest) }
    try await source.waitForRead()
    await rig.broker.close(revoke: true)
    await source.release()
    #expect(await request.value == NativeReadBroker.unavailable)
}

@Test func xpcTimeoutClosesAdmissionAndLateReplyCannotRestoreIt() async throws {
    let source = try PausedReminderSource()
    let rig = try await BrokerRig.make(reader: source)
    let transport = SampleXPCTransport(broker: rig.broker, channel: rig.channel)
    let review = try await rig.broker.prepareReview()
    try await rig.broker.approve(review.id)
    let request = Task { await transport.send(discoveryRequest) }
    try await source.waitForRead()
    #expect(await request.value == NativeReadBroker.unavailable)
    #expect(!rig.channel.isOpen)
    await source.release()
    #expect(await transport.send(discoveryRequest) == NativeReadBroker.unavailable)
    transport.close()
    await rig.broker.close()
}

private let discoveryRequest = Data(
    #"{"version":1,"tool":"list_reminder_lists","arguments":{}}"#.utf8)
private final class BridgeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 1
    var now: TimeInterval { lock.withLock { value } }
    func advance() { lock.withLock { value += 61 } }
}
private struct BrokerRig {
    let broker: NativeReadBroker
    let channel: ConnectionChannel
    static func make(
        channel: ConnectionChannel = ConnectionChannel(verify: { true }),
        reader: (any ReminderReading & ReminderDiscovering)? = nil,
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) async throws -> Self {
        let fixture = try SyntheticReminderSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings(), uptime: uptime)
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: fixture.list, operations: [.discover], fields: [])
        let record = try await controller.configure(
            label: "Test launch", grants: [], reminderGrants: [grant])
        return Self(
            broker: NativeReadBroker(
                controller: controller, channel: channel, record: record,
                reader: reader ?? fixture, authorization: { .fullAccess }), channel: channel)
    }
}
private actor PausedReminderSource: ReminderReading, ReminderDiscovering {
    private let fixture: SyntheticReminderSource
    private var started = 0
    private var blocked: [CheckedContinuation<Void, Never>] = []
    init() throws { fixture = try SyntheticReminderSource() }
    func authorization() -> OSAuthorization { .fullAccess }
    func requestAccess() -> OSAuthorization { .fullAccess }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func waitForRead(_ count: Int = 1) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while started < count {
            guard ContinuousClock.now < deadline else {
                release()
                throw SampleBridgeFailure.unavailable
            }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func release() {
        let current = blocked
        blocked = []
        for waiter in current { waiter.resume() }
    }
    func discoverReminderLists() async -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        started += 1
        await withCheckedContinuation { blocked.append($0) }
        return fixture.discoverReminderLists()
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        fixture.readReminders(request, fields: fields)
    }
}

@Test func cancellingXPCReadClosesChannelWithoutReturningLateData() async throws {
    let source = try PausedReminderSource()
    let rig = try await BrokerRig.make(reader: source)
    let transport = SampleXPCTransport(broker: rig.broker, channel: rig.channel)
    let review = try await rig.broker.prepareReview()
    try await rig.broker.approve(review.id)
    let request = Task { await transport.send(discoveryRequest) }
    try await source.waitForRead()
    request.cancel()
    #expect(await request.value == NativeReadBroker.unavailable)
    #expect(!rig.channel.isOpen)
    await source.release()
    transport.close()
    await rig.broker.close()
}

@Test func xpcBoundsConcurrentProviderWorkAndClosesAllPendingReads() async throws {
    let source = try PausedReminderSource()
    let rig = try await BrokerRig.make(reader: source)
    let transport = SampleXPCTransport(broker: rig.broker, channel: rig.channel)
    let review = try await rig.broker.prepareReview()
    try await rig.broker.approve(review.id)
    let reads = (0..<4).map { _ in Task { await transport.send(discoveryRequest) } }
    try await source.waitForRead(4)
    #expect(await transport.send(discoveryRequest) == NativeReadBroker.unavailable)
    transport.close()
    await rig.broker.close()
    await source.release()
    for read in reads { #expect(await read.value == NativeReadBroker.unavailable) }
}

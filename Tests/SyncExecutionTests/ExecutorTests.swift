import CoreDomain
import Foundation
import SyncPersistence
import SyncPlanning
import Testing

@testable import AppleCalendarProvider
@testable import GoogleAuthorization
@testable import SyncExecution

private func instant(_ seconds: Double) -> Instant {
    try! Instant(Date(timeIntervalSince1970: seconds))
}
private let window = try! InstantInterval(start: instant(0), end: instant(10000))
private let time = EventTime.timed(
    try! InstantInterval(start: instant(1000), end: instant(2000)), timeZone: try! TimeZoneID("UTC")
)
private func reference(_ id: String) -> CalendarReference {
    CalendarReference(
        account: AccountReference(
            provider: try! ProviderID("synthetic"), store: try! StoreID("local"),
            account: try! AccountID("account")), localID: try! DomainID(id))
}
private let scope = PlanningScope(
    source: reference("source"), destination: reference("synthetic@group.calendar.google.com"))
private let observation = ObservationState(
    observedAt: instant(100), completeness: .complete, freshness: .verifiedThrough(instant(100)))
private let policyRevision = try! ObservedRevision("policy-1")
private func source(
    _ id: String = "one", status: EventStatus = .active, time: EventTime = time,
    anchor: RecurrenceAnchor = .notRecurring
)
    -> CalendarOccurrence
{
    CalendarOccurrence(
        id: OccurrenceReference(
            calendar: scope.source, item: try! EventID(id), originalAnchor: anchor),
        time: time, occupancy: .busy, status: status, title: .value("Synthetic title"))
}
private actor Authority: ExecutionAuthorizing {
    var input: ReconciliationInput
    let binding: PersistenceBinding
    var enabled = true
    var deletesApproved = false
    var deletionPlan: ReconciliationPlan?
    var denyCommit = false
    init(_ input: ReconciliationInput, _ binding: PersistenceBinding) {
        self.input = input
        self.binding = binding
    }
    func set(_ input: ReconciliationInput) { self.input = input }
    func revoke() { enabled = false }
    func approveDeletes() {
        deletesApproved = true
        deletionPlan = ReconciliationPlanner.plan(input)
    }
    func checkDeletions(_ plan: ReconciliationPlan) throws {
        guard enabled, deletesApproved, deletionPlan == plan else { throw ExecutionFailure.blocked }
    }
    func blockCommit() { denyCommit = true }
    func currentInput() throws -> ReconciliationInput {
        guard enabled else { throw ExecutionFailure.blocked }
        return input
    }
    func check(_ request: ExecutionRequest) throws {
        guard enabled, request.binding == binding,
            request.plan == ReconciliationPlanner.plan(input),
            !denyCommit || request.phase != .commit
        else { throw ExecutionFailure.blocked }
        if request.proposal?.requiresDeletionConfirmation == true && !deletesApproved {
            throw ExecutionFailure.blocked
        }
    }
}
private actor Remote: GoogleCalendarSending {
    let lease = GoogleCalendarLease(authority: UUID(), generation: 1)
    var calendar: [String: String] = [:]
    var events: [String: GoogleEventWire] = [:]
    var requests: [URLRequest] = []
    var loseResponse = false
    var loseCreation = false
    func loseCalendarCreation() { loseCreation = true }
    var rejectWrites = false
    var quotaOnce = false
    var corruptVerification = false
    var hook: (@Sendable () async throws -> Void)?
    var onQuota: (@Sendable () async -> Void)?
    var count = 0
    var loseAt: Int?
    func loseAfterWrite(_ count: Int) { loseAt = count }
    func calendarLease() -> GoogleCalendarLease { lease }
    func configure(
        lost: Bool = false, reject: Bool = false, quota: Bool = false, corrupt: Bool = false
    ) {
        loseResponse = lost
        rejectWrites = reject
        quotaOnce = quota
        corruptVerification = corrupt
    }
    func setHook(_ value: @escaping @Sendable () async throws -> Void) { hook = value }
    func setQuotaHook(_ value: @escaping @Sendable () async -> Void) { onQuota = value }
    func writes() -> [URLRequest] {
        requests.filter { $0.url!.path.contains("/events") && $0.httpMethod != "GET" }
    }
    func sendCalendar(_ request: URLRequest, lease: GoogleCalendarLease) async throws
        -> OAuthHTTPResponse
    {
        guard lease == self.lease else { throw GoogleDestinationFailure.authorization }
        requests.append(request)
        let method = request.httpMethod!
        if !request.url!.path.contains("/events") {
            if method == "POST" {
                calendar = try JSONDecoder().decode([String: String].self, from: request.httpBody!)
                calendar["id"] = scope.destination.localID.rawValue
                calendar["etag"] = "\"calendar-1\""
            }
            if method == "PATCH" {
                guard request.value(forHTTPHeaderField: "If-Match") == calendar["etag"] else {
                    return OAuthHTTPResponse(status: 412, data: Data())
                }
                let value = try JSONDecoder().decode([String: String].self, from: request.httpBody!)
                calendar["description"] = value["description"]
                calendar["etag"] = "\"calendar-transferred\""
            }
            if method == "POST" && loseCreation { throw GoogleDestinationFailure.unavailable }
            return OAuthHTTPResponse(status: 200, data: try JSONEncoder().encode(calendar))
        }
        if request.url!.path.hasSuffix("/events") && method == "GET" {
            let data = try JSONEncoder().encode(Array(events.values))
            return OAuthHTTPResponse(
                status: 200, data: Data("{\"items\":".utf8) + data + Data("}".utf8))
        }
        if method != "GET" {
            try await hook?()
            if quotaOnce {
                quotaOnce = false
                await onQuota?()
                return OAuthHTTPResponse(status: 429, data: Data())
            }
            if rejectWrites { return OAuthHTTPResponse(status: 412, data: Data()) }
            count += 1
            if method == "DELETE" {
                let id = request.url!.lastPathComponent
                guard events[id]?.etag == request.value(forHTTPHeaderField: "If-Match") else {
                    return OAuthHTTPResponse(status: 412, data: Data())
                }
                events[id] = nil
            } else {
                var event = try JSONDecoder().decode(GoogleEventWire.self, from: request.httpBody!)
                if method == "POST" && events[event.id] != nil {
                    return OAuthHTTPResponse(status: 409, data: Data())
                }
                if method == "PUT"
                    && events[event.id]?.etag != request.value(forHTTPHeaderField: "If-Match")
                {
                    return OAuthHTTPResponse(status: 412, data: Data())
                }
                event.etag = "\"v\(count)\""
                event.status = "confirmed"
                events[event.id] = event
            }
            if loseResponse || count == loseAt { throw GoogleDestinationFailure.unavailable }
            return OAuthHTTPResponse(status: method == "DELETE" ? 204 : 200, data: Data())
        }
        guard var value = events[request.url!.lastPathComponent] else {
            return OAuthHTTPResponse(status: 404, data: Data())
        }
        if corruptVerification { value.extendedProperties?.private["macHandleMutation"] = "wrong" }
        return OAuthHTTPResponse(status: 200, data: try JSONEncoder().encode(value))
    }
    func edit() { for id in events.keys { events[id]?.etag = "\"external\"" } }
}
private struct Fixture {
    let root: URL
    let store: SQLiteSyncStore
    let binding: PersistenceBinding
    let remote: Remote
    let bridge: GoogleDurableDestination
    let resource: UUID
    static func make() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("machandle-synthetic-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let binding = try PersistenceBinding(
            storeID: UUID(), installationID: UUID(),
            clientID: "synthetic.apps.googleusercontent.com",
            accountKey: PersistenceDigest(String(repeating: "a", count: 64)))
        let store = try SQLiteSyncStore(
            directory: root.appendingPathComponent("store"), binding: binding, mode: .createNew)
        let operation = try await store.prepareDestination(
            sourceKey: PersistenceDigest(PlanningFingerprint.calendar(scope.source).value))
        _ = try await store.beginAttempt(operation.id)
        let remote = Remote()
        let client = GoogleDestinationClient(transport: remote, sleep: { _ in }, jitter: { 0 })
        let destination = try await client.createDestination(
            ownershipMarker: operation.id, writerID: binding.installationID)
        let bridge = try await client.durableDestination(destination)
        try await store.recordDestinationResult(
            operation.id, destinationID: bridge.calendarID, ownershipMarker: bridge.marker)
        return Fixture(
            root: root, store: store, binding: binding, remote: remote, bridge: bridge,
            resource: operation.resourceID)
    }
    func input(
        _ sources: [CalendarOccurrence] = [source()], detailed: Bool = false,
        baselineSources: [CalendarOccurrence]? = nil, coverageWindow: InstantInterval = window,
        sourceState: ObservationState = observation
    ) async throws -> ReconciliationInput {
        let snapshot = try await store.snapshot()
        let remoteEvents = await remote.events
        var maps: [PlanningMapping] = []
        var events: [DestinationObservation] = []
        for saved in snapshot.events {
            guard
                let original = (baselineSources ?? sources).first(where: {
                    try! PlanningFingerprint.occurrence($0.id).value == saved.sourceKey.value
                })
            else { throw ExecutionFailure.blocked }
            let disposition: MappingDisposition =
                saved.deleted
                ? .deleted
                : .active(
                    fingerprint: try PlanningFingerprint(saved.fingerprint!.value),
                    revision: try ObservedRevision(saved.etag!))
            maps.append(
                PlanningMapping(
                    source: original.id, destinationID: try EventID(saved.destinationEventID),
                    lastSourceInterval: try CalendarTimeResolution.interval(for: original.time),
                    disposition: disposition))
            if let wire = remoteEvents[saved.destinationEventID] {
                let payload = PlannedEventContent(
                    time: try observedTime(wire), isFree: wire.transparency == "transparent",
                    title: wire.summary ?? "Busy",
                    location: wire.location ?? "", notes: wire.description ?? "")
                events.append(
                    DestinationObservation(
                        id: try EventID(saved.destinationEventID), content: payload,
                        revision: try ObservedRevision(wire.etag!), ownership: .verified))
            }
        }
        return ReconciliationInput(
            scope: scope,
            policy: PlanningPolicy(
                revision: policyRevision, enabled: true, fields: detailed ? [.title] : []),
            source: try CalendarSnapshot(
                coverage: CalendarReadRequest(calendars: [scope.source], window: coverageWindow),
                occurrences: sources, observation: sourceState), sourceIdentity: .verified,
            destination: PlanningDestination(
                scope: scope, window: coverageWindow, observation: observation,
                ownership: .verified,
                events: events),
            mappings: PlanningMappings(
                scope: scope, health: .verified,
                hasUnresolvedOperations: snapshot.operations.contains { $0.state != .completed },
                records: maps))
    }
    private func observedTime(_ wire: GoogleEventWire) throws -> EventTime {
        let first = try #require(wire.start?.value)
        let last = try #require(wire.end?.value)
        let utc = try TimeZoneID("UTC")
        if wire.start?.date != nil {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            func day(_ date: Date) throws -> LocalDate {
                let parts = calendar.dateComponents([.year, .month, .day], from: date)
                return try LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)
            }
            return .allDay(try LocalDateInterval(start: day(first), end: day(last)), timeZone: utc)
        }
        return .timed(try InstantInterval(start: Instant(first), end: Instant(last)), timeZone: utc)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func executor(_ authority: any ExecutionAuthorizing, store: SQLiteSyncStore? = nil)
        -> SynchronizationExecutor
    {
        SynchronizationExecutor(
            store: store ?? self.store, binding: binding, destination: bridge, authority: authority)
    }
}

@Test func orderedDurableCreatesVerifyBeforeCheckpointAndConverge() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input([source("b"), source("a")])
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    await f.remote.setHook {
        let state = try await f.store.snapshot()
        #expect(state.operations.contains { $0.state == .unknown })
        #expect(state.checkpoint.revision == 0)
    }
    let result = await f.executor(authority).run(preview: plan)
    #expect(result == ExecutionReport(status: .completed, completedOperations: 2))
    let state = try await f.store.snapshot()
    #expect(
        state.checkpoint.revision == 1 && state.operations.allSatisfy { $0.state == .completed })
    let writes = await f.remote.writes()
    let sentIDs = try writes.map {
        try JSONDecoder().decode(GoogleEventWire.self, from: $0.httpBody!).id
    }
    let expected = plan.proposals.map { proposal in
        state.events.first {
            $0.sourceKey.value == (try! PlanningFingerprint.occurrence(proposal.source).value)
        }!.destinationEventID
    }
    #expect(sentIDs == expected)
    let next = try await f.input([source("a"), source("b")])
    await authority.set(next)
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(next))
            .completedOperations == 0)
    #expect(await f.remote.writes().count == 2)
    await f.store.close()
}
@Test func lostInsertResponseRecoversAfterStoreReopenWithoutAnotherPost() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    await f.remote.configure(lost: true)
    #expect(await f.executor(authority).run(preview: plan).status == .recoveryRequired)
    let state = try await f.store.snapshot()
    let unknown = try #require(state.operations.first { $0.state == .unknown })
    #expect(state.checkpoint.revision == 0 && state.events.first?.fingerprint == nil)
    await f.store.close()
    let reopened = try SQLiteSyncStore(
        directory: f.root.appendingPathComponent("store"), binding: f.binding, mode: .resume)
    let executor = f.executor(authority, store: reopened)
    #expect(await executor.run(preview: plan).status == .recoveryRequired)
    #expect(
        await executor.recover(operationID: unknown.id, proposal: plan.proposals[0], preview: plan)
            .status == .recovered)
    #expect(try await reopened.snapshot().checkpoint.revision == 0)
    #expect(await f.remote.writes().count == 1)
    await reopened.close()
}
@Test func conditionalUpdateClearsDetailsAndDeleteRequiresExactConfirmation() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let initial = try await f.input(detailed: true)
    let authority = Authority(initial, f.binding)
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(initial)).status
            == .completed)
    let reduced = try await f.input()
    await authority.set(reduced)
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(reduced)).status
            == .completed)
    let wire = try #require(await f.remote.events.values.first)
    #expect(wire.summary == "Busy" && wire.description == "" && wire.location == "")
    let cancelled = try await f.input([source(status: .cancelled)])
    await authority.set(cancelled)
    let plan = ReconciliationPlanner.plan(cancelled)
    #expect(await f.executor(authority).run(preview: plan).status == .blocked)
    await authority.approveDeletes()
    #expect(await f.executor(authority).run(preview: plan).status == .completed)
    #expect(try await f.store.snapshot().events.first?.deleted == true)
    let writes = await f.remote.writes()
    #expect(writes.map(\.httpMethod) == ["POST", "PUT", "DELETE"])
    #expect(writes.dropFirst().allSatisfy { $0.value(forHTTPHeaderField: "If-Match") != nil })
    await f.store.close()
}
@Test func revocationDuringQuotaDelayPreventsSecondWrite() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let authority = Authority(input, f.binding)
    await f.remote.configure(quota: true)
    await f.remote.setQuotaHook { await authority.revoke() }
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(input)).status
            == .blocked)
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot().checkpoint.revision == 0)
    await f.store.close()
}
@Test func rejectedWriteAndWrongVerificationNeverCheckpointOrBlindlyReplay() async throws {
    for reject in [true, false] {
        let f = try await Fixture.make()
        defer { f.remove() }
        let input = try await f.input()
        let plan = ReconciliationPlanner.plan(input)
        let authority = Authority(input, f.binding)
        await f.remote.configure(reject: reject, corrupt: !reject)
        #expect(await f.executor(authority).run(preview: plan).status == .conflict)
        #expect(try await f.store.snapshot().checkpoint.revision == 0)
        #expect(await f.executor(authority).run(preview: plan).status == .recoveryRequired)
        #expect(await f.remote.writes().count == 1)
        await f.store.close()
    }
}
@Test func currentPreviewAndDefaultDenyAreRequiredBeforeAnyWrite() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    #expect(await f.executor(InactiveExecutionAuthority()).run(preview: plan).status == .blocked)
    let changed = try await f.input(detailed: true)
    let authority = Authority(changed, f.binding)
    #expect(await f.executor(authority).run(preview: plan).status == .blocked)
    #expect(await f.remote.writes().isEmpty)
    await f.store.close()
}
@Test func commitRevocationRetainsUnknownResultForVerification() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let authority = Authority(input, f.binding)
    await authority.blockCommit()
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(input)).status
            == .blocked)
    let state = try await f.store.snapshot()
    #expect(state.operations.contains { $0.state == .unknown })
    #expect(state.events.first?.etag == nil && state.checkpoint.revision == 0)
    await f.store.close()
}
@Test func lossyTimestampIsRejectedBeforeDurableIntent() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let fractional = EventTime.timed(
        try InstantInterval(start: instant(1000.0001), end: instant(2000.0001)),
        timeZone: try TimeZoneID("UTC"))
    let input = try await f.input([source(time: fractional)])
    let authority = Authority(input, f.binding)
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(input)).status
            == .blocked)
    #expect(await f.remote.writes().isEmpty)
    #expect(try await f.store.snapshot().events.isEmpty)
    await f.store.close()
}

@Test func partialRemoteSuccessKeepsPriorCommitsButDoesNotCompleteRun() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input([source("a"), source("b")])
    let authority = Authority(input, f.binding)
    await f.remote.loseAfterWrite(2)
    let result = await f.executor(authority).run(preview: ReconciliationPlanner.plan(input))
    #expect(result == ExecutionReport(status: .recoveryRequired, completedOperations: 1))
    let state = try await f.store.snapshot()
    #expect(
        state.checkpoint.revision == 0 && state.events.filter { $0.fingerprint != nil }.count == 1)
    #expect(state.operations.filter { $0.state == .unknown }.count == 1)
    #expect(await f.remote.writes().count == 2)
    await f.store.close()
}
@Test func failedLocalResultCommitRecoversFromOriginalDurableIdentity() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    await f.remote.setHook { await f.store.close() }
    #expect(await f.executor(authority).run(preview: plan).status == .storageFailure)
    let resumed = try SQLiteSyncStore(
        directory: f.root.appendingPathComponent("store"), binding: f.binding, mode: .resume)
    let state = try await resumed.snapshot()
    let operation = try #require(state.operations.first { $0.state == .unknown })
    #expect(
        await f.executor(authority, store: resumed).recover(
            operationID: operation.id, proposal: plan.proposals[0], preview: plan
        ).status == .recovered)
    #expect(await f.remote.writes().count == 1)
    #expect(try await resumed.snapshot().checkpoint.revision == 0)
    await resumed.close()
}
private actor Pause {
    var entered = false
    var continuation: CheckedContinuation<Void, Never>?
    func stop() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func waitUntilEntered() async { while !entered { await Task.yield() } }
    func release() {
        continuation?.resume()
        continuation = nil
    }
}
@Test func cancellationAndConcurrentRunNeverAdvanceCheckpoint() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    let pause = Pause()
    await f.remote.setHook { await pause.stop() }
    let executor = f.executor(authority)
    let task = Task { await executor.run(preview: plan) }
    await pause.waitUntilEntered()
    #expect(await executor.run(preview: plan).status == .busy)
    task.cancel()
    await pause.release()
    #expect(await task.value.status == .cancelled)
    let state = try await f.store.snapshot()
    #expect(state.checkpoint.revision == 0 && state.operations.contains { $0.state == .unknown })
    await f.store.close()
}
@Test func missingRecoveryTargetNeverRetriesAnInsert() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    await f.remote.configure(reject: true)
    _ = await f.executor(authority).run(preview: plan)
    let operation = try #require(
        try await f.store.snapshot().operations.first { $0.state == .unknown })
    #expect(
        await f.executor(authority).recover(
            operationID: operation.id, proposal: plan.proposals[0], preview: plan
        ).status == .recoveryRequired)
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot().checkpoint.revision == 0)
    await f.store.close()
}
@Test func remoteVersionRaceBlocksUpdateBeforeMutation() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input(detailed: true)
    let authority = Authority(input, f.binding)
    _ = await f.executor(authority).run(preview: ReconciliationPlanner.plan(input))
    let next = try await f.input()
    await authority.set(next)
    await f.remote.edit()
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(next)).status
            == .conflict)
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot().checkpoint.revision == 1)
    await f.store.close()
}

@Test func lostUpdateAndDeleteResponsesRecoverByReadingWithoutReplaying() async throws {
    for deletion in [false, true] {
        let f = try await Fixture.make()
        defer { f.remove() }
        let initial = try await f.input(detailed: true)
        let authority = Authority(initial, f.binding)
        _ = await f.executor(authority).run(preview: ReconciliationPlanner.plan(initial))
        let next = try await f.input([source(status: deletion ? .cancelled : .active)])
        await authority.set(next)
        await authority.approveDeletes()
        await f.remote.configure(lost: true)
        let plan = ReconciliationPlanner.plan(next)
        #expect(await f.executor(authority).run(preview: plan).status == .recoveryRequired)
        let operation = try #require(
            try await f.store.snapshot().operations.first { $0.state == .unknown })
        #expect(
            await f.executor(authority).recover(
                operationID: operation.id, proposal: plan.proposals[0], preview: plan
            ).status == .recovered)
        #expect(await f.remote.writes().count == 2)
        #expect(try await f.store.snapshot().checkpoint.revision == 1)
        #expect(try await f.store.snapshot().events.first?.deleted == deletion)
        await f.store.close()
    }
}
@Test func inaccessibleStorePreventsAnyRemoteMutation() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let authority = Authority(input, f.binding)
    await f.store.close()
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(input)).status
            == .storageFailure)
    #expect(await f.remote.writes().isEmpty)
}

@Test func materializedRecurringExceptionsUpdateAndCancelWithoutDuplicateIDs() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let read = try CalendarReadRequest(calendars: [scope.source], window: window)
    func materialize(_ moved: Bool = false, cancelled: Bool = false) throws -> [CalendarOccurrence]
    {
        try CalendarEventNormalization.occurrences(
            [1000.0, 3000.0, 5000.0].map { original in
                let start = original + (moved && original == 3000 ? 500 : 0)
                return CalendarEventRecord(
                    calendar: scope.source, itemID: "synthetic-series",
                    start: Date(timeIntervalSince1970: start),
                    end: Date(timeIntervalSince1970: start + 600),
                    allDay: false, timeZone: "UTC", recurring: true,
                    originalDate: Date(timeIntervalSince1970: original), occupancy: .busy,
                    status: cancelled && original == 5000 ? .cancelled : .active,
                    title: .notFetched, location: .notFetched, notes: .notFetched)
            }, request: read)
    }
    let original = try materialize()
    var input = try await f.input(original)
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    let originalIDs = Set(try await f.store.snapshot().events.map(\.destinationEventID))
    #expect(originalIDs.count == 3)
    let edited = try materialize(true, cancelled: true)
    input = try await f.input(edited, baselineSources: original)
    await authority.set(input)
    await authority.approveDeletes()
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    let writes = await f.remote.writes()
    #expect(writes.map(\.httpMethod).filter { $0 == "POST" }.count == 3)
    #expect(writes.map(\.httpMethod).filter { $0 == "PUT" }.count == 1)
    #expect(writes.map(\.httpMethod).filter { $0 == "DELETE" }.count == 1)
    #expect(Set(try await f.store.snapshot().events.map(\.destinationEventID)) == originalIDs)
    input = try await f.input(edited)
    await authority.set(input)
    #expect(ReconciliationPlanner.plan(input).proposals.allSatisfy { $0.action == .noChange })
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().count == 5)
    await f.store.close()
}

@Test func fractionalSecondsExecuteWithoutLossAndThenConverge() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let fractional = EventTime.timed(
        try InstantInterval(start: instant(1000.125), end: instant(2000.25)),
        timeZone: try TimeZoneID("America/Detroit"))
    let events = [source(time: fractional, anchor: .timed(instant(1000.125)))]
    var input = try await f.input(events)
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    let wire = try #require(await f.remote.events.values.first)
    #expect(wire.start?.value == instant(1000.125).date && wire.end?.value == instant(2000.25).date)
    input = try await f.input(events)
    await authority.set(input)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func allDayTravelAndDSTKeepCivilDatesAndAvoidWrites() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    func point(_ text: String) throws -> Instant {
        try Instant(ISO8601DateFormatter().date(from: text)!)
    }
    let coverage = try CalendarSyncHorizon.window(
        containing: point("2026-03-08T12:00:00Z"), timeZone: TimeZoneID("America/Detroit"))
    let read = try CalendarReadRequest(calendars: [scope.source], window: coverage)
    func materialize(_ zone: String, _ start: String, _ end: String, _ original: String) throws
        -> [CalendarOccurrence]
    {
        try CalendarEventNormalization.occurrences(
            [
                CalendarEventRecord(
                    calendar: scope.source, itemID: "all-day-series",
                    start: point(start).date, end: point(end).date, allDay: true, timeZone: zone,
                    recurring: true, originalDate: point(original).date, occupancy: .busy,
                    status: .active,
                    title: .notFetched, location: .notFetched, notes: .notFetched)
            ], request: read)
    }
    let local = try materialize(
        "America/Detroit", "2026-03-07T05:00:00Z", "2026-03-10T04:00:00Z", "2026-03-01T05:00:00Z")
    var input = try await f.input(local, coverageWindow: coverage)
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    let wire = try #require(await f.remote.events.values.first)
    #expect(wire.start?.date == "2026-03-07" && wire.end?.date == "2026-03-10")
    #expect(wire.start?.dateTime == nil && wire.recurrence == nil)
    let abroad = try materialize(
        "Asia/Tokyo", "2026-03-06T15:00:00Z", "2026-03-09T15:00:00Z", "2026-02-28T15:00:00Z")
    input = try await f.input(abroad, coverageWindow: coverage)
    await authority.set(input)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func advancingHorizonAddsNewOccurrencesWithoutDeletingExpiredOnes() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let original = source(anchor: .timed(instant(1000)))
    var input = try await f.input([original])
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    let added = source(
        time: .timed(
            try InstantInterval(start: instant(11000), end: instant(12000)),
            timeZone: try TimeZoneID("UTC")), anchor: .timed(instant(11000)))
    let nextWindow = try InstantInterval(start: instant(2500), end: instant(20000))
    input = try await f.input([added], baselineSources: [original], coverageWindow: nextWindow)
    await authority.set(input)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().map(\.httpMethod) == ["POST", "POST"])
    #expect(try await f.store.snapshot().events.count == 2)
    input = try await f.input(
        [added], baselineSources: [original, added], coverageWindow: nextWindow)
    await authority.set(input)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().count == 2)
    await f.store.close()
}

@Test func destructiveBatchApprovalCannotBeReusedForADifferentDeletionSet() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let originals = [source("one"), source("two")]
    var input = try await f.input(originals)
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    input = try await f.input([source("one", status: .cancelled), source("two")])
    await authority.set(input)
    await authority.approveDeletes()
    input = try await f.input([
        source("one", status: .cancelled), source("two", status: .cancelled),
    ])
    await authority.set(input)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .blocked)
    #expect(await f.remote.writes().count == 2)
    await authority.approveDeletes()
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    #expect(await f.remote.writes().filter { $0.httpMethod == "DELETE" }.count == 2)
    await f.store.close()
}

private struct PerItemOnlyAuthority: ExecutionAuthorizing {
    let input: ReconciliationInput
    func currentInput() -> ReconciliationInput { input }
    func check(_ request: ExecutionRequest) {}
}

@Test func permissiveItemAuthorityCannotBypassDefaultBatchDeletionDenial() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let authority = Authority(input, f.binding)
    #expect(
        await f.executor(authority).run(preview: ReconciliationPlanner.plan(input)).status
            == .completed)
    let deletes = try await f.input([source(status: .cancelled)])
    #expect(
        await f.executor(PerItemOnlyAuthority(input: deletes)).run(
            preview: ReconciliationPlanner.plan(deletes)
        ).status == .blocked)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func incompleteSourceCannotDeleteExistingRemoteEvents() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    #expect(await executor.run(preview: ReconciliationPlanner.plan(input)).status == .completed)
    for completeness: ReadCompleteness in [
        .unknown, .partial(.morePages), .partial(.interrupted(.revoked)),
    ] {
        let state = ObservationState(
            observedAt: instant(100), completeness: completeness, freshness: .localCache)
        let incomplete = try await f.input([], baselineSources: [source()], sourceState: state)
        await authority.set(incomplete)
        await authority.approveDeletes()
        #expect(
            await executor.run(preview: ReconciliationPlanner.plan(incomplete)).status == .blocked)
    }
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func preparedIntentResumesWithOriginalIdentityOnlyAfterFreshApproval() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let proposal = try #require(plan.proposals.first)
    let operation = try await f.store.prepareInsert(
        resourceID: f.resource,
        sourceKey: PersistenceDigest(PlanningFingerprint.occurrence(proposal.source).value),
        fingerprint: PersistenceDigest(
            PlanningFingerprint.content(
                PlannedEventContent(time: source().time, isFree: false, title: "Busy")
            ).value))
    #expect(
        await f.executor(InactiveExecutionAuthority()).resumePrepared(
            operationID: operation.id,
            proposal: proposal, preview: plan
        ).status == .blocked)
    #expect(
        try await f.store.snapshot().operations.first { $0.id == operation.id }?.state == .prepared)
    let authority = Authority(input, f.binding)
    let executor = f.executor(authority)
    let originalID = try #require(try await f.store.snapshot().events.first).destinationEventID
    #expect(
        await executor.resumePrepared(operationID: operation.id, proposal: proposal, preview: plan)
            .status == .recovered)
    #expect(try await f.store.snapshot().events.first?.destinationEventID == originalID)
    #expect(try await f.store.snapshot().checkpoint.revision == 0)
    #expect(
        await executor.resumePrepared(operationID: operation.id, proposal: proposal, preview: plan)
            .status == .recoveryRequired)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func newProviderSessionAndReopenedStoreRecoverUnknownInsertWithoutReplay() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    let plan = ReconciliationPlanner.plan(input)
    let authority = Authority(input, f.binding)
    await f.remote.configure(lost: true)
    #expect(await f.executor(authority).run(preview: plan).status == .recoveryRequired)
    let before = try await f.store.snapshot()
    let operation = try #require(before.operations.first { $0.kind == .insertEvent })
    let marker = try #require(UUID(uuidString: f.bridge.marker))
    await f.store.close()
    let reopened = try SQLiteSyncStore(
        directory: f.root.appendingPathComponent("store"), binding: f.binding, mode: .resume)
    let client = GoogleDestinationClient(transport: f.remote)
    let handle = try await client.restoreDestination(
        calendarID: f.bridge.calendarID, ownershipMarker: marker,
        writerID: f.binding.installationID, authorize: {})
    let bridge = try await client.durableDestination(handle)
    let executor = SynchronizationExecutor(
        store: reopened, binding: f.binding, destination: bridge, authority: authority)
    #expect(
        await executor.recover(
            operationID: operation.id, proposal: try #require(plan.proposals.first), preview: plan
        ).status == .recovered)
    #expect(try await reopened.snapshot().events.first?.id == before.events.first?.id)
    #expect(await f.remote.writes().count == 1)
    await reopened.close()
}

private func review(_ store: SQLiteSyncStore, replacement: CalendarReference = scope.source)
    async throws -> RecoveryReview
{
    let state = try await store.snapshot()
    let event = try #require(state.events.first)
    return RecoveryReview(
        expected: state, resourceID: event.resourceID, source: replacement,
        events: [
            RecoveryEventBinding(
                eventID: event.id, original: source().id,
                replacement: OccurrenceReference(
                    calendar: replacement, item: source().id.item, originalAnchor: .notRecurring),
                baseline: PlannedEventContent(time: source().time, isFree: false, title: "Busy"))
        ])
}

@Test func verifiedLegacyRebaselineAndCalendarMigrationPreserveRemoteIdentity() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let input = try await f.input()
    #expect(
        await f.executor(Authority(input, f.binding)).run(
            preview: ReconciliationPlanner.plan(input)
        ).status == .completed)
    let before = try await f.store.snapshot()
    let event = try #require(before.events.first)
    let legacy = try PlanningFingerprint.legacyContentV1(
        PlannedEventContent(time: source().time, isFree: false, title: "Busy"))
    try await f.store.recoverMetadata(
        expected: before, resourceID: f.resource, sourceKey: before.resources[0].sourceKey,
        changes: [
            RecoveryMappingChange(
                eventID: event.id, sourceKey: event.sourceKey,
                fingerprint: PersistenceDigest(legacy.value))
        ])
    let candidate = try await review(f.store, replacement: reference("moved-calendar"))
    let denied = SynchronizationRecovery(store: f.store, destination: f.bridge)
    await #expect(throws: ExecutionFailure.blocked) { try await denied.recoverMetadata(candidate) }
    let recovery = SynchronizationRecovery(
        store: f.store, destination: f.bridge,
        authorize: {
            guard $0 == candidate else { throw ExecutionFailure.blocked }
        })
    try await recovery.recoverMetadata(candidate)
    let after = try await f.store.snapshot()
    #expect(
        after.events[0].destinationEventID == event.destinationEventID
            && after.events[0].etag == event.etag)
    #expect(after.events[0].fingerprint == before.events[0].fingerprint)
    #expect(
        after.resources[0].sourceKey.value
            == PlanningFingerprint.calendar(reference("moved-calendar")).value)
    #expect(after.checkpoint.completedRun == nil && after.operations == before.operations)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func recoveryRejectsRemoteEditsAndLocalDriftWithoutMetadataChanges() async throws {
    for localDrift in [false, true] {
        let f = try await Fixture.make()
        defer { f.remove() }
        let input = try await f.input()
        #expect(
            await f.executor(Authority(input, f.binding)).run(
                preview: ReconciliationPlanner.plan(input)
            ).status == .completed)
        let candidate = try await review(f.store)
        if localDrift {
            _ = try await f.store.commitCheckpoint(
                expectedRevision: candidate.expected.checkpoint.revision, completedRun: UUID())
        } else {
            await f.remote.edit()
        }
        let before = try await f.store.snapshot()
        let recovery = SynchronizationRecovery(
            store: f.store, destination: f.bridge, authorize: { _ in })
        await #expect(throws: (any Error).self) { try await recovery.recoverMetadata(candidate) }
        #expect(try await f.store.snapshot() == before)
        #expect(await f.remote.writes().count == 1)
        await f.store.close()
    }
}

@Test func missingMappingsRestoreOnlyFromCompleteVerifiedCandidate() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let incompleteBackup = try await f.store.snapshot()
    let input = try await f.input()
    #expect(
        await f.executor(Authority(input, f.binding)).run(
            preview: ReconciliationPlanner.plan(input)
        ).status == .completed)
    let completeBackup = try await f.store.snapshot()
    for (name, backup) in [("complete", completeBackup), ("incomplete", incompleteBackup)] {
        let replacement = try SQLiteSyncStore(
            directory: f.root.appendingPathComponent(name),
            binding: f.binding, mode: .createNew)
        try await replacement.restoreCandidate(backup)
        let recovery = SynchronizationRecovery(
            store: replacement, destination: f.bridge, authorize: { _ in })
        if name == "complete" {
            try await recovery.recoverMetadata(review(replacement))
            #expect(try await replacement.snapshot().events == completeBackup.events)
        } else {
            let candidate = RecoveryReview(
                expected: try await replacement.snapshot(), resourceID: f.resource,
                source: scope.source, events: [])
            await #expect(throws: ExecutionFailure.recoveryRequired) {
                try await recovery.recoverMetadata(candidate)
            }
            #expect(try await replacement.snapshot().events.isEmpty)
        }
        await replacement.close()
    }
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot() == completeBackup)
    await f.store.close()
}

@Test func lostCalendarCreationResponseRecoversByCandidateReadWithoutAnotherPost() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let store = try SQLiteSyncStore(
        directory: f.root.appendingPathComponent("lost-calendar"),
        binding: f.binding, mode: .createNew)
    let operation = try await store.prepareDestination(
        sourceKey: PersistenceDigest(PlanningFingerprint.calendar(scope.source).value))
    _ = try await store.beginAttempt(operation.id)
    let remote = Remote()
    await remote.loseCalendarCreation()
    let client = GoogleDestinationClient(transport: remote)
    await #expect(throws: GoogleDestinationFailure.outcomeUnknown) {
        try await client.createDestination(
            ownershipMarker: operation.id, writerID: f.binding.installationID)
    }
    let restarted = GoogleDestinationClient(transport: remote)
    let handle = try await restarted.restoreDestination(
        calendarID: scope.destination.localID.rawValue,
        ownershipMarker: operation.id, writerID: f.binding.installationID, authorize: {})
    let bridge = try await restarted.durableDestination(handle)
    let recovery = SynchronizationRecovery(store: store, destination: bridge)
    await #expect(throws: ExecutionFailure.blocked) {
        try await recovery.recoverDestination(operationID: operation.id)
    }
    try await recovery.recoverDestination(
        operationID: operation.id,
        authorizeCreation: { snapshot in
            guard snapshot.binding == f.binding,
                snapshot.operations.contains(where: { $0.id == operation.id })
            else {
                throw ExecutionFailure.blocked
            }
        })
    #expect(
        try await store.snapshot().resources[0].destinationID == scope.destination.localID.rawValue)
    #expect(try await store.snapshot().checkpoint.completedRun == nil)
    #expect(await remote.requests.filter { $0.httpMethod == "POST" }.count == 1)
    await store.close()
    await f.store.close()
}

@Test func writerTransferRequiresResolvedJournalAndExactTrustedRecipient() async throws {
    for pending in [false, true] {
        let f = try await Fixture.make()
        defer { f.remove() }
        if pending {
            _ = try await f.store.prepareInsert(
                resourceID: f.resource,
                sourceKey: PersistenceDigest(PlanningFingerprint.occurrence(source().id).value),
                fingerprint: PersistenceDigest(String(repeating: "a", count: 64)))
        }
        let recovery = SynchronizationRecovery(store: f.store, destination: f.bridge)
        let recipient = UUID()
        await #expect(throws: (any Error).self) { try await recovery.transferWriter(to: recipient) }
        let approval: @Sendable (PersistenceSnapshot, UUID) async throws -> Void = {
            snapshot, target in
            guard snapshot.binding == f.binding, target == recipient else {
                throw ExecutionFailure.blocked
            }
        }
        if pending {
            await #expect(throws: ExecutionFailure.recoveryRequired) {
                try await recovery.transferWriter(to: recipient, authorizeTransfer: approval)
            }
            #expect(await f.remote.requests.filter { $0.httpMethod == "PATCH" }.isEmpty)
        } else {
            try await recovery.transferWriter(to: recipient, authorizeTransfer: approval)
            let client = GoogleDestinationClient(transport: f.remote)
            let owner = try #require(UUID(uuidString: f.bridge.marker))
            _ = try await client.restoreDestination(
                calendarID: f.bridge.calendarID, ownershipMarker: owner,
                writerID: recipient, authorize: {})
            #expect(await f.remote.requests.filter { $0.httpMethod == "PATCH" }.count == 1)
        }
        await f.store.close()
    }
}

@Test func scheduledJobRefreshesInputAndKeepsExecutorApproval() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let authority = Authority(try await f.input(), f.binding)
    let job = ScheduledSynchronizationJob(
        store: f.store, binding: f.binding, destination: f.bridge, authority: authority)
    #expect(await job.run(check: {}) == .completed)
    #expect(await f.remote.writes().count == 1)
    await authority.set(try await f.input())
    #expect(await job.run(check: {}) == .completed)
    #expect(await f.remote.writes().count == 1)
    await authority.revoke()
    #expect(await job.run(check: {}) == .needsAttention)
    #expect(await f.remote.writes().count == 1)
    await f.store.close()
}

@Test func scheduledJobNeverAutomaticallyReplaysUnknownWrites() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    await f.remote.configure(lost: true)
    let job = ScheduledSynchronizationJob(
        store: f.store, binding: f.binding, destination: f.bridge,
        authority: Authority(try await f.input(), f.binding))
    #expect(await job.run(check: {}) == .needsAttention)
    #expect(await job.run(check: {}) == .needsAttention)
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot().checkpoint.completedRun == nil)
    await f.store.close()
}

@Test func scheduledJobRechecksCancellationAtRemoteAttempts() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let gate = ScheduledTestGate()
    await f.remote.configure(quota: true)
    await f.remote.setQuotaHook { await gate.revoke() }
    let job = ScheduledSynchronizationJob(
        store: f.store, binding: f.binding, destination: f.bridge,
        authority: Authority(try await f.input(), f.binding))
    #expect(await job.run(check: { try await gate.check() }) == .needsAttention)
    #expect(await f.remote.writes().count == 1)
    #expect(await f.remote.events.isEmpty)
    await f.store.close()
}

private actor ScheduledTestGate {
    var allowed = true
    func revoke() { allowed = false }
    func check() throws { if !allowed { throw CancellationError() } }
}

private struct TransientPreparation: ExecutionAuthorizing {
    func currentInput() throws -> ReconciliationInput {
        throw BackgroundPreparationFailure.retry(after: 45)
    }
    func check(_ request: ExecutionRequest) throws { throw ExecutionFailure.blocked }
}

@Test func scheduledRetriesOnlyKnownPreparationFailuresAndRejectsPendingJournal() async throws {
    let f = try await Fixture.make()
    defer { f.remove() }
    let job = ScheduledSynchronizationJob(
        store: f.store, binding: f.binding, destination: f.bridge, authority: TransientPreparation()
    )
    #expect(await job.run(check: {}) == .retry(after: 45))
    _ = try await f.store.prepareInsert(
        resourceID: f.resource,
        sourceKey: PersistenceDigest(PlanningFingerprint.occurrence(source().id).value),
        fingerprint: PersistenceDigest(String(repeating: "a", count: 64)))
    #expect(await job.run(check: {}) == .needsAttention)
    #expect(await f.remote.writes().isEmpty)
    await f.store.close()
}

private func onboarding(
    _ fixture: Fixture, _ authority: Authority,
    now: @escaping @Sendable () -> Date = { Date() }
) async -> GoogleSyncWorkflow {
    let workflow = GoogleSyncWorkflow(
        store: fixture.store, binding: fixture.binding,
        factory: { _ in
            [
                SyncOnboardingLane(
                    scope: scope, binding: fixture.binding,
                    store: fixture.store, destination: fixture.bridge, authority: authority)
            ]
        },
        connect: {}, check: { _ = try await authority.currentInput() }, now: now)
    await workflow.setWriterActive(true)
    await workflow.setEnvironment(awake: true, sessionActive: true, online: true)
    return workflow
}

@Test func onboardingReviewsCreatesEditsClearsAndRestoresPausedPreferences() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(detailed: true), f.binding)
    let workflow = await onboarding(f, authority)
    #expect(await workflow.connect().phase == .ready)
    let detailed = CalendarSyncConfiguration(sources: [scope.source], fields: [.title])
    let review = try await workflow.preview(detailed)
    #expect(review.items.first?.contentTitle == "Synthetic title")
    #expect(await f.remote.writes().isEmpty)
    let first = await workflow.confirm(review.id, approveDeletions: false)
    #expect(first.lastSuccess != nil && first.phase == .waiting)
    _ = await workflow.pause()
    let original = try #require(try await f.store.snapshot().events.first)
    #expect(await f.remote.events[original.destinationEventID]?.summary == "Synthetic title")
    let moved = source(
        time: .timed(
            try InstantInterval(start: instant(3000), end: instant(4000)),
            timeZone: try TimeZoneID("UTC")))
    await authority.set(try await f.input([moved], detailed: true))
    let edit = try await workflow.preview(detailed)
    #expect(edit.items.first?.action == .update)
    #expect(await workflow.confirm(edit.id, approveDeletions: false).lastSuccess != nil)
    _ = await workflow.pause()
    #expect(
        try await f.store.snapshot().events.first?.destinationEventID == original.destinationEventID
    )
    await authority.set(try await f.input([moved]))
    let availability = CalendarSyncConfiguration(sources: [scope.source])
    let clearing = try await workflow.preview(availability)
    #expect(clearing.items.first?.contentTitle == "Busy")
    _ = await workflow.confirm(clearing.id, approveDeletions: false)
    _ = await workflow.pause()
    #expect(await f.remote.events[original.destinationEventID]?.summary == "Busy")
    await authority.set(try await f.input([moved]))
    let unchanged = try await workflow.preview(availability)
    #expect(unchanged.items.first?.action == .unchanged)
    let before = await f.remote.writes().count
    _ = await workflow.confirm(unchanged.id, approveDeletions: false)
    await workflow.shutdown()
    #expect(await f.remote.writes().count == before)
    let restored = await onboarding(f, authority)
    _ = await restored.connect()
    try await restored.restoreCandidates(from: [scope.source])
    #expect(await restored.status().phase == .paused)
    #expect(await restored.status().configuration == availability)
    #expect(await restored.status().lastSuccess == nil)
    _ = await restored.disconnect(revokeGrant: false)
    #expect(try await f.store.snapshot().preferences == nil)
    #expect(await f.remote.events.count == 1)
    await restored.shutdown()
    await f.store.close()
}

@Test func onboardingRejectsChangedAndConsumedReceipts() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(), f.binding)
    let workflow = await onboarding(f, authority)
    let config = CalendarSyncConfiguration(sources: [scope.source])
    let old = try await workflow.preview(config)
    await authority.set(try await f.input([source("two")]))
    #expect(await workflow.confirm(old.id, approveDeletions: true).failure == .staleReview)
    #expect(await f.remote.writes().isEmpty)
    let fresh = try await workflow.preview(config)
    await workflow.sourceChanged()
    #expect(await workflow.confirm(fresh.id, approveDeletions: true).failure == .staleReview)
    let next = try await workflow.preview(config)
    _ = await workflow.confirm(next.id, approveDeletions: false)
    _ = await workflow.pause()
    let writes = await f.remote.writes().count
    #expect(await workflow.confirm(next.id, approveDeletions: true).failure == .staleReview)
    #expect(await f.remote.writes().count == writes)
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingLostReplyNeverReportsSuccessOrReplaysOnReview() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(), f.binding)
    let workflow = await onboarding(f, authority)
    await f.remote.configure(lost: true)
    let config = CalendarSyncConfiguration(sources: [scope.source])
    let review = try await workflow.preview(config)
    let result = await workflow.confirm(review.id, approveDeletions: false)
    #expect(result.phase == .recoveryRequired && result.lastSuccess == nil)
    let writes = await f.remote.writes().count
    await #expect(throws: CalendarSyncFailure.recoveryRequired) {
        try await workflow.preview(config)
    }
    #expect(await f.remote.writes().count == writes)
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingDefaultDenyAndSelectionValidationCannotWrite() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let blocked = GoogleSyncWorkflow(store: f.store, binding: f.binding)
    #expect(await blocked.connect().failure == .notConfigured)
    await #expect(throws: CalendarSyncFailure.notConfigured) {
        try await blocked.preview(.init(sources: [scope.source]))
    }
    let authority = Authority(try await f.input(), f.binding)
    let workflow = await onboarding(f, authority)
    await #expect(throws: CalendarSyncFailure.invalidSelection) {
        try await workflow.preview(.init())
    }
    await #expect(throws: CalendarSyncFailure.invalidSelection) {
        try await workflow.preview(.init(sources: [scope.source, reference("unapproved")]))
    }
    await #expect(throws: CalendarSyncFailure.staleReview) {
        try await workflow.preview(.init(sources: [scope.source], fields: [.notes]))
    }
    await authority.revoke()
    await #expect(throws: CalendarSyncFailure.unavailable) {
        try await workflow.preview(.init(sources: [scope.source]))
    }
    #expect(await f.remote.writes().isEmpty)
    await workflow.shutdown()
    await blocked.shutdown()
    await f.store.close()
}

private final class ReviewClock: @unchecked Sendable {
    private let lock = NSLock()
    private var seconds: Double = 1000
    func now() -> Date { lock.withLock { Date(timeIntervalSince1970: seconds) } }
    func advance() { lock.withLock { seconds += 301 } }
}
private actor OnboardingBarrier {
    private var reached = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    func enter() async {
        reached = true
        waiter?.resume()
        waiter = nil
        await withCheckedContinuation { release = $0 }
    }
    func wait() async { if !reached { await withCheckedContinuation { waiter = $0 } } }
    func finish() {
        release?.resume()
        release = nil
    }
}

@Test func onboardingExpiredReviewAndInactiveSessionCannotDispatch() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(), f.binding)
    let clock = ReviewClock()
    let workflow = await onboarding(f, authority, now: clock.now)
    let config = CalendarSyncConfiguration(sources: [scope.source])
    let review = try await workflow.preview(config)
    clock.advance()
    #expect(await workflow.confirm(review.id, approveDeletions: true).failure == .staleReview)
    let fresh = try await workflow.preview(config)
    await workflow.setEnvironment(awake: true, sessionActive: false, online: true)
    #expect(await workflow.confirm(fresh.id, approveDeletions: true).lastSuccess == nil)
    #expect(await f.remote.writes().isEmpty)
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingRequiresWholeDeletionApprovalAndPreservesOriginalIdentity() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(), f.binding)
    let workflow = await onboarding(f, authority)
    let config = CalendarSyncConfiguration(sources: [scope.source])
    let initial = try await workflow.preview(config)
    _ = await workflow.confirm(initial.id, approveDeletions: false)
    _ = await workflow.pause()
    await authority.set(try await f.input([source(status: .cancelled)]))
    await authority.approveDeletes()
    let deletion = try await workflow.preview(config)
    #expect(deletion.deletionCount == 1 && deletion.items.first?.time != nil)
    let before = await f.remote.writes().count
    #expect(
        await workflow.confirm(deletion.id, approveDeletions: false).failure == .approvalRequired)
    #expect(await f.remote.writes().count == before)
    #expect(await workflow.confirm(deletion.id, approveDeletions: true).phase == .waiting)
    #expect(await f.remote.events.isEmpty)
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingPauseDrainsAcceptedWriteAndRejectsConcurrentResume() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let authority = Authority(try await f.input(), f.binding)
    let workflow = await onboarding(f, authority)
    let barrier = OnboardingBarrier()
    await f.remote.setHook { await barrier.enter() }
    let config = CalendarSyncConfiguration(sources: [scope.source])
    let review = try await workflow.preview(config)
    let running = Task { await workflow.confirm(review.id, approveDeletions: false) }
    await barrier.wait()
    let stopping = Task { await workflow.pause() }
    while await workflow.status().phase != .paused { await Task.yield() }
    await #expect(throws: CalendarSyncFailure.busy) { try await workflow.preview(config) }
    await barrier.finish()
    _ = await running.value
    let stopped = await stopping.value
    #expect(stopped.phase == .paused && stopped.lastSuccess == nil)
    #expect(await f.remote.writes().count == 1)
    #expect(try await f.store.snapshot().checkpoint.revision == 0)
    await #expect(throws: CalendarSyncFailure.recoveryRequired) {
        try await workflow.preview(config)
    }
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingDisconnectDrainsLateSignInAndCannotReenable() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let barrier = OnboardingBarrier()
    let workflow = GoogleSyncWorkflow(
        store: f.store, binding: f.binding,
        connect: { await barrier.enter() }, check: {})
    let connecting = Task { await workflow.connect() }
    await barrier.wait()
    let stopping = Task { await workflow.disconnect(revokeGrant: false) }
    while await workflow.status().phase != .disconnected { await Task.yield() }
    await barrier.finish()
    _ = await connecting.value
    #expect(await stopping.value.phase == .disconnected)
    #expect(await workflow.status().phase == .disconnected)
    #expect(await f.remote.writes().isEmpty)
    await workflow.shutdown()
    await f.store.close()
}

@Test func onboardingOngoingConsentCannotApproveLaterDeletions() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let plan = ReconciliationPlanner.plan(try await f.input())
    let permit = SyncOnboardingPermit()
    let token = await permit.issue(.init(sources: [scope.source]), plans: [plan])
    try await permit.checkDeletions(token, plan: plan)
    try await permit.complete(token, at: Date())
    try await permit.check(token, plan: plan)
    await #expect(throws: ExecutionFailure.blocked) {
        try await permit.checkDeletions(token, plan: plan)
    }
    await permit.revoke()
    await #expect(throws: ExecutionFailure.blocked) { try await permit.check(token, plan: plan) }
    await f.store.close()
}

@Test func onboardingDisconnectFailureStillStopsLocalAccessAndPreservesRemoteCopies() async throws {
    let f = try await Fixture.make()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let workflow = GoogleSyncWorkflow(
        store: f.store, binding: f.binding,
        disconnect: { _ in throw CalendarSyncFailure.unavailable })
    let result = await workflow.disconnect(revokeGrant: true)
    #expect(result.phase == .disconnected && result.failure == .disconnectIncomplete)
    #expect(await f.remote.writes().isEmpty)
    await workflow.shutdown()
    await f.store.close()
}

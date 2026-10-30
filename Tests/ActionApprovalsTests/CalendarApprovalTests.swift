import CoreDomain
import Foundation
import PermissionEngine
import Testing

@testable import ActionApprovals
@testable import MCPConnections

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
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    func now() -> TimeInterval { lock.withLock { value } }
    func advance(_ amount: TimeInterval) { lock.withLock { value += amount } }
}
private actor Probe: CalendarActionProvider {
    let base: SyntheticActionProvider
    var reads = 0
    var writes = 0
    var changes: [CalendarMutation] = []
    var holdRead: (Int, Barrier)?
    var holdWrite: Barrier?
    var unknown = false
    var wrongReceipt = false
    var altered = false
    var overReturn = false
    var conflictAtApply = false
    var expectedNotes: FieldValue<String?>?
    init(_ base: SyntheticActionProvider) { self.base = base }
    func readGate(_ count: Int, _ gate: Barrier) { holdRead = (count, gate) }
    func writeGate(_ gate: Barrier) { holdWrite = gate }
    func uncertain() { unknown = true }
    func mismatch() { wrongReceipt = true }
    func alter() { altered = true }
    func overReturns() { overReturn = true }
    func races() { conflictAtApply = true }
    func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) async throws
        -> CalendarActionSnapshot
    {
        reads += 1
        if let (count, gate) = holdRead, count == reads { await gate.enter() }
        let value = try await base.inspect(
            change, fields: overReturn ? fields.union([.notes, .location]) : fields)
        if altered {
            return CalendarActionSnapshot(
                calendar: value.calendar, accountLabel: value.accountLabel,
                calendarLabel: "Changed after review", writable: value.writable, event: value.event)
        }
        return value
    }
    func apply(_ action: AuthorizedCalendarAction) async throws -> CalendarActionReceipt {
        writes += 1
        changes.append(action.proposal.change)
        expectedNotes = action.expected.event?.notes
        if conflictAtApply, let event = action.expected.event {
            let competing = ProposedChange(
                id: try OperationID("synthetic-racing-operation"),
                connection: action.proposal.connection,
                change: CalendarMutation.delete(event.id, precondition: event.revision))
            _ = try await base.apply(
                AuthorizedCalendarAction(
                    proposal: competing, expected: action.expected, fields: action.fields))
        }
        let result = try await base.apply(action)
        if let holdWrite { await holdWrite.enter() }
        if unknown { throw ProviderFailure.unavailable }
        if wrongReceipt { return .applied(try OperationID("synthetic-wrong-receipt")) }
        return result
    }
}
private struct Fixture {
    let seed: SyntheticActionFixture
    let provider: Probe
    let engine: CalendarApprovalEngine
    let clock: Clock
    static func make() async throws -> Self {
        let seed = try await SyntheticActionFixture.make()
        let probe = Probe(seed.provider)
        let clock = Clock()
        return Self(
            seed: seed, provider: probe,
            engine: CalendarApprovalEngine(
                session: seed.session, provider: probe, authorized: { true },
                uptime: { clock.now() }), clock: clock)
    }
    func review(_ kind: ActionKind = .update) async throws -> ActionReview {
        try await engine.prepare(seed.change(kind))
    }
    func token(_ kind: ActionKind = .update) async throws -> ActionConfirmation {
        try await engine.confirm(review(kind), acknowledgeDeletion: kind == .delete)
    }
}

@Test func approvalCreateUpdateDeleteExecuteExactlyOnceAfterLocalConfirmation() async throws {
    for kind in ActionKind.allCases {
        let f = try await Fixture.make()
        let review = try await f.review(kind)
        #expect(await f.provider.writes == 0)
        #expect(review.display.kind == kind)
        let confirmation = try await f.engine.confirm(review, acknowledgeDeletion: kind == .delete)
        #expect(await f.provider.writes == 0)
        #expect(await f.engine.commit(confirmation) == .applied)
        #expect(await f.engine.commit(confirmation) == .notApplied)
        #expect(await f.provider.writes == 1)
        #expect(await f.provider.changes == [try f.seed.change(kind)])
        let state = try await f.seed.provider.inspect(
            f.seed.change(.delete), fields: [.title, .location, .notes])
        switch kind {
        case .create: #expect(state.event?.title == f.seed.event.title)
        case .update:
            #expect(state.event?.title == .value("Sample revised planning session"))
            #expect(state.event?.location == .value(nil))
            #expect(state.event?.notes == f.seed.event.notes)
        case .delete: #expect(state.event == nil)
        }
    }
}
@Test func approvalForeignReviewsAndTokensCannotChooseAnotherConnectionOrArguments() async throws {
    let first = try await Fixture.make()
    let second = try await Fixture.make()
    let review = try await first.review(.create)
    await #expect(throws: (any Error).self) { try await second.engine.confirm(review) }
    let token = try await first.engine.confirm(review)
    #expect(await second.engine.commit(token) == .notApplied)
    _ = try await first.review(.delete)
    #expect(await first.engine.commit(token) == .applied)
    #expect(await first.provider.changes == [try first.seed.change(.create)])
    #expect(await second.provider.writes == 0)
}
@Test func approvalReviewAndConfirmationExpiryAreIndependentAndSingleUse() async throws {
    let f = try await Fixture.make()
    let review = try await f.review()
    f.clock.advance(121)
    await #expect(throws: (any Error).self) { try await f.engine.confirm(review) }
    let token = try await f.token()
    f.clock.advance(31)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.provider.writes == 0)
}
@Test func approvalDeletionRequiresSeparateLocalAcknowledgementAndRejectInvalidates() async throws {
    let f = try await Fixture.make()
    let review = try await f.review(.delete)
    await #expect(throws: (any Error).self) { try await f.engine.confirm(review) }
    let token = try await f.engine.confirm(review, acknowledgeDeletion: true)
    await f.engine.reject(review)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.provider.writes == 0)
}
@Test func approvalPolicyAndOSChangesInvalidateReviewedAndConfirmedActions() async throws {
    for os in [false, true] {
        for confirmed in [false, true] {
            let f = try await Fixture.make()
            let review = try await f.review()
            let token = confirmed ? try await f.engine.confirm(review) : nil
            if os {
                await f.seed.authority.observeOSPermissions(OSPermissions(calendars: .denied))
            } else {
                await f.seed.authority.revokeConnection(f.seed.session.connectionID)
            }
            if let token {
                #expect(await f.engine.commit(token) == .notApplied)
            } else {
                await #expect(throws: (any Error).self) { try await f.engine.confirm(review) }
            }
            #expect(await f.provider.writes == 0)
        }
    }
}
@Test func approvalSuspendedPrepareAndDispatchRecheckRevocation() async throws {
    for duringPrepare in [true, false] {
        let f = try await Fixture.make()
        let gate = Barrier()
        if duringPrepare {
            await f.provider.readGate(1, gate)
            let task = Task { try await f.review() }
            await gate.wait()
            await f.engine.invalidate()
            await gate.release()
            await #expect(throws: (any Error).self) { try await task.value }
        } else {
            let token = try await f.token()
            await f.provider.readGate(2, gate)
            let task = Task { await f.engine.commit(token) }
            await gate.wait()
            await f.seed.authority.revokeConnection(f.seed.session.connectionID)
            await gate.release()
            #expect(await task.value == .notApplied)
        }
        #expect(await f.provider.writes == 0)
    }
}
@Test func approvalChangedProviderStateAndConflictingPreconditionsDoNotWrite() async throws {
    let f = try await Fixture.make()
    let first = try await f.token()
    let competing = try await f.token()
    #expect(await f.engine.commit(competing) == .applied)
    #expect(await f.engine.commit(first) == .notApplied)
    #expect(await f.provider.writes == 1)
    let g = try await Fixture.make()
    let token = try await g.token()
    await g.provider.alter()
    #expect(await g.engine.commit(token) == .notApplied)
    #expect(await g.provider.writes == 0)
}
@Test func approvalConcurrentConfirmationAndCommitCannotReplay() async throws {
    let f = try await Fixture.make()
    let review = try await f.review()
    async let a = try? f.engine.confirm(review)
    async let b = try? f.engine.confirm(review)
    let tokens = await [a, b].compactMap { $0 }
    #expect(tokens.count == 1)
    let token = try #require(tokens.first)
    async let one = f.engine.commit(token)
    async let two = f.engine.commit(token)
    let outcomes = await [one, two]
    #expect(outcomes.filter { $0 == .applied }.count == 1)
    #expect(await f.provider.writes == 1)
}
@Test func approvalAcceptedWriteCanFinishAfterRevocationAndCancellation() async throws {
    let f = try await Fixture.make()
    let token = try await f.token()
    let gate = Barrier()
    await f.provider.writeGate(gate)
    let task = Task { await f.engine.commit(token) }
    await gate.wait()
    await f.engine.invalidate()
    task.cancel()
    await gate.release()
    #expect(await task.value == .applied)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.engine.activity().last?.phase == .applied)
}
@Test func approvalLostOrMismatchedReceiptsBlockFurtherWritesWithoutReplay() async throws {
    for wrong in [false, true] {
        let f = try await Fixture.make()
        let token = try await f.token(.create)
        let other = try await f.token(.create)
        if wrong { await f.provider.mismatch() } else { await f.provider.uncertain() }
        #expect(await f.engine.commit(token) == .unknown)
        #expect(await f.engine.commit(token) == .notApplied)
        #expect(await f.engine.commit(other) == .notApplied)
        await #expect(throws: (any Error).self) { try await f.review(.create) }
        #expect(await f.provider.writes == 1)
        #expect(await f.engine.activity().contains { $0.phase == .unknown })
    }
}
@Test func approvalCancellationBeforeDispatchConsumesConfirmation() async throws {
    let f = try await Fixture.make()
    let token = try await f.token()
    let gate = Barrier()
    await f.provider.readGate(2, gate)
    let task = Task { await f.engine.commit(token) }
    await gate.wait()
    task.cancel()
    await gate.release()
    #expect(await task.value == .notApplied)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.provider.writes == 0)
}
@Test func approvalDefaultAuthorizationAndReadOnlyMCPDoNotAcquireWrites() async throws {
    let f = try await Fixture.make()
    let denied = CalendarApprovalEngine(session: f.seed.session, provider: f.provider)
    await #expect(throws: (any Error).self) { try await denied.prepare(f.seed.change(.create)) }
    let connections = try ConnectionController(store: MemoryConnectionSettings())
    await connections.observePermissions(OSPermissions(calendars: .fullAccess))
    let record = try await connections.configure(
        label: "Synthetic read-only",
        grants: [
            SavedCalendarGrant(
                reference: f.seed.calendar, operations: [.details],
                fields: [.title, .time, .occupancy, .status])
        ])
    let pending = try await connections.requestPairing(ConnectionChannel(verify: { true }))
    let lease = try await connections.approve(connections.review(pending, connection: record.id))
    let engine = CalendarApprovalEngine(
        session: lease.session, provider: f.provider, authorized: { lease.isOpen })
    await #expect(throws: (any Error).self) { try await engine.prepare(f.seed.change(.create)) }
    #expect(await f.provider.reads == 0)
    #expect(await f.provider.writes == 0)
}
@Test func approvalReviewBoundsAndAuditNeverRetainEventContent() async throws {
    let f = try await Fixture.make()
    var reviews: [ActionReview] = []
    for _ in 0..<16 { reviews.append(try await f.review(.create)) }
    await #expect(throws: (any Error).self) { try await f.review(.create) }
    for review in reviews { await f.engine.reject(review) }
    for _ in 0..<70 {
        let review = try await f.review(.create)
        await f.engine.reject(review)
    }
    let audit = await f.engine.activity()
    #expect(audit.count == 128)
    #expect(audit.first!.sequence < audit.last!.sequence)
    #expect(!String(reflecting: audit).contains("Sample new event"))
}
@Test func approvalExactDiffsPreserveClearVersusTextAndRejectMalformedValues() async throws {
    let f = try await Fixture.make()
    let review = try await f.review()
    let location = try #require(review.display.rows.first { $0.field == "Location" })
    #expect(location.before == "\"Sample room\"" && location.after == "Not set")
    for title in ["", "\u{202E}spoof", String(repeating: "x", count: 513)] {
        await #expect(throws: (any Error).self) {
            try await f.engine.prepare(
                .create(
                    in: f.seed.calendar,
                    event: EventDraft(title: title, time: f.seed.event.time, occupancy: .busy)))
        }
    }
    let same = try EventChanges(title: .set("Sample planning session"))
    await #expect(throws: (any Error).self) {
        try await f.engine.prepare(
            .update(f.seed.event.id, changes: same, precondition: f.seed.event.revision))
    }
    let literal = try EventChanges(location: .set("Not set"))
    let different = try await f.engine.prepare(
        .update(f.seed.event.id, changes: literal, precondition: f.seed.event.revision))
    #expect(different.display.rows.last?.after == "\"Not set\"")
    let allDay = EventTime.allDay(
        try LocalDateInterval(
            start: LocalDate(year: 2026, month: 11, day: 1),
            end: LocalDate(year: 2026, month: 11, day: 2)),
        timeZone: try TimeZoneID("America/Detroit"))
    #expect(try CalendarActionReview.time(allDay).contains("end exclusive"))
}

@Test func approvalSerializedDispatchConsumesCompetingConfirmationWithoutQueueing() async throws {
    let f = try await Fixture.make()
    let first = try await f.token(.create)
    let second = try await f.token(.create)
    let gate = Barrier()
    await f.provider.writeGate(gate)
    let task = Task { await f.engine.commit(first) }
    await gate.wait()
    #expect(await f.engine.commit(second) == .notApplied)
    await #expect(throws: (any Error).self) { try await f.review(.create) }
    await gate.release()
    #expect(await task.value == .applied)
    #expect(await f.engine.commit(second) == .notApplied)
    #expect(await f.provider.writes == 1)
}
@Test func approvalReviewRequiresVisibleFieldsAndGoogleCannotWriteSources() async throws {
    for google in [false, true] {
        let f = try await Fixture.make()
        let id = f.seed.session.connectionID
        let fields: Set<CalendarField> =
            google
            ? [.title, .time, .occupancy, .status, .location, .notes]
            : [.time, .occupancy, .status]
        await f.seed.authority.setConnection(
            Connection(id: id, kind: google ? .googleSync : .localMCP, state: .enabled),
            policy: ConnectionPolicy(calendars: [
                f.seed.calendar: CalendarGrant(
                    operations: [.readDetails, .create, .update, .delete], readableFields: fields,
                    writableFields: fields)
            ]))
        let session = try await f.seed.authority.bindTrustedConnection(id)
        let engine = CalendarApprovalEngine(
            session: session, provider: f.provider, authorized: { true })
        await #expect(throws: (any Error).self) { try await engine.prepare(f.seed.change(.delete)) }
        await #expect(throws: (any Error).self) { try await engine.prepare(f.seed.change(.create)) }
        #expect(await f.provider.reads == 0)
    }
}
@Test func approvalLatePreparationCannotOutliveReviewExpiry() async throws {
    let f = try await Fixture.make()
    let gate = Barrier()
    await f.provider.readGate(1, gate)
    let task = Task { try await f.review() }
    await gate.wait()
    f.clock.advance(121)
    await gate.release()
    await #expect(throws: (any Error).self) { try await task.value }
    #expect(await f.provider.writes == 0)
}

@Test func approvalPreparingConcurrencyIsBoundedEvenWhenProvidersIgnoreCancellation() async throws {
    let f = try await Fixture.make()
    var gates: [Barrier] = []
    var tasks: [Task<ActionReview, any Error>] = []
    for index in 1...4 {
        let gate = Barrier()
        gates.append(gate)
        await f.provider.readGate(index, gate)
        tasks.append(Task { try await f.review() })
        await gate.wait()
    }
    await #expect(throws: (any Error).self) { try await f.review() }
    await f.engine.invalidate()
    for gate in gates { await gate.release() }
    for task in tasks { await #expect(throws: (any Error).self) { try await task.value } }
    #expect(await f.provider.reads == 4)
}
@Test func approvalOverReturnedFieldsAreExcludedFromReviewAndDispatchState() async throws {
    let f = try await Fixture.make()
    await f.provider.overReturns()
    let review = try await f.review()
    #expect(!String(reflecting: review.display).contains("Sample notes"))
    let token = try await f.engine.confirm(review)
    #expect(await f.engine.commit(token) == .applied)
    #expect(await f.provider.expectedNotes == .notFetched)
}
@Test func approvalProviderComparisonRejectsRaceAfterEngineRevalidation() async throws {
    let f = try await Fixture.make()
    let token = try await f.token()
    await f.provider.races()
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.provider.writes == 1)
}

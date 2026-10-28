import ActionApprovals
import CoreDomain
import Foundation
import PermissionEngine
import SyncPersistence
import Testing

@testable import CalendarMutations

private actor Gate {
    private var entered = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var suspended: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiting?.resume()
        waiting = nil
        await withCheckedContinuation { suspended = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { waiting = $0 } } }
    func release() {
        suspended?.resume()
        suspended = nil
    }
}
private actor Backend: CalendarMutationBackend {
    enum Mode { case normal, notApplied, lost, wrong, closeJournal }
    let seed: SyntheticActionFixture
    let journal: CalendarMutationJournal
    var mode: Mode = .normal
    var before: Gate?
    var after: Gate?
    var writes = 0
    var sawDurableIntent = false
    init(seed: SyntheticActionFixture, journal: CalendarMutationJournal) {
        self.seed = seed
        self.journal = journal
    }
    func configure(_ mode: Mode = .normal, before: Gate? = nil, after: Gate? = nil) {
        self.mode = mode
        self.before = before
        self.after = after
    }
    func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) async throws
        -> CalendarActionSnapshot
    {
        try await seed.provider.inspect(change, fields: fields)
    }
    func apply(_ action: AuthorizedCalendarAction) async throws -> CalendarActionReceipt {
        if let before { await before.enter() }
        guard await action.revalidate(), !Task.isCancelled else { return .notApplied }
        sawDurableIntent = try await journal.records().contains {
            $0.operation.uuidString == action.proposal.id.rawValue && $0.state == .pending
        }
        if mode == .notApplied { return .notApplied }
        writes += 1
        let receipt = try await seed.provider.apply(action)
        if let after { await after.enter() }
        switch mode {
        case .lost: throw ProviderFailure.unavailable
        case .wrong: return .applied(try OperationID(UUID().uuidString))
        case .closeJournal: await journal.close()
        default: break
        }
        return receipt
    }
}
private struct Fixture {
    let directory: URL
    let installation: UUID
    let seed: SyntheticActionFixture
    let journal: CalendarMutationJournal
    let backend: Backend
    let provider: JournaledCalendarProvider
    let engine: CalendarApprovalEngine
    static func make() async throws -> Self {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("machandle-calendar-test-\(UUID())", isDirectory: true)
        let installation = UUID()
        let journal = try CalendarMutationJournal(
            directory: directory, installation: installation, mode: .createNew)
        let seed = try await SyntheticActionFixture.make()
        let backend = Backend(seed: seed, journal: journal)
        let provider = JournaledCalendarProvider(backend: backend, journal: journal)
        return Self(
            directory: directory, installation: installation, seed: seed, journal: journal,
            backend: backend, provider: provider,
            engine: CalendarApprovalEngine(
                session: seed.session, provider: provider, authorized: { true }))
    }
    func confirmation(_ kind: ActionKind) async throws -> ActionConfirmation {
        let review = try await engine.prepare(seed.change(kind))
        return try await engine.confirm(review, acknowledgeDeletion: kind == .delete)
    }
    func clean() async throws {
        await journal.close()
        try FileManager.default.removeItem(at: directory)
    }
}

struct CalendarMutationTests {
    @Test func approvedOperationsPersistBeforeDispatchAndCannotReplay() async throws {
        for kind in ActionKind.allCases {
            let f = try await Fixture.make()
            let confirmation = try await f.confirmation(kind)
            #expect(await f.engine.commit(confirmation) == .applied)
            #expect(await f.engine.commit(confirmation) == .notApplied)
            #expect(await f.backend.writes == 1)
            #expect(await f.backend.sawDurableIntent)
            let records = try await f.journal.records()
            #expect(records.count == 1 && records[0].state == .applied)
            await f.journal.close()
            let reopened = try CalendarMutationJournal(
                directory: f.directory, installation: f.installation, mode: .resume)
            #expect(try await reopened.records() == records)
            await #expect(throws: PersistenceFailure.self) {
                try await reopened.begin(records[0].operation)
            }
            await reopened.close()
            try await f.clean()
        }
    }
    @Test func ambiguousReceiptsBlockAcrossEngineAndProcessRestart() async throws {
        for mode in [Backend.Mode.lost, .wrong] {
            let f = try await Fixture.make()
            await f.backend.configure(mode)
            #expect(await f.engine.commit(try await f.confirmation(.create)) == .unknown)
            await #expect(throws: (any Error).self) {
                try await f.engine.prepare(f.seed.change(.create))
            }
            await f.journal.close()
            let reopened = try CalendarMutationJournal(
                directory: f.directory, installation: f.installation, mode: .resume)
            #expect(try await reopened.records().first?.state == .unknown)
            let next = JournaledCalendarProvider(backend: f.backend, journal: reopened)
            let engine = CalendarApprovalEngine(
                session: f.seed.session, provider: next, authorized: { true })
            await #expect(throws: (any Error).self) {
                try await engine.prepare(f.seed.change(.create))
            }
            #expect(await f.backend.writes == 1)
            await reopened.close()
            try await f.clean()
        }
    }
    @Test func lostJournalReceiptLeavesDurablePendingAndDoesNotClaimRollback() async throws {
        let f = try await Fixture.make()
        await f.backend.configure(.closeJournal)
        #expect(await f.engine.commit(try await f.confirmation(.create)) == .unknown)
        #expect(await f.backend.writes == 1)
        let reopened = try CalendarMutationJournal(
            directory: f.directory, installation: f.installation, mode: .resume)
        #expect(try await reopened.records().first?.state == .pending)
        await #expect(throws: PersistenceFailure.self) { try await reopened.requireReady() }
        await reopened.close()
        try await f.clean()
    }
    @Test func crashAfterIntentBeforeDispatchNeverAutomaticallyRetries() async throws {
        let f = try await Fixture.make()
        try await f.journal.begin(UUID())
        await f.journal.close()
        let reopened = try CalendarMutationJournal(
            directory: f.directory, installation: f.installation, mode: .resume)
        await #expect(throws: PersistenceFailure.self) { try await reopened.requireReady() }
        await #expect(throws: PersistenceFailure.self) { try await reopened.begin(UUID()) }
        #expect(await f.backend.writes == 0)
        await reopened.close()
        try await f.clean()
    }
    @Test func explicitNonacceptanceAllowsFreshReview() async throws {
        let f = try await Fixture.make()
        await f.backend.configure(.notApplied)
        #expect(await f.engine.commit(try await f.confirmation(.create)) == .notApplied)
        #expect(try await f.journal.records().first?.state == .notApplied)
        await f.backend.configure()
        #expect(await f.engine.commit(try await f.confirmation(.create)) == .applied)
        #expect(await f.backend.writes == 1)
        try await f.clean()
    }
    @Test func revokedAfterJournalPreparationDoesNotWrite() async throws {
        let f = try await Fixture.make()
        let gate = Gate()
        await f.backend.configure(before: gate)
        let confirmation = try await f.confirmation(.update)
        let task = Task { await f.engine.commit(confirmation) }
        await gate.wait()
        await f.seed.authority.observeOSPermissions(OSPermissions(calendars: .denied))
        await gate.release()
        #expect(await task.value == .notApplied)
        #expect(await f.backend.writes == 0)
        #expect(try await f.journal.records().first?.state == .notApplied)
        try await f.clean()
    }
    @Test func cancellationBeforeAndAfterProviderAcceptanceHasDifferentOutcomes() async throws {
        for accepted in [false, true] {
            let f = try await Fixture.make()
            let gate = Gate()
            await f.backend.configure(before: accepted ? nil : gate, after: accepted ? gate : nil)
            let confirmation = try await f.confirmation(.delete)
            let task = Task { await f.engine.commit(confirmation) }
            await gate.wait()
            task.cancel()
            await f.engine.invalidate()
            await gate.release()
            #expect(await task.value == (accepted ? .applied : .notApplied))
            #expect(await f.backend.writes == (accepted ? 1 : 0))
            #expect(
                try await f.journal.records().first?.state == (accepted ? .applied : .notApplied))
            try await f.clean()
        }
    }
    @Test func twoEnginesCannotDispatchConcurrentlyThroughOneProvider() async throws {
        let f = try await Fixture.make()
        let second = CalendarApprovalEngine(
            session: f.seed.session, provider: f.provider, authorized: { true })
        let review = try await second.prepare(f.seed.change(.create))
        let confirmation = try await second.confirm(review)
        let first = try await f.confirmation(.create)
        let gate = Gate()
        await f.backend.configure(after: gate)
        let task = Task { await f.engine.commit(first) }
        await gate.wait()
        #expect(await second.commit(confirmation) == .notApplied)
        await gate.release()
        #expect(await task.value == .applied)
        #expect(await f.backend.writes == 1)
        try await f.clean()
    }
    @Test func missingJournalAndLiveActivationFailClosed() async throws {
        let f = try await Fixture.make()
        #expect(throws: (any Error).self) { try JournaledCalendarProvider.live(journal: f.journal) }
        let confirmation = try await f.confirmation(.create)
        await f.journal.close()
        #expect(await f.engine.commit(confirmation) == .notApplied)
        #expect(await f.backend.writes == 0)
        try await f.clean()
    }
    @Test func unsupportedRecurrenceAndUnknownVersionCannotBecomeSingleEvents() async throws {
        let seed = try await SyntheticActionFixture.make()
        for anchor in [
            RecurrenceAnchor.unknown, .timed(try Instant(Date())),
            .allDay(try LocalDate(year: 2027, month: 1, day: 2)),
        ] {
            let id = OccurrenceReference(
                calendar: seed.calendar, item: seed.event.id.item, originalAnchor: anchor)
            #expect(throws: (any Error).self) {
                try CalendarMutationScope.validate(.delete(id, precondition: seed.event.revision))
            }
        }
        #expect(throws: (any Error).self) {
            try CalendarMutationScope.validate(.delete(seed.event.id, precondition: .unknown))
        }
        try CalendarMutationScope.validate(seed.change(.delete))
        #expect(throws: (any Error).self) { try CalendarMutationScope.revision(nil) }
    }
    @Test func foreignTargetsAndUnsafeEventMetadataFailClosed() async throws {
        let seed = try await SyntheticActionFixture.make()
        let foreign = CalendarReference(
            account: seed.calendar.account, localID: try DomainID("other-calendar"))
        for (actual, writable, events) in [
            (foreign, true, true), (seed.calendar, false, true), (seed.calendar, true, false),
        ] {
            #expect(throws: (any Error).self) {
                try CalendarMutationScope.validateTarget(
                    seed.calendar, actual: actual, writable: writable, allowsEvents: events)
            }
        }
        for index in 0..<8 {
            let actual = OccurrenceReference(
                calendar: index == 0 ? foreign : seed.calendar,
                item: index == 1 ? try EventID("foreign-event") : seed.event.id.item,
                originalAnchor: .notRecurring)
            #expect(throws: (any Error).self) {
                try CalendarMutationScope.validateEvent(
                    seed.event.id, actual: actual,
                    recurring: index == 2, detached: index == 3, hasOccurrenceDate: index == 4,
                    hasAttendees: index == 5, hasOrganizer: index == 6, cancelled: index == 7)
            }
        }
    }
    @Test func civilDaysRetainExclusiveEndAcrossDSTAndSubsecondsAreRejected() throws {
        let zone = try TimeZoneID("America/Detroit")
        let time = EventTime.allDay(
            try LocalDateInterval(
                start: LocalDate(year: 2027, month: 3, day: 14),
                end: LocalDate(year: 2027, month: 3, day: 15)), timeZone: zone)
        let mapped = try CalendarMutationScope.time(time)
        #expect(mapped.allDay)
        #expect(mapped.end.timeIntervalSince(mapped.start) == 23 * 3600)
        #expect(
            try CalendarMutationScope.civil(mapped.end, zone: mapped.zone)
                == LocalDate(year: 2027, month: 3, day: 15))
        let fractional = EventTime.timed(
            try InstantInterval(
                start: Instant(Date(timeIntervalSince1970: 100.5)),
                end: Instant(Date(timeIntervalSince1970: 200))), timeZone: zone)
        #expect(throws: (any Error).self) { try CalendarMutationScope.time(fractional) }
    }
}

import ActionApprovals
import CoreDomain
import Foundation
import PermissionEngine
import SyncPersistence
import Testing

@testable import ReminderMutations

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
private actor Backend: ReminderMutationBackend {
    enum Mode { case normal, notApplied, lost, wrong, closeJournal }
    let seed: SyntheticReminderActionFixture
    let journal: ReminderMutationJournal
    var mode: Mode = .normal
    var before: Gate?
    var after: Gate?
    var writes = 0
    var sawDurableIntent = false
    init(seed: SyntheticReminderActionFixture, journal: ReminderMutationJournal) {
        self.seed = seed
        self.journal = journal
    }
    func configure(_ mode: Mode = .normal, before: Gate? = nil, after: Gate? = nil) {
        self.mode = mode
        self.before = before
        self.after = after
    }
    func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) async throws
        -> ReminderActionSnapshot
    {
        try await seed.provider.inspect(change, fields: fields)
    }
    func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt {
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
    let seed: SyntheticReminderActionFixture
    let journal: ReminderMutationJournal
    let backend: Backend
    let provider: JournaledReminderProvider
    let engine: ReminderApprovalEngine
    static func make(completed: Bool = false) async throws -> Self {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("machandle-calendar-test-\(UUID())", isDirectory: true)
        let installation = UUID()
        let journal = try ReminderMutationJournal(
            directory: directory, installation: installation, mode: .createNew)
        let seed = try await SyntheticReminderActionFixture.make(completed: completed)
        let backend = Backend(seed: seed, journal: journal)
        let provider = JournaledReminderProvider(backend: backend, journal: journal)
        return Self(
            directory: directory, installation: installation, seed: seed, journal: journal,
            backend: backend, provider: provider,
            engine: ReminderApprovalEngine(
                session: seed.session, provider: provider, authorized: { true }))
    }
    func confirmation(_ kind: ReminderActionKind) async throws -> ReminderConfirmation {
        let review = try await engine.prepare(seed.change(kind))
        return try await engine.confirm(review, acknowledgeDeletion: kind == .delete)
    }
    func clean() async throws {
        await journal.close()
        try FileManager.default.removeItem(at: directory)
    }
}

struct ReminderMutationTests {
    @Test func approvedOperationsPersistBeforeDispatchAndCannotReplay() async throws {
        for kind in ReminderActionKind.allCases {
            let f = try await Fixture.make(completed: kind == .uncomplete)
            let confirmation = try await f.confirmation(kind)
            #expect(await f.engine.commit(confirmation) == .applied)
            #expect(await f.engine.commit(confirmation) == .notApplied)
            #expect(await f.backend.writes == 1)
            #expect(await f.backend.sawDurableIntent)
            let records = try await f.journal.records()
            #expect(records.count == 1 && records[0].state == .applied)
            await f.journal.close()
            let reopened = try ReminderMutationJournal(
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
            let reopened = try ReminderMutationJournal(
                directory: f.directory, installation: f.installation, mode: .resume)
            #expect(try await reopened.records().first?.state == .unknown)
            let next = JournaledReminderProvider(backend: f.backend, journal: reopened)
            let engine = ReminderApprovalEngine(
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
        let reopened = try ReminderMutationJournal(
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
        let reopened = try ReminderMutationJournal(
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
        let second = ReminderApprovalEngine(
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
        #expect(throws: (any Error).self) { try JournaledReminderProvider.live(journal: f.journal) }
        let confirmation = try await f.confirmation(.create)
        await f.journal.close()
        #expect(await f.engine.commit(confirmation) == .notApplied)
        #expect(await f.backend.writes == 0)
        try await f.clean()
    }
}

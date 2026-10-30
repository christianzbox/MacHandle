import CoreDomain
import Foundation
import PermissionEngine
import Testing

@testable import ActionApprovals

private final class ReminderClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    func now() -> TimeInterval { lock.withLock { value } }
    func advance(_ amount: TimeInterval) { lock.withLock { value += amount } }
}
private actor ReminderProbe: ReminderActionProvider {
    let base: SyntheticReminderActionProvider
    var reads = 0
    var writes = 0
    var altered = false
    var recurring = false
    var missingRevision = false
    var hiddenNotes: FieldValue<String?>?
    init(_ base: SyntheticReminderActionProvider) { self.base = base }
    func changeTarget() { altered = true }
    func repeatItem() { recurring = true }
    func unknownRevision() { missingRevision = true }
    func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) async throws
        -> ReminderActionSnapshot
    {
        reads += 1
        let value = try await base.inspect(change, fields: fields.union([.notes]))
        let reminder = value.reminder.map {
            Reminder(
                id: $0.id, title: $0.title, notes: $0.notes, due: $0.due, completion: $0.completion,
                recurrence: recurring ? .value(.recurring) : $0.recurrence,
                revision: missingRevision ? .unknown : $0.revision)
        }
        return ReminderActionSnapshot(
            list: value.list, accountLabel: value.accountLabel,
            listLabel: altered ? "Changed list" : value.listLabel, writable: value.writable,
            reminder: reminder)
    }
    func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt {
        writes += 1
        hiddenNotes = action.expected.reminder?.notes
        return try await base.apply(action)
    }
}
private struct ReminderFixture {
    let seed: SyntheticReminderActionFixture
    let probe: ReminderProbe
    let clock: ReminderClock
    let engine: ReminderApprovalEngine
    static func make(completed: Bool = false) async throws -> Self {
        let seed = try await SyntheticReminderActionFixture.make(completed: completed)
        let clock = ReminderClock()
        let probe = ReminderProbe(seed.provider)
        return Self(
            seed: seed, probe: probe, clock: clock,
            engine: ReminderApprovalEngine(
                session: seed.session, provider: probe, authorized: { true },
                uptime: { clock.now() }))
    }
}
@Test func reminderApprovalBindsObservedStateAndAllSixOperations() async throws {
    for kind in ReminderActionKind.allCases {
        let f = try await ReminderFixture.make(completed: kind == .uncomplete)
        let review = try await f.engine.prepare(f.seed.change(kind))
        #expect(review.display.kind == kind)
        #expect(await f.probe.writes == 0)
        let token = try await f.engine.confirm(review, acknowledgeDeletion: kind == .delete)
        #expect(await f.engine.commit(token) == .applied)
        #expect(await f.engine.commit(token) == .notApplied)
        #expect(await f.probe.writes == 1)
        if kind != .create { #expect(await f.probe.hiddenNotes == .notFetched) }
        let state = try await f.seed.provider.inspect(
            f.seed.change(.delete), fields: [.title, .notes, .due, .completion, .recurrence])
        switch kind {
        case .create: #expect(state.reminder?.title == f.seed.reminder.title)
        case .update: #expect(state.reminder?.title == .value("Sample revised groceries"))
        case .setDue: #expect(state.reminder?.due == .value(nil))
        case .complete:
            #expect(
                state.reminder?.completion
                    == .value(
                        .completed(at: try Instant(Date(timeIntervalSince1970: 1_800_000_000)))))
        case .uncomplete: #expect(state.reminder?.completion == .value(.incomplete))
        case .delete: #expect(state.reminder == nil)
        }
    }
}
@Test func reminderApprovalExpiresAndRejectsForeignOrReplayedConfirmation() async throws {
    let f = try await ReminderFixture.make()
    let other = try await ReminderFixture.make()
    let review = try await f.engine.prepare(f.seed.change(.update))
    await #expect(throws: (any Error).self) { try await other.engine.confirm(review) }
    f.clock.advance(121)
    await #expect(throws: (any Error).self) { try await f.engine.confirm(review) }
    let next = try await f.engine.prepare(f.seed.change(.create))
    let token = try await f.engine.confirm(next)
    #expect(await other.engine.commit(token) == .notApplied)
    f.clock.advance(31)
    #expect(await f.engine.commit(token) == .notApplied)
    #expect(await f.probe.writes == 0)
}
@Test func reminderDeletionAcknowledgementAndDismissalAreLocalAndSingleUse() async throws {
    let f = try await ReminderFixture.make()
    let review = try await f.engine.prepare(f.seed.change(.delete))
    await #expect(throws: (any Error).self) { try await f.engine.confirm(review) }
    await f.engine.reject(review)
    await #expect(throws: (any Error).self) {
        try await f.engine.confirm(review, acknowledgeDeletion: true)
    }
    #expect(await f.probe.writes == 0)
}
@Test func reminderCurrentTargetOSAndPolicyChangesInvalidateApproval() async throws {
    for reason in 0..<4 {
        let f = try await ReminderFixture.make()
        let token = try await f.engine.confirm(f.engine.prepare(f.seed.change(.update)))
        switch reason {
        case 0: await f.probe.changeTarget()
        case 1:
            await f.seed.authority.observeOSPermissions(
                OSPermissions(calendars: .fullAccess, reminders: .denied))
        case 2: await f.seed.authority.revokeConnection(f.seed.session.connectionID)
        default: await f.engine.invalidate()
        }
        #expect(await f.engine.commit(token) == .notApplied)
        #expect(await f.probe.writes == 0)
    }
}
@Test func reminderRecurringAndUnknownObservationsCannotAuthorizeCompletionOrDelete() async throws {
    for unknown in [false, true] {
        let f = try await ReminderFixture.make()
        if unknown { await f.probe.unknownRevision() } else { await f.probe.repeatItem() }
        for kind in [ReminderActionKind.update, .setDue, .complete, .delete] {
            await #expect(throws: (any Error).self) {
                try await f.engine.prepare(f.seed.change(kind))
            }
        }
        #expect(await f.probe.writes == 0)
    }
}
@Test func reminderFieldAndIndependentOperationGrantsDenyBeforeObservation() async throws {
    for kind in [ConnectionKind.localMCP, .googleSync] {
        let f = try await ReminderFixture.make()
        await f.seed.authority.setConnection(
            Connection(id: f.seed.session.connectionID, kind: kind, state: .enabled),
            policy: ConnectionPolicy(reminderLists: [
                f.seed.list: ReminderGrant(
                    operations: [.readDetails, .complete], readableFields: [.title],
                    writableFields: [.completion])
            ]))
        let session = try await f.seed.authority.bindTrustedConnection(f.seed.session.connectionID)
        let engine = ReminderApprovalEngine(
            session: session, provider: f.probe, authorized: { true })
        for operation in [ReminderActionKind.complete, .uncomplete, .update, .delete] {
            await #expect(throws: (any Error).self) {
                try await engine.prepare(f.seed.change(operation))
            }
        }
        #expect(await f.probe.reads == 0)
    }
}
@Test func reminderNoOpCompletionAndSpoofedReviewTextAreRejected() async throws {
    let f = try await ReminderFixture.make(completed: true)
    await #expect(throws: (any Error).self) { try await f.engine.prepare(f.seed.change(.complete)) }
    for title in ["", "\u{202E}trusted approval", "text\u{0000}"] {
        await #expect(throws: (any Error).self) {
            try await f.engine.prepare(
                .create(in: f.seed.list, reminder: ReminderDraft(title: title)))
        }
    }
    let review = try await f.engine.prepare(
        .update(
            f.seed.reminder.id,
            changes: ReminderChanges(notes: .set(nil)), precondition: .unknown))
    #expect(
        review.display.rows.contains {
            $0.field == "Notes" && $0.before == "\"Sample notes\"" && $0.after == "Not set"
        })
}
@Test func reminderDefaultAuthorizationAndCapacityFailClosed() async throws {
    let f = try await ReminderFixture.make()
    let closed = ReminderApprovalEngine(session: f.seed.session, provider: f.probe)
    await #expect(throws: (any Error).self) { try await closed.prepare(f.seed.change(.create)) }
    for _ in 0..<16 { _ = try await f.engine.prepare(f.seed.change(.create)) }
    await #expect(throws: (any Error).self) { try await f.engine.prepare(f.seed.change(.create)) }
    #expect(await f.probe.writes == 0)
}

@Test func reminderObservationPermitIsNotMutationAuthorityAndCompleteDoesNotGrantUncomplete()
    async throws
{
    let f = try await ReminderFixture.make()
    await f.seed.authority.setConnection(
        Connection(id: f.seed.session.connectionID, kind: .localMCP, state: .enabled),
        policy: ConnectionPolicy(reminderLists: [
            f.seed.list: ReminderGrant(
                operations: [.readDetails, .complete],
                readableFields: [.title, .due, .completion, .recurrence],
                writableFields: [.completion])
        ]))
    let session = try await f.seed.authority.bindTrustedConnection(f.seed.session.connectionID)
    let proposal = ProposedChange(
        id: try OperationID(UUID().uuidString), connection: session.connectionID,
        change: try f.seed.change(.complete))
    guard
        case .allowed = await session.evaluate(
            .reminderMutationObservation(
                proposal,
                fields: [.title, .due, .completion, .recurrence]))
    else {
        Issue.record("Expected scoped observation")
        return
    }
    guard case .denied = await session.evaluate(.reminderMutation(proposal)) else {
        Issue.record("Unknown revision authorized mutation")
        return
    }
    let engine = ReminderApprovalEngine(session: session, provider: f.probe, authorized: { true })
    _ = try await engine.prepare(f.seed.change(.complete))
    await #expect(throws: (any Error).self) { try await engine.prepare(f.seed.change(.uncomplete)) }
}

import ActionApprovals
import CoreDomain
import Foundation
import MCPServer
import PermissionEngine
import Testing

@testable import MCPRemindersAdapter

private struct MutationFixture {
    let seed: SyntheticReminderActionFixture
    let adapter: ReminderMutationAdapter
    static func make(completed: Bool = false) async throws -> Self {
        let seed = try await SyntheticReminderActionFixture.make(completed: completed)
        let engine = ReminderApprovalEngine(
            session: seed.session, provider: seed.provider, authorized: { true })
        return Self(
            seed: seed,
            adapter: ReminderMutationAdapter(
                engine: engine,
                resolve: { token, create in
                    guard token == (create ? "sample-list" : "sample-reminder") else {
                        throw ReminderReadFailure.unavailable
                    }
                    return (seed.list, create ? nil : seed.reminder.id)
                }, authorized: { true }))
    }
    func propose(_ operation: String, extra: [String: MCPJSON] = [:]) async throws -> String {
        let args: [String: MCPJSON] = [
            "operation": .string(operation),
            "targetId": .string(operation == "create" ? "sample-list" : "sample-reminder"),
        ]
        let result = try await adapter.propose(args.merging(extra) { _, new in new })
        #expect(result.value["status"]?.string == "pendingLocalApproval")
        return try #require(result.value["actionId"]?.string)
    }
}
@Test func reminderWireCannotApproveItsOwnProposalOrReplayNativeConfirmation() async throws {
    for kind in ReminderActionKind.allCases {
        let f = try await MutationFixture.make(completed: kind == .uncomplete)
        let extra: [String: MCPJSON]
        switch kind {
        case .create, .update: extra = ["title": .string("Synthetic tool title")]
        case .setDue:
            extra = [
                "dueDate": .string("2027-03-14"), "dueTime": .string("02:30:00"),
                "timeZone": .string("America/New_York"),
            ]
        default: extra = [:]
        }
        let id = try await f.propose(kind.rawValue, extra: extra)
        let unapproved = try await f.adapter.commit(["actionId": .string(id)])
        #expect(unapproved.value["status"]?.string == "notApproved")
        let forged = try await f.adapter.commit(["actionId": .string(id), "approved": .bool(true)])
        #expect(forged.value["status"]?.string == "notApproved")
        let review = try await f.adapter.reviewForLocalDisplay(id)
        #expect(review.kind == kind)
        if kind == .delete {
            await #expect(throws: (any Error).self) { try await f.adapter.confirmLocally(id) }
        }
        try await f.adapter.confirmLocally(id, acknowledgeDeletion: kind == .delete)
        let applied = try await f.adapter.commit(["actionId": .string(id)])
        #expect(applied.value["status"]?.string == "applied")
        let replay = try await f.adapter.commit(["actionId": .string(id)])
        #expect(replay.value["status"]?.string == "notApproved")
    }
}
@Test func reminderWireRejectsForeignTargetsMixedOperationsAndRevokedPolicy() async throws {
    let f = try await MutationFixture.make()
    for args: [String: MCPJSON] in [
        ["operation": .string("delete"), "targetId": .string("foreign")],
        [
            "operation": .string("complete"), "targetId": .string("sample-reminder"),
            "title": .string("not reviewed"),
        ],
        [
            "operation": .string("delete"), "targetId": .string("sample-reminder"),
            "approved": .bool(true),
        ],
        ["operation": .string("setDue"), "targetId": .string("sample-reminder")],
    ] { await #expect(throws: (any Error).self) { try await f.adapter.propose(args) } }
    let id = try await f.propose("complete")
    try await f.adapter.confirmLocally(id)
    await f.seed.authority.revokeConnection(f.seed.session.connectionID)
    let outcome = try await f.adapter.commit(["actionId": .string(id)])
    #expect(outcome.value["status"]?.string == "notApplied")
}
@Test func reminderWireDueParserDistinguishesClearingDateFloatingAndNamedZone() throws {
    #expect(try ReminderMutationAdapter.due(["dueDate": .string("")]) == nil)
    let date = try LocalDate(year: 2027, month: 1, day: 15)
    #expect(try ReminderMutationAdapter.due(["dueDate": .string("2027-01-15")]) == .date(date))
    #expect(
        try ReminderMutationAdapter.due([
            "dueDate": .string("2027-01-15"), "dueTime": .string("10:00:00"),
        ])
            == .localDateTime(date, try LocalTime(hour: 10, minute: 0), timeZone: nil))
    for args: [String: MCPJSON] in [
        ["dueDate": .string("2027-02-30")], ["dueTime": .string("10:00:00")],
        ["dueDate": .string("2027-01-15"), "timeZone": .string("UTC")],
        ["dueDate": .string("2027-01-15"), "dueTime": .string("25:00:00")],
        [
            "dueDate": .string("2027-01-15"), "dueTime": .string("10:00:00"),
            "timeZone": .string("invented"),
        ],
    ] { #expect(throws: (any Error).self) { try ReminderMutationAdapter.due(args) } }
}

private actor DrainGate {
    private var entered = false
    private var entrance: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true
        entrance?.resume()
        entrance = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { entrance = $0 } } }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
private actor DrainingProvider: ReminderActionProvider {
    let source: SyntheticReminderActionProvider
    let gate: DrainGate
    let accepted: Bool
    init(source: SyntheticReminderActionProvider, gate: DrainGate, accepted: Bool) {
        self.source = source
        self.gate = gate
        self.accepted = accepted
    }
    func inspect(_ change: ReminderMutation, fields: Set<ReminderField>) async throws
        -> ReminderActionSnapshot
    {
        try await source.inspect(change, fields: fields)
    }
    func apply(_ action: AuthorizedReminderAction) async throws -> ReminderActionReceipt {
        if !accepted { await gate.pause() }
        let receipt = try await source.apply(action)
        if accepted { await gate.pause() }
        return receipt
    }
}
private actor DrainObservations {
    var outcomes: [ActionOutcome] = []
    var closeReturned = false
    var clearCount = 0
    private var closing: CheckedContinuation<Void, Never>?
    func review(_ value: ReminderReviewDisplay?) {
        if value == nil { clearCount += 1 }
        if clearCount == 3 {
            closing?.resume()
            closing = nil
        }
    }
    func waitForClose() async {
        if clearCount < 3 { await withCheckedContinuation { closing = $0 } }
    }
    func outcome(_ value: ActionOutcome) { outcomes.append(value) }
    func finished() { closeReturned = true }
}
@Test func closingReminderAdapterDrainsAcceptedCommitAndNeverClaimsRollback() async throws {
    for accepted in [false, true] {
        let seed = try await SyntheticReminderActionFixture.make()
        let gate = DrainGate()
        let observations = DrainObservations()
        let provider = DrainingProvider(source: seed.provider, gate: gate, accepted: accepted)
        let engine = ReminderApprovalEngine(
            session: seed.session, provider: provider, authorized: { true })
        let adapter = ReminderMutationAdapter(
            engine: engine, privateSession: true,
            onReview: { _, value in await observations.review(value) },
            onOutcome: { await observations.outcome($0) },
            resolve: { _, _ in (seed.list, nil) }, authorized: { true })
        let proposal = try await adapter.propose([
            "operation": .string("create"), "targetId": .string("sample-list"),
            "title": .string("Synthetic drain"),
        ])
        let token = try #require(proposal.value["actionId"]?.string)
        try await adapter.confirmLocally(token)
        let commit = Task { try? await adapter.commit(["actionId": .string(token)]) }
        await gate.wait()
        let close = Task {
            await adapter.close()
            await observations.finished()
        }
        await observations.waitForClose()
        #expect(await observations.closeReturned == false)
        #expect(await observations.outcomes.isEmpty)
        await #expect(throws: (any Error).self) { try await adapter.confirmLocally(token) }
        await gate.release()
        await close.value
        #expect(await commit.value == nil)  // Closed wire response is not evidence of no effect.
        #expect(await observations.outcomes == [accepted ? .applied : .notApplied])
        #expect(await observations.closeReturned)
        await #expect(throws: (any Error).self) {
            try await adapter.propose([
                "operation": .string("create"), "targetId": .string("sample-list"),
                "title": .string("Must stay closed"),
            ])
        }
    }
}

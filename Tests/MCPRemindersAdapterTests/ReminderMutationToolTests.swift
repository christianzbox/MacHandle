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

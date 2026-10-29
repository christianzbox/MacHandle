import ActionApprovals
import CoreDomain
import Foundation
import PermissionEngine
import Testing

@testable import MCPContactsAdapter
@testable import MCPServer

private struct MutationFixture {
    let seed: SyntheticContactActionFixture
    let adapter: ContactMutationAdapter
    static func make() async throws -> Self {
        let seed = try await SyntheticContactActionFixture.make()
        let engine = ContactApprovalEngine(
            session: seed.session, provider: seed.provider, authorized: { true })
        return Self(
            seed: seed,
            adapter: ContactMutationAdapter(
                engine: engine,
                resolve: { token, create in
                    guard token == (create ? "sample-container" : "sample-contact") else {
                        throw ContactReadFailure.unavailable
                    }
                    return (seed.container, create ? nil : seed.record)
                }, authorized: { true }))
    }
    func propose(_ operation: String, extra: [String: MCPJSON] = [:]) async throws -> String {
        let args: [String: MCPJSON] = [
            "operation": .string(operation),
            "targetId": .string(operation == "create" ? "sample-container" : "sample-contact"),
        ]
        let result = try await adapter.propose(args.merging(extra) { _, new in new })
        #expect(result.value["status"]?.string == "pendingLocalApproval")
        return try #require(result.value["actionId"]?.string)
    }
}
@Test func contactWireCannotApproveItsOwnProposalOrReplayNativeConfirmation() async throws {
    for kind in ContactActionKind.allCases {
        let f = try await MutationFixture.make()
        let extra: [String: MCPJSON]
        switch kind {
        case .create: extra = ["givenName": .string("Sample"), "familyName": .string("Created")]
        case .update: extra = ["organization": .string("Sample updated")]
        case .delete: extra = [:]
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
        try await f.adapter.confirmLocally(
            id, acknowledgeDeletion: kind == .delete, deletionPhrase: "DELETE")
        let applied = try await f.adapter.commit(["actionId": .string(id)])
        #expect(applied.value["status"]?.string == "applied")
        let replay = try await f.adapter.commit(["actionId": .string(id)])
        #expect(replay.value["status"]?.string == "notApproved")
    }
}
@Test func contactWireRejectsForeignTargetsMixedOperationsAndRevokedPolicy() async throws {
    let f = try await MutationFixture.make()
    for args: [String: MCPJSON] in [
        ["operation": .string("delete"), "targetId": .string("foreign")],
        [
            "operation": .string("delete"), "targetId": .string("sample-contact"),
            "organization": .string("not reviewed"),
        ],
        [
            "operation": .string("delete"), "targetId": .string("sample-contact"),
            "approved": .bool(true),
        ],
        [
            "operation": .string("update"), "targetId": .string("sample-contact"),
            "givenName": .string("Partial name"),
        ],
        [
            "operation": .string("update"), "targetId": .string("sample-contact"),
            "notes": .string("forbidden"),
        ],
    ] { await #expect(throws: (any Error).self) { try await f.adapter.propose(args) } }
    let id = try await f.propose("update", extra: ["organization": .string("Sample updated")])
    try await f.adapter.confirmLocally(id)
    await f.seed.authority.revokeConnection(f.seed.session.connectionID)
    let outcome = try await f.adapter.commit(["actionId": .string(id)])
    #expect(outcome.value["status"]?.string == "notApplied")
}
@Test func contactWireExplicitClearAndWholeArrayReplacementAreTyped() throws {
    let patch = try ContactMutationAdapter.patch([
        "organization": .string(""), "emailAddresses": .array([]),
    ])
    #expect(
        patch.organization == .set(nil) && patch.emailAddresses == .set([]) && !patch.name.isChanged
    )
    #expect(throws: (any Error).self) {
        try ContactMutationAdapter.patch(["emailAddresses": .array([.number(1)])])
    }
    #expect(throws: (any Error).self) {
        try ContactMutationAdapter.patch(["givenName": .string("Missing family")])
    }
}

@Test func contactMutationToolRegistrationAndHintsMatchItsEffects() async throws {
    let tools = try await SyntheticContactTools.make()
    #expect(tools.allSatisfy { $0.validRegistration })
    let commit = try #require(tools.first { $0.name == "commit_contact_change" })
    #expect(commit.definition["annotations"]?["readOnlyHint"] == .bool(false))
    #expect(commit.definition["annotations"]?["destructiveHint"] == .bool(true))
    #expect(commit.definition["annotations"]?["idempotentHint"] == .bool(false))
}

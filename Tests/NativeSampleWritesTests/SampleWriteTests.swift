import ActionApprovals
import CoreDomain
import Foundation
import MCPConnections
import MCPServer
import NativeMCPBridge
import SyncPersistence
import Testing

@testable import NativeSampleWrites

private actor ReviewBox {
    var token: String?
    var review: ReminderReviewDisplay?
    func set(_ token: String?, _ review: ReminderReviewDisplay?) {
        self.token = token
        self.review = review
    }
}
private struct Rig {
    let directory: URL
    let installation: UUID
    let journal: ReminderMutationJournal
    let composition: SampleWriteComposition
    let broker: NativeReadBroker
    let box: ReviewBox
    static func make() async throws -> Self {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("sample-write-tests-" + UUID().uuidString)
        let installation = UUID()
        let journal = try ReminderMutationJournal(
            directory: directory, installation: installation, mode: .createNew)
        let box = ReviewBox()
        let composition = try await SampleWriteComposition.make(
            journal: journal, onReview: { await box.set($0, $1) })
        let broker = try await composition.broker(channel: ConnectionChannel(verify: { true }))
        return Self(
            directory: directory, installation: installation, journal: journal,
            composition: composition, broker: broker, box: box)
    }
    func pair() async throws { try await broker.approve(broker.prepareReview().id) }
    func call(_ name: String, _ args: [String: MCPJSON] = [:]) async throws -> MCPJSON {
        let data = try MCPJSON.object([
            "version": .number(1), "tool": .string(name), "arguments": .object(args),
        ]).encoded()
        var parser = try MCPJSONParser(await broker.request(data))
        guard let result = try parser.parse()["result"] else { throw ActionFailure.denied }
        return result
    }
    func list() async throws -> String {
        try #require(await call("list_reminder_lists")["lists"]?.array?.first?["listId"]?.string)
    }
    func search(_ list: String, title: String = "") async throws -> [MCPJSON] {
        try #require(
            await call(
                "search_reminders",
                [
                    "listIds": .array([.string(list)]),
                    "fields": .array([.string("title"), .string("completion")]),
                    "query": .string(title), "limit": .number(20),
                ])["reminders"]?.array)
    }
    func propose(_ kind: String, target: String, extra: [String: MCPJSON] = [:]) async throws
        -> String
    {
        let args: [String: MCPJSON] = ["operation": .string(kind), "targetId": .string(target)]
        return try #require(
            await call("propose_reminder_change", args.merging(extra) { _, b in b })["actionId"]?
                .string)
    }
    func commit(_ token: String) async throws -> String {
        try #require(
            await call("commit_reminder_change", ["actionId": .string(token)])["status"]?.string)
    }
    func clean() async throws {
        await broker.close(revoke: true)
        await journal.close()
        try FileManager.default.removeItem(at: directory)
    }
}

@Test func sampleWriteBridgeRequiresPairingExactNativeApprovalAndPersistsSixEffects() async throws {
    let rig = try await Rig.make()
    await #expect(throws: (any Error).self) {
        try await rig.call(
            "propose_reminder_change",
            [
                "operation": .string("create"), "targetId": .string("sample-list"),
                "title": .string("unapproved"),
            ])
    }
    try await rig.pair()
    let list = try await rig.list()
    let create = try await rig.propose(
        "create", target: list, extra: ["title": .string("Synthetic new")])
    #expect(try await rig.commit(create) == "notApproved")
    await #expect(throws: (any Error).self) {
        try await rig.call("approve", ["actionId": .string(create)])
    }
    await #expect(throws: (any Error).self) {
        try await rig.call(
            "commit_reminder_change", ["actionId": .string(create), "approved": .bool(true)])
    }
    await #expect(throws: (any Error).self) {
        try await rig.propose("create", target: list, extra: ["title": .string("Overlapping")])
    }
    #expect(await rig.box.review?.kind == .create)
    try await rig.composition.actions.confirm(create, deletion: false)
    #expect(try await rig.commit(create) == "applied")
    #expect(try await rig.commit(create) == "notApproved")
    let item = try #require(
        await rig.search(list, title: "Synthetic new").first?["reminderId"]?.string)
    for kind in ["update", "setDue", "complete", "uncomplete", "delete"] {
        let extra: [String: MCPJSON] =
            kind == "update"
            ? ["title": .string("Synthetic revised")]
            : (kind == "setDue" ? ["dueDate": .string("2027-02-03")] : [:])
        let token = try await rig.propose(kind, target: item, extra: extra)
        #expect(await rig.box.token == token)
        if kind == "delete" {
            await #expect(throws: (any Error).self) {
                try await rig.composition.actions.confirm(token, deletion: false)
            }
        }
        try await rig.composition.actions.confirm(token, deletion: kind == "delete")
        #expect(try await rig.commit(token) == "applied")
        #expect(try await rig.commit(token) == "notApproved")
    }
    #expect(try await rig.search(list, title: "Synthetic revised").isEmpty)
    let records = try await rig.journal.records()
    #expect(records.count == 6 && records.allSatisfy { $0.state == .applied })
    await rig.broker.close()
    await rig.journal.close()
    let reopened = try ReminderMutationJournal(
        directory: rig.directory, installation: rig.installation, mode: .resume)
    #expect(try await reopened.records() == records)
    await reopened.close()
    try FileManager.default.removeItem(at: rig.directory)
}

@Test func staleSnapshotAndRevocationPreventSampleWriteDispatch() async throws {
    let rig = try await Rig.make()
    try await rig.pair()
    let list = try await rig.list()
    let item = try #require(await rig.search(list).first?["reminderId"]?.string)
    let token = try await rig.propose(
        "update", target: item, extra: ["title": .string("Must not overwrite")])
    try await rig.composition.actions.confirm(token, deletion: false)
    // A second trusted fixture writer changes the same in-memory source after native review.
    let seed = try await SyntheticReminderActionFixture.make()
    let other = ReminderApprovalEngine(
        session: seed.session, provider: rig.composition.source, authorized: { true })
    let review = try await other.prepare(seed.change(.complete))
    #expect(await other.commit(try await other.confirm(review)) == .applied)
    #expect(try await rig.commit(token) == "notApplied")
    #expect(try await rig.journal.records().isEmpty)
    let next = try await rig.propose("uncomplete", target: item)
    try await rig.composition.actions.confirm(next, deletion: false)
    await rig.broker.close(revoke: true)
    await #expect(throws: (any Error).self) { try await rig.commit(next) }
    #expect(try await rig.journal.records().isEmpty)
    try await rig.clean()
}

@Test func rejectedAndForeignLaunchActionsCannotCommit() async throws {
    let a = try await Rig.make()
    let b = try await Rig.make()
    try await a.pair()
    try await b.pair()
    let list = try await a.list()
    let token = try await a.propose(
        "create", target: list, extra: ["title": .string("Synthetic rejected")])
    #expect(try await b.commit(token) == "notApproved")
    await #expect(throws: (any Error).self) {
        try await b.propose("create", target: list, extra: ["title": .string("Foreign list")])
    }
    await a.composition.actions.reject(token)
    #expect(try await a.commit(token) == "notApproved")
    #expect(try await a.journal.records().isEmpty)
    try await a.clean()
    try await b.clean()
}

@Test func pendingAndUnknownJournalBlockNewCompositionAfterRestart() async throws {
    for unknown in [false, true] {
        let rig = try await Rig.make()
        let operation = UUID()
        try await rig.journal.begin(operation)
        if unknown { try await rig.journal.finish(operation, state: .unknown) }
        await rig.broker.close()
        await rig.journal.close()
        let reopened = try ReminderMutationJournal(
            directory: rig.directory, installation: rig.installation, mode: .resume)
        await #expect(throws: PersistenceFailure.self) {
            try await SampleWriteComposition.make(journal: reopened)
        }
        #expect(try await reopened.records().count == 1)
        await reopened.close()
        try FileManager.default.removeItem(at: rig.directory)
    }
}

@MainActor @Test func unsignedNativeWriteModelCannotOpenJournalOrListener() async {
    let model = PrivateWriteModel()
    #expect(model.phase == .idle && model.review == nil)
    await model.start()
    #expect(model.phase == .unavailable)
    #expect(model.journalStatus == "Journal not opened.")
    await model.stop()
    #expect(model.phase == .closed)
}

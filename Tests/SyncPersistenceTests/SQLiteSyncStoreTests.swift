import Darwin
import Foundation
import Testing

@testable import SyncPersistence

private let keyA = try! PersistenceDigest(String(repeating: "a", count: 64))
private let keyB = try! PersistenceDigest(String(repeating: "b", count: 64))
private let keyC = try! PersistenceDigest(String(repeating: "c", count: 64))
private let keyD = try! PersistenceDigest(String(repeating: "d", count: 64))
private struct Fixture {
    let root: URL
    let directory: URL
    let binding: PersistenceBinding
    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("machandle-synthetic-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        directory = root.appendingPathComponent("store")
        binding = try PersistenceBinding(
            storeID: UUID(), installationID: UUID(),
            clientID: "synthetic.apps.googleusercontent.com", accountKey: keyA)
    }
    func store(_ mode: PersistenceOpenMode = .createNew) throws -> SQLiteSyncStore {
        try SQLiteSyncStore(directory: directory, binding: binding, mode: mode)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
private func destination(_ store: SQLiteSyncStore) async throws -> UUID {
    let operation = try await store.prepareDestination(sourceKey: keyB)
    _ = try await store.beginAttempt(operation.id)
    try await store.recordDestinationResult(
        operation.id, destinationID: "synthetic@group.calendar.google.com",
        ownershipMarker: operation.id.uuidString)
    return operation.resourceID
}
private func event(_ store: SQLiteSyncStore, resource: UUID) async throws -> (UUID, UUID) {
    let operation = try await store.prepareInsert(
        resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    _ = try await store.beginAttempt(operation.id)
    try await store.recordEventResult(
        operation.id, observedETag: "\"synthetic-1\"", confirmedFingerprint: keyD)
    return (try #require(operation.eventID), operation.id)
}
private final class CommitFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    func enable(_ value: Bool) { lock.withLock { enabled = value } }
    func check() throws { if lock.withLock({ enabled }) { throw PersistenceFailure.unavailable } }
}

@Test func explicitCreationResumesBoundStateAndNeverRecreatesMissingDatabase() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    #expect(throws: PersistenceFailure.missingStore) { try fixture.store(.resume) }
    let store = try fixture.store()
    let initial = try await store.snapshot()
    #expect(
        initial.resources.isEmpty && initial.checkpoint.revision == 0
            && initial.syncState == .paused)
    #expect(throws: PersistenceFailure.alreadyExists) { try fixture.store() }
    let resource = try await destination(store)
    let (eventID, _) = try await event(store, resource: resource)
    let run = UUID()
    _ = try await store.commitCheckpoint(expectedRevision: 0, completedRun: run)
    let before = try await store.snapshot()
    await store.close()
    let reopened = try fixture.store(.resume)
    let after = try await reopened.snapshot()
    #expect(
        after.binding == fixture.binding && after.resources == before.resources
            && after.events == before.events)
    #expect(after.events.first?.id == eventID && after.checkpoint == before.checkpoint)
    #expect(after.resumeRequirement == .remoteVerificationRequired)
    await reopened.close()
    try FileManager.default.removeItem(at: fixture.directory.appendingPathComponent("state.sqlite"))
    #expect(throws: PersistenceFailure.missingStore) { try fixture.store(.resume) }
    #expect(throws: PersistenceFailure.alreadyExists) { try fixture.store(.createNew) }
}

@Test func unknownOperationsKeepStableIDsAcrossRestartAndBlockNewAttemptsAndCheckpoints()
    async throws
{
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    let resource = try await destination(store)
    let prepared = try await store.prepareInsert(
        resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    let before = try await store.snapshot()
    _ = try await store.beginAttempt(prepared.id)
    await store.close()
    let resumed = try fixture.store(.resume)
    let after = try await resumed.snapshot()
    #expect(after.events == before.events && after.syncState == .recoveryRequired)
    #expect(after.operations.first(where: { $0.id == prepared.id })?.state == .unknown)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await resumed.beginAttempt(prepared.id)
    }
    await #expect(throws: PersistenceFailure.constraint) {
        try await resumed.prepareInsert(resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    }
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await resumed.commitCheckpoint(expectedRevision: 0, completedRun: UUID())
    }
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await resumed.recordEventResult(
            prepared.id, observedETag: "\"synthetic-2\"", confirmedFingerprint: keyA)
    }
    try await resumed.recordEventResult(
        prepared.id, observedETag: "\"synthetic-2\"", confirmedFingerprint: keyD)
    #expect(try await resumed.snapshot().syncState == .paused)
    await resumed.close()
}

@Test func updatesAndTombstonesRequireVersionsAndDoNotSilentlyResurrectMappings() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    let resource = try await destination(store)
    let (eventID, _) = try await event(store, resource: resource)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.prepareChange(
            eventID: eventID, kind: .updateEvent, expectedETag: "\"wrong\"",
            desiredFingerprint: keyA)
    }
    let update = try await store.prepareChange(
        eventID: eventID, kind: .updateEvent, expectedETag: "\"synthetic-1\"",
        desiredFingerprint: keyA)
    await #expect(throws: PersistenceFailure.constraint) {
        try await store.prepareChange(
            eventID: eventID, kind: .deleteEvent, expectedETag: "\"synthetic-1\"")
    }
    _ = try await store.beginAttempt(update.id)
    try await store.recordEventResult(
        update.id, observedETag: "\"synthetic-2\"", confirmedFingerprint: keyA)
    let deletion = try await store.prepareChange(
        eventID: eventID, kind: .deleteEvent, expectedETag: "\"synthetic-2\"")
    _ = try await store.beginAttempt(deletion.id)
    try await store.recordEventResult(deletion.id, observedETag: nil, confirmedFingerprint: nil)
    let state = try await store.snapshot()
    #expect(state.events.first?.deleted == true && state.events.first?.fingerprint == nil)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.recordEventResult(deletion.id, observedETag: nil, confirmedFingerprint: nil)
    }
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.prepareChange(
            eventID: eventID, kind: .deleteEvent, expectedETag: "\"synthetic-2\"")
    }
    await #expect(throws: PersistenceFailure.constraint) {
        try await store.prepareInsert(resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    }
    await store.close()
}

@Test func commitFailureRollsBackMappingAndCompletionTogether() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let failure = CommitFailure()
    let store = try SQLiteSyncStore(
        directory: fixture.directory, binding: fixture.binding, mode: .createNew,
        beforeCommit: { try failure.check() })
    let resource = try await destination(store)
    let operation = try await store.prepareInsert(
        resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    _ = try await store.beginAttempt(operation.id)
    failure.enable(true)
    await #expect(throws: PersistenceFailure.unavailable) {
        try await store.recordEventResult(
            operation.id, observedETag: "\"synthetic-1\"", confirmedFingerprint: keyD)
    }
    failure.enable(false)
    let state = try await store.snapshot()
    #expect(state.events.first?.etag == nil && state.events.first?.fingerprint == nil)
    #expect(
        state.operations.first(where: { $0.id == operation.id })?.state == .unknown
            && state.syncState == .recoveryRequired)
    await store.close()
    let resumed = try fixture.store(.resume)
    #expect(try await resumed.snapshot().events == state.events)
    await resumed.close()
}

@Test func failedAttemptCommitCannotAuthorizeDispatchAndCheckpointUsesCompareAndSwap() async throws
{
    let fixture = try Fixture()
    defer { fixture.remove() }
    let failure = CommitFailure()
    let store = try SQLiteSyncStore(
        directory: fixture.directory, binding: fixture.binding, mode: .createNew,
        beforeCommit: { try failure.check() })
    let operation = try await store.prepareDestination(sourceKey: keyB)
    failure.enable(true)
    await #expect(throws: PersistenceFailure.unavailable) {
        try await store.beginAttempt(operation.id)
    }
    failure.enable(false)
    #expect(try await store.snapshot().operations.first?.state == .prepared)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.recordDestinationResult(
            operation.id, destinationID: "synthetic-destination",
            ownershipMarker: operation.id.uuidString)
    }
    _ = try await store.beginAttempt(operation.id)
    try await store.recordDestinationResult(
        operation.id, destinationID: "synthetic-destination",
        ownershipMarker: operation.id.uuidString)
    _ = try await store.commitCheckpoint(expectedRevision: 0, completedRun: UUID())
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.commitCheckpoint(expectedRevision: 0, completedRun: UUID())
    }
    #expect(try await store.snapshot().checkpoint.revision == 1)
    await store.close()
}

@Test func identityBindingRejectsDifferentStoreInstallationClientOrAccount() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    await store.close()
    for index in 0..<4 {
        let wrong = try PersistenceBinding(
            storeID: index == 0 ? UUID() : fixture.binding.storeID,
            installationID: index == 1 ? UUID() : fixture.binding.installationID,
            clientID: index == 2 ? "other.apps.googleusercontent.com" : fixture.binding.clientID,
            accountKey: index == 3 ? keyB : keyA)
        #expect(throws: PersistenceFailure.identityMismatch) {
            try SQLiteSyncStore(directory: fixture.directory, binding: wrong, mode: .resume)
        }
    }
    let original = try fixture.store(.resume)
    await original.close()
}

@Test func privateFilesAndExclusiveWriterAreEnforced() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    #expect(throws: PersistenceFailure.busy) { try fixture.store(.resume) }
    let file = fixture.directory.appendingPathComponent("state.sqlite")
    let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
    #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    let dirAttrs = try FileManager.default.attributesOfItem(atPath: fixture.directory.path)
    #expect((dirAttrs[.posixPermissions] as? NSNumber)?.intValue == 0o700)
    await store.close()
    #expect(chmod(file.path, 0o644) == 0)
    #expect(throws: PersistenceFailure.unsafeLocation) { try fixture.store(.resume) }
}

@Test func symlinksSidecarsAndReplacedLiveFilesFailClosed() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    let file = fixture.directory.appendingPathComponent("state.sqlite")
    let backup = fixture.root.appendingPathComponent("moved.sqlite")
    try FileManager.default.moveItem(at: file, to: backup)
    await #expect(throws: PersistenceFailure.missingStore) { try await store.snapshot() }
    await store.close()
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: backup)
    #expect(throws: PersistenceFailure.unsafeLocation) { try fixture.store(.resume) }
    try FileManager.default.removeItem(at: file)
    try FileManager.default.moveItem(at: backup, to: file)
    try FileManager.default.createSymbolicLink(
        atPath: file.path + "-journal", withDestinationPath: file.path)
    #expect(throws: PersistenceFailure.unsafeLocation) { try fixture.store(.resume) }
}

@Test func corruptAndFutureStoresAreNotReset() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    await store.close()
    let db = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    try db.execute("PRAGMA user_version=999")
    db.close()
    #expect(throws: PersistenceFailure.incompatibleSchema) { try fixture.store(.resume) }
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    #expect(try raw.query("PRAGMA user_version") == [["999"]])
    raw.close()
    let file = fixture.directory.appendingPathComponent("state.sqlite")
    try Data("synthetic-invalid-database".utf8).write(to: file)
    #expect(throws: PersistenceFailure.corrupt) { try fixture.store(.resume) }
    #expect(try Data(contentsOf: file) == Data("synthetic-invalid-database".utf8))
}

@Test func unexpectedSchemaAndMalformedRowsAreRejectedWithoutRepair() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    _ = try await destination(store)
    await store.close()
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    try raw.execute("CREATE VIEW unexpected AS SELECT * FROM identity")
    raw.close()
    #expect(throws: PersistenceFailure.corrupt) { try fixture.store(.resume) }
    let repairFixture = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    try repairFixture.execute("DROP VIEW unexpected")
    try repairFixture.execute("UPDATE resources SET source_key='synthetic-invalid-hash'")
    repairFixture.close()
    let resumed = try fixture.store(.resume)
    await #expect(throws: PersistenceFailure.corrupt) { try await resumed.snapshot() }
    await #expect(throws: PersistenceFailure.corrupt) {
        try await resumed.prepareDestination(sourceKey: keyC)
    }
    await resumed.close()
}

private func legacyFixture(_ fixture: Fixture) throws -> UUID {
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .createNew)
    defer { raw.close() }
    // Frozen synthetic v1 schema, independent of the migration under test.
    let schema = [
        "CREATE TABLE identity (singleton INTEGER PRIMARY KEY CHECK(singleton=1), store_id TEXT NOT NULL, installation_id TEXT NOT NULL, client_id TEXT NOT NULL, account_key TEXT NOT NULL) STRICT",
        "CREATE TABLE resources (id TEXT PRIMARY KEY NOT NULL, source_key TEXT UNIQUE NOT NULL, destination_id TEXT UNIQUE, marker TEXT UNIQUE NOT NULL) STRICT",
        "CREATE TABLE events (id TEXT PRIMARY KEY NOT NULL, resource_id TEXT NOT NULL REFERENCES resources(id), source_key TEXT NOT NULL, remote_id TEXT NOT NULL, fingerprint TEXT, etag TEXT, deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)), UNIQUE(resource_id,source_key), UNIQUE(resource_id,remote_id), UNIQUE(id,resource_id)) STRICT",
    ]
    let resource = UUID()
    try raw.transaction {
        for sql in schema { try raw.execute(sql) }
        try raw.execute(
            "INSERT INTO identity VALUES(1,?,?,?,?)",
            [
                fixture.binding.storeID.uuidString, fixture.binding.installationID.uuidString,
                fixture.binding.clientID, keyA.value,
            ])
        try raw.execute(
            "INSERT INTO resources VALUES(?,?,?,?)",
            [resource.uuidString, keyB.value, "synthetic-legacy-destination", UUID().uuidString])
        try raw.execute("PRAGMA application_id=1296581708")
        try raw.execute("PRAGMA user_version=1")
    }
    return resource
}

@Test func migrationPreservesLegacyIdentityButCannotInferDispatchAuthority() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let resource = try legacyFixture(fixture)
    let store = try fixture.store(.resume)
    let state = try await store.snapshot()
    #expect(
        state.resources.first?.id == resource
            && state.resources.first?.destinationID == "synthetic-legacy-destination")
    #expect(
        state.operations.isEmpty && state.syncState == .paused
            && state.resumeRequirement == .remoteVerificationRequired)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.prepareInsert(resourceID: resource, sourceKey: keyC, fingerprint: keyD)
    }
    await store.close()
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    #expect(try raw.query("PRAGMA user_version") == [["2"]])
    raw.close()
    let reopened = try fixture.store(.resume)
    #expect(try await reopened.snapshot().resources == state.resources)
    await reopened.close()
}

@Test func failedMigrationRollsBackVersionSchemaAndData() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let resource = try legacyFixture(fixture)
    #expect(throws: PersistenceFailure.unavailable) {
        try SQLiteSyncStore(
            directory: fixture.directory, binding: fixture.binding, mode: .resume,
            beforeCommit: { throw PersistenceFailure.unavailable })
    }
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    #expect(try raw.query("PRAGMA user_version") == [["1"]])
    #expect(try raw.query("SELECT id FROM resources") == [[resource.uuidString]])
    #expect(try raw.query("SELECT name FROM sqlite_master WHERE name='operations'").isEmpty)
    raw.close()
    let store = try fixture.store(.resume)
    #expect(try await store.snapshot().resources.first?.id == resource)
    await store.close()
}

@Test func incompatibleIdentityIsRejectedBeforeLegacyMigration() throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    _ = try legacyFixture(fixture)
    let wrong = try PersistenceBinding(
        storeID: fixture.binding.storeID, installationID: fixture.binding.installationID,
        clientID: fixture.binding.clientID, accountKey: keyB)
    #expect(throws: PersistenceFailure.identityMismatch) {
        try SQLiteSyncStore(directory: fixture.directory, binding: wrong, mode: .resume)
    }
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    #expect(try raw.query("PRAGMA user_version") == [["1"]])
    raw.close()
}

@Test func interruptedUncommittedTransactionIsDiscardedOnReopen() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    _ = try await destination(store)
    let before = try await store.snapshot()
    await store.close()
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    try raw.execute("BEGIN IMMEDIATE")
    try raw.execute("UPDATE checkpoint SET revision=99,completed_run=?", [UUID().uuidString])
    try raw.execute("UPDATE resources SET destination_id='synthetic-uncommitted'")
    raw.close()  // An abandoned transaction, not a simulated successful commit.
    let resumed = try fixture.store(.resume)
    let after = try await resumed.snapshot()
    #expect(after.resources == before.resources && after.checkpoint == before.checkpoint)
    await resumed.close()
}

@Test func foreignKeysAndUnknownDestinationCreationRejectUnsafeRecovery() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    await store.close()
    let raw = try SQLiteConnection(directory: fixture.directory, mode: .resume)
    #expect(throws: PersistenceFailure.constraint) {
        try raw.execute(
            "INSERT INTO events(id,resource_id,source_key,remote_id) VALUES(?,?,?,?)",
            [UUID().uuidString, UUID().uuidString, keyC.value, String(repeating: "a", count: 32)])
    }
    #expect(try raw.query("SELECT id FROM events").isEmpty)
    raw.close()
    let resumed = try fixture.store(.resume)
    let pending = try await resumed.prepareDestination(sourceKey: keyB)
    _ = try await resumed.beginAttempt(pending.id)
    await resumed.close()
    let reopened = try fixture.store(.resume)
    #expect(try await reopened.snapshot().syncState == .recoveryRequired)
    await #expect(throws: PersistenceFailure.constraint) {
        try await reopened.prepareDestination(sourceKey: keyB)
    }
    await reopened.close()
}

@Test func candidateRestorePreservesIDsPromotesPreparedAndDiscardsSuccessCheckpoint() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    let resource = try await destination(store)
    _ = try await event(store, resource: resource)
    _ = try await store.commitCheckpoint(expectedRevision: 0, completedRun: UUID())
    let pending = try await store.prepareChange(
        eventID: #require(try await store.snapshot().events.first).id,
        kind: .updateEvent, expectedETag: "\"synthetic-1\"", desiredFingerprint: keyB)
    let candidate = try await store.snapshot()
    await store.close()
    let replacement = try SQLiteSyncStore(
        directory: fixture.root.appendingPathComponent("replacement"),
        binding: fixture.binding, mode: .createNew)
    try await replacement.restoreCandidate(candidate)
    let restored = try await replacement.snapshot()
    #expect(restored.resources == candidate.resources && restored.events == candidate.events)
    #expect(restored.operations.first { $0.id == pending.id }?.state == .unknown)
    #expect(restored.checkpoint.revision == 0 && restored.checkpoint.completedRun == nil)
    #expect(
        restored.syncState == .recoveryRequired
            && restored.resumeRequirement == .remoteVerificationRequired)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await replacement.restoreCandidate(candidate)
    }
    await replacement.close()
}

@Test func restorationRejectsAnotherAccountWithoutChangingEmptyStore() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    _ = try await destination(store)
    let candidate = try await store.snapshot()
    let other = try PersistenceBinding(
        storeID: UUID(), installationID: UUID(),
        clientID: fixture.binding.clientID, accountKey: keyD)
    let replacement = try SQLiteSyncStore(
        directory: fixture.root.appendingPathComponent("replacement"),
        binding: other, mode: .createNew)
    await #expect(throws: PersistenceFailure.identityMismatch) {
        try await replacement.restoreCandidate(candidate)
    }
    #expect(try await replacement.snapshot().resources.isEmpty)
    await replacement.close()
    await store.close()
}

@Test func metadataRecoveryIsAtomicAndRejectsStaleOrIncompleteMappings() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let store = try fixture.store()
    let resource = try await destination(store)
    let (id, _) = try await event(store, resource: resource)
    let expected = try await store.snapshot()
    await #expect(throws: PersistenceFailure.invalidInput) {
        try await store.recoverMetadata(
            expected: expected, resourceID: resource, sourceKey: keyC, changes: [])
    }
    #expect(try await store.snapshot() == expected)
    let change = RecoveryMappingChange(eventID: id, sourceKey: keyB, fingerprint: keyA)
    try await store.recoverMetadata(
        expected: expected, resourceID: resource, sourceKey: keyC, changes: [change])
    let recovered = try await store.snapshot()
    #expect(recovered.events[0].destinationEventID == expected.events[0].destinationEventID)
    #expect(
        recovered.events[0].etag == expected.events[0].etag
            && recovered.operations == expected.operations)
    #expect(recovered.events[0].fingerprint == keyA && recovered.checkpoint.completedRun == nil)
    await #expect(throws: PersistenceFailure.stateConflict) {
        try await store.recoverMetadata(
            expected: expected, resourceID: resource, sourceKey: keyC, changes: [change])
    }
    await store.close()
}

@Test func failedRecoveryCommitRollsBackEveryMetadataChange() async throws {
    let fixture = try Fixture()
    defer { fixture.remove() }
    let failure = CommitFailure()
    let store = try SQLiteSyncStore(
        directory: fixture.directory, binding: fixture.binding,
        mode: .createNew, beforeCommit: failure.check)
    let resource = try await destination(store)
    let (id, _) = try await event(store, resource: resource)
    let before = try await store.snapshot()
    failure.enable(true)
    await #expect(throws: PersistenceFailure.unavailable) {
        try await store.recoverMetadata(
            expected: before, resourceID: resource, sourceKey: keyC,
            changes: [RecoveryMappingChange(eventID: id, sourceKey: keyB, fingerprint: keyA)])
    }
    await store.close()
    let reopened = try fixture.store(.resume)
    #expect(try await reopened.snapshot() == before)
    await reopened.close()
}

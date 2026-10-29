import Foundation
import Testing

@testable import SyncPersistence

struct ContactMutationJournalTests {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("machandle-journal-test-\(UUID())", isDirectory: true)
    }
    @Test func exclusiveIdentityBoundStoreCannotBeRecreatedOrSilentlySubstituted() async throws {
        let directory = location()
        defer { try? FileManager.default.removeItem(at: directory) }
        let installation = UUID()
        let journal = try ContactMutationJournal(
            directory: directory, installation: installation, mode: .createNew)
        #expect(throws: PersistenceFailure.self) {
            try ContactMutationJournal(
                directory: directory, installation: installation, mode: .resume)
        }
        await journal.close()
        #expect(throws: PersistenceFailure.self) {
            try ContactMutationJournal(directory: directory, installation: UUID(), mode: .resume)
        }
        #expect(throws: PersistenceFailure.self) {
            try ContactMutationJournal(
                directory: directory, installation: installation, mode: .createNew)
        }
        #expect(throws: PersistenceFailure.self) {
            try ContactMutationJournal(
                directory: location(), installation: installation, mode: .resume)
        }
    }
    @Test func transitionsCannotForgeReceiptOrEraseUncertainty() async throws {
        let directory = location()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try ContactMutationJournal(
            directory: directory, installation: UUID(), mode: .createNew)
        let id = UUID()
        await #expect(throws: PersistenceFailure.self) {
            try await journal.finish(id, state: .applied)
        }
        try await journal.begin(id)
        await #expect(throws: PersistenceFailure.self) { try await journal.begin(UUID()) }
        await #expect(throws: PersistenceFailure.self) {
            try await journal.finish(id, state: .pending)
        }
        try await journal.finish(id, state: .unknown)
        await #expect(throws: PersistenceFailure.self) {
            try await journal.finish(id, state: .applied)
        }
        await #expect(throws: PersistenceFailure.self) { try await journal.begin(UUID()) }
        await journal.close()
    }
    @Test func alteredSchemaAndUnsafePermissionsFailClosed() async throws {
        for schema in [false, true] {
            let directory = location()
            defer { try? FileManager.default.removeItem(at: directory) }
            let installation = UUID()
            let journal = try ContactMutationJournal(
                directory: directory, installation: installation, mode: .createNew)
            await journal.close()
            if schema {
                let db = try SQLiteConnection(directory: directory, mode: .resume)
                try db.execute("CREATE TABLE unexpected (value TEXT) STRICT")
                db.close()
            } else {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o644],
                    ofItemAtPath: directory.appendingPathComponent("state.sqlite").path)
            }
            #expect(throws: PersistenceFailure.self) {
                try ContactMutationJournal(
                    directory: directory, installation: installation, mode: .resume)
            }
        }
    }
    @Test func failedIntentCommitRollsBackWithoutDispatchAuthorization() async throws {
        let directory = location()
        defer { try? FileManager.default.removeItem(at: directory) }
        let installation = UUID()
        let journal = try ContactMutationJournal(
            directory: directory, installation: installation, mode: .createNew)
        await journal.close()
        let db = try SQLiteConnection(directory: directory, mode: .resume)
        db.beforeCommit = { throw PersistenceFailure.unavailable }
        #expect(throws: PersistenceFailure.self) {
            try db.transaction {
                try db.execute("INSERT INTO actions VALUES (?, 'pending')", [UUID().uuidString])
            }
        }
        db.close()
        let reopened = try ContactMutationJournal(
            directory: directory, installation: installation, mode: .resume)
        #expect(try await reopened.records().isEmpty)
        try await reopened.requireReady()
        await reopened.close()
    }
}

@Test func calendarJournalCannotBeOpenedAsContactAuthority() async throws {
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        .appendingPathComponent("machandle-journal-service-\(UUID())", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let installation = UUID()
    let calendar = try CalendarMutationJournal(
        directory: directory, installation: installation, mode: .createNew)
    await calendar.close()
    #expect(throws: PersistenceFailure.self) {
        try ContactMutationJournal(directory: directory, installation: installation, mode: .resume)
    }
}

@Test func reminderJournalCannotBeOpenedAsContactAuthority() async throws {
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        .appendingPathComponent("machandle-contact-journal-\(UUID())", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let installation = UUID()
    let reminder = try ReminderMutationJournal(
        directory: directory, installation: installation, mode: .createNew)
    await reminder.close()
    #expect(throws: PersistenceFailure.self) {
        try ContactMutationJournal(directory: directory, installation: installation, mode: .resume)
    }
}

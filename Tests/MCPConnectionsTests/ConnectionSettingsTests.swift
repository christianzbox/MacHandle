import CoreDomain
import Darwin
import Foundation
import PermissionEngine
import Testing

@testable import MCPConnections

private func directory() -> URL {
    FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(
        "machandle-synthetic-connections-" + UUID().uuidString)
}
private func record() throws -> SavedConnection {
    let account = AccountReference(
        provider: try ProviderID("synthetic-provider"), store: try StoreID("synthetic-store"),
        account: try AccountID("synthetic-account"))
    let grant = try SavedCalendarGrant(
        reference: CalendarReference(account: account, localID: try DomainID("synthetic-calendar")),
        operations: [.discover, .availability], fields: [.time, .occupancy])
    return try SavedConnection(label: "Synthetic connection", grants: [grant])
}
@Test func connectionSettingsRoundTripIsPrivateAndRestoresOnlyCandidates() async throws {
    let root = directory()
    defer { try? FileManager.default.removeItem(at: root) }
    let saved = try record()
    do {
        let store = try FileConnectionSettings(directory: root, create: true)
        #expect(try store.load().isEmpty)
        try store.save([saved])
        var info = stat()
        #expect(lstat(root.appendingPathComponent("connections.json").path, &info) == 0)
        #expect(info.st_mode & 0o077 == 0)
        #expect(try store.load() == [saved])
        #expect(throws: (any Error).self) {
            try FileConnectionSettings(directory: root, create: false)
        }
    }
    let reopened = try FileConnectionSettings(directory: root, create: false)
    let controller = try ConnectionController(store: reopened)
    #expect(try await controller.settings() == [saved])
    #expect(await controller.activity().isEmpty)
    let data = try Data(contentsOf: root.appendingPathComponent("connections.json"))
    let string = String(decoding: data, as: UTF8.self)
    for key in ["enabled", "channel", "token", "credential", "session"] {
        #expect(!string.contains("\"" + key + "\""))
    }
}
@Test func connectionSettingsRejectsMissingCorruptFutureAndOversizedState() throws {
    let missing = directory()
    #expect(throws: (any Error).self) {
        try FileConnectionSettings(directory: missing, create: false)
    }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
    for data in [
        Data("not-json".utf8), Data(#"{"version":99,"connections":[]}"#.utf8),
        Data(repeating: 32, count: 262145),
    ] {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        do { _ = try FileConnectionSettings(directory: root, create: true) }
        try data.write(to: root.appendingPathComponent("connections.json"))
        #expect(throws: (any Error).self) {
            try FileConnectionSettings(directory: root, create: false)
        }
    }
}
@Test func connectionSettingsRejectsPermissionAndSymlinkReplacement() throws {
    for symbolic in [false, true] {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FileConnectionSettings(directory: root, create: true)
        let file = root.appendingPathComponent("connections.json")
        if symbolic {
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createSymbolicLink(
                at: file, withDestinationURL: root.appendingPathComponent("writer.lock"))
        } else {
            #expect(chmod(file.path, 0o644) == 0)
        }
        #expect(throws: (any Error).self) { try store.load() }
        #expect(throws: (any Error).self) { try store.save([]) }
    }
}
@Test func connectionSettingsRejectsUnknownGrantEnumsAndDuplicateIDs() throws {
    let saved = try record()
    #expect(throws: (any Error).self) { try SettingsEnvelope.encode([saved, saved]) }
    let data = try SettingsEnvelope.encode([saved])
    let text = String(decoding: data, as: UTF8.self).replacingOccurrences(
        of: "\"availability\"", with: "\"delete\"")
    #expect(throws: (any Error).self) { try SettingsEnvelope.decode(Data(text.utf8)) }
    let many = try (0..<33).map { _ in try record() }
    #expect(throws: (any Error).self) { try SettingsEnvelope.encode(many) }
}

private final class FailingStore: ConnectionSettingsStore, @unchecked Sendable {
    let base = MemoryConnectionSettings()
    private let lock = NSLock()
    private var failed = false
    func fail() { lock.withLock { failed = true } }
    func load() throws -> [SavedConnection] { try base.load() }
    func save(_ values: [SavedConnection]) throws {
        if lock.withLock({ failed }) { throw ConnectionFailure.storage }
        try base.save(values)
    }
}
@Test func connectionPersistenceFailureClosesAdmissionAndDoesNotResurrectOnRestart() async throws {
    let store = FailingStore()
    let controller = try ConnectionController(store: store)
    await controller.observePermissions(OSPermissions(calendars: .fullAccess))
    let config = try await controller.configure(label: "Synthetic", grants: record().grants)
    let pending = try await controller.requestPairing(ConnectionChannel(verify: { true }))
    let review = try await controller.review(pending, connection: config.id)
    let lease = try await controller.approve(review)
    store.fail()
    await #expect(throws: (any Error).self) { try await controller.revoke(config.id) }
    #expect(!lease.isOpen)
    await #expect(throws: (any Error).self) { try await controller.settings() }
    await #expect(throws: (any Error).self) {
        try await controller.requestPairing(ConnectionChannel(verify: { true }))
    }
    let restarted = try ConnectionController(store: store.base)
    await #expect(throws: (any Error).self) { try await restarted.approve(review) }
    #expect(await controller.activity().last?.action == .storageFailed)
}

@Test func reminderSettingsMigrateLegacyWithoutAddingGrantsAndRoundTripIndependentReads() throws {
    let old = try record()
    let encoded = try SettingsEnvelope.encode([old])
    let legacy = String(decoding: encoded, as: UTF8.self).replacingOccurrences(
        of: "\"version\":2", with: "\"version\":1")
    #expect(try SettingsEnvelope.decode(Data(legacy.utf8)).first?.reminderGrants.isEmpty == true)
    let calendar = try old.grants[0].reference
    let list = ReminderListReference(
        account: calendar.account, localID: try DomainID("reminder-list"))
    let grant = try SavedReminderGrant(
        reference: list, operations: [.discover, .summary, .details], fields: [.title, .recurrence])
    let both = try SavedConnection(
        label: "Synthetic independent grants", grants: old.grants, reminderGrants: [grant])
    let decoded = try SettingsEnvelope.decode(SettingsEnvelope.encode([both]))
    #expect(decoded == [both])
    #expect(try both.policy.reminderLists[list]?.writableFields.isEmpty == true)
    let downgrade = String(decoding: try SettingsEnvelope.encode([both]), as: UTF8.self)
        .replacingOccurrences(of: "\"version\":2", with: "\"version\":1")
    #expect(throws: (any Error).self) { try SettingsEnvelope.decode(Data(downgrade.utf8)) }
}
@Test func reminderGrantsRejectDuplicatesAndNeverGrantSourceWritesToGoogle() async throws {
    let calendar = try record().grants[0].reference
    let list = ReminderListReference(
        account: calendar.account, localID: try DomainID("reminder-list"))
    let grant = try SavedReminderGrant(reference: list, operations: [.summary], fields: [.title])
    #expect(throws: (any Error).self) {
        try SavedConnection(label: "Synthetic", grants: [], reminderGrants: [grant, grant])
    }
    let authority = PolicyAuthority()
    let id = try ConnectionID("synthetic-google")
    await authority.setConnection(
        Connection(id: id, kind: .googleSync, state: .enabled),
        policy: ConnectionPolicy(reminderLists: [list: grant.grant]))
    await authority.observeOSPermissions(OSPermissions(reminders: .fullAccess))
    let session = try await authority.bindTrustedConnection(id)
    guard
        case .denied = await session.evaluate(
            .reminderRead([list], operation: .readSummary, fields: [.title]))
    else {
        Issue.record("Google cannot read Reminders")
        return
    }
}

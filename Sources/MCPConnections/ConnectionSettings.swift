import CoreDomain
import Foundation
import PermissionEngine

package enum ConnectionFailure: Error {
    case denied, expired, stale, busy, invalid, storage, closed, limit
}

/// Saved candidates, never an enabled session or credential. Calendar and Reminders reads remain independent.
package struct SavedCalendarGrant: Codable, Equatable, Sendable {
    package enum Operation: String, Codable, Sendable {
        case discover, availability, summary, details
    }
    package enum Field: String, Codable, Sendable {
        case time, occupancy, status, title, location, notes
    }
    package let provider: String
    package let store: String
    package let account: String
    package let calendar: String
    package let operations: [Operation]
    package let fields: [Field]
    package init(reference: CalendarReference, operations: [Operation], fields: [Field]) throws {
        provider = reference.account.provider.rawValue
        store = reference.account.store.rawValue
        account = reference.account.account.rawValue
        calendar = reference.localID.rawValue
        self.operations = operations
        self.fields = fields
        try validate()
    }
    func validate() throws {
        guard
            [provider, store, account, calendar].allSatisfy({
                !$0.isEmpty && $0.utf8.count <= 256 && !$0.utf8.contains(0)
            }),
            Set(operations).count == operations.count, Set(fields).count == fields.count
        else { throw ConnectionFailure.invalid }
    }
    var reference: CalendarReference {
        get throws {
            CalendarReference(
                account: AccountReference(
                    provider: try ProviderID(provider), store: try StoreID(store),
                    account: try AccountID(account)), localID: try DomainID(calendar))
        }
    }
    var grant: CalendarGrant {
        CalendarGrant(
            operations: Set(
                operations.map {
                    switch $0 {
                    case .discover: .discover
                    case .availability: .checkAvailability
                    case .summary: .readSummary
                    case .details: .readDetails
                    }
                }),
            readableFields: Set(
                fields.map {
                    switch $0 {
                    case .time: .time
                    case .occupancy: .occupancy
                    case .status: .status
                    case .title: .title
                    case .location: .location
                    case .notes: .notes
                    }
                }))
    }
}

package struct SavedConnection: Codable, Equatable, Sendable {
    package let id: UUID
    package let revision: UUID
    package let label: String
    package let grants: [SavedCalendarGrant]
    private let reminderCandidates: [SavedReminderGrant]?
    package var reminderGrants: [SavedReminderGrant] { reminderCandidates ?? [] }
    private let contactCandidates: [SavedContactGrant]?
    package var contactGrants: [SavedContactGrant] { contactCandidates ?? [] }
    package let revoked: Bool
    init(
        id: UUID = UUID(), label: String, grants: [SavedCalendarGrant],
        reminderGrants: [SavedReminderGrant] = [], contactGrants: [SavedContactGrant] = [],
        revoked: Bool = false
    )
        throws
    {
        self.id = id
        revision = UUID()
        self.label = label
        self.grants = grants
        self.reminderCandidates = reminderGrants.isEmpty ? nil : reminderGrants
        self.contactCandidates = contactGrants.isEmpty ? nil : contactGrants
        self.revoked = revoked
        try validate()
    }
    func validate() throws {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            label.utf8.count <= 256,
            !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            grants.count <= 32, reminderGrants.count <= 32, contactGrants.count <= 32
        else { throw ConnectionFailure.invalid }
        for grant in contactGrants { try grant.validate() }
        guard try Set(contactGrants.map { try $0.reference }).count == contactGrants.count else {
            throw ConnectionFailure.invalid
        }
        for grant in grants { try grant.validate() }
        for grant in reminderGrants { try grant.validate() }
        guard try Set(reminderGrants.map { try $0.reference }).count == reminderGrants.count else {
            throw ConnectionFailure.invalid
        }
        guard try Set(grants.map { try $0.reference }).count == grants.count else {
            throw ConnectionFailure.invalid
        }
    }
    var policy: ConnectionPolicy {
        get throws {
            ConnectionPolicy(
                calendars: Dictionary(
                    uniqueKeysWithValues: try grants.map { (try $0.reference, $0.grant) }),
                reminderLists: Dictionary(
                    uniqueKeysWithValues: try reminderGrants.map { (try $0.reference, $0.grant) }),
                contactContainers: Dictionary(
                    uniqueKeysWithValues: try contactGrants.map { (try $0.reference, try $0.grant) }
                ))
        }
    }
}

package protocol ConnectionSettingsStore: Sendable {
    // Synchronous atomic replacement avoids suspension inside a configuration transaction.
    func load() throws -> [SavedConnection]
    func save(_ connections: [SavedConnection]) throws
}

struct SettingsEnvelope: Codable {
    let version: Int
    let connections: [SavedConnection]
    static func validate(_ records: [SavedConnection]) throws {
        guard records.count <= 32, Set(records.map(\.id)).count == records.count else {
            throw ConnectionFailure.invalid
        }
        for record in records { try record.validate() }
    }
    static func encode(_ records: [SavedConnection]) throws -> Data {
        try validate(records)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(
            Self(version: 3, connections: records.sorted { $0.id.uuidString < $1.id.uuidString }))
        guard data.count <= 262_144 else { throw ConnectionFailure.limit }
        return data
    }
    static func decode(_ data: Data) throws -> [SavedConnection] {
        guard !data.isEmpty, data.count <= 262_144 else { throw ConnectionFailure.storage }
        let envelope = try JSONDecoder().decode(Self.self, from: data)
        guard (1...3).contains(envelope.version),
            envelope.version >= 3 || envelope.connections.allSatisfy({ $0.contactGrants.isEmpty }),
            envelope.version >= 2 || envelope.connections.allSatisfy({ $0.reminderGrants.isEmpty })
        else { throw ConnectionFailure.storage }
        try validate(envelope.connections)
        return envelope.connections
    }
}

/// Used only by explicit synthetic composition and tests; no hidden global state.
package final class MemoryConnectionSettings: ConnectionSettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data
    package init() { data = Data(#"{"version":1,"connections":[]}"#.utf8) }
    package func load() throws -> [SavedConnection] {
        try lock.withLock { try SettingsEnvelope.decode(data) }
    }
    package func save(_ connections: [SavedConnection]) throws {
        try lock.withLock { data = try SettingsEnvelope.encode(connections) }
    }
}

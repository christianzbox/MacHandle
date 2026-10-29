import Foundation

public struct ContactContainer: Hashable, Sendable {
    public let id: ContactContainerReference
    public let name: String
    public init(id: ContactContainerReference, name: String) {
        self.id = id
        self.name = name
    }
}
/// Application selection, not an OS limited-Contacts grant. IDs refer to underlying records only.
public enum ContactReadScope: Hashable, Sendable {
    case allRecords
    case records(Set<ContactID>)
    public func contains(_ id: ContactID) -> Bool {
        switch self {
        case .allRecords: true
        case .records(let ids): ids.contains(id)
        }
    }
}
public struct ContactReadRequest: Hashable, Sendable {
    public let scopes: [ContactContainerReference: ContactReadScope]
    public let item: ContactRecordReference?
    public init(
        scopes: [ContactContainerReference: ContactReadScope], item: ContactRecordReference? = nil
    ) throws {
        guard !scopes.isEmpty, scopes.count <= 32,
            scopes.values.allSatisfy({
                if case .records(let ids) = $0 { return !ids.isEmpty && ids.count <= 256 }
                return true
            }),
            item == nil
                || (scopes.count == 1 && scopes[item!.container]?.contains(item!.item) == true)
        else { throw ProviderFailure.invalidData }
        self.scopes = scopes
        self.item = item
    }
    public func contains(_ ref: ContactRecordReference) -> Bool {
        scopes[ref.container]?.contains(ref.item) == true && (item == nil || ref == item)
    }
}
public struct ContactSnapshot: Sendable {
    public static let maximumItems = 1000
    public let coverage: ContactReadRequest
    public let contacts: [Contact]
    public let observation: ObservationState
    public init(coverage: ContactReadRequest, contacts: [Contact], observation: ObservationState)
        throws
    {
        guard contacts.count <= Self.maximumItems, Set(contacts.map(\.id)).count == contacts.count,
            contacts.allSatisfy({
                if case .record(let ref) = $0.id { return coverage.contains(ref) }
                return false
            })
        else { throw ProviderFailure.ambiguousIdentity }
        self.coverage = coverage
        self.contacts = contacts
        self.observation = observation
    }
}
public protocol ContactDiscovering: Sendable {
    func authorization() async -> OSAuthorization
    func requestAccess() async -> OSAuthorization
    func discoverContactContainers() async -> ProviderReadResult<
        ResourceDiscovery<ContactContainer>
    >
    func changes() async -> AsyncStream<Void>
}
public protocol ContactReading: Sendable {
    func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>) async
        -> ProviderReadResult<ContactSnapshot>
}
public enum ContactReadCapabilities {
    public static let fields: Set<ContactField> = [
        .name, .emailAddresses, .phoneNumbers, .postalAddresses, .organization,
    ]
    public static let searchFields: Set<ContactField> = [
        .name, .emailAddresses, .phoneNumbers, .organization,
    ]
}
/// Call only after policy projection; matching never examines hidden values or provider predicates.
public enum ContactSearch {
    public static func matches(_ contact: Contact, query: String, fields: Set<ContactField>) throws
        -> Bool
    {
        guard query.utf8.count <= 256, !fields.isEmpty,
            fields.isSubset(of: ContactReadCapabilities.searchFields)
        else { throw ProviderFailure.invalidData }
        if query.isEmpty { return true }
        var values: [String] = []
        for field in fields {
            switch field {
            case .name:
                guard case .value(let name) = contact.name else {
                    throw ProviderFailure.invalidData
                }
                values += [name.given, name.family, name.given + " " + name.family]
            case .emailAddresses:
                guard case .value(let emails) = contact.emailAddresses else {
                    throw ProviderFailure.invalidData
                }
                values += emails.map(\.value)
            case .phoneNumbers:
                guard case .value(let phones) = contact.phoneNumbers else {
                    throw ProviderFailure.invalidData
                }
                values += phones.map(\.value)
            case .organization:
                guard case .value(let org) = contact.organization else {
                    throw ProviderFailure.invalidData
                }
                values += org.map { [$0] } ?? []
            default: throw ProviderFailure.invalidData
            }
        }
        return values.contains {
            $0.range(
                of: query, options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
                != nil
        }
    }
}

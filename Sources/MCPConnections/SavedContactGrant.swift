import CoreDomain
import Foundation
import PermissionEngine

package struct SavedContactGrant: Codable, Equatable, Sendable {
    package enum Operation: String, Codable, Sendable { case discover, search, details }
    package enum Field: String, Codable, Sendable {
        case name, emailAddresses, phoneNumbers, postalAddresses, organization
    }
    package enum Scope: String, Codable, Sendable { case allRecords, records }
    package let provider: String
    package let store: String
    package let account: String
    package let container: String
    package let scope: Scope
    package let records: [String]
    package let operations: [Operation]
    package let fields: [Field]
    package init(
        reference: ContactContainerReference, selection: ContactReadScope,
        operations: [Operation], fields: [Field]
    ) throws {
        provider = reference.account.provider.rawValue
        store = reference.account.store.rawValue
        account = reference.account.account.rawValue
        container = reference.localID.rawValue
        switch selection {
        case .allRecords:
            scope = .allRecords
            records = []
        case .records(let ids):
            scope = .records
            records = ids.map(\.rawValue).sorted()
        }
        self.operations = operations
        self.fields = fields
        try validate()
    }
    func validate() throws {
        guard
            ([provider, store, account, container] + records).allSatisfy({
                !$0.isEmpty && $0.utf8.count <= 256 && !$0.utf8.contains(0)
            }),
            Set(operations).count == operations.count, Set(fields).count == fields.count,
            Set(records).count == records.count, records.count <= 256,
            scope == .allRecords ? records.isEmpty : !records.isEmpty
        else { throw ConnectionFailure.invalid }
    }
    var reference: ContactContainerReference {
        get throws {
            try ContactContainerReference(
                account: AccountReference(
                    provider: ProviderID(provider), store: StoreID(store),
                    account: AccountID(account)), localID: DomainID(container))
        }
    }
    var readScope: ContactReadScope {
        get throws {
            scope == .allRecords ? .allRecords : .records(try Set(records.map(ContactID.init)))
        }
    }
    var grant: ContactGrant {
        get throws {
            ContactGrant(
                selection: scope == .allRecords
                    ? .allRecords : .records(try Set(records.map(ContactID.init))),
                access: ResourceGrant(
                    operations: Set(
                        operations.map {
                            switch $0 {
                            case .discover: .discover
                            case .search: .search
                            case .details: .readFields
                            }
                        }),
                    readableFields: Set(
                        fields.map {
                            switch $0 {
                            case .name: .name
                            case .emailAddresses: .emailAddresses
                            case .phoneNumbers: .phoneNumbers
                            case .postalAddresses: .postalAddresses
                            case .organization: .organization
                            }
                        })))
        }
    }
}

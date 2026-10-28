import CoreDomain
import Foundation
import PermissionEngine

package struct SavedReminderGrant: Codable, Equatable, Sendable {
    package enum Operation: String, Codable, Sendable { case discover, summary, details }
    package enum Field: String, Codable, Sendable { case title, notes, due, completion, recurrence }
    package let provider: String
    package let store: String
    package let account: String
    package let list: String
    package let operations: [Operation]
    package let fields: [Field]
    package init(reference: ReminderListReference, operations: [Operation], fields: [Field]) throws
    {
        provider = reference.account.provider.rawValue
        store = reference.account.store.rawValue
        account = reference.account.account.rawValue
        list = reference.localID.rawValue
        self.operations = operations
        self.fields = fields
        try validate()
    }
    func validate() throws {
        guard
            [provider, store, account, list].allSatisfy({
                !$0.isEmpty && $0.utf8.count <= 256 && !$0.utf8.contains(0)
            }),
            Set(operations).count == operations.count, Set(fields).count == fields.count
        else { throw ConnectionFailure.invalid }
    }
    var reference: ReminderListReference {
        get throws {
            try ReminderListReference(
                account: AccountReference(
                    provider: ProviderID(provider), store: StoreID(store),
                    account: AccountID(account)), localID: DomainID(list))
        }
    }
    var grant: ReminderGrant {
        ReminderGrant(
            operations: Set(
                operations.map {
                    switch $0 {
                    case .discover: .discover
                    case .summary: .readSummary
                    case .details: .readDetails
                    }
                }),
            readableFields: Set(
                fields.map {
                    switch $0 {
                    case .title: .title
                    case .notes: .notes
                    case .due: .due
                    case .completion: .completion
                    case .recurrence: .recurrence
                    }
                }))
    }
}

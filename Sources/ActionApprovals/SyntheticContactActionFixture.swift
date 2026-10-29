import CoreDomain
import Foundation
import PermissionEngine

package struct SyntheticContactActionFixture: Sendable {
    package let authority: PolicyAuthority
    package let session: PolicySession
    package let provider: SyntheticContactActionProvider
    package let container: ContactContainerReference
    package let record: ContactRecordReference
    package let contact: Contact
    package static func make() async throws -> Self {
        let container = try ContactContainerReference(
            account: AccountReference(
                provider: ProviderID("synthetic"), store: StoreID("synthetic-store"),
                account: AccountID("synthetic-account")), localID: DomainID("synthetic-container"))
        let record = ContactRecordReference(
            container: container, item: try ContactID("synthetic-contact"))
        let contact = try Contact(
            id: .record(record), name: .value(ContactName(given: "Sample Ada", family: "Example")),
            emailAddresses: .value([LabeledValue(label: "Sample", value: "ada@example.invalid")]),
            phoneNumbers: .value([]), postalAddresses: .value([]),
            organization: .value("Sample organization"),
            notes: .value("synthetic-hidden-contact-mutation-canary"),
            revision: .revision(ObservedRevision("synthetic-v1")))
        let authority = PolicyAuthority()
        let id = try ConnectionID(UUID().uuidString)
        await authority.setConnection(
            Connection(id: id, kind: .localMCP, state: .enabled),
            policy: ConnectionPolicy(contactContainers: [
                container: ContactGrant(
                    selection: .allRecords,
                    access: ResourceGrant(
                        operations: [.readFields, .create, .update, .delete],
                        readableFields: ContactReadCapabilities.fields,
                        writableFields: ContactReadCapabilities.fields))
            ]))
        await authority.observeOSPermissions(OSPermissions(contacts: .fullAccess))
        return Self(
            authority: authority, session: try await authority.bindTrustedConnection(id),
            provider: SyntheticContactActionProvider(container: container, contact: contact),
            container: container, record: record, contact: contact)
    }
    package func change(_ kind: ContactActionKind) throws -> ContactMutation {
        switch kind {
        case .create:
            .create(
                in: container,
                fields: try ContactChanges(
                    name: .set(ContactName(given: "Sample new", family: "Contact"))))
        case .update:
            .update(
                record,
                changes: try ContactChanges(organization: .set("Sample revised organization")),
                precondition: .unknown)
        case .delete: .delete(record, precondition: .unknown)
        }
    }
}
package actor SyntheticContactActionProvider: ContactActionProvider {
    private let container: ContactContainerReference
    private var contacts: [ContactRecordReference: Contact]
    private var applied: Set<OperationID> = []
    package init(container: ContactContainerReference, contact: Contact) {
        self.container = container
        if case .record(let ref) = contact.id { contacts = [ref: contact] } else { contacts = [:] }
    }
    package func inspect(_ change: ContactMutation, fields: Set<ContactField>) throws
        -> ContactActionSnapshot
    {
        guard change.target == container else { throw ActionFailure.denied }
        return ContactActionReview.project(
            ContactActionSnapshot(
                container: container, accountLabel: "Sample local account",
                containerLabel: "Sample address book", writable: true,
                contact: change.item.flatMap { contacts[$0] }), fields: fields)
    }
    package func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt {
        guard await action.revalidate(), !Task.isCancelled, !applied.contains(action.proposal.id),
            try inspect(action.proposal.change, fields: action.fields) == action.expected
        else { return .notApplied }
        let revision = MutationPrecondition.revision(try ObservedRevision(UUID().uuidString))
        let change = action.proposal.change
        switch change {
        case .create(_, let patch):
            let ref = ContactRecordReference(
                container: container, item: try ContactID(UUID().uuidString))
            contacts[ref] = ContactActionReview.applying(
                patch,
                to: Contact(
                    id: .record(ref), name: .value(ContactName(given: "", family: "")),
                    emailAddresses: .value([]), phoneNumbers: .value([]),
                    postalAddresses: .value([]), organization: .value(nil)), revision: revision)
        case .update(let ref, let patch, _):
            guard let old = contacts[ref] else { return .notApplied }
            contacts[ref] = ContactActionReview.applying(patch, to: old, revision: revision)
        case .delete(let ref, _): contacts.removeValue(forKey: ref)
        }
        applied.insert(action.proposal.id)
        return .applied(action.proposal.id)
    }
}

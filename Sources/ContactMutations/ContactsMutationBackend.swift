import ActionApprovals
import Contacts
import CoreDomain
import CryptoKit
import Foundation

/// Closed production factory. Candidate writable containers must come from trusted runtime acceptance,
/// never CNContainer.type, caller assertions or saved read grants. No permission prompt exists here.
actor ContactsMutationBackend: ContactMutationBackend {
    private let containers: Set<ContactContainerReference>
    private let changes = ContactMutationSignal()
    init(acceptedContainers: Set<ContactContainerReference>) { containers = acceptedContainers }
    private func access() throws {
        try Task.checkCancellation()
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            throw ActionFailure.denied
        }
    }
    private func target(_ change: ContactMutation, store: CNContactStore) throws -> CNContainer {
        guard containers.contains(change.target),
            change.target.account.provider.rawValue == "apple-contacts",
            let container = try store.containers(
                matching: CNContainer.predicateForContainers(withIdentifiers: [
                    change.target.localID.rawValue
                ])
            ).first,
            container.identifier == change.target.localID.rawValue
        else { throw ActionFailure.denied }
        return container
    }
    private func membership(_ ref: ContactRecordReference, store: CNContactStore) throws {
        let request = ContactNativeValues.request(keys: [CNContactIdentifierKey])
        request.predicate = CNContact.predicateForContactsInContainer(
            withIdentifier: ref.container.localID.rawValue)
        var found = false
        var count = 0
        let start = ProcessInfo.processInfo.systemUptime
        var failure = false
        try store.enumerateContacts(with: request) { contact, stop in
            if Task.isCancelled || count >= 1000
                || ProcessInfo.processInfo.systemUptime - start >= 10
            {
                failure = true
                stop.pointee = true
                return
            }
            count += 1
            if contact.identifier == ref.item.rawValue {
                found = true
                stop.pointee = true
            }
        }
        guard found && !failure else { throw ActionFailure.stale }
    }
    private struct Capture {
        let store: CNContactStore
        let native: CNContact?
        let snapshot: ContactActionSnapshot
        let epoch: UInt64
    }
    private func capture(_ change: ContactMutation, fields: Set<ContactField>) throws -> Capture {
        try access()
        try ContactActionReview.validate(change)
        guard fields == change.reviewFields else { throw ActionFailure.denied }
        let epoch = changes.generation
        let store = CNContactStore()
        let container = try target(change, store: store)
        var native: CNContact?
        var contact: Contact?
        if let ref = change.item {
            try membership(ref, store: store)
            let request = ContactNativeValues.request(keys: try ContactNativeValues.keys(fields))
            request.predicate = CNContact.predicateForContacts(withIdentifiers: [ref.item.rawValue])
            var values: [CNContact] = []
            try store.enumerateContacts(with: request) { value, stop in
                values.append(value)
                if values.count > 1 { stop.pointee = true }
            }
            guard values.count == 1, let value = values.first, value.identifier == ref.item.rawValue
            else { throw ActionFailure.stale }
            native = value
            let normalized = try ContactNativeValues.normalize(
                value, reference: ref, fields: fields)
            var parts = [
                ref.container.account.store.rawValue, ref.container.localID.rawValue,
                ref.item.rawValue, String(epoch),
            ]
            for field in ContactActionReview.orderedFields where fields.contains(field) {
                parts += [
                    ContactActionReview.label(field),
                    try ContactActionReview.display(normalized, field: field),
                ]
            }
            let encoded = try JSONSerialization.data(withJSONObject: parts)
            let digest = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
            let revision = MutationPrecondition.revision(
                try ObservedRevision("contacts-observed-" + digest))
            if let expected = change.precondition, expected != .unknown, expected != revision {
                throw ActionFailure.stale
            }
            contact = Contact(
                id: normalized.id, name: normalized.name, emailAddresses: normalized.emailAddresses,
                phoneNumbers: normalized.phoneNumbers, postalAddresses: normalized.postalAddresses,
                organization: normalized.organization, revision: revision)
            try membership(ref, store: store)
        }
        guard try target(change, store: store).name == container.name, epoch == changes.generation
        else { throw ActionFailure.stale }
        try access()
        return Capture(
            store: store, native: native,
            snapshot: ContactActionSnapshot(
                container: change.target, accountLabel: "Local Contacts store",
                containerLabel: container.name, writable: true, contact: contact), epoch: epoch)
    }
    func inspect(_ change: ContactMutation, fields: Set<ContactField>) throws
        -> ContactActionSnapshot
    {
        try capture(change, fields: fields).snapshot
    }
    func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt {
        guard await action.revalidate() else { return .notApplied }
        let captured: Capture
        let mutable: CNMutableContact
        let request = CNSaveRequest()
        request.shouldRefetchContacts = false
        do {
            captured = try capture(action.proposal.change, fields: action.fields)
            guard captured.snapshot == action.expected else { return .notApplied }
            if action.proposal.change.item == nil {
                mutable = CNMutableContact()
            } else {
                guard case .revision = action.proposal.change.precondition,
                    let copy = captured.native?.mutableCopy() as? CNMutableContact
                else { return .notApplied }
                mutable = copy
            }
            if let patch = action.proposal.change.changes {
                try ContactNativeValues.apply(patch, to: mutable)
            }
            switch action.proposal.change {
            case .create:
                request.add(
                    mutable,
                    toContainerWithIdentifier: action.proposal.change.target.localID.rawValue)
            case .update: request.update(mutable)
            case .delete: request.delete(mutable)
            }
            guard await action.revalidate() else { return .notApplied }
            try access()
            guard captured.epoch == changes.generation else { return .notApplied }
        } catch { return .notApplied }
        // No suspension before dispatch. Cross-process writes are still last-writer-wins, not CAS.
        do {
            try captured.store.execute(request)
            return .applied(action.proposal.id)
        } catch { return .unknown }
    }
}
private final class ContactMutationSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0
    private var observer: NSObjectProtocol?
    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.withLock { self.value &+= 1 }
        }
    }
    var generation: UInt64 { lock.withLock { value } }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

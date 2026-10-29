import Contacts
import CoreDomain
import Foundation

/// Only immutable domain values leave this actor. CNContactStore is lazy and never used before opt-in.
actor NativeContactsBackend: ContactsBackend {
    private var store: CNContactStore?
    private let scope = UUID().uuidString
    private let signal = ContactChangeSignal()
    private func contactStore() -> CNContactStore {
        if let store { return store }
        let result = CNContactStore()
        store = result
        return result
    }
    static func mapAuthorization(_ status: CNAuthorizationStatus) -> OSAuthorization {
        switch status {
        case .authorized: .fullAccess
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unknown
        }
    }
    func authorization() -> OSAuthorization {
        Self.mapAuthorization(CNContactStore.authorizationStatus(for: .contacts))
    }
    func requestAccess() async -> OSAuthorization {
        guard authorization() == .notDetermined, !Task.isCancelled else { return authorization() }
        do {
            _ = try await contactStore().requestAccess(for: .contacts)
            return authorization()
        } catch { return .unknown }
    }
    func generation() -> UInt64 { signal.generation }
    func changes() -> AsyncStream<Void> { signal.stream() }
    private func access() throws {
        try Task.checkCancellation()
        guard authorization() == .fullAccess else { throw ProviderFailure.denied }
    }
    private func reference(_ id: String) throws -> ContactContainerReference {
        try ContactContainerReference(
            account: AccountReference(
                provider: ProviderID("apple-contacts"),
                store: StoreID(scope), account: AccountID("local-address-book")),
            localID: DomainID(id))
    }
    func containers() throws -> [ContactContainer] {
        try access()
        let values = try contactStore().containers(matching: nil)
        guard values.count <= 1000 else { throw ProviderFailure.invalidData }
        let result = try values.map {
            try ContactContainer(id: reference($0.identifier), name: $0.name)
        }
        try access()
        return result
    }
    func identifiers(
        in container: ContactContainerReference, limit: Int,
        check: @Sendable () throws -> Void
    ) throws -> ContactMembership {
        try access()
        try check()
        guard (1...1000).contains(limit), try reference(container.localID.rawValue) == container
        else { throw ProviderFailure.invalidData }
        let request = Self.request(keys: [CNContactIdentifierKey])
        request.predicate = CNContact.predicateForContactsInContainer(
            withIdentifier: container.localID.rawValue)
        var ids: [ContactID] = []
        var truncated = false
        var failure: (any Error)?
        try contactStore().enumerateContacts(with: request) { value, stop in
            do {
                try check()
                if ids.count == limit {
                    truncated = true
                    stop.pointee = true
                    return
                }
                ids.append(try ContactID(value.identifier))
            } catch {
                failure = error
                stop.pointee = true
            }
        }
        if let failure { throw failure }
        try access()
        try check()
        return ContactMembership(ids: ids, truncated: truncated)
    }
    static func keys(_ fields: Set<ContactField>) throws -> [String] {
        guard !fields.isEmpty, fields.isSubset(of: ContactReadCapabilities.fields) else {
            throw ProviderFailure.invalidData
        }
        var keys = [CNContactIdentifierKey]
        for field in fields {
            switch field {
            case .name: keys += [CNContactGivenNameKey, CNContactFamilyNameKey]
            case .emailAddresses: keys.append(CNContactEmailAddressesKey)
            case .phoneNumbers: keys.append(CNContactPhoneNumbersKey)
            case .postalAddresses: keys.append(CNContactPostalAddressesKey)
            case .organization: keys.append(CNContactOrganizationNameKey)
            case .notes: throw ProviderFailure.invalidData
            }
        }
        return keys.sorted()
    }
    static func request(keys: [String]) -> CNContactFetchRequest {
        let request = CNContactFetchRequest(keysToFetch: keys.map { $0 as CNKeyDescriptor })
        request.unifyResults = false
        request.mutableObjects = false
        request.sortOrder = .none  // Sorting by a hidden name must not affect membership or order.
        return request
    }
    func fetch(
        _ records: [ContactRecordReference], fields: Set<ContactField>,
        check: @Sendable () throws -> Void
    ) throws -> [Contact] {
        try access()
        try check()
        guard !records.isEmpty, records.count <= 1000,
            Set(records.map(\.item)).count == records.count
        else { throw ProviderFailure.ambiguousIdentity }
        let refs = Dictionary(uniqueKeysWithValues: records.map { ($0.item.rawValue, $0) })
        let keys = try Self.keys(fields)
        let request = Self.request(keys: keys)
        request.predicate = CNContact.predicateForContacts(
            withIdentifiers: records.map { $0.item.rawValue })
        var result: [Contact] = []
        var failure: (any Error)?
        try contactStore().enumerateContacts(with: request) { value, stop in
            do {
                try check()
                guard let ref = refs[value.identifier], result.count < records.count,
                    value.areKeysAvailable(keys.map { $0 as CNKeyDescriptor })
                else { throw ProviderFailure.invalidData }
                result.append(try Self.normalize(value, reference: ref, fields: fields))
            } catch {
                failure = error
                stop.pointee = true
            }
        }
        if let failure { throw failure }
        try access()
        try check()
        return result
    }
    static func normalize(
        _ value: CNContact, reference: ContactRecordReference, fields: Set<ContactField>
    ) throws -> Contact {
        guard value.identifier == reference.item.rawValue,
            value.areKeysAvailable(try keys(fields).map { $0 as CNKeyDescriptor })
        else { throw ProviderFailure.invalidData }
        var bytes = 0
        func text(_ value: String) throws -> String {
            bytes += value.utf8.count
            guard value.utf8.count <= 4096, bytes <= 16384 else {
                throw ProviderFailure.invalidData
            }
            return value
        }
        func array<T>(_ values: [T]) throws -> [T] {
            guard values.count <= 32 else { throw ProviderFailure.invalidData }
            return values
        }
        let name: FieldValue<ContactName> =
            fields.contains(.name)
            ? .value(try ContactName(given: text(value.givenName), family: text(value.familyName)))
            : .notFetched
        let emails: FieldValue<[LabeledValue<String>]> =
            fields.contains(.emailAddresses)
            ? .value(
                try array(value.emailAddresses).map {
                    try LabeledValue(label: $0.label.map(text), value: text($0.value as String))
                }) : .notFetched
        let phones: FieldValue<[LabeledValue<String>]> =
            fields.contains(.phoneNumbers)
            ? .value(
                try array(value.phoneNumbers).map {
                    try LabeledValue(label: $0.label.map(text), value: text($0.value.stringValue))
                }) : .notFetched
        let addresses: FieldValue<[LabeledValue<PostalAddress>]> =
            fields.contains(.postalAddresses)
            ? .value(
                try array(value.postalAddresses).map {
                    try LabeledValue(
                        label: $0.label.map(text),
                        value: PostalAddress(
                            street: text($0.value.street), city: text($0.value.city),
                            region: text($0.value.state), postalCode: text($0.value.postalCode),
                            country: text($0.value.country)))
                }) : .notFetched
        let organization: FieldValue<String?> =
            fields.contains(.organization)
            ? .value(try text(value.organizationName).isEmpty ? nil : value.organizationName)
            : .notFetched
        // Never export notes, linked IDs or mutation authority.
        return Contact(
            id: .record(reference), name: name, emailAddresses: emails, phoneNumbers: phones,
            postalAddresses: addresses, organization: organization)
    }
}

private final class ContactChangeSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var version: UInt64 = 0
    private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var observer: NSObjectProtocol?
    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            let waiting = self.lock.withLock {
                self.version &+= 1
                return Array(self.listeners.values)
            }
            for listener in waiting { listener.yield(()) }
        }
    }
    var generation: UInt64 { lock.withLock { version } }
    func stream() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.withLock { listeners[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                _ = self?.lock.withLock { self?.listeners.removeValue(forKey: id) }
            }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

import Contacts
import CoreDomain
import Foundation
import Testing

@testable import AppleContactsProvider

private actor ContactGate {
    var entered = false
    var waiting: CheckedContinuation<Void, Never>?
    var held: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiting?.resume()
        waiting = nil
        await withCheckedContinuation { held = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { waiting = $0 } } }
    func release() {
        held?.resume()
        held = nil
    }
}
private actor ContactBackendFixture: ContactsBackend {
    let selected: ContactContainerReference
    let other: ContactContainerReference
    var access: OSAuthorization = .fullAccess
    var epoch: UInt64 = 0
    var memberships: [ContactContainerReference: [ContactID]]
    var requests = 0, inventories = 0, fetches = 0
    var fetched: [ContactRecordReference] = []
    var fetchedFields: Set<ContactField> = []
    var mode = "normal"
    var gate: ContactGate?
    init(count: Int = 2) throws {
        let account = try AccountReference(
            provider: ProviderID("synthetic"), store: StoreID("fixture"),
            account: AccountID("fixture"))
        selected = try ContactContainerReference(account: account, localID: DomainID("selected"))
        other = try ContactContainerReference(account: account, localID: DomainID("other"))
        memberships = [
            selected: try (0..<count).map { try ContactID("contact-\($0)") },
            other: [try ContactID("hidden")],
        ]
    }
    func configure(_ mode: String, gate: ContactGate? = nil) {
        self.mode = mode
        self.gate = gate
    }
    func setAccess(_ value: OSAuthorization) { access = value }
    func duplicateAcrossContainers() { memberships[other] = memberships[selected] }
    func authorization() -> OSAuthorization { access }
    func requestAccess() -> OSAuthorization {
        requests += 1
        access = .fullAccess
        return access
    }
    func generation() -> UInt64 { epoch }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func containers() -> [ContactContainer] {
        inventories += 1
        return [
            ContactContainer(id: selected, name: "Selected"),
            ContactContainer(id: other, name: "Other"),
        ]
    }
    func identifiers(
        in container: ContactContainerReference, limit: Int, check: @Sendable () throws -> Void
    ) throws -> ContactMembership {
        try check()
        let ids = memberships[container] ?? []
        return ContactMembership(ids: Array(ids.prefix(limit)), truncated: ids.count > limit)
    }
    func fetch(
        _ records: [ContactRecordReference], fields: Set<ContactField>,
        check: @Sendable () throws -> Void
    ) async throws -> [Contact] {
        try check()
        fetches += 1
        fetched = records
        fetchedFields = fields
        if let gate { await gate.enter() }
        if mode == "moved" { memberships[selected] = [] }
        if mode == "notification" { epoch += 1 }
        if mode == "revoked" { access = .denied }
        if mode == "unified" {
            return [
                try Contact(
                    id: .unified(
                        provider: ProviderID("synthetic"), store: StoreID("fixture"),
                        item: ContactID("contact-0")))
            ]
        }
        return records.map {
            Contact(
                id: .record($0),
                name: .value(ContactName(given: "Synthetic", family: $0.item.rawValue)))
        }
    }
}
@Test func contactsProviderDoesNotReadOrPromptWithoutIndependentAuthorization() async throws {
    let backend = try ContactBackendFixture()
    await backend.setAccess(.notDetermined)
    let provider = ContactsProvider(backend: backend)
    guard case .failed(.denied) = await provider.discoverContactContainers() else {
        Issue.record("Expected denial")
        return
    }
    #expect(await backend.requests == 0)
    #expect(await backend.inventories == 0)
    #expect(await provider.requestAccess() == .fullAccess)
    _ = await provider.discoverContactContainers()
    #expect(await backend.requests == 1)
    #expect(await backend.inventories == 1)
}
@Test func contactsProviderFetchesOnlySelectedUnderlyingIDsAndRequestedFields() async throws {
    let backend = try ContactBackendFixture()
    let provider = ContactsProvider(backend: backend)
    let id = try ContactID("contact-1")
    let request = try ContactReadRequest(scopes: [backend.selected: .records([id])])
    guard case .observed(let result) = await provider.readContacts(request, fields: [.name]) else {
        Issue.record("Expected scoped result")
        return
    }
    #expect(result.contacts.count == 1)
    #expect(
        await backend.fetched == [ContactRecordReference(container: backend.selected, item: id)])
    #expect(await backend.fetchedFields == [.name])
    #expect(result.observation.freshness == .localCache)
}
@Test func contactsProviderRejectsPostFetchMovesRevocationNotificationsAndUnifiedValues()
    async throws
{
    for mode in ["moved", "revoked", "notification", "unified"] {
        let backend = try ContactBackendFixture(count: 1)
        let provider = ContactsProvider(backend: backend)
        await backend.configure(mode)
        let request = try ContactReadRequest(scopes: [backend.selected: .allRecords])
        guard case .failed = await provider.readContacts(request, fields: [.name]) else {
            Issue.record("Expected rejection: \(mode)")
            continue
        }
        #expect(await backend.fetches == 1)
    }
}
@Test func contactsProviderRejectsAmbiguousMembershipBeforeFetchingFields() async throws {
    let backend = try ContactBackendFixture()
    let provider = ContactsProvider(backend: backend)
    await backend.duplicateAcrossContainers()
    let request = try ContactReadRequest(scopes: [
        backend.selected: .allRecords, backend.other: .allRecords,
    ])
    guard case .failed = await provider.readContacts(request, fields: [.name]) else {
        Issue.record("Expected ambiguity failure")
        return
    }
    #expect(await backend.fetches == 0)
}
@Test func contactsProviderLimitsArePartialAndMissingDetailNeverProvesDeletion() async throws {
    let backend = try ContactBackendFixture(count: 1001)
    let provider = ContactsProvider(backend: backend)
    let request = try ContactReadRequest(scopes: [backend.selected: .allRecords])
    guard case .observed(let result) = await provider.readContacts(request, fields: [.name]) else {
        Issue.record("Expected partial result")
        return
    }
    #expect(result.contacts.count == 1000)
    #expect(result.observation.completeness == .partial(.providerLimit))
    let detail = try ContactReadRequest(
        scopes: [backend.selected: .allRecords],
        item: ContactRecordReference(container: backend.selected, item: ContactID("absent")))
    guard case .observed(let missing) = await provider.readContacts(detail, fields: [.name]) else {
        Issue.record("Expected unknown empty result")
        return
    }
    #expect(missing.contacts.isEmpty && missing.observation.completeness == .unknown)
}
@Test func contactsProviderCancellationSuppressesLateFieldResults() async throws {
    let backend = try ContactBackendFixture()
    let provider = ContactsProvider(backend: backend)
    let gate = ContactGate()
    await backend.configure("normal", gate: gate)
    let request = try ContactReadRequest(scopes: [backend.selected: .allRecords])
    let task = Task { await provider.readContacts(request, fields: [.name]) }
    await gate.wait()
    task.cancel()
    await gate.release()
    guard case .failed(.cancelled) = await task.value else {
        Issue.record("Expected cancellation")
        return
    }
}
@Test func contactsFetchKeysAreMinimalUnificationOffAndNotesUnavailable() async throws {
    #expect(
        try Set(NativeContactsBackend.keys([.name])) == [
            CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey,
        ])
    let request = NativeContactsBackend.request(
        keys: try NativeContactsBackend.keys([.emailAddresses]))
    #expect(!request.unifyResults && !request.mutableObjects && request.sortOrder == .none)
    #expect(throws: (any Error).self) { try NativeContactsBackend.keys([.notes]) }
    #expect(NativeContactsBackend.mapAuthorization(.denied) == .denied)
    #expect(NativeContactsBackend.mapAuthorization(.authorized) == .fullAccess)
    let backend = try ContactBackendFixture()
    let provider = ContactsProvider(backend: backend)
    _ = await provider.readContacts(
        try ContactReadRequest(scopes: [backend.selected: .allRecords]), fields: [.notes])
    #expect(await backend.fetches == 0)
    #expect(await backend.inventories == 0)
}
@Test func contactsNormalizationTouchesOnlyFetchedFieldsAndBoundsSyntheticValues() throws {
    // In-memory public value only; no CNContactStore or personal data.
    let value = CNMutableContact()
    value.givenName = "Synthetic"
    value.familyName = "Contact"
    value.note = "hidden"
    value.emailAddresses = [
        CNLabeledValue(label: "sample", value: "synthetic@example.invalid" as NSString)
    ]
    let container = try ContactContainerReference(
        account: AccountReference(
            provider: ProviderID("synthetic"), store: StoreID("fixture"),
            account: AccountID("fixture")), localID: DomainID("selected"))
    let ref = try ContactRecordReference(container: container, item: ContactID(value.identifier))
    let contact = try NativeContactsBackend.normalize(value, reference: ref, fields: [.name])
    #expect(contact.name == .value(ContactName(given: "Synthetic", family: "Contact")))
    #expect(
        contact.emailAddresses == .notFetched && contact.notes == .notFetched
            && contact.linkedRecords == .notFetched && contact.revision == .unknown)
    value.givenName = String(repeating: "x", count: 4097)
    #expect(throws: (any Error).self) {
        try NativeContactsBackend.normalize(value, reference: ref, fields: [.name])
    }
}

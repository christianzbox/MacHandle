import CoreDomain
import Foundation
import Testing

@testable import MacHandleApplication

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
private actor ContactSource: ContactDiscovering, ContactReading {
    let container: ContactContainerReference
    let contact: Contact
    let ref: ContactRecordReference
    var access: OSAuthorization = .notDetermined
    var requests = 0
    var discoveries = 0
    var reads = 0
    var fields: Set<ContactField> = []
    var cancelled = false
    var requestGate: ContactGate?
    var readGate: ContactGate?
    init() throws {
        container = try ContactContainerReference(
            account: AccountReference(
                provider: ProviderID("synthetic"), store: StoreID("store"),
                account: AccountID("account")), localID: DomainID("container"))
        ref = try ContactRecordReference(container: container, item: ContactID("item"))
        contact = Contact(
            id: .record(ref), name: .value(ContactName(given: "Synthetic", family: "Contact")),
            emailAddresses: .value([
                LabeledValue(label: "Sample", value: "synthetic@example.invalid")
            ]), notes: .value("hidden notes"))
    }
    func configure(
        access: OSAuthorization = .fullAccess, request: ContactGate? = nil,
        read: ContactGate? = nil
    ) {
        self.access = access
        requestGate = request
        readGate = read
    }
    func authorization() -> OSAuthorization { access }
    func requestAccess() async -> OSAuthorization {
        requests += 1
        if let requestGate { await requestGate.enter() }
        access = .fullAccess
        return access
    }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverContactContainers() -> ProviderReadResult<ResourceDiscovery<ContactContainer>> {
        discoveries += 1
        return .observed(
            ResourceDiscovery(
                resources: [ContactContainer(id: container, name: "Synthetic container")],
                observation: observation()))
    }
    private func observation() -> ObservationState {
        ObservationState(
            observedAt: try! Instant(Date()), completeness: .complete, freshness: .localCache)
    }
    func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>) async
        -> ProviderReadResult<ContactSnapshot>
    {
        reads += 1
        self.fields = fields
        if let readGate { await readGate.enter() }
        cancelled = Task.isCancelled
        return .observed(
            try! ContactSnapshot(
                coverage: request, contacts: [contact], observation: observation()))
    }
}
@MainActor struct ContactsStoreTests {
    @Test func disabledAndRefreshNeverRequestPermissionOrReadData() async throws {
        let source = try ContactSource()
        let store = ContactsStore(provider: source)
        await store.refresh()
        await store.search()
        #expect(await source.requests == 0)
        #expect(await source.discoveries == 0)
        #expect(await source.reads == 0)
        #expect(!store.isEnabled && store.selection.isEmpty)
    }
    @Test func optInDoesNotSelectContainersAndSearchFetchesNamesOnly() async throws {
        let source = try ContactSource()
        let store = ContactsStore(provider: source)
        await store.enable()
        #expect(await source.requests == 1)
        #expect(store.selection.isEmpty)
        await store.search()
        #expect(await source.reads == 0)
        store.select(source.container, selected: true)
        await store.search()
        #expect(store.results.count == 1)
        #expect(await !source.fields.contains(.notes))
        #expect(store.results.first?.notes != .value("hidden notes"))
        #expect(await source.fields == [.name])
    }
    @Test func emailRequiresExplicitDetailChoice() async throws {
        let source = try ContactSource()
        let store = ContactsStore(provider: source)
        await store.enable()
        store.select(source.container, selected: true)
        await store.search()
        await store.showDetails(source.ref)
        #expect(store.detail?.notes != .value("hidden notes"))
        store.setField(.emailAddresses, enabled: true)
        await store.search()
        await store.showDetails(source.ref)
        #expect(
            store.detail?.emailAddresses
                == .value([LabeledValue(label: "Sample", value: "synthetic@example.invalid")]))
        #expect(store.detail?.notes != .value("hidden notes"))
        #expect(await source.fields == [.name, .emailAddresses])
    }
    @Test func disablingDuringPermissionPromptDiscardsGrantAndPreventsDiscovery() async throws {
        let source = try ContactSource()
        let gate = ContactGate()
        await source.configure(access: .notDetermined, request: gate)
        let store = ContactsStore(provider: source)
        let task = Task { await store.enable() }
        await gate.wait()
        store.disable()
        await gate.release()
        await task.value
        #expect(await source.requests == 1)
        #expect(await source.discoveries == 0)
        #expect(!store.isEnabled && store.containers.isEmpty)
    }
    @Test func selectionOrQueryInvalidationCancelsAndSuppressesLateResults() async throws {
        let source = try ContactSource()
        let store = ContactsStore(provider: source)
        await store.enable()
        store.select(source.container, selected: true)
        let gate = ContactGate()
        await source.configure(read: gate)
        let task = Task { await store.search() }
        await gate.wait()
        store.query = "different"
        await gate.release()
        await task.value
        #expect(store.results.isEmpty)
        #expect(await source.cancelled)
    }
    @Test func revocationClearsPreviouslyDisplayedContent() async throws {
        let source = try ContactSource()
        let store = ContactsStore(provider: source)
        await store.enable()
        store.select(source.container, selected: true)
        await store.search()
        #expect(!store.results.isEmpty)
        await source.configure(access: .denied)
        await store.showDetails(source.ref)
        #expect(store.results.isEmpty && store.detail == nil && store.selection.isEmpty)
    }
}

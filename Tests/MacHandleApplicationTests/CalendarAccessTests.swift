import CoreDomain
import MacHandleApplication
import Observation
import Testing

actor CalendarProviderStub: CalendarDiscovering {
    enum Pause { case authorization, request, discovery }
    var status: OSAuthorization = .notDetermined
    var requestedStatus: OSAuthorization = .fullAccess
    var result: CalendarDiscoveryResult = .unavailable
    var authorizationCalls = 0
    var requestCalls = 0
    var discoveryCalls = 0
    private var pause: Pause?
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func configure(status: OSAuthorization, result: CalendarDiscoveryResult, pause: Pause? = nil) {
        self.status = status
        self.result = result
        self.pause = pause
    }
    func respondToRequest(with status: OSAuthorization) { requestedStatus = status }

    func authorization() async -> OSAuthorization {
        authorizationCalls += 1
        let value = status
        await suspend(at: .authorization)
        return value
    }
    func requestAccess() async -> OSAuthorization {
        requestCalls += 1
        await suspend(at: .request)
        status = requestedStatus
        return status
    }
    func discover() async -> CalendarDiscoveryResult {
        discoveryCalls += 1
        let value = result
        await suspend(at: .discovery)
        return value
    }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func waitUntilSuspended() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
    private func suspend(at point: Pause) async {
        guard pause == point else { return }
        pause = nil
        started = true
        startWaiter?.resume()
        startWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }
}

private func inventory(_ ids: [String] = ["one", "two"], store: String = "synthetic-store") throws
    -> CalendarCatalog
{
    let account = try AccountReference(
        provider: ProviderID("synthetic"), store: StoreID(store),
        account: AccountID("sample-account"))
    return try CalendarCatalog(
        accounts: [CalendarAccount(id: account, name: "Sample account")],
        calendars: ids.map {
            CalendarResource(
                id: try CalendarReference(account: account, localID: DomainID($0)),
                name: "Sample calendar")
        })
}

@Test @MainActor func calendarStartupAndDisabledRefreshDoNotTouchProvider() async {
    let provider = CalendarProviderStub()
    let store = CalendarAccessStore(provider: provider)
    await store.refresh()
    #expect(store.state == .disabled)
    #expect(!store.isEnabled)
    #expect(store.selectedCalendars.isEmpty)
    #expect(await provider.authorizationCalls == 0)
    #expect(await provider.requestCalls == 0)
    #expect(await provider.discoveryCalls == 0)
}

@Test @MainActor func calendarOptInRequestsOnlyWhenNeeded() async throws {
    let catalog = try inventory()
    for status in [OSAuthorization.notDetermined, .writeOnly, .fullAccess] {
        let provider = CalendarProviderStub()
        await provider.configure(status: status, result: .available(catalog))
        let store = CalendarAccessStore(provider: provider)
        await store.enable()
        #expect(store.state == .ready(catalog))
        #expect(store.selectedCalendars.isEmpty)
        #expect(await provider.requestCalls == (status == .fullAccess ? 0 : 1))
        await store.refresh()
        #expect(await provider.requestCalls == (status == .fullAccess ? 0 : 1))
    }
}

@Test @MainActor func calendarDeniedRestrictedAndUnknownFailClosedWithoutPrompting() async {
    for status in [OSAuthorization.denied, .restricted, .unsupported, .unknown] {
        let provider = CalendarProviderStub()
        await provider.configure(status: status, result: .unavailable)
        let store = CalendarAccessStore(provider: provider)
        await store.enable()
        #expect(store.state == .access(status))
        #expect(await provider.requestCalls == 0)
        #expect(await provider.discoveryCalls == 0)
    }
}

@Test func calendarInventoryRejectsAmbiguousOrForeignIdentities() throws {
    let catalog = try inventory()
    #expect(throws: CalendarDiscoveryError.self) {
        try CalendarCatalog(accounts: catalog.accounts + catalog.accounts, calendars: [])
    }
    #expect(throws: CalendarDiscoveryError.self) {
        try CalendarCatalog(
            accounts: catalog.accounts, calendars: catalog.calendars + catalog.calendars)
    }
    #expect(throws: CalendarDiscoveryError.self) {
        try CalendarCatalog(
            accounts: catalog.accounts, calendars: inventory(store: "another-store").calendars)
    }
    #expect(catalog.calendars[0].id != catalog.calendars[1].id)
    #expect(catalog.calendars[0].name == catalog.calendars[1].name)
}

@Test @MainActor func calendarSelectionIsExplicitAndScopedToCurrentInventory() async throws {
    let provider = CalendarProviderStub()
    let catalog = try inventory()
    await provider.configure(status: .fullAccess, result: .available(catalog))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    let selected = catalog.calendars[0].id
    store.setSelected(selected, selected: true)
    store.setSelected(try inventory(store: "other-store").calendars[0].id, selected: true)
    #expect(store.selectedCalendars == [selected])
    await provider.configure(status: .fullAccess, result: .available(try inventory(["two"])))
    await store.refresh()
    #expect(store.selectedCalendars.isEmpty)
    store.setSelected(selected, selected: true)
    #expect(store.selectedCalendars.isEmpty)
}

@Test @MainActor func calendarRefreshPreservesOnlyMatchingIdentityAndClearsUncertainResults()
    async throws
{
    let provider = CalendarProviderStub()
    let catalog = try inventory()
    await provider.configure(status: .fullAccess, result: .available(catalog))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    let id = catalog.calendars[0].id
    store.setSelected(id, selected: true)
    await store.refresh()
    #expect(store.selectedCalendars == [id])
    for result in [
        CalendarDiscoveryResult.incomplete, .unavailable, .access(.denied), .access(.writeOnly),
    ] {
        await provider.configure(status: .fullAccess, result: result)
        await store.refresh()
        #expect(store.selectedCalendars.isEmpty)
        #expect(store.state != .ready(catalog))
        await provider.configure(status: .fullAccess, result: .available(catalog))
        await store.refresh()
        #expect(store.selectedCalendars.isEmpty)
        store.setSelected(id, selected: true)
    }
}

@Test @MainActor func calendarRevocationStopsDiscoveryAndClearsNamesAndSelection() async throws {
    let provider = CalendarProviderStub()
    let catalog = try inventory()
    await provider.configure(status: .fullAccess, result: .available(catalog))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    store.setSelected(catalog.calendars[0].id, selected: true)
    await provider.configure(status: .denied, result: .available(catalog))
    await store.refresh()
    #expect(store.state == .access(.denied))
    #expect(store.selectedCalendars.isEmpty)
    #expect(await provider.discoveryCalls == 1)
    #expect(await provider.requestCalls == 0)
}

@Test @MainActor func calendarDisableDuringAuthorizationPreventsLatePrompt() async {
    let provider = CalendarProviderStub()
    await provider.configure(status: .notDetermined, result: .unavailable, pause: .authorization)
    let store = CalendarAccessStore(provider: provider)
    let pending = Task { await store.enable() }
    await provider.waitUntilSuspended()
    store.disable()
    await provider.release()
    await pending.value
    #expect(store.state == .disabled)
    #expect(await provider.requestCalls == 0)
    #expect(await provider.discoveryCalls == 0)
}

@Test @MainActor func calendarDisableDuringPromptDiscardsLateGrantAndDoesNotDiscover() async throws
{
    let provider = CalendarProviderStub()
    await provider.configure(
        status: .notDetermined, result: .available(try inventory()), pause: .request)
    let store = CalendarAccessStore(provider: provider)
    let pending = Task { await store.enable() }
    await provider.waitUntilSuspended()
    store.disable()
    await store.enable()  // A second prompt cannot overlap the first.
    #expect(await provider.requestCalls == 1)
    await provider.release()
    await pending.value
    #expect(store.state == .disabled)
    #expect(!store.isBusy)
    #expect(await provider.discoveryCalls == 0)
}

@Test @MainActor func calendarDisableDuringDiscoveryDiscardsLateNames() async throws {
    let provider = CalendarProviderStub()
    await provider.configure(
        status: .fullAccess, result: .available(try inventory()), pause: .discovery)
    let store = CalendarAccessStore(provider: provider)
    let pending = Task { await store.enable() }
    await provider.waitUntilSuspended()
    store.disable()
    await provider.release()
    await pending.value
    #expect(store.state == .disabled)
    #expect(store.selectedCalendars.isEmpty)
}

@Test @MainActor func calendarChangeDuringReadDiscardsStaleInventoryAndReloads() async throws {
    let provider = CalendarProviderStub()
    let old = try inventory()
    await provider.configure(status: .fullAccess, result: .available(old))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    store.setSelected(old.calendars[0].id, selected: true)
    await provider.configure(status: .fullAccess, result: .available(old), pause: .discovery)
    let pending = Task { await store.refresh() }
    await provider.waitUntilSuspended()
    #expect(store.selectedCalendars.isEmpty)
    await provider.configure(status: .denied, result: .unavailable)
    await store.refresh()
    await store.refresh()  // Coalesce repeat notifications.
    await provider.release()
    await pending.value
    #expect(store.state == .access(.denied))
    #expect(store.selectedCalendars.isEmpty)
    #expect(await provider.authorizationCalls == 3)
}

@Test @MainActor func calendarEmptyLocalInventoryAndNewSessionDoNotGrantAccess() async throws {
    let provider = CalendarProviderStub()
    let catalog = try inventory([])
    await provider.configure(status: .fullAccess, result: .available(catalog))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    #expect(store.state == .ready(catalog))
    #expect(store.selectedCalendars.isEmpty)
    let fresh = CalendarAccessStore(provider: provider)
    #expect(fresh.state == .disabled)
    #expect(await provider.discoveryCalls == 1)
}

@Test @MainActor func calendarPermissionRefusalNeverStartsMetadataDiscovery() async {
    let provider = CalendarProviderStub()
    await provider.respondToRequest(with: .denied)
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    #expect(store.state == .access(.denied))
    #expect(await provider.requestCalls == 1)
    #expect(await provider.discoveryCalls == 0)
}

@Test @MainActor func calendarCanceledDiscoveryCannotPublishLateNamesOrSelection() async throws {
    let provider = CalendarProviderStub()
    await provider.configure(
        status: .fullAccess, result: .available(try inventory()), pause: .discovery)
    let store = CalendarAccessStore(provider: provider)
    let pending = Task { await store.enable() }
    await provider.waitUntilSuspended()
    pending.cancel()
    await provider.release()
    await pending.value
    #expect(store.state == .unavailable)
    #expect(store.selectedCalendars.isEmpty)
    #expect(!store.isBusy)
}

@Test @MainActor func calendarSelectionChangesNotifyTheRenderedSelectionCount() async throws {
    let provider = CalendarProviderStub()
    let catalog = try inventory()
    await provider.configure(status: .fullAccess, result: .available(catalog))
    let store = CalendarAccessStore(provider: provider)
    await store.enable()
    await confirmation("Selection invalidates observation", expectedCount: 1) { changed in
        withObservationTracking {
            _ = store.selectedCalendars
        } onChange: {
            changed()
        }
        store.setSelected(catalog.calendars[0].id, selected: true)
    }
}

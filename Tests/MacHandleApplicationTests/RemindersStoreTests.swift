import CoreDomain
import Foundation
import Testing

@testable import MacHandleApplication

private actor ReminderGate {
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
private actor ReminderSource: ReminderDiscovering, ReminderReading {
    let list: ReminderListReference
    let reminder: Reminder
    var access: OSAuthorization = .notDetermined
    var requests = 0
    var discoveries = 0
    var reads = 0
    var fields: Set<ReminderReadField> = []
    var cancelled = false
    var requestGate: ReminderGate?
    var readGate: ReminderGate?
    init() throws {
        list = try ReminderListReference(
            account: AccountReference(
                provider: ProviderID("synthetic"), store: StoreID("store"),
                account: AccountID("account")), localID: DomainID("list"))
        reminder = try Reminder(
            id: ReminderReference(list: list, item: ReminderID("item")),
            title: .value("Synthetic task"), notes: .value("hidden notes"), due: .value(nil),
            completion: .value(.incomplete), recurrence: .value(.recurring))
    }
    func configure(
        access: OSAuthorization = .fullAccess, request: ReminderGate? = nil,
        read: ReminderGate? = nil
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
    func discoverReminderLists() -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        discoveries += 1
        return .observed(
            ResourceDiscovery(
                resources: [ReminderList(id: list, name: "Synthetic list")],
                observation: observation()))
    }
    private func observation() -> ObservationState {
        ObservationState(
            observedAt: try! Instant(Date()), completeness: .complete, freshness: .localCache)
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        reads += 1
        self.fields = fields
        if let readGate { await readGate.enter() }
        cancelled = Task.isCancelled
        return .observed(
            try! ReminderSnapshot(
                coverage: request, reminders: [reminder], observation: observation()))
    }
}
@MainActor struct RemindersStoreTests {
    @Test func disabledAndRefreshNeverRequestPermissionOrReadData() async throws {
        let source = try ReminderSource()
        let store = RemindersStore(provider: source)
        await store.refresh()
        await store.search()
        #expect(await source.requests == 0)
        #expect(await source.discoveries == 0)
        #expect(await source.reads == 0)
        #expect(!store.isEnabled && store.selection.isEmpty)
    }
    @Test func optInDoesNotSelectListsAndSearchDoesNotFetchNotes() async throws {
        let source = try ReminderSource()
        let store = RemindersStore(provider: source)
        await store.enable()
        #expect(await source.requests == 1)
        #expect(store.selection.isEmpty)
        await store.search()
        #expect(await source.reads == 0)
        store.select(source.list, selected: true)
        await store.search()
        #expect(store.results.count == 1)
        #expect(await !source.fields.contains(.notes))
        #expect(store.results.first?.notes != .value("hidden notes"))
        #expect(store.results.first?.recurrence == .value(.recurring))
    }
    @Test func notesRequireExplicitDetailChoice() async throws {
        let source = try ReminderSource()
        let store = RemindersStore(provider: source)
        await store.enable()
        store.select(source.list, selected: true)
        await store.search()
        await store.showDetails(source.reminder.id)
        #expect(store.detail?.notes != .value("hidden notes"))
        store.includeNotes = true
        await store.search()
        await store.showDetails(source.reminder.id)
        #expect(store.detail?.notes == .value("hidden notes"))
        #expect(await source.fields.contains(.notes))
    }
    @Test func disablingDuringPermissionPromptDiscardsGrantAndPreventsDiscovery() async throws {
        let source = try ReminderSource()
        let gate = ReminderGate()
        await source.configure(access: .notDetermined, request: gate)
        let store = RemindersStore(provider: source)
        let task = Task { await store.enable() }
        await gate.wait()
        store.disable()
        await gate.release()
        await task.value
        #expect(await source.requests == 1)
        #expect(await source.discoveries == 0)
        #expect(!store.isEnabled && store.lists.isEmpty)
    }
    @Test func selectionOrQueryInvalidationCancelsAndSuppressesLateResults() async throws {
        let source = try ReminderSource()
        let store = RemindersStore(provider: source)
        await store.enable()
        store.select(source.list, selected: true)
        let gate = ReminderGate()
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
        let source = try ReminderSource()
        let store = RemindersStore(provider: source)
        await store.enable()
        store.select(source.list, selected: true)
        await store.search()
        #expect(!store.results.isEmpty)
        await source.configure(access: .denied)
        await store.showDetails(source.reminder.id)
        #expect(store.results.isEmpty && store.detail == nil && store.selection.isEmpty)
    }
}

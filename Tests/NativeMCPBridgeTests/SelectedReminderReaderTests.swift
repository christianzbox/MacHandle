import CoreDomain
import MCPRemindersAdapter
import Testing

@testable import NativeMCPBridge

private actor ScopedSource: ReminderDiscovering, ReminderReading {
    let fixture: SyntheticReminderSource
    var access: OSAuthorization = .fullAccess
    var reads = 0
    var requests = 0
    var revokeDuringRead = false
    init() throws { fixture = try SyntheticReminderSource() }
    func revokeOnRead() { revokeDuringRead = true }
    func authorization() -> OSAuthorization { access }
    func requestAccess() -> OSAuthorization {
        requests += 1
        return access
    }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverReminderLists() -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        fixture.discoverReminderLists()
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>)
        -> ProviderReadResult<ReminderSnapshot>
    {
        reads += 1
        if revokeDuringRead { access = .denied }
        return fixture.readReminders(request, fields: fields)
    }
}

@Test func selectedReaderDeniesForeignListsAndHiddenFieldsBeforeProviderReads() async throws {
    let fixture = try SyntheticReminderSource()
    let source = try ScopedSource()
    let reader = SelectedReminderReader(
        source: source,
        selection: try PrivateReminderSelection(lists: [fixture.list], fields: [.title]))
    guard case .observed(let inventory) = await reader.discoverReminderLists() else {
        Issue.record("Discovery failed")
        return
    }
    #expect(inventory.resources.map(\.id) == [fixture.list])
    let hidden = try #require(
        fixture.discoverReminderLists().resourcesForTest?.first(where: { $0.id != fixture.list }))
    for (lists, fields) in [
        (Set([hidden.id]), Set([ReminderReadField.title])),
        (Set([fixture.list]), Set([ReminderReadField.notes])),
    ] {
        let result = await reader.readReminders(
            try ReminderReadRequest(lists: lists), fields: fields)
        guard case .failed = result else {
            Issue.record("Ungrantable read allowed")
            return
        }
    }
    #expect(await source.reads == 0)
    _ = await reader.requestAccess()
    #expect(await source.requests == 0)
}

@Test func permissionRevokedDuringReadDiscardsTheProviderResult() async throws {
    let fixture = try SyntheticReminderSource()
    let source = try ScopedSource()
    let reader = SelectedReminderReader(
        source: source,
        selection: try PrivateReminderSelection(lists: [fixture.list], fields: [.title]))
    await source.revokeOnRead()
    let result = await reader.readReminders(
        try ReminderReadRequest(lists: [fixture.list]), fields: [.title])
    guard case .failed = result else {
        Issue.record("Late result leaked after permission loss")
        return
    }
    #expect(await source.reads == 1)
}

extension ProviderReadResult where Value == ResourceDiscovery<ReminderList> {
    fileprivate var resourcesForTest: [ReminderList]? {
        if case .observed(let value) = self { return value.resources }
        return nil
    }
}

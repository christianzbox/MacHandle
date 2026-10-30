import CoreDomain
import Foundation
import MacHandleApplication
import PermissionEngine
import Testing

private actor ReadFixture: CalendarReading, CalendarDiscovering {
    let catalog: CalendarCatalog
    var status: OSAuthorization = .fullAccess
    private var authorizationChecks = 0
    private var denyOnCheck: Int?
    var requestedFields: Set<CalendarDetailField> = []
    var reads = 0
    var completeness: ReadCompleteness = .complete
    var failure: ProviderFailure?
    var wrongScope = false
    var suspended = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var hasStarted = false
    init() throws {
        let account = try AccountReference(
            provider: ProviderID("synthetic"), store: StoreID("store"),
            account: AccountID("account"))
        catalog = try CalendarCatalog(
            accounts: [CalendarAccount(id: account, name: "Sample")],
            calendars: [
                CalendarResource(
                    id: CalendarReference(account: account, localID: DomainID("calendar")),
                    name: "Sample calendar")
            ])
    }
    func authorization() -> OSAuthorization {
        authorizationChecks += 1
        if let denyOnCheck, authorizationChecks >= denyOnCheck { return .denied }
        return status
    }
    func denyOnThirdCheck() {
        authorizationChecks = 0
        denyOnCheck = 3
    }
    func requestAccess() -> OSAuthorization { .denied }
    func discover() -> CalendarDiscoveryResult { .available(catalog) }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverCalendars() -> ProviderReadResult<ResourceDiscovery<CalendarResource>> {
        .failed(.unsupported)
    }
    func configure(
        status: OSAuthorization = .fullAccess, suspended: Bool = false,
        failure: ProviderFailure? = nil, completeness: ReadCompleteness = .complete,
        wrongScope: Bool = false
    ) {
        self.status = status
        self.suspended = suspended
        self.failure = failure
        self.completeness = completeness
        self.wrongScope = wrongScope
    }
    func waitForRead() async {
        if hasStarted { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() {
        waiting?.resume()
        waiting = nil
    }
    func readOccurrences(_ request: CalendarReadRequest, fields: Set<CalendarDetailField>) async
        -> ProviderReadResult<CalendarSnapshot>
    {
        reads += 1
        requestedFields = fields
        hasStarted = true
        started?.resume()
        started = nil
        if suspended { await withCheckedContinuation { waiting = $0 } }
        if let failure { return .failed(failure) }
        do {
            let coverage =
                wrongScope
                ? try CalendarReadRequest(
                    calendars: request.calendars,
                    window: InstantInterval(
                        start: request.window.start,
                        end: Instant(request.window.end.date.addingTimeInterval(3600)))) : request
            let event = try CalendarOccurrence(
                id: OccurrenceReference(
                    calendar: catalog.calendars[0].id, item: EventID("synthetic-event"),
                    originalAnchor: .notRecurring),
                time: .timed(request.window, timeZone: TimeZoneID("UTC")), occupancy: .busy,
                status: .active,
                title: .value("Synthetic secret title"),
                location: .value("Synthetic secret location"),
                notes: .value("Synthetic secret notes"))
            // Deliberately over-return details to exercise trusted response projection.
            return .observed(
                try CalendarSnapshot(
                    coverage: coverage, occurrences: [event],
                    observation: ObservationState(
                        observedAt: Instant(Date()), completeness: completeness,
                        freshness: .localCache)))
        } catch { return .failed(.invalidData) }
    }
}

@MainActor private func prepared() async throws -> (
    ReadFixture, CalendarAccessStore, CalendarReadStore
) {
    let fixture = try ReadFixture()
    let access = CalendarAccessStore(provider: fixture)
    let store = CalendarReadStore(
        access: access, reader: fixture, authorization: fixture, authority: PolicyAuthority(),
        now: Date(timeIntervalSince1970: 0))
    await access.enable()
    access.setSelected(fixture.catalog.calendars[0].id, selected: true)
    return (fixture, access, store)
}

@Test @MainActor func localReadDefaultsToAvailabilityAndNeverReadsWithoutSelection() async throws {
    let (fixture, access, store) = try await prepared()
    #expect(await fixture.reads == 0)
    access.disable()
    await store.read()
    #expect(await fixture.reads == 0)
    #expect(store.mode == .availability)
    guard case .denied = store.result else {
        Issue.record("Expected default-deny")
        return
    }
}

@Test @MainActor func localAvailabilityUsesNoDetailFieldsAndKeepsPartialObservation() async throws {
    let (fixture, _, store) = try await prepared()
    await fixture.configure(completeness: .partial(.providerLimit))
    await store.read()
    #expect(await fixture.requestedFields.isEmpty)
    guard case .availability(let value) = store.result else {
        Issue.record("Expected privacy projection")
        return
    }
    #expect(value.blocks.count == 1)
    #expect(value.observation.completeness == .partial(.providerLimit))
    #expect(value.observation.freshness == .localCache)
}

@Test @MainActor func localTitleReadStripsOverreturnedLocationsAndNotes() async throws {
    let (fixture, _, store) = try await prepared()
    store.mode = .titles
    await store.read()
    #expect(await fixture.requestedFields == [.title])
    guard case .events(let value) = store.result else {
        Issue.record("Expected event result")
        return
    }
    #expect(value.occurrences[0].title == .value("Synthetic secret title"))
    #expect(value.occurrences[0].location == .notAuthorized)
    #expect(value.occurrences[0].notes == .notAuthorized)
    store.mode = .availability
    #expect(store.result == nil)
}

@Test @MainActor func localReadRejectsDeniedPermissionAndInvalidRangesBeforeProvider() async throws
{
    let (fixture, _, store) = try await prepared()
    await fixture.configure(status: .denied)
    await store.read()
    #expect(await fixture.reads == 0)
    await fixture.configure()
    store.endDate = store.startDate
    await store.read()
    #expect(await fixture.reads == 0)
    store.endDate = store.startDate.addingTimeInterval(CalendarReadLimits.maximumDuration + 1)
    await store.read()
    #expect(await fixture.reads == 0)
}

@Test @MainActor func localReadDropsLateResultsAfterDisableOrSelectionRemoval() async throws {
    for disable in [true, false] {
        let (fixture, access, store) = try await prepared()
        await fixture.configure(suspended: true)
        let pending = Task { await store.read() }
        await fixture.waitForRead()
        if disable {
            access.disable()
        } else {
            access.setSelected(fixture.catalog.calendars[0].id, selected: false)
        }
        await fixture.release()
        await pending.value
        #expect(store.result == nil)
        #expect(!store.isBusy)
    }
}

@Test @MainActor func localReadDropsLateResultsAfterModeWindowClearOrCancellation() async throws {
    for change in 0..<4 {
        let (fixture, _, store) = try await prepared()
        await fixture.configure(suspended: true)
        let pending = Task { await store.read() }
        await fixture.waitForRead()
        switch change {
        case 0: store.mode = .details
        case 1: store.endDate = store.endDate.addingTimeInterval(60)
        case 2: store.clear()
        default: pending.cancel()
        }
        await fixture.release()
        await pending.value
        #expect(store.result == nil)
    }
}

@Test @MainActor func localReadRechecksOSAfterProviderSuspension() async throws {
    let (fixture, _, store) = try await prepared()
    await fixture.configure(suspended: true)
    let pending = Task { await store.read() }
    await fixture.waitForRead()
    await fixture.configure(status: .denied)
    await fixture.release()
    await pending.value
    guard case .denied = store.result else {
        Issue.record("Revoked read escaped")
        return
    }
}

@Test @MainActor func localReadRejectsScopeMismatchAndPreservesSanitizedFailure() async throws {
    let (fixture, _, store) = try await prepared()
    await fixture.configure(wrongScope: true)
    await store.read()
    guard case .failed(.invalidData) = store.result else {
        Issue.record("Wrong coverage accepted")
        return
    }
    await fixture.configure(failure: .unavailable)
    await store.read()
    guard case .failed(.unavailable) = store.result else {
        Issue.record("Failure became empty")
        return
    }
}

@Test @MainActor func localReadClearsAlreadyDisplayedContentOnRefreshAndPreventsOverlap()
    async throws
{
    let (fixture, access, store) = try await prepared()
    store.mode = .details
    await store.read()
    guard case .events = store.result else {
        Issue.record("Expected initial content")
        return
    }
    await access.refresh()
    #expect(store.result == nil)
    await fixture.configure(suspended: true)
    let pending = Task { await store.read() }
    // Prior read set the fixture signal; yield until the second read reaches suspension.
    while await fixture.reads < 2 { await Task.yield() }
    await store.read()
    #expect(await fixture.reads == 2)
    await fixture.release()
    await pending.value
}

@Test @MainActor func localReadChecksPermissionAgainImmediatelyBeforePublishing() async throws {
    let (fixture, _, store) = try await prepared()
    await fixture.denyOnThirdCheck()
    await store.read()
    guard case .denied = store.result else {
        Issue.record("Late OS revocation escaped the final check")
        return
    }
}

@Test @MainActor func localReadPolicyNeverGrantsMutations() async throws {
    let fixture = try ReadFixture()
    let access = CalendarAccessStore(provider: fixture)
    let authority = PolicyAuthority()
    let store = CalendarReadStore(
        access: access, reader: fixture, authorization: fixture, authority: authority)
    await access.enable()
    access.setSelected(fixture.catalog.calendars[0].id, selected: true)
    store.mode = .details
    await store.read()
    let id = try ConnectionID("trusted-local-calendar-reader")
    let session = try await authority.bindTrustedConnection(id)
    let interval = try InstantInterval(
        start: Instant(Date(timeIntervalSince1970: 0)),
        end: Instant(Date(timeIntervalSince1970: 3600)))
    let draft = try EventDraft(
        title: "Synthetic", time: .timed(interval, timeZone: TimeZoneID("UTC")), occupancy: .busy)
    let proposal = try ProposedChange(
        id: OperationID("synthetic-write"), connection: id,
        change: CalendarMutation.create(in: fixture.catalog.calendars[0].id, event: draft))
    guard case .denied(.operationNotAllowed) = await session.evaluate(.calendarMutation(proposal))
    else {
        Issue.record("Local read enabled a mutation")
        return
    }
}

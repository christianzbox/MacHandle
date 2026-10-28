import CoreDomain
import Foundation
import MCPConnections
import MCPServer
import PermissionEngine

/// Only package-visible executable composition. No production provider or caller-selected identity.
package enum SyntheticCalendarTools {
    package static func make() async throws -> [MCPTool] {
        let source = try SyntheticCalendarSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(calendars: .fullAccess))
        let grant = try SavedCalendarGrant(
            reference: source.calendar,
            operations: [.discover, .availability, .summary, .details],
            fields: [.time, .occupancy, .status, .title, .location])
        let record = try await controller.configure(
            label: "Synthetic MCP read fixture", grants: [grant])
        // Explicit fixture-only approval. This callback is not a live peer verifier.
        let channel = ConnectionChannel(verify: { true })
        let request = try await controller.requestPairing(channel)
        let review = try await controller.review(request, connection: record.id)
        let lease = try await controller.approve(review)
        let adapter = try CalendarReadAdapter(
            session: lease.session, reader: source,
            selected: lease.selection, authorization: { .fullAccess }, lease: lease)
        return adapter.tools()
    }
}

/// Fixed, memory-only fixture; hidden fields intentionally over-return to exercise projection.
struct SyntheticCalendarSource: CalendarReading {
    let calendar: CalendarReference
    let hidden: CalendarReference
    let occurrence: CalendarOccurrence
    let observation: ObservationState
    init() throws {
        let account = AccountReference(
            provider: try ProviderID("synthetic-provider-private"),
            store: try StoreID("synthetic-store-private"),
            account: try AccountID("synthetic-account-private"))
        calendar = CalendarReference(
            account: account, localID: try DomainID("synthetic-calendar-private"))
        hidden = CalendarReference(
            account: account, localID: try DomainID("synthetic-unselected-private"))
        let start = try Instant(Date(timeIntervalSince1970: 1_800_000_000))
        occurrence = CalendarOccurrence(
            id: OccurrenceReference(
                calendar: calendar, item: try EventID("synthetic-item-private"),
                originalAnchor: .notRecurring),
            seriesID: try EventID("synthetic-series-private"),
            time: .timed(
                try InstantInterval(
                    start: start, end: Instant(start.date.addingTimeInterval(3600))),
                timeZone: try TimeZoneID("UTC")),
            occupancy: .busy, status: .active, title: .value("Synthetic planning session"),
            location: .value("Synthetic meeting room"),
            notes: .value("synthetic-hidden-note-canary"),
            revision: .revision(try ObservedRevision("synthetic-revision-private")))
        observation = ObservationState(
            observedAt: start, completeness: .complete, freshness: .localCache)
    }
    func discoverCalendars() async -> ProviderReadResult<ResourceDiscovery<CalendarResource>> {
        .observed(
            ResourceDiscovery(
                resources: [
                    CalendarResource(id: calendar, name: "Synthetic selected calendar"),
                    CalendarResource(id: hidden, name: "Synthetic hidden calendar"),
                ], observation: observation))
    }
    func readOccurrences(_ request: CalendarReadRequest, fields: Set<CalendarDetailField>) async
        -> ProviderReadResult<CalendarSnapshot>
    {
        do {
            let interval = try CalendarTimeResolution.interval(for: occurrence.time)
            let items =
                request.calendars.contains(calendar)
                    && interval.overlaps(
                        request.window)
                ? [occurrence] : []
            return .observed(
                try CalendarSnapshot(
                    coverage: request, occurrences: items, observation: observation))
        } catch { return .failed(.invalidData) }
    }
}

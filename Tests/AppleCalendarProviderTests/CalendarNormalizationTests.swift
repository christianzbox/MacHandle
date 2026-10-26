import CoreDomain
import Foundation
import Testing

@testable import AppleCalendarProvider

private func reference(_ id: String = "calendar", store: String = "store") throws
    -> CalendarReference
{
    try CalendarReference(
        account: AccountReference(
            provider: ProviderID("synthetic"), store: StoreID(store), account: AccountID("account")),
        localID: DomainID(id))
}
private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
private func request(
    _ start: Date = Date(timeIntervalSince1970: 0), _ end: Date = Date(timeIntervalSince1970: 3600)
) throws -> CalendarReadRequest {
    try CalendarReadRequest(
        calendars: [reference()], window: InstantInterval(start: Instant(start), end: Instant(end)))
}
private func record(
    start: Date = Date(timeIntervalSince1970: 0), end: Date = Date(timeIntervalSince1970: 3600),
    allDay: Bool = false,
    zone: String = "UTC", original: Date? = nil, recurring: Bool = false,
    occupancy: Occupancy = .busy,
    status: EventStatus = .active, calendar: CalendarReference? = nil
) throws -> CalendarEventRecord {
    CalendarEventRecord(
        calendar: try calendar ?? reference(), itemID: "synthetic-item", start: start, end: end,
        allDay: allDay, timeZone: zone, recurring: recurring, originalDate: original,
        occupancy: occupancy, status: status,
        title: .value("Synthetic private title"), location: .notFetched, notes: .notFetched)
}

@Test func exactSelectionRejectsMissingForeignAndDuplicateCalendarIDs() throws {
    let read = try request()
    #expect(
        try CalendarEventNormalization.selectedIndices(
            [reference("other"), reference()], request: read) == [1])
    #expect(throws: ProviderFailure.notFound) {
        try CalendarEventNormalization.selectedIndices([reference(store: "foreign")], request: read)
    }
    #expect(throws: ProviderFailure.ambiguousIdentity) {
        try CalendarEventNormalization.selectedIndices([reference(), reference()], request: read)
    }
    #expect(throws: DomainValidationError.emptySelection) {
        try CalendarReadRequest(calendars: [], window: read.window)
    }
}

@Test func normalizationHonorsHalfOpenWindowsAndRejectsForeignRecords() throws {
    let read = try request()
    #expect(
        try CalendarEventNormalization.occurrence(
            record(start: Date(timeIntervalSince1970: -3600), end: Date(timeIntervalSince1970: 0)),
            request: read) == nil)
    #expect(
        try CalendarEventNormalization.occurrence(
            record(
                start: Date(timeIntervalSince1970: 3600), end: Date(timeIntervalSince1970: 7200)),
            request: read) == nil)
    #expect(throws: ProviderFailure.invalidData) {
        try CalendarEventNormalization.occurrence(
            record(calendar: reference("outside")), request: read)
    }
    #expect(throws: DomainValidationError.invalidInterval) {
        try CalendarEventNormalization.occurrence(
            record(end: Date(timeIntervalSince1970: 0)), request: read)
    }
}

@Test func detachedOccurrenceRetainsOriginalAnchorAndUnknownRevision() throws {
    let original = Date(timeIntervalSince1970: -86400)
    let value = try #require(
        try CalendarEventNormalization.occurrence(
            record(original: original, recurring: true), request: request()))
    #expect(value.id.originalAnchor == .timed(try Instant(original)))
    #expect(value.revision == .unknown)
    #expect(value.seriesID == nil)
    let missing = try #require(
        try CalendarEventNormalization.occurrence(record(recurring: true), request: request()))
    #expect(missing.id.originalAnchor == .unknown)
    let single = try #require(
        try CalendarEventNormalization.occurrence(record(), request: request()))
    #expect(single.id.originalAnchor == .notRecurring)
}

@Test func allDayNormalizationUsesCivilDatesAcrossSpringAndFallDST() throws {
    for (start, end, hours) in [
        ("2026-03-08T05:00:00Z", "2026-03-09T04:00:00Z", 23.0),
        ("2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z", 25.0),
    ] {
        let read = try request(date(start), date(end))
        let value = try #require(
            try CalendarEventNormalization.occurrence(
                record(
                    start: date(start), end: date(end), allDay: true, zone: "America/Detroit",
                    original: date(start)), request: read))
        guard case .allDay(let dates, _) = value.time else {
            Issue.record("Expected civil interval")
            return
        }
        #expect(dates.end.day == dates.start.day + 1)
        #expect(
            try CalendarTimeResolution.interval(for: value.time).end.date.timeIntervalSince(
                date(start)) == hours * 3600)
        #expect(value.id.originalAnchor == .allDay(dates.start))
    }
}

@Test func invalidTimezoneAndSkippedCivilDayFailInsteadOfNormalizingSilently() throws {
    #expect(throws: DomainValidationError.invalidTimeZone) {
        try CalendarEventNormalization.occurrence(
            record(zone: "Synthetic/Invalid"), request: request())
    }
    let skipped = try LocalDateInterval(
        start: LocalDate(year: 2011, month: 12, day: 30),
        end: LocalDate(year: 2011, month: 12, day: 31))
    #expect(throws: ProviderFailure.invalidData) {
        try CalendarTimeResolution.interval(
            for: .allDay(skipped, timeZone: TimeZoneID("Pacific/Apia")))
    }
}

@Test func readLimitRejectsSilentTruncationAndOutOfCalendarRange() throws {
    try CalendarReadLimits.validate(request())
    #expect(throws: ProviderFailure.invalidData) {
        try CalendarReadLimits.validate(
            request(
                Date(timeIntervalSince1970: 0),
                Date(timeIntervalSince1970: CalendarReadLimits.maximumDuration + 1)))
    }
    #expect(throws: ProviderFailure.invalidData) {
        try CalendarReadLimits.validate(
            request(Date(timeIntervalSince1970: -1e15), Date(timeIntervalSince1970: -1e15 + 60)))
    }
}

@Test func availabilityClipsBusyPreservesUncertaintyAndOmitsCanceledAndFree() throws {
    let read = try request()
    let records = try [
        record(start: Date(timeIntervalSince1970: -100), end: Date(timeIntervalSince1970: 4000)),
        record(occupancy: .free), record(status: .cancelled), record(occupancy: .tentative),
        record(occupancy: .free, status: .unknown),
    ]
    let events = try records.map {
        try #require(try CalendarEventNormalization.occurrence($0, request: read))
    }
    let observation = try ObservationState(
        observedAt: Instant(Date(timeIntervalSince1970: 0)), completeness: .partial(.providerLimit),
        freshness: .localCache)
    let projected = try CalendarAvailability.project(
        CalendarSnapshot(coverage: read, occurrences: events, observation: observation))
    #expect(projected.blocks.count == 3)
    #expect(Set(projected.blocks.map(\.occupancy)) == [.busy, .tentative, .unknown])
    #expect(projected.blocks.allSatisfy { $0.interval == read.window })
    #expect(projected.observation.completeness == .partial(.providerLimit))
    #expect(projected.observation.freshness == .localCache)
}

@Test func availabilityRejectsAllDayOutsideRequestedCoverageAndKeepsEmptyUncertainty() throws {
    let read = try request()
    let dates = try LocalDateInterval(
        start: LocalDate(year: 2026, month: 1, day: 1), end: LocalDate(year: 2026, month: 1, day: 2)
    )
    let event = try CalendarOccurrence(
        id: OccurrenceReference(
            calendar: reference(), item: EventID("sample"), originalAnchor: .notRecurring),
        time: .allDay(dates, timeZone: TimeZoneID("UTC")), occupancy: .busy, status: .active)
    let observation = try ObservationState(observedAt: Instant(Date()), completeness: .unknown)
    #expect(throws: ProviderFailure.invalidData) {
        try CalendarAvailability.project(
            CalendarSnapshot(coverage: read, occurrences: [event], observation: observation))
    }
    let empty = try CalendarAvailability.project(
        CalendarSnapshot(coverage: read, occurrences: [], observation: observation))
    #expect(empty.blocks.isEmpty)
    #expect(empty.observation.completeness == .unknown)
}

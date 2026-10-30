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

@Test func materializedSeriesKeepsAnchorsForMovedAndCancelledExceptions() throws {
    let first = date("2026-03-01T14:00:00Z")
    let second = date("2026-03-08T13:00:00Z")
    let third = date("2026-03-15T13:00:00Z")
    let read = try request(date("2026-03-01T00:00:00Z"), date("2026-04-01T00:00:00Z"))
    let events = try CalendarEventNormalization.occurrences(
        [
            record(
                start: first, end: first.addingTimeInterval(3600), zone: "America/Detroit",
                original: first, recurring: true),
            record(
                start: second.addingTimeInterval(7200), end: second.addingTimeInterval(10800),
                zone: "America/Detroit", original: second, recurring: true),
            record(
                start: third, end: third.addingTimeInterval(3600), zone: "America/Detroit",
                original: third, recurring: true, status: .cancelled),
        ], request: read)
    #expect(events.count == 3 && Set(events.map(\.id)).count == 3)
    #expect(
        events.map(\.id.originalAnchor) == [first, second, third].map { .timed(try! Instant($0)) })
    #expect(events[2].status == .cancelled)
    #expect(
        try CalendarTimeResolution.interval(for: events[1].time).start.date
            == second.addingTimeInterval(7200))
    // A removed exception is absent, never synthesized as a cancellation or a normal instance.
    #expect(try CalendarEventNormalization.occurrences([], request: read).isEmpty)
}

@Test func materializationRejectsConflictingDuplicateOrUnknownAnchors() throws {
    let original = Date(timeIntervalSince1970: 0)
    let normal = try record(original: original, recurring: true)
    let moved = try record(
        start: Date(timeIntervalSince1970: 100), original: original, recurring: true)
    for records in [
        [normal, normal], [normal, moved], [try record(recurring: true)],
        [normal, try record()],
    ] {
        #expect(throws: ProviderFailure.ambiguousIdentity) {
            try CalendarEventNormalization.occurrences(records, request: request())
        }
    }
}

@Test func allDayTravelKeepsCivilAnchorAndMultiDayExclusiveEnd() throws {
    var values: [CalendarOccurrence] = []
    for (zone, start, end, original) in [
        ("America/Detroit", "2026-03-07T05:00:00Z", "2026-03-10T04:00:00Z", "2026-03-01T05:00:00Z"),
        ("Asia/Tokyo", "2026-03-06T15:00:00Z", "2026-03-09T15:00:00Z", "2026-02-28T15:00:00Z"),
    ] {
        let read = try request(date("2026-03-01T00:00:00Z"), date("2026-04-01T00:00:00Z"))
        let events = try CalendarEventNormalization.occurrences(
            [
                record(
                    start: date(start), end: date(end), allDay: true, zone: zone,
                    original: date(original), recurring: true)
            ], request: read)
        values.append(try #require(events.first))
        guard case .allDay(let dates, _) = events[0].time else {
            Issue.record("Expected civil dates")
            return
        }
        #expect(dates.start == (try LocalDate(year: 2026, month: 3, day: 7)))
        #expect(dates.end == (try LocalDate(year: 2026, month: 3, day: 10)))
    }
    #expect(values[0].id == values[1].id)
    #expect(values[0].id.originalAnchor == .allDay(try LocalDate(year: 2026, month: 3, day: 1)))
    let interval = try CalendarTimeResolution.interval(for: values[0].time)
    #expect(interval.end.date.timeIntervalSince(interval.start.date) == 71 * 3600)
}

@Test func calendarMoveChangesScopedIdentityAndMissingSelectionFails() throws {
    let old = try reference()
    let new = try reference("moved")
    let read = try CalendarReadRequest(calendars: [old, new], window: request().window)
    let first = try #require(
        try CalendarEventNormalization.occurrence(record(calendar: old), request: read))
    let second = try #require(
        try CalendarEventNormalization.occurrence(record(calendar: new), request: read))
    #expect(first.id != second.id)
    #expect(throws: ProviderFailure.notFound) {
        try CalendarEventNormalization.selectedIndices([new], request: request())
    }
}

@Test func repeatedFallClockTimeKeepsDistinctInstantAnchors() throws {
    let read = try request(date("2026-11-01T00:00:00Z"), date("2026-11-02T00:00:00Z"))
    let events = try CalendarEventNormalization.occurrences(
        ["2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z"].map {
            let start = date($0)
            return try record(
                start: start, end: start.addingTimeInterval(1800),
                zone: "America/Detroit", original: start, recurring: true)
        }, request: read)
    #expect(events.count == 2 && Set(events.map(\.id)).count == 2)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Detroit")!
    for event in events {
        let start = try CalendarTimeResolution.interval(for: event.time).start.date
        #expect(calendar.component(.hour, from: start) == 1)
        #expect(calendar.component(.minute, from: start) == 30)
    }
}

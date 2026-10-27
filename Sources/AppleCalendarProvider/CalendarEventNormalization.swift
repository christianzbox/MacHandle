import CoreDomain
import Foundation

/// Primitive adapter record used for deterministic tests. Never exported to clients or logs.
struct CalendarEventRecord: Sendable {
    let calendar: CalendarReference
    let itemID: String
    let start: Date
    let end: Date
    let allDay: Bool
    let timeZone: String
    let recurring: Bool
    let originalDate: Date?
    let occupancy: Occupancy
    let status: EventStatus
    let title: FieldValue<String?>
    let location: FieldValue<String?>
    let notes: FieldValue<String?>
}

enum CalendarEventNormalization {
    /// EventKit expands the selected bounded predicate; never synthesize a missing
    /// instance or choose a winner between conflicting exception records.
    static func occurrences(_ records: [CalendarEventRecord], request: CalendarReadRequest) throws
        -> [CalendarOccurrence]
    {
        try CalendarReadLimits.validate(request)
        guard records.count <= CalendarReadLimits.maximumOccurrences else {
            throw ProviderFailure.invalidData
        }
        let events = try records.compactMap { try occurrence($0, request: request) }
        let identities = Set(events.map(\.id))
        guard identities.count == events.count else { throw ProviderFailure.ambiguousIdentity }
        try CalendarOccurrenceIdentity.validate(identities)
        return try events.sorted {
            try CalendarTimeResolution.interval(for: $0.time).start
                < CalendarTimeResolution.interval(for: $1.time).start
        }
    }

    static func occurrence(_ record: CalendarEventRecord, request: CalendarReadRequest) throws
        -> CalendarOccurrence?
    {
        guard request.calendars.contains(record.calendar) else { throw ProviderFailure.invalidData }
        let interval = try InstantInterval(start: Instant(record.start), end: Instant(record.end))
        // Half-open boundary filtering.
        guard interval.overlaps(request.window) else { return nil }
        let zone = try TimeZoneID(record.timeZone)
        let time: EventTime =
            record.allDay
            ? .allDay(
                try LocalDateInterval(
                    start: civil(record.start, zone), end: civil(record.end, zone)), timeZone: zone)
            : .timed(interval, timeZone: zone)
        guard try CalendarTimeResolution.interval(for: time).overlaps(request.window) else {
            return nil
        }
        let anchor: RecurrenceAnchor
        if let original = record.originalDate {
            anchor =
                record.allDay ? .allDay(try civil(original, zone)) : .timed(try Instant(original))
        } else {
            anchor = record.recurring ? .unknown : .notRecurring
        }
        return CalendarOccurrence(
            id: OccurrenceReference(
                calendar: record.calendar, item: try EventID(record.itemID), originalAnchor: anchor),
            time: time, occupancy: record.occupancy, status: record.status,
            title: record.title, location: record.location, notes: record.notes, revision: .unknown)
    }

    static func selectedIndices(_ references: [CalendarReference], request: CalendarReadRequest)
        throws -> [Int]
    {
        guard Set(references).count == references.count else {
            throw ProviderFailure.ambiguousIdentity
        }
        let indices = references.indices.filter { request.calendars.contains(references[$0]) }
        guard indices.count == request.calendars.count else { throw ProviderFailure.notFound }
        return indices
    }

    private static func civil(_ date: Date, _ zone: TimeZoneID) throws -> LocalDate {
        guard date.timeIntervalSinceReferenceDate.isFinite,
            let timeZone = TimeZone(identifier: zone.rawValue)
        else { throw ProviderFailure.invalidData }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw ProviderFailure.invalidData
        }
        return try LocalDate(year: year, month: month, day: day)
    }
}

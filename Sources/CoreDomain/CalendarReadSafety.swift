import Foundation

/// Conservative local fetch bound, below EventKit's silent four-year truncation.
public enum CalendarReadLimits {
    public static let maximumDuration: TimeInterval = 400 * 24 * 60 * 60
    public static let maximumOccurrences = 10_000

    public static func validate(_ request: CalendarReadRequest) throws {
        let duration = request.window.end.date.timeIntervalSince(request.window.start.date)
        let earliest = Date(timeIntervalSince1970: -62_135_596_800)  // Gregorian year 1.
        let latest = Date(timeIntervalSince1970: 253_402_300_800)  // Gregorian year 10000.
        guard duration <= maximumDuration, request.window.start.date >= earliest,
            request.window.end.date < latest
        else { throw ProviderFailure.invalidData }
    }
}

/// Shared civil-day resolution avoids treating a DST day as 24 hours.
public enum CalendarTimeResolution {
    public static func interval(for time: EventTime) throws -> InstantInterval {
        switch time {
        case .timed(let interval, _): return interval
        case .allDay(let dates, let zone):
            return try InstantInterval(
                start: Instant(resolve(dates.start, zone: zone)),
                end: Instant(resolve(dates.end, zone: zone)))
        }
    }

    private static func resolve(_ date: LocalDate, zone: TimeZoneID) throws -> Date {
        guard let timeZone = TimeZone(identifier: zone.rawValue) else {
            throw ProviderFailure.invalidData
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard
            let resolved = calendar.date(
                from: DateComponents(year: date.year, month: date.month, day: date.day))
        else {
            throw ProviderFailure.invalidData
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: resolved)
        guard parts.year == date.year, parts.month == date.month, parts.day == date.day else {
            throw ProviderFailure.invalidData
        }
        return resolved
    }
}

public enum CalendarAvailability {
    /// Only occupied/uncertain blocks; absence is never a guarantee of free time.
    /// Overlapping blocks remain separate to preserve uncertainty instead of inventing precedence.
    public static func project(_ snapshot: CalendarSnapshot) throws -> AvailabilitySnapshot {
        var blocks: [AvailabilityBlock] = []
        for event in snapshot.occurrences {
            guard event.status != .cancelled else { continue }
            let interval = try CalendarTimeResolution.interval(for: event.time)
            guard interval.overlaps(snapshot.coverage.window) else {
                throw ProviderFailure.invalidData
            }
            let occupancy: Occupancy = event.status == .unknown ? .unknown : event.occupancy
            guard occupancy != .free else { continue }
            let clipped = try InstantInterval(
                start: max(interval.start, snapshot.coverage.window.start),
                end: min(interval.end, snapshot.coverage.window.end))
            blocks.append(AvailabilityBlock(interval: clipped, occupancy: occupancy))
        }
        blocks.sort { $0.interval.start < $1.interval.start }
        return try AvailabilitySnapshot(
            coverage: snapshot.coverage, blocks: blocks, observation: snapshot.observation)
    }
}

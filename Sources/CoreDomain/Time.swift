import Foundation

public struct Instant: Hashable, Comparable, Sendable {
    public let date: Date

    public init(_ date: Date) throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw DomainValidationError.invalidInstant
        }
        self.date = date
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.date < rhs.date }
}

/// Nonempty half-open interval [start, end). Adjacent intervals do not overlap.
public struct InstantInterval: Hashable, Sendable {
    public let start: Instant
    public let end: Instant

    public init(start: Instant, end: Instant) throws {
        guard start < end else { throw DomainValidationError.invalidInterval }
        self.start = start
        self.end = end
    }

    public func contains(_ instant: Instant) -> Bool { start <= instant && instant < end }
    public func contains(_ other: Self) -> Bool { start <= other.start && other.end <= end }
    public func overlaps(_ other: Self) -> Bool { start < other.end && other.start < end }
}

/// Gregorian civil date, years 1...9999. Not an instant or a 24-hour duration.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month) else {
            throw DomainValidationError.invalidDate
        }
        let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard (1...days[month - 1]).contains(day) else { throw DomainValidationError.invalidDate }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public struct LocalDateInterval: Hashable, Sendable {
    public let start: LocalDate
    public let end: LocalDate

    /// End is exclusive, including for a one-day event.
    public init(start: LocalDate, end: LocalDate) throws {
        guard start < end else { throw DomainValidationError.invalidInterval }
        self.start = start
        self.end = end
    }
}

public struct TimeZoneID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard TimeZone(identifier: rawValue) != nil else {
            throw DomainValidationError.invalidTimeZone
        }
        self.rawValue = rawValue
    }
}

/// Wall-clock components; no implicit conversion through the machine's current zone.
public struct LocalTime: Hashable, Sendable {
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(hour: Int, minute: Int, second: Int = 0) throws {
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            throw DomainValidationError.invalidTime
        }
        self.hour = hour
        self.minute = minute
        self.second = second
    }
}

public enum EventTime: Hashable, Sendable {
    case timed(InstantInterval, timeZone: TimeZoneID)
    case allDay(LocalDateInterval, timeZone: TimeZoneID)
}

public enum RecurrenceAnchor: Hashable, Sendable {
    case notRecurring
    case unknown
    case timed(Instant)
    case allDay(LocalDate)
}

/// Nil time zone is deliberately floating, never silently treated as UTC.
public enum ReminderDue: Hashable, Sendable {
    case date(LocalDate)
    case localDateTime(LocalDate, LocalTime, timeZone: TimeZoneID?)
}

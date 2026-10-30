import ActionApprovals
import CoreDomain
import Foundation

/// Component mapping retains civil time. No instant, implicit zone, midnight or alarm is invented.
enum ReminderMutationScope {
    static func components(_ due: ReminderDue?) -> DateComponents? {
        guard let due else { return nil }
        let date: LocalDate
        var result = DateComponents()
        result.calendar = Calendar(identifier: .gregorian)
        switch due {
        case .date(let d): date = d
        case .localDateTime(let d, let time, let zone):
            date = d
            result.hour = time.hour
            result.minute = time.minute
            result.second = time.second
            result.timeZone = zone.flatMap { TimeZone(identifier: $0.rawValue) }
        }
        result.year = date.year
        result.month = date.month
        result.day = date.day
        return result
    }
    static func due(_ value: DateComponents?) throws -> ReminderDue? {
        guard let value else { return nil }
        guard value.calendar == nil || value.calendar?.identifier == .gregorian,
            value.era == nil || value.era == 1, value.isLeapMonth != true,
            value.weekOfYear == nil, value.weekOfMonth == nil, value.yearForWeekOfYear == nil,
            value.weekday == nil, value.weekdayOrdinal == nil, value.quarter == nil,
            value.nanosecond == nil || value.nanosecond == 0,
            let year = value.year, let month = value.month, let day = value.day
        else { throw ActionFailure.invalid }
        let date = try LocalDate(year: year, month: month, day: day)
        if value.hour == nil && value.minute == nil && value.second == nil { return .date(date) }
        guard let hour = value.hour, let minute = value.minute else { throw ActionFailure.invalid }
        return .localDateTime(
            date, try LocalTime(hour: hour, minute: minute, second: value.second ?? 0),
            timeZone: try value.timeZone.map { try TimeZoneID($0.identifier) })
    }
    static func revision(_ modified: Date?) throws -> MutationPrecondition {
        guard let modified, modified.timeIntervalSince1970.isFinite else {
            throw ActionFailure.stale
        }
        // Local observation only, not an atomic compare-and-swap version.
        return .revision(
            try ObservedRevision("reminder-observed-\(modified.timeIntervalSince1970.bitPattern)"))
    }
    static func validate(
        _ expected: ReminderReference, actual: ReminderReference,
        recurring: Bool, alarms: Bool
    ) throws {
        guard expected == actual, !recurring, !alarms else { throw ActionFailure.stale }
    }
}

import CoreDomain
import Foundation

/// Component conversion never assumes the machine's time zone or turns a date-only due into midnight.
enum ReminderNormalization {
    static func due(_ value: DateComponents?) throws -> ReminderDue? {
        guard let value else { return nil }
        guard value.calendar == nil || value.calendar?.identifier == .gregorian,
            value.era == nil || value.era == 1, value.isLeapMonth != true,
            value.weekOfYear == nil, value.weekOfMonth == nil, value.yearForWeekOfYear == nil,
            value.weekday == nil, value.weekdayOrdinal == nil, value.quarter == nil,
            value.nanosecond == nil || value.nanosecond == 0,
            let year = value.year, let month = value.month, let day = value.day
        else { throw ProviderFailure.invalidData }
        let date = try LocalDate(year: year, month: month, day: day)
        if value.hour == nil && value.minute == nil && value.second == nil { return .date(date) }
        guard let hour = value.hour, let minute = value.minute else {
            throw ProviderFailure.invalidData
        }
        return .localDateTime(
            date, try LocalTime(hour: hour, minute: minute, second: value.second ?? 0),
            timeZone: try value.timeZone.map { try TimeZoneID($0.identifier) })
    }
}

/// EventKit cancellation suppresses its callback, so cancellation must resolve our continuation too.
final class ReminderFetchBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: ProviderReadResult<ReminderSnapshot>?
    private var continuation: CheckedContinuation<ProviderReadResult<ReminderSnapshot>, Never>?
    func finish(_ value: ProviderReadResult<ReminderSnapshot>) {
        let waiting = lock.withLock {
            () -> CheckedContinuation<ProviderReadResult<ReminderSnapshot>, Never>? in
            guard result == nil else { return nil }
            result = value
            let waiting = continuation
            continuation = nil
            return waiting
        }
        waiting?.resume(returning: value)
    }
    func value() async -> ProviderReadResult<ReminderSnapshot> {
        await withCheckedContinuation { next in
            let ready = lock.withLock { () -> ProviderReadResult<ReminderSnapshot>? in
                if let result { return result }
                continuation = next
                return nil
            }
            if let ready { next.resume(returning: ready) }
        }
    }
}

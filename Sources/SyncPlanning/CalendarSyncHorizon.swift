import CoreDomain
import Foundation

/// Initial bounded materialization window: local midnight 30 days ago through
/// local midnight 365 days ahead (exclusive). Callers supply the clock and zone.
public enum CalendarSyncHorizon {
    public static func window(containing now: Instant, timeZone: TimeZoneID) throws
        -> InstantInterval
    {
        guard now.date >= Date(timeIntervalSince1970: -62_135_596_800),
            now.date < Date(timeIntervalSince1970: 253_402_300_800),
            let zone = TimeZone(identifier: timeZone.rawValue)
        else {
            throw PlanningIssue.invalidInput
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: now.date)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today),
            let end = calendar.date(byAdding: .day, value: 365, to: today),
            start >= Date(timeIntervalSince1970: -62_135_596_800),
            end < Date(timeIntervalSince1970: 253_402_300_800),
            end.timeIntervalSince(start) <= CalendarReadLimits.maximumDuration
        else { throw PlanningIssue.invalidInput }
        return try InstantInterval(start: Instant(start), end: Instant(end))
    }
}

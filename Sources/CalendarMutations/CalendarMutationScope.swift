import ActionApprovals
import CoreDomain
import Foundation

extension CalendarMutation {
    var target: CalendarReference {
        switch self {
        case .create(let calendar, _): calendar
        case .update(let event, _, _), .delete(let event, _): event.calendar
        }
    }
    var occurrence: OccurrenceReference? {
        switch self {
        case .create: nil
        case .update(let event, _, _), .delete(let event, _): event
        }
    }
    var precondition: MutationPrecondition? {
        switch self {
        case .create: nil
        case .update(_, _, let value), .delete(_, let value): value
        }
    }
}

enum CalendarMutationScope {
    static func validateTarget(
        _ expected: CalendarReference, actual: CalendarReference,
        writable: Bool, allowsEvents: Bool
    ) throws {
        guard expected == actual, writable, allowsEvents else { throw ActionFailure.denied }
    }
    static func validateEvent(
        _ expected: OccurrenceReference, actual: OccurrenceReference,
        recurring: Bool, detached: Bool, hasOccurrenceDate: Bool,
        hasAttendees: Bool, hasOrganizer: Bool, cancelled: Bool
    ) throws {
        guard expected == actual, expected.originalAnchor == .notRecurring,
            !recurring, !detached, !hasOccurrenceDate, !hasAttendees, !hasOrganizer, !cancelled
        else { throw ActionFailure.stale }
    }
    static func validate(_ change: CalendarMutation) throws {
        if let reference = change.occurrence {
            // No recurrence inference from first-occurrence lookup, detached ID or shifted start.
            guard reference.originalAnchor == .notRecurring,
                case .revision = change.precondition
            else { throw ActionFailure.denied }
        }
    }
    static func time(_ time: EventTime) throws -> (
        start: Date, end: Date, zone: TimeZone, allDay: Bool
    ) {
        let interval = try CalendarTimeResolution.interval(for: time)
        let id: TimeZoneID
        let allDay: Bool
        switch time {
        case .timed(_, let zone):
            id = zone
            allDay = false
        case .allDay(_, let zone):
            id = zone
            allDay = true
        }
        guard let zone = TimeZone(identifier: id.rawValue),
            interval.start.date.timeIntervalSince1970.rounded()
                == interval.start.date.timeIntervalSince1970,
            interval.end.date.timeIntervalSince1970.rounded()
                == interval.end.date.timeIntervalSince1970
        else { throw ActionFailure.invalid }
        return (interval.start.date, interval.end.date, zone, allDay)
    }
    static func civil(_ date: Date, zone: TimeZone) throws -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw ActionFailure.invalid
        }
        return try LocalDate(year: year, month: month, day: day)
    }
    // Observation token only, NOT a server revision or compare-and-swap precondition.
    static func revision(_ modified: Date?) throws -> MutationPrecondition {
        guard let modified, modified.timeIntervalSince1970.isFinite else {
            throw ActionFailure.stale
        }
        return .revision(
            try ObservedRevision("eventkit-observed-\(modified.timeIntervalSince1970.bitPattern)"))
    }
}

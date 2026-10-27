import CoreDomain
import Foundation
import GoogleAuthorization
import SyncPlanning

enum GoogleContentProjection {
    static func convert(_ content: PlannedEventContent) throws -> GoogleEventContent {
        let start: GoogleEventTime
        let end: GoogleEventTime
        switch content.time {
        case .timed(let interval, _):
            do {
                start = try GoogleEventTime(instant: interval.start.date)
                end = try GoogleEventTime(instant: interval.end.date)
            } catch { throw ExecutionFailure.invalidTime }
            // Keep an independent round-trip gate even if the wire encoder changes.
            guard start.value == interval.start.date, end.value == interval.end.date else {
                throw ExecutionFailure.invalidTime
            }
        case .allDay(let days, _):
            func day(_ value: LocalDate) -> String {
                String(format: "%04d-%02d-%02d", value.year, value.month, value.day)
            }
            start = try GoogleEventTime(day: day(days.start))
            end = try GoogleEventTime(day: day(days.end))
        }
        return try GoogleEventContent(
            start: start, end: end, summary: content.title,
            description: content.notes, location: content.location, isFree: content.isFree)
    }
}

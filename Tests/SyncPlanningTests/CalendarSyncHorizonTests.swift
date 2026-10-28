import CoreDomain
import Foundation
import SyncPlanning
import Testing

private func point(_ text: String) throws -> Instant {
    try Instant(ISO8601DateFormatter().date(from: text)!)
}

@Test func rollingHorizonUsesLocalCalendarDaysAcrossDSTAndLeapYear() throws {
    let zone = try TimeZoneID("America/Detroit")
    for (now, start, end) in [
        ("2026-10-27T16:00:00Z", "2026-09-27T04:00:00Z", "2027-10-27T04:00:00Z"),
        ("2026-03-08T16:00:00Z", "2026-02-06T05:00:00Z", "2027-03-08T05:00:00Z"),
        ("2026-11-01T16:00:00Z", "2026-10-02T04:00:00Z", "2027-11-01T04:00:00Z"),
        ("2026-03-15T16:00:00Z", "2026-02-13T05:00:00Z", "2027-03-15T04:00:00Z"),
        ("2026-11-08T16:00:00Z", "2026-10-09T04:00:00Z", "2027-11-08T05:00:00Z"),
        ("2024-02-29T16:00:00Z", "2024-01-30T05:00:00Z", "2025-02-28T05:00:00Z"),
    ] {
        let window = try CalendarSyncHorizon.window(containing: point(now), timeZone: zone)
        #expect(window.start == (try point(start)))
        #expect(window.end == (try point(end)))
    }
    let before = try CalendarSyncHorizon.window(
        containing: point("2026-03-08T16:00:00Z"), timeZone: zone)
    let after = try CalendarSyncHorizon.window(
        containing: point("2026-03-09T16:00:00Z"), timeZone: zone)
    #expect(after.start > before.start && after.end > before.end)
}

@Test func horizonRejectsUnsupportedCalendarRange() throws {
    for seconds in [-1e15, -62_135_596_800, 253_402_300_799, 1e15] {
        #expect(throws: PlanningIssue.invalidInput) {
            try CalendarSyncHorizon.window(
                containing: Instant(Date(timeIntervalSince1970: seconds)),
                timeZone: TimeZoneID("UTC"))
        }
    }
}

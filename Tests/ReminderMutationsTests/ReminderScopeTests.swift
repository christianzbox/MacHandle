import ActionApprovals
import CoreDomain
import Foundation
import Testing

@testable import ReminderMutations

@Test func reminderDueComponentsRoundTripCivilFloatingNamedZoneAndDSTGap() throws {
    let date = try LocalDate(year: 2027, month: 3, day: 14)
    let time = try LocalTime(hour: 2, minute: 30)
    let zone = try TimeZoneID("America/New_York")
    for value: ReminderDue? in [
        nil, .date(date), .localDateTime(date, time, timeZone: nil),
        .localDateTime(date, time, timeZone: zone),
    ] {
        #expect(try ReminderMutationScope.due(ReminderMutationScope.components(value)) == value)
    }
    #expect(ReminderMutationScope.components(.date(date))?.hour == nil)
    #expect(
        ReminderMutationScope.components(.localDateTime(date, time, timeZone: nil))?.timeZone == nil
    )
    #expect(throws: (any Error).self) {
        try ReminderMutationScope.due(DateComponents(year: 2027, month: 2, day: 30))
    }
    #expect(throws: (any Error).self) {
        try ReminderMutationScope.due(DateComponents(year: 2027, month: 1, day: 1, hour: 4))
    }
}
@Test func reminderMutationScopeRejectsMovedRecurringAndAlarmTargets() async throws {
    let fixture = try await SyntheticReminderActionFixture.make()
    let ref = fixture.reminder.id
    try ReminderMutationScope.validate(ref, actual: ref, recurring: false, alarms: false)
    let other = try ReminderReference(list: ref.list, item: ReminderID("foreign"))
    for (actual, recurring, alarms) in [
        (other, false, false), (ref, true, false), (ref, false, true),
    ] {
        #expect(throws: (any Error).self) {
            try ReminderMutationScope.validate(
                ref, actual: actual, recurring: recurring, alarms: alarms)
        }
    }
    #expect(throws: (any Error).self) { try ReminderMutationScope.revision(nil) }
}

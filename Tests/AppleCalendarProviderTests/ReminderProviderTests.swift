import CoreDomain
import EventKit
import Foundation
import Testing

@testable import AppleCalendarProvider

struct ReminderProviderTests {
    @Test func dueDatesPreserveCivilFloatingAndExplicitZones() throws {
        #expect(try ReminderNormalization.due(nil) == nil)
        var value = DateComponents(year: 2027, month: 3, day: 14)
        #expect(
            try ReminderNormalization.due(value) == .date(LocalDate(year: 2027, month: 3, day: 14)))
        value.hour = 2
        value.minute = 30
        #expect(
            try ReminderNormalization.due(value)
                == .localDateTime(
                    LocalDate(year: 2027, month: 3, day: 14), LocalTime(hour: 2, minute: 30),
                    timeZone: nil))
        value.timeZone = TimeZone(identifier: "America/Detroit")
        #expect(
            try ReminderNormalization.due(value)
                == .localDateTime(
                    LocalDate(year: 2027, month: 3, day: 14), LocalTime(hour: 2, minute: 30),
                    timeZone: TimeZoneID("America/Detroit")))
        // A civil time in the DST gap is retained as components, not converted into an invented instant.
    }
    @Test func malformedDueComponentsAreNotTreatedAsNoDueDate() {
        let values = [
            DateComponents(year: 2027, month: 2, day: 30), DateComponents(month: 1, day: 1),
            DateComponents(calendar: Calendar(identifier: .hebrew), year: 2027, month: 1, day: 1),
            DateComponents(year: 2027, month: 1, day: 1, hour: 12),
            DateComponents(year: 2027, month: 1, day: 1, hour: 12, minute: 0, nanosecond: 1),
        ]
        for value in values {
            #expect(throws: (any Error).self) { try ReminderNormalization.due(value) }
        }
    }
    @Test func remindersAuthorizationRejectsCalendarWriteOnlyAndUnknown() {
        #expect(EventKitRemindersProvider.mapAuthorization(.fullAccess) == .fullAccess)
        #expect(EventKitRemindersProvider.mapAuthorization(.writeOnly) == .denied)
        #expect(EventKitRemindersProvider.mapAuthorization(.notDetermined) == .notDetermined)
        #expect(EventKitRemindersProvider.mapAuthorization(.restricted) == .restricted)
        #expect(EventKitRemindersProvider.mapAuthorization(.denied) == .denied)
    }
    @Test func cancelWithoutEventKitCallbackResolvesWaiterAndIgnoresLateCallback() async {
        let box = ReminderFetchBox()
        let task = Task { await box.value() }
        box.finish(.failed(.cancelled))
        box.finish(.failed(.unavailable))
        guard case .failed(let failure) = await task.value else {
            Issue.record("Expected cancellation")
            return
        }
        #expect(failure == .cancelled)
    }
    @Test func cancellationBeforeWaiterInstallationIsNotLost() async {
        let box = ReminderFetchBox()
        box.finish(.failed(.cancelled))
        guard case .failed(let failure) = await box.value() else {
            Issue.record("Expected cancellation")
            return
        }
        #expect(failure == .cancelled)
    }
    @Test func snapshotRejectsForeignDuplicateAndUnboundedCoverage() throws {
        let account = try AccountReference(
            provider: ProviderID("synthetic"), store: StoreID("store"),
            account: AccountID("account"))
        let list = try ReminderListReference(account: account, localID: DomainID("list"))
        let other = try ReminderListReference(account: account, localID: DomainID("other"))
        let item = try Reminder(id: ReminderReference(list: list, item: ReminderID("item")))
        let manyLists = try Set(
            (0..<33).map {
                try ReminderListReference(account: account, localID: DomainID("list-\($0)"))
            })
        #expect(throws: (any Error).self) { try ReminderReadRequest(lists: manyLists) }
        let request = try ReminderReadRequest(lists: [list])
        let observation = ObservationState(observedAt: try Instant(Date()), completeness: .complete)
        let manyItems = try (0...ReminderSnapshot.maximumItems).map {
            try Reminder(id: ReminderReference(list: list, item: ReminderID("item-\($0)")))
        }
        #expect(throws: (any Error).self) {
            try ReminderSnapshot(coverage: request, reminders: manyItems, observation: observation)
        }
        #expect(throws: (any Error).self) { try ReminderReadRequest(lists: []) }
        #expect(throws: (any Error).self) { try ReminderReadRequest(lists: [other], item: item.id) }
        #expect(throws: (any Error).self) {
            try ReminderSnapshot(
                coverage: request, reminders: [item, item], observation: observation)
        }
        #expect(throws: (any Error).self) {
            try ReminderSnapshot(
                coverage: ReminderReadRequest(lists: [other]), reminders: [item],
                observation: observation)
        }
    }
}

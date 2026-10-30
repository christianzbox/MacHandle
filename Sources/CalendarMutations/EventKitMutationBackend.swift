import ActionApprovals
import CoreDomain
import EventKit
import Foundation
import PermissionEngine

/// Unreachable from production composition until JournaledCalendarProvider.live's explicit gate opens.
/// One private store, no batched commits, no EventKit objects outside this actor, no permission prompts.
actor EventKitMutationBackend: CalendarMutationBackend {
    private var store: EKEventStore?
    private func eventStore() -> EKEventStore {
        if let store { return store }
        let value = EKEventStore()
        store = value
        return value
    }
    private func access() throws {
        guard !Task.isCancelled, EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw ActionFailure.denied
        }
    }
    private func reference(_ calendar: EKCalendar, store: EKEventStore) throws -> CalendarReference
    {
        try CalendarReference(
            account: AccountReference(
                provider: ProviderID("apple-eventkit"),
                store: StoreID(store.eventStoreIdentifier),
                account: AccountID(calendar.source.sourceIdentifier)),
            localID: DomainID(calendar.calendarIdentifier))
    }
    private func target(_ change: CalendarMutation, store: EKEventStore) throws -> EKCalendar {
        guard let calendar = store.calendar(withIdentifier: change.target.localID.rawValue) else {
            throw ActionFailure.denied
        }
        try CalendarMutationScope.validateTarget(
            change.target, actual: reference(calendar, store: store),
            writable: calendar.allowsContentModifications,
            allowsEvents: calendar.allowedEntityTypes.contains(.event))
        return calendar
    }
    private func event(_ change: CalendarMutation, store: EKEventStore) throws -> EKEvent? {
        guard let id = change.occurrence else { return nil }
        guard let event = store.calendarItem(withIdentifier: id.item.rawValue) as? EKEvent,
            event.refresh(), let calendar = event.calendar
        else { throw ActionFailure.stale }
        switch event.status {
        case .none, .confirmed, .tentative: break
        case .canceled: throw ActionFailure.stale
        @unknown default: throw ActionFailure.stale
        }
        try CalendarMutationScope.validateEvent(
            id,
            actual: OccurrenceReference(
                calendar: reference(calendar, store: store),
                item: EventID(event.calendarItemIdentifier), originalAnchor: .notRecurring),
            recurring: event.hasRecurrenceRules, detached: event.isDetached,
            hasOccurrenceDate: event.occurrenceDate != nil,
            hasAttendees: event.hasAttendees, hasOrganizer: event.organizer != nil,
            cancelled: event.status == .canceled)
        return event
    }
    private func snapshot(
        _ change: CalendarMutation, fields: Set<CalendarField>,
        store: EKEventStore, calendar: EKCalendar, event: EKEvent?
    ) throws -> CalendarActionSnapshot {
        let occurrence: CalendarOccurrence?
        if let event, let id = change.occurrence {
            guard let start = event.startDate, let end = event.endDate else {
                throw ActionFailure.stale
            }
            let zone = event.isAllDay ? TimeZone.current : event.timeZone
            // Floating timed events are not inferred.
            guard let zone else { throw ActionFailure.invalid }
            let zoneID = try TimeZoneID(zone.identifier)
            let time: EventTime =
                event.isAllDay
                ? .allDay(
                    try LocalDateInterval(
                        start: CalendarMutationScope.civil(start, zone: zone),
                        end: CalendarMutationScope.civil(end, zone: zone)), timeZone: zoneID)
                : .timed(
                    try InstantInterval(start: Instant(start), end: Instant(end)), timeZone: zoneID)
            let revision = try CalendarMutationScope.revision(event.lastModifiedDate)
            guard revision == change.precondition else { throw ActionFailure.stale }
            let occupancy: Occupancy
            switch event.availability {
            case .free: occupancy = .free
            case .busy: occupancy = .busy
            case .tentative: occupancy = .tentative
            default: throw ActionFailure.invalid
            }
            occurrence = CalendarOccurrence(
                id: id, time: time, occupancy: occupancy, status: .active,
                title: fields.contains(.title) ? .value(event.title) : .notFetched,
                location: fields.contains(.location) ? .value(event.location) : .notFetched,
                notes: fields.contains(.notes) ? .value(event.notes) : .notFetched,
                revision: revision)
        } else {
            occurrence = nil
        }
        return CalendarActionSnapshot(
            calendar: try reference(calendar, store: store),
            accountLabel: calendar.source.title, calendarLabel: calendar.title, writable: true,
            event: occurrence)
    }
    func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) throws
        -> CalendarActionSnapshot
    {
        try access()
        try CalendarMutationScope.validate(change)
        let store = eventStore()
        let calendar = try target(change, store: store)
        let event = try event(change, store: store)
        let result = try snapshot(
            change, fields: fields, store: store, calendar: calendar, event: event)
        try access()
        return result
    }
    func apply(_ action: AuthorizedCalendarAction) async throws -> CalendarActionReceipt {
        // Journal preparation and any actor suspension precede this final authority check.
        guard await action.revalidate() else { return .notApplied }
        do { try access() } catch { return .notApplied }
        let store = eventStore()
        let change = action.proposal.change
        let calendar: EKCalendar
        let existing: EKEvent?
        do {
            try access()
            try CalendarMutationScope.validate(change)
            calendar = try target(change, store: store)
            existing = try event(change, store: store)
            guard
                try snapshot(
                    change, fields: action.fields, store: store, calendar: calendar, event: existing
                )
                    == action.expected
            else { return .notApplied }
        } catch { return .notApplied }
        let event: EKEvent
        do {
            switch change {
            case .create(_, let draft):
                event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = draft.title
                event.location = draft.location
                event.notes = draft.notes
                try setTime(draft.time, event: event)
                try setOccupancy(draft.occupancy, event: event, calendar: calendar)
            case .update(_, let changes, _):
                guard let existing else { return .notApplied }
                event = existing
                if case .set(let value) = changes.title { event.title = value }
                if case .set(let value) = changes.location { event.location = value }
                if case .set(let value) = changes.notes { event.notes = value }
                if case .set(let value) = changes.time { try setTime(value, event: event) }
                if case .set(let value) = changes.occupancy {
                    try setOccupancy(value, event: event, calendar: calendar)
                }
            case .delete:
                guard let existing else { return .notApplied }
                event = existing
            }
            try access()
            guard try reference(calendar, store: store) == change.target,
                calendar.allowsContentModifications
            else { throw ActionFailure.denied }
        } catch {
            store.reset()
            return .notApplied
        }
        // No suspension between inspection, patch and dispatch. This is NOT atomic with other apps/cloud.
        // EventKit save can recreate an externally deleted item. Activation remains blocked for that reason.
        do {
            switch change {
            case .delete: try store.remove(event, span: .thisEvent, commit: true)
            case .create, .update: try store.save(event, span: .thisEvent, commit: true)
            }
            // Local save acceptance, not remote synchronization proof.
            return .applied(action.proposal.id)
        } catch {
            store.reset()
            return .unknown  // Never infer rollback, retry, or absence from a provider error.
        }
    }
    private func setTime(_ value: EventTime, event: EKEvent) throws {
        let time = try CalendarMutationScope.time(value)
        guard !time.allDay || time.zone.identifier == TimeZone.current.identifier else {
            throw ActionFailure.invalid
        }
        event.timeZone = time.zone
        event.isAllDay = time.allDay
        event.startDate = time.start
        event.endDate = time.end
    }
    private func setOccupancy(_ value: Occupancy, event: EKEvent, calendar: EKCalendar) throws {
        let mask: EKCalendarEventAvailabilityMask
        let availability: EKEventAvailability
        switch value {
        case .free:
            mask = .free
            availability = .free
        case .busy:
            mask = .busy
            availability = .busy
        case .tentative:
            mask = .tentative
            availability = .tentative
        case .unknown: throw ActionFailure.invalid
        }
        guard calendar.supportedEventAvailabilities.contains(mask) else {
            throw ActionFailure.denied
        }
        event.availability = availability
    }
}

import CoreDomain
import Foundation
import PermissionEngine

/// Explicit in-memory fixture. Never accepts live resources, caller identity, providers or credentials.
package struct SyntheticActionFixture: Sendable {
    package let authority: PolicyAuthority
    package let session: PolicySession
    package let provider: SyntheticActionProvider
    package let calendar: CalendarReference
    package let event: CalendarOccurrence
    package static func make() async throws -> Self {
        let account = AccountReference(
            provider: try ProviderID("synthetic"), store: try StoreID("synthetic-store"),
            account: try AccountID("synthetic-account"))
        let calendar = CalendarReference(
            account: account, localID: try DomainID("synthetic-calendar"))
        let time = EventTime.timed(
            try InstantInterval(
                start: Instant(Date(timeIntervalSince1970: 1_800_000_000)),
                end: Instant(Date(timeIntervalSince1970: 1_800_003_600))),
            timeZone: try TimeZoneID("UTC"))
        let event = CalendarOccurrence(
            id: OccurrenceReference(
                calendar: calendar, item: try EventID("synthetic-event"),
                originalAnchor: .notRecurring),
            time: time, occupancy: .busy, status: .active, title: .value("Sample planning session"),
            location: .value("Sample room"), notes: .value("Sample notes"),
            revision: .revision(try ObservedRevision("synthetic-v1")))
        let authority = PolicyAuthority()
        let id = try ConnectionID(UUID().uuidString)
        let fields: Set<CalendarField> = [.title, .time, .occupancy, .status, .location, .notes]
        await authority.setConnection(
            Connection(id: id, kind: .localMCP, state: .enabled),
            policy: ConnectionPolicy(calendars: [
                calendar: CalendarGrant(
                    operations: [.readDetails, .create, .update, .delete], readableFields: fields,
                    writableFields: fields)
            ]))
        await authority.observeOSPermissions(OSPermissions(calendars: .fullAccess))
        return Self(
            authority: authority, session: try await authority.bindTrustedConnection(id),
            provider: SyntheticActionProvider(calendar: calendar, event: event), calendar: calendar,
            event: event)
    }
    package func change(_ kind: ActionKind) throws -> CalendarMutation {
        switch kind {
        case .create:
            .create(
                in: calendar,
                event: EventDraft(title: "Sample new event", time: event.time, occupancy: .busy))
        case .update:
            .update(
                event.id,
                changes: try EventChanges(
                    title: .set("Sample revised planning session"), location: .set(nil)),
                precondition: event.revision)
        case .delete: .delete(event.id, precondition: event.revision)
        }
    }
}

package actor SyntheticActionProvider: CalendarActionProvider {
    private let calendar: CalendarReference
    private var events: [OccurrenceReference: CalendarOccurrence]
    private var applied: Set<OperationID> = []
    init(calendar: CalendarReference, event: CalendarOccurrence) {
        self.calendar = calendar
        self.events = [event.id: event]
    }
    package func inspect(_ change: CalendarMutation, fields: Set<CalendarField>) throws
        -> CalendarActionSnapshot
    {
        guard change.target == calendar else { throw ActionFailure.denied }
        let projected: CalendarOccurrence?
        if case .create = change {
            projected = nil
        } else if let event = events[change.occurrence!] {
            projected = CalendarOccurrence(
                id: event.id, seriesID: event.seriesID, time: event.time,
                occupancy: event.occupancy, status: event.status,
                title: fields.contains(.title) ? event.title : .notFetched,
                location: fields.contains(.location) ? event.location : .notFetched,
                notes: fields.contains(.notes) ? event.notes : .notFetched, revision: event.revision
            )
        } else {
            projected = nil
        }
        return CalendarActionSnapshot(
            calendar: calendar, accountLabel: "Sample local account",
            calendarLabel: "Sample calendar", writable: true, event: projected)
    }
    package func apply(_ action: AuthorizedCalendarAction) throws -> CalendarActionReceipt {
        guard !applied.contains(action.proposal.id),
            try inspect(action.proposal.change, fields: action.fields) == action.expected
        else { return .notApplied }
        // No suspension between current-state comparison, mutation and receipt in this mock actor.
        let revision = MutationPrecondition.revision(try ObservedRevision(UUID().uuidString))
        switch action.proposal.change {
        case .create(_, let draft):
            let event = CalendarOccurrence(
                id: OccurrenceReference(
                    calendar: calendar, item: try EventID(UUID().uuidString),
                    originalAnchor: .notRecurring),
                time: draft.time, occupancy: draft.occupancy, status: .active,
                title: .value(draft.title), location: .value(draft.location),
                notes: .value(draft.notes), revision: revision)
            events[event.id] = event
        case .update(let id, let patch, _):
            guard let previous = events[id], previous.id == id else { return .notApplied }
            func edited<T>(_ patch: ValueChange<T>, _ old: T) -> T {
                if case .set(let value) = patch { value } else { old }
            }
            func field<T>(_ patch: ValueChange<T>, _ old: FieldValue<T>) -> FieldValue<T> {
                if case .set(let value) = patch { .value(value) } else { old }
            }
            let title: FieldValue<String?>
            if case .set(let value) = patch.title {
                title = .value(value)
            } else {
                title = previous.title
            }
            events[id] = CalendarOccurrence(
                id: id, seriesID: previous.seriesID, time: edited(patch.time, previous.time),
                occupancy: edited(patch.occupancy, previous.occupancy), status: previous.status,
                title: title, location: field(patch.location, previous.location),
                notes: field(patch.notes, previous.notes), revision: revision)
        case .delete(let id, _):
            guard events[id] != nil else { return .notApplied }
            events.removeValue(forKey: id)
        }
        applied.insert(action.proposal.id)
        return .applied(action.proposal.id)
    }
}

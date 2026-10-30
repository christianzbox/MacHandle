import CoreDomain
import Foundation
import PermissionEngine

extension CalendarMutation {
    var target: CalendarReference {
        switch self {
        case .create(let target, _): target
        case .update(let reference, _, _), .delete(let reference, _): reference.calendar
        }
    }
    var occurrence: OccurrenceReference? {
        switch self {
        case .create: nil
        case .update(let id, _, _), .delete(let id, _): id
        }
    }
    var kind: ActionKind {
        switch self {
        case .create: .create
        case .update: .update
        case .delete: .delete
        }
    }
    var reviewFields: Set<CalendarField> {
        switch self {
        case .create: return []
        case .delete: return [.time, .occupancy, .status, .title]
        case .update(_, let changes, _):
            var fields: Set<CalendarField> = [.time, .occupancy, .status, .title]
            if changes.location.isChanged { fields.insert(.location) }
            if changes.notes.isChanged { fields.insert(.notes) }
            return fields
        }
    }
}

enum CalendarActionReview {
    static func text(_ value: String, limit: Int = 8192, multiline: Bool = false) throws -> String {
        guard value.utf8.count <= limit,
            !value.unicodeScalars.contains(where: {
                if multiline && ($0 == "\n" || $0 == "\t") { return false }
                return CharacterSet.controlCharacters.contains($0)
                    || $0.properties.generalCategory == .format
            })
        else { throw ActionFailure.invalid }
        return value
    }
    static func validate(_ change: CalendarMutation) throws {
        switch change {
        case .create(_, let draft):
            guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ActionFailure.invalid
            }
            _ = try text(draft.title, limit: 512)
            _ = try time(draft.time)
            _ = try text(draft.location ?? "", limit: 2048)
            _ = try text(draft.notes ?? "", multiline: true)
            guard draft.occupancy != .unknown else { throw ActionFailure.invalid }
        case .update(_, let patch, _):
            if case .set(let value) = patch.title {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ActionFailure.invalid
                }
                _ = try text(value, limit: 512)
            }
            if case .set(let value) = patch.time { _ = try time(value) }
            if case .set(let value) = patch.location { _ = try text(value ?? "", limit: 2048) }
            if case .set(let value) = patch.notes { _ = try text(value ?? "", multiline: true) }
            if case .set(.unknown) = patch.occupancy { throw ActionFailure.invalid }
        case .delete: break
        }
    }
    static func time(_ value: EventTime) throws -> String {
        _ = try CalendarTimeResolution.interval(for: value)
        switch value {
        case .timed(let interval, let zone):
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            func instant(_ date: Date) throws -> String {
                let value = format.string(from: date)
                guard !value.isEmpty else { throw ActionFailure.invalid }
                if format.date(from: value) == date { return value }
                return "\(value) (exact epoch seconds: \(date.timeIntervalSince1970))"
            }
            return try
                "\(instant(interval.start.date)) – \(instant(interval.end.date)) · \(zone.rawValue)"
        case .allDay(let dates, let zone):
            func date(_ d: LocalDate) -> String {
                String(format: "%04d-%02d-%02d", d.year, d.month, d.day)
            }
            return
                "All day: \(date(dates.start)) to \(date(dates.end)) (end exclusive) · \(zone.rawValue)"
        }
    }
    static func occupancy(_ value: Occupancy) -> String {
        switch value {
        case .free: "Free"
        case .busy: "Busy"
        case .tentative: "Tentative"
        case .unknown: "Unknown"
        }
    }
    static func value(_ field: FieldValue<String?>, multiline: Bool = false) throws -> String {
        guard case .value(let string) = field else { throw ActionFailure.invalid }
        return try displayText(string, multiline: multiline)
    }
    static func displayText(_ value: String?, multiline: Bool = false) throws -> String {
        guard let value else { return "Not set" }
        return String(reflecting: try text(value, multiline: multiline))
    }
    static func project(_ snapshot: CalendarActionSnapshot, fields: Set<CalendarField>)
        -> CalendarActionSnapshot
    {
        let event = snapshot.event.map {
            CalendarOccurrence(
                id: $0.id, seriesID: $0.seriesID, time: $0.time, occupancy: $0.occupancy,
                status: $0.status,
                title: fields.contains(.title) ? $0.title : .notFetched,
                location: fields.contains(.location) ? $0.location : .notFetched,
                notes: fields.contains(.notes) ? $0.notes : .notFetched, revision: $0.revision)
        }
        return CalendarActionSnapshot(
            calendar: snapshot.calendar, accountLabel: snapshot.accountLabel,
            calendarLabel: snapshot.calendarLabel, writable: snapshot.writable, event: event)
    }
    static func make(id: UUID, change: CalendarMutation, snapshot: CalendarActionSnapshot) throws
        -> ActionReviewDisplay
    {
        guard snapshot.calendar == change.target, snapshot.writable else {
            throw ActionFailure.denied
        }
        let account = try text(snapshot.accountLabel, limit: 256)
        let calendar = try text(snapshot.calendarLabel, limit: 256)
        guard !account.isEmpty, !calendar.isEmpty else { throw ActionFailure.invalid }
        var rows: [ActionReviewDisplay.Row] = []
        var scope = "One new event"
        switch change {
        case .create(_, let event):
            guard snapshot.event == nil else { throw ActionFailure.invalid }
            rows = [
                .init("Title", nil, try displayText(event.title)),
                .init("Time", nil, try time(event.time)),
                .init("Availability", nil, occupancy(event.occupancy)),
                .init("Location", nil, try displayText(event.location)),
                .init("Notes", nil, try displayText(event.notes, multiline: true)),
            ]
        case .update(let target, _, let revision), .delete(let target, let revision):
            guard let event = snapshot.event, event.id == target, event.revision == revision,
                revision != .unknown, event.status == .active
            else { throw ActionFailure.stale }
            scope =
                target.originalAnchor == .notRecurring
                ? "This event only" : "This occurrence only; no series-wide change"
            let title = try value(event.title)
            if case .delete = change {
                rows = [.init("Title", title, nil), .init("Time", try time(event.time), nil)]
            } else if case .update(_, let changes, _) = change {
                rows = [.init("Event", title, title)]
                func add<T>(
                    _ label: String, _ patch: ValueChange<T>, _ before: String,
                    _ display: (T) throws -> String
                ) throws {
                    if case .set(let new) = patch {
                        rows.append(.init(label, before, try display(new)))
                    }
                }
                try add("Title", changes.title, title) { try displayText($0) }
                try add("Time", changes.time, time(event.time)) { try time($0) }
                try add("Availability", changes.occupancy, occupancy(event.occupancy)) {
                    occupancy($0)
                }
                if changes.location.isChanged {
                    try add("Location", changes.location, value(event.location)) {
                        try displayText($0)
                    }
                }
                if changes.notes.isChanged {
                    try add("Notes", changes.notes, value(event.notes, multiline: true)) {
                        try displayText($0, multiline: true)
                    }
                }
                guard rows.contains(where: { $0.before != $0.after }) else {
                    throw ActionFailure.invalid
                }
            }
        }
        guard
            rows.reduce(0, { $0 + ($1.before?.utf8.count ?? 0) + ($1.after?.utf8.count ?? 0) })
                <= 32768
        else { throw ActionFailure.capacity }
        return ActionReviewDisplay(
            id: id, kind: change.kind, account: account, calendar: calendar, rows: rows,
            scope: scope)
    }
}

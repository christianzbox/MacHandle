import CoreDomain
import Foundation
import PermissionEngine

package enum ReminderActionReview {
    static func title(_ value: String) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ActionFailure.invalid
        }
        return try CalendarActionReview.text(value, limit: 512)
    }
    package static func validate(_ change: ReminderMutation) throws {
        switch change {
        case .create(_, let draft):
            _ = try title(draft.title)
            _ = try CalendarActionReview.text(draft.notes ?? "", multiline: true)
        case .update(_, let patch, _):
            if case .set(let t) = patch.title { _ = try title(t) }
            if case .set(let n) = patch.notes {
                _ = try CalendarActionReview.text(n ?? "", multiline: true)
            }
        default: break
        }
    }
    static func due(_ value: ReminderDue?) -> String {
        guard let value else { return "Not set (no alarm change)" }
        func date(_ d: LocalDate) -> String {
            String(format: "%04d-%02d-%02d", d.year, d.month, d.day)
        }
        switch value {
        case .date(let d): return "\(date(d)) · date only; no alarm change"
        case .localDateTime(let d, let t, let zone):
            return
                "\(date(d)) \(String(format: "%02d:%02d:%02d", t.hour, t.minute, t.second)) · \(zone?.rawValue ?? "floating local time"); no alarm change"
        }
    }
    static func completion(_ value: ReminderCompletion) -> String {
        switch value {
        case .incomplete: "Incomplete; no completion date"
        case .completed(let at):
            at.map { "Completed · epoch seconds \($0.date.timeIntervalSince1970)" }
                ?? "Completed; completion date unknown"
        }
    }
    static func value<T>(_ field: FieldValue<T>) throws -> T {
        guard case .value(let value) = field else { throw ActionFailure.invalid }
        return value
    }
    package static func project(_ snapshot: ReminderActionSnapshot, fields: Set<ReminderField>)
        -> ReminderActionSnapshot
    {
        let reminder = snapshot.reminder.map {
            Reminder(
                id: $0.id, title: fields.contains(.title) ? $0.title : .notFetched,
                notes: fields.contains(.notes) ? $0.notes : .notFetched,
                due: fields.contains(.due) ? $0.due : .notFetched,
                completion: fields.contains(.completion) ? $0.completion : .notFetched,
                recurrence: fields.contains(.recurrence) ? $0.recurrence : .notFetched,
                revision: $0.revision)
        }
        return ReminderActionSnapshot(
            list: snapshot.list, accountLabel: snapshot.accountLabel,
            listLabel: snapshot.listLabel, writable: snapshot.writable, reminder: reminder)
    }
    static func make(id: UUID, change: ReminderMutation, snapshot: ReminderActionSnapshot) throws
        -> ReminderReviewDisplay
    {
        guard snapshot.list == change.target, snapshot.writable else { throw ActionFailure.denied }
        let account = try CalendarActionReview.text(snapshot.accountLabel, limit: 256)
        let list = try CalendarActionReview.text(snapshot.listLabel, limit: 256)
        guard !account.isEmpty, !list.isEmpty else { throw ActionFailure.invalid }
        var rows: [ActionReviewDisplay.Row] = []
        func text(_ value: String?) throws -> String {
            try CalendarActionReview.displayText(value, multiline: true)
        }
        if case .create(_, let draft) = change {
            guard snapshot.reminder == nil else { throw ActionFailure.invalid }
            rows = [
                .init("Title", nil, try text(draft.title)),
                .init("Notes", nil, try text(draft.notes)),
                .init("Due", nil, due(draft.due)), .init("Completion", nil, "Incomplete"),
                .init("Recurrence", nil, "Does not repeat"),
            ]
        } else {
            guard let reminder = snapshot.reminder, reminder.id == change.item,
                case .revision = reminder.revision, reminder.revision == change.precondition,
                reminder.recurrence == .value(.notRecurring)
            else { throw ActionFailure.stale }
            let title = try text(value(reminder.title))
            let oldDue = try due(value(reminder.due))
            let completed = try value(reminder.completion)
            rows = [
                .init("Reminder", title, title), .init("Due", oldDue, oldDue),
                .init("Completion", completion(completed), completion(completed)),
            ]
            switch change {
            case .create: throw ActionFailure.invalid
            case .update(_, let changes, _):
                if case .set(let t) = changes.title {
                    rows.append(.init("Title", title, try text(t)))
                }
                if case .set(let n) = changes.notes {
                    rows.append(.init("Notes", try text(value(reminder.notes)), try text(n)))
                }
            case .setDue(_, let new, _): rows.append(.init("Due change", oldDue, due(new)))
            case .complete:
                guard completed == .incomplete else { throw ActionFailure.invalid }
                rows.append(
                    .init(
                        "Completion change", completion(completed),
                        "Completed; timestamp recorded at execution"))
            case .uncomplete:
                guard case .completed = completed else { throw ActionFailure.invalid }
                rows.append(
                    .init(
                        "Completion change", completion(completed),
                        "Incomplete; completion date cleared"))
            case .delete:
                rows = rows.map { .init($0.field, $0.before, nil) }
            }
            guard rows.contains(where: { $0.before != $0.after }) else {
                throw ActionFailure.invalid
            }
        }
        guard
            rows.reduce(0, { $0 + ($1.before?.utf8.count ?? 0) + ($1.after?.utf8.count ?? 0) })
                <= 32768
        else { throw ActionFailure.capacity }
        return ReminderReviewDisplay(
            id: id, kind: change.kind, account: account, list: list, rows: rows,
            scope: "One nonrecurring reminder. No list move, recurrence-rule or alarm edits.")
    }
}

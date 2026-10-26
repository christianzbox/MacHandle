public struct ReminderList: Hashable, Sendable {
    public let id: ReminderListReference
    public let name: String

    public init(id: ReminderListReference, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ReminderReference: Hashable, Sendable {
    public let list: ReminderListReference
    public let item: ReminderID

    public init(list: ReminderListReference, item: ReminderID) {
        self.list = list
        self.item = item
    }
}

public enum ReminderCompletion: Hashable, Sendable {
    case incomplete
    case completed(at: Instant?)
}

/// Due date, completion, and alarms are distinct. Alarm/recurrence adapters belong to PR-22/23.
public struct Reminder: Hashable, Sendable {
    public let id: ReminderReference
    public let title: FieldValue<String>
    public let notes: FieldValue<String?>
    public let due: FieldValue<ReminderDue?>
    public let completion: FieldValue<ReminderCompletion>
    public let revision: MutationPrecondition

    public init(
        id: ReminderReference, title: FieldValue<String> = .notFetched,
        notes: FieldValue<String?> = .notFetched, due: FieldValue<ReminderDue?> = .notFetched,
        completion: FieldValue<ReminderCompletion> = .notFetched,
        revision: MutationPrecondition = .unknown
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.due = due
        self.completion = completion
        self.revision = revision
    }
}

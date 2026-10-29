public struct ReminderList: Hashable, Sendable {
    public let id: ReminderListReference
    public let name: String
    public let accountName: String?

    public init(id: ReminderListReference, name: String, accountName: String? = nil) {
        self.id = id
        self.name = name
        self.accountName = accountName
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

/// Due, completion and alarms are distinct. Recurrence is presence only; recurring mutations require a separate verified capability.
public struct Reminder: Hashable, Sendable {
    public let id: ReminderReference
    public let title: FieldValue<String>
    public let notes: FieldValue<String?>
    public let due: FieldValue<ReminderDue?>
    public let completion: FieldValue<ReminderCompletion>
    public let recurrence: FieldValue<ReminderRecurrence>
    public let revision: MutationPrecondition

    public init(
        id: ReminderReference, title: FieldValue<String> = .notFetched,
        notes: FieldValue<String?> = .notFetched, due: FieldValue<ReminderDue?> = .notFetched,
        completion: FieldValue<ReminderCompletion> = .notFetched,
        recurrence: FieldValue<ReminderRecurrence> = .notFetched,
        revision: MutationPrecondition = .unknown
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.due = due
        self.completion = completion
        self.recurrence = recurrence
        self.revision = revision
    }
}

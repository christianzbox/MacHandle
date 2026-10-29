public enum CalendarOperation: Hashable, Sendable {
    case discover, readSummary, readDetails, checkAvailability, create, update, delete
}

public enum ReminderOperation: Hashable, Sendable {
    case discover, readSummary, readDetails, create, update, delete, complete, uncomplete,
        changeDueDate
}

public enum ContactOperation: Hashable, Sendable {
    case discover, search, readFields, create, update, delete
}

/// A patch distinguishes keeping a value from explicitly clearing an optional value.
public enum ValueChange<Value: Hashable & Sendable>: Hashable, Sendable {
    case unchanged
    case set(Value)

    public var isChanged: Bool {
        if case .set = self { return true }
        return false
    }
}

public struct EventDraft: Hashable, Sendable {
    public let title: String
    public let time: EventTime
    public let occupancy: Occupancy
    public let location: String?
    public let notes: String?

    public init(
        title: String, time: EventTime, occupancy: Occupancy, location: String? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.time = time
        self.occupancy = occupancy
        self.location = location
        self.notes = notes
    }
}

public struct EventChanges: Hashable, Sendable {
    public let title: ValueChange<String>
    public let time: ValueChange<EventTime>
    public let occupancy: ValueChange<Occupancy>
    public let location: ValueChange<String?>
    public let notes: ValueChange<String?>

    public init(
        title: ValueChange<String> = .unchanged, time: ValueChange<EventTime> = .unchanged,
        occupancy: ValueChange<Occupancy> = .unchanged,
        location: ValueChange<String?> = .unchanged, notes: ValueChange<String?> = .unchanged
    ) throws {
        guard
            title.isChanged || time.isChanged || occupancy.isChanged || location.isChanged
                || notes.isChanged
        else { throw DomainValidationError.emptyChange }
        self.title = title
        self.time = time
        self.occupancy = occupancy
        self.location = location
        self.notes = notes
    }
}

public enum CalendarMutation: Hashable, Sendable {
    case create(in: CalendarReference, event: EventDraft)
    case update(OccurrenceReference, changes: EventChanges, precondition: MutationPrecondition)
    case delete(OccurrenceReference, precondition: MutationPrecondition)

    public var operation: CalendarOperation {
        switch self {
        case .create: .create
        case .update: .update
        case .delete: .delete
        }
    }
}

public struct ReminderDraft: Hashable, Sendable {
    public let title: String
    public let notes: String?
    public let due: ReminderDue?

    public init(title: String, notes: String? = nil, due: ReminderDue? = nil) {
        self.title = title
        self.notes = notes
        self.due = due
    }
}

public struct ReminderChanges: Hashable, Sendable {
    public let title: ValueChange<String>
    public let notes: ValueChange<String?>

    public init(title: ValueChange<String> = .unchanged, notes: ValueChange<String?> = .unchanged)
        throws
    {
        guard title.isChanged || notes.isChanged else { throw DomainValidationError.emptyChange }
        self.title = title
        self.notes = notes
    }
}

public enum ReminderMutation: Hashable, Sendable {
    case create(in: ReminderListReference, reminder: ReminderDraft)
    case update(ReminderReference, changes: ReminderChanges, precondition: MutationPrecondition)
    case setDue(ReminderReference, due: ReminderDue?, precondition: MutationPrecondition)
    case complete(ReminderReference, precondition: MutationPrecondition)
    case uncomplete(ReminderReference, precondition: MutationPrecondition)
    case delete(ReminderReference, precondition: MutationPrecondition)

    public var operation: ReminderOperation {
        switch self {
        case .create: .create
        case .update: .update
        case .setDue: .changeDueDate
        case .complete: .complete
        case .uncomplete: .uncomplete
        case .delete: .delete
        }
    }
}

public struct ContactChanges: Hashable, Sendable {
    public let name: ValueChange<ContactName>
    public let emailAddresses: ValueChange<[LabeledValue<String>]>
    public let phoneNumbers: ValueChange<[LabeledValue<String>]>
    public let postalAddresses: ValueChange<[LabeledValue<PostalAddress>]>
    public let organization: ValueChange<String?>
    public let notes: ValueChange<String?>

    public init(
        name: ValueChange<ContactName> = .unchanged,
        emailAddresses: ValueChange<[LabeledValue<String>]> = .unchanged,
        phoneNumbers: ValueChange<[LabeledValue<String>]> = .unchanged,
        postalAddresses: ValueChange<[LabeledValue<PostalAddress>]> = .unchanged,
        organization: ValueChange<String?> = .unchanged, notes: ValueChange<String?> = .unchanged
    ) throws {
        guard
            name.isChanged || emailAddresses.isChanged || phoneNumbers.isChanged
                || postalAddresses.isChanged || organization.isChanged || notes.isChanged
        else { throw DomainValidationError.emptyChange }
        self.name = name
        self.emailAddresses = emailAddresses
        self.phoneNumbers = phoneNumbers
        self.postalAddresses = postalAddresses
        self.organization = organization
        self.notes = notes
    }

    public var changedFields: Set<ContactField> {
        var fields: Set<ContactField> = []
        if name.isChanged { fields.insert(.name) }
        if emailAddresses.isChanged { fields.insert(.emailAddresses) }
        if phoneNumbers.isChanged { fields.insert(.phoneNumbers) }
        if postalAddresses.isChanged { fields.insert(.postalAddresses) }
        if organization.isChanged { fields.insert(.organization) }
        if notes.isChanged { fields.insert(.notes) }
        return fields
    }
}

public enum ContactMutation: Hashable, Sendable {
    case create(in: ContactContainerReference, fields: ContactChanges)
    case update(ContactRecordReference, changes: ContactChanges, precondition: MutationPrecondition)
    case delete(ContactRecordReference, precondition: MutationPrecondition)

    public var operation: ContactOperation {
        switch self {
        case .create: .create
        case .update: .update
        case .delete: .delete
        }
    }
}

/// Exact immutable proposal, not approval. IDs and caller-supplied values confer no authority.
/// Trusted approval code separately binds authentication, policy generation, expiry and single use.
public struct ProposedChange<Change: Hashable & Sendable>: Hashable, Sendable {
    public let id: OperationID
    public let connection: ConnectionID
    public let change: Change

    public init(id: OperationID, connection: ConnectionID, change: Change) {
        self.id = id
        self.connection = connection
        self.change = change
    }
}

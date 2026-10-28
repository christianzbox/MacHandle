import CoreDomain

public enum CalendarField: Hashable, Sendable {
    case time, occupancy, status, title, location, notes
}

public enum ReminderField: Hashable, Sendable {
    case title, notes, due, completion, recurrence
}

/// Grants are explicit and independent; an operation never implies another operation or field.
public struct ResourceGrant<Operation: Hashable & Sendable, Field: Hashable & Sendable>:
    Hashable, Sendable
{
    public let operations: Set<Operation>
    public let readableFields: Set<Field>
    public let writableFields: Set<Field>

    public init(
        operations: Set<Operation> = [], readableFields: Set<Field> = [],
        writableFields: Set<Field> = []
    ) {
        self.operations = operations
        self.readableFields = readableFields
        self.writableFields = writableFields
    }
}

public typealias CalendarGrant = ResourceGrant<CalendarOperation, CalendarField>
public typealias ReminderGrant = ResourceGrant<ReminderOperation, ReminderField>

public enum ContactSelection: Hashable, Sendable {
    case records(Set<ContactID>)
    case allRecords

    func contains(_ id: ContactID) -> Bool {
        switch self {
        case .records(let ids): ids.contains(id)
        case .allRecords: true
        }
    }
}

public struct ContactGrant: Hashable, Sendable {
    public let selection: ContactSelection
    public let access: ResourceGrant<ContactOperation, ContactField>

    public init(
        selection: ContactSelection = .records([]),
        access: ResourceGrant<ContactOperation, ContactField> = .init()
    ) {
        self.selection = selection
        self.access = access
    }
}

/// Keys are exact provider/store/account/resource references, never names or bare local IDs.
public struct ConnectionPolicy: Hashable, Sendable {
    public let calendars: [CalendarReference: CalendarGrant]
    public let reminderLists: [ReminderListReference: ReminderGrant]
    public let contactContainers: [ContactContainerReference: ContactGrant]

    public init(
        calendars: [CalendarReference: CalendarGrant] = [:],
        reminderLists: [ReminderListReference: ReminderGrant] = [:],
        contactContainers: [ContactContainerReference: ContactGrant] = [:]
    ) {
        self.calendars = calendars
        self.reminderLists = reminderLists
        self.contactContainers = contactContainers
    }
}

/// Trusted provider observations only. A session cannot set these or request OS permission.
public struct OSPermissions: Hashable, Sendable {
    public let calendars: OSAuthorization
    public let reminders: OSAuthorization
    public let contacts: OSAuthorization

    public init(
        calendars: OSAuthorization = .notDetermined, reminders: OSAuthorization = .notDetermined,
        contacts: OSAuthorization = .notDetermined
    ) {
        self.calendars = calendars
        self.reminders = reminders
        self.contacts = contacts
    }
}

public struct ContactQuery: Hashable, Sendable {
    public let containers: Set<ContactContainerReference>
    public let operation: ContactOperation
    public let fields: Set<ContactField>
    /// Search must not infer hidden fields through matching; adapters must honor this set.
    public let searchFields: Set<ContactField>

    public init(
        containers: Set<ContactContainerReference>, operation: ContactOperation,
        fields: Set<ContactField>, searchFields: Set<ContactField> = []
    ) {
        self.containers = containers
        self.operation = operation
        self.fields = fields
        self.searchFields = searchFields
    }
}

public enum PolicyRequest: Hashable, Sendable {
    case calendarDiscovery(Set<CalendarReference>)
    case calendarRead(CalendarReadRequest, operation: CalendarOperation, fields: Set<CalendarField>)
    case calendarMutation(ProposedChange<CalendarMutation>)
    /// Point-read fields needed for an exact local mutation review, never write approval.
    case calendarMutationReview(ProposedChange<CalendarMutation>, fields: Set<CalendarField>)
    case reminderDiscovery(Set<ReminderListReference>)
    case reminderRead(
        Set<ReminderListReference>, operation: ReminderOperation, fields: Set<ReminderField>)
    case reminderMutation(ProposedChange<ReminderMutation>)
    case contactDiscovery(Set<ContactContainerReference>)
    case contactRead(ContactQuery)
    case contactMutation(ProposedChange<ContactMutation>)

    var isMutation: Bool {
        switch self {
        case .calendarMutation, .reminderMutation, .contactMutation: true
        default: false
        }
    }
}

/// Sanitized deterministic reasons; no resource contents or grant inventories in diagnostics.
public enum PolicyDenial: Error, Equatable, Sendable {
    case unknownConnection, disabled, revoked, staleContext, foreignPermit, identityMismatch
    case osDenied, resourceNotSelected, operationNotAllowed, fieldNotAllowed, invalidRequest
    case unresolvedTarget, missingPrecondition, sourceWritesForbidden, responseScopeMismatch
}

public enum PolicyDecision: Sendable {
    case allowed(PolicyPermit)
    case denied(PolicyDenial)
}

public enum PolicyResult<Value: Sendable>: Sendable {
    case value(Value)
    case denied(PolicyDenial)
}

/// Availability projection deliberately omits calendar and event identifiers.
public struct PermittedAvailability: Sendable {
    public let window: InstantInterval
    public let blocks: [AvailabilityBlock]
    public let observation: ObservationState
}

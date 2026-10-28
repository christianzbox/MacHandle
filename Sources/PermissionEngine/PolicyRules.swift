import CoreDomain

/// Pure decisions over trusted configuration and a typed request; no clock, I/O or cached allows.
enum PolicyRules {
    static let calendarSummary: Set<CalendarField> = [.time, .occupancy, .status, .title]
    static let calendarRequired: Set<CalendarField> = [.time, .occupancy, .status]
    static let availabilityFields: Set<CalendarField> = [.time, .occupancy]
    static let reminderSummary: Set<ReminderField> = [.title, .due, .completion, .recurrence]

    static func denial(
        for request: PolicyRequest, connection: Connection, policy: ConnectionPolicy,
        os: OSPermissions
    ) -> PolicyDenial? {
        switch request {
        case .calendarDiscovery(let calendars):
            guard os.calendars == .fullAccess else { return .osDenied }
            return selected(calendars, grants: policy.calendars, operation: .discover, fields: [])
        case .calendarRead(let read, let operation, let fields):
            guard os.calendars == .fullAccess else { return .osDenied }
            switch operation {
            case .checkAvailability:
                guard fields == availabilityFields else { return .invalidRequest }
            case .readSummary:
                guard calendarRequired.isSubset(of: fields), fields.isSubset(of: calendarSummary)
                else {
                    return .invalidRequest
                }
            case .readDetails:
                guard calendarRequired.isSubset(of: fields) else { return .invalidRequest }
            default: return .invalidRequest
            }
            return selected(
                read.calendars, grants: policy.calendars, operation: operation, fields: fields)
        case .calendarMutationReview(let proposal, let fields):
            if let denied = denial(
                for: .calendarMutation(proposal), connection: connection, policy: policy, os: os)
            {
                return denied
            }
            let calendar: CalendarReference
            switch proposal.change {
            case .create: return .invalidRequest
            case .update(let reference, _, _), .delete(let reference, _):
                calendar = reference.calendar
            }
            guard calendarRequired.isSubset(of: fields) else { return .invalidRequest }
            return selected(
                [calendar], grants: policy.calendars, operation: .readDetails, fields: fields)
        case .calendarMutation(let proposal):
            guard proposal.connection == connection.id else { return .identityMismatch }
            // These are SOURCE resource policies. Google destination writes have a separate future owner.
            guard connection.kind != .googleSync else { return .sourceWritesForbidden }
            guard os.calendars == .fullAccess else { return .osDenied }
            return calendarMutation(proposal.change, policy: policy)
        case .reminderDiscovery(let lists):
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.reminders == .fullAccess else { return .osDenied }
            return selected(lists, grants: policy.reminderLists, operation: .discover, fields: [])
        case .reminderRead(let lists, let operation, let fields):
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.reminders == .fullAccess else { return .osDenied }
            guard !fields.isEmpty,
                operation == .readDetails
                    || (operation == .readSummary && fields.isSubset(of: reminderSummary))
            else { return .invalidRequest }
            return selected(
                lists, grants: policy.reminderLists, operation: operation, fields: fields)
        case .reminderMutation(let proposal):
            guard proposal.connection == connection.id else { return .identityMismatch }
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.reminders == .fullAccess else { return .osDenied }
            return reminderMutation(proposal.change, policy: policy)
        case .contactDiscovery(let containers):
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.contacts == .fullAccess else { return .osDenied }
            guard !containers.isEmpty else { return .invalidRequest }
            guard containers.allSatisfy({ policy.contactContainers[$0] != nil }) else {
                return .resourceNotSelected
            }
            guard
                containers.allSatisfy({
                    policy.contactContainers[$0]?.access.operations.contains(.discover) == true
                })
            else {
                return .operationNotAllowed
            }
            return nil
        case .contactRead(let query):
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.contacts == .fullAccess else { return .osDenied }
            guard !query.containers.isEmpty, !query.fields.isEmpty else { return .invalidRequest }
            switch query.operation {
            case .search:
                guard !query.searchFields.isEmpty else { return .invalidRequest }
            case .readFields:
                guard query.searchFields.isEmpty else { return .invalidRequest }
            default: return .invalidRequest
            }
            // Separate passes keep denial precedence independent of Set iteration order.
            guard query.containers.allSatisfy({ policy.contactContainers[$0] != nil }) else {
                return .resourceNotSelected
            }
            guard
                query.containers.allSatisfy({
                    hasSelection(policy.contactContainers[$0]!.selection)
                })
            else {
                return .resourceNotSelected
            }
            guard
                query.containers.allSatisfy({
                    policy.contactContainers[$0]!.access.operations.contains(query.operation)
                })
            else {
                return .operationNotAllowed
            }
            guard
                query.containers.allSatisfy({
                    query.fields.union(query.searchFields).isSubset(
                        of: policy.contactContainers[$0]!.access.readableFields)
                })
            else {
                return .fieldNotAllowed
            }
            return nil
        case .contactMutation(let proposal):
            guard proposal.connection == connection.id else { return .identityMismatch }
            guard connection.kind != .googleSync else { return .operationNotAllowed }
            guard os.contacts == .fullAccess else { return .osDenied }
            return contactMutation(proposal.change, policy: policy)
        }
    }

    private static func selected<
        Key: Hashable, Operation: Hashable & Sendable, Field: Hashable & Sendable
    >(
        _ keys: Set<Key>, grants: [Key: ResourceGrant<Operation, Field>], operation: Operation,
        fields: Set<Field>
    ) -> PolicyDenial? {
        guard !keys.isEmpty else { return .invalidRequest }
        guard keys.allSatisfy({ grants[$0] != nil }) else { return .resourceNotSelected }
        guard keys.allSatisfy({ grants[$0]!.operations.contains(operation) }) else {
            return .operationNotAllowed
        }
        guard keys.allSatisfy({ fields.isSubset(of: grants[$0]!.readableFields) }) else {
            return .fieldNotAllowed
        }
        return nil
    }

    private static func write<Operation: Hashable & Sendable, Field: Hashable & Sendable>(
        grant: ResourceGrant<Operation, Field>?, operation: Operation, fields: Set<Field>
    ) -> PolicyDenial? {
        guard let grant else { return .resourceNotSelected }
        guard grant.operations.contains(operation) else { return .operationNotAllowed }
        guard fields.isSubset(of: grant.writableFields), fields.isSubset(of: grant.readableFields)
        else {
            return .fieldNotAllowed
        }
        return nil
    }

    private static func hasSelection(_ selection: ContactSelection) -> Bool {
        switch selection {
        case .allRecords: true
        case .records(let ids): !ids.isEmpty
        }
    }

    private static func preconditionDenial(_ precondition: MutationPrecondition) -> PolicyDenial? {
        if case .unknown = precondition { return .missingPrecondition }
        return nil
    }

    private static func calendarMutation(_ change: CalendarMutation, policy: ConnectionPolicy)
        -> PolicyDenial?
    {
        let target: CalendarReference
        var fields: Set<CalendarField> = []
        var existing: (OccurrenceReference, MutationPrecondition)?
        switch change {
        case .create(let calendar, let event):
            target = calendar
            fields = [.title, .time, .occupancy]
            if event.location != nil { fields.insert(.location) }
            if event.notes != nil { fields.insert(.notes) }
        case .update(let occurrence, let changes, let precondition):
            target = occurrence.calendar
            existing = (occurrence, precondition)
            if changes.title.isChanged { fields.insert(.title) }
            if changes.time.isChanged { fields.insert(.time) }
            if changes.occupancy.isChanged { fields.insert(.occupancy) }
            if changes.location.isChanged { fields.insert(.location) }
            if changes.notes.isChanged { fields.insert(.notes) }
        case .delete(let occurrence, let precondition):
            target = occurrence.calendar
            existing = (occurrence, precondition)
        }
        let grant = policy.calendars[target]
        if let denial = write(grant: grant, operation: change.operation, fields: fields) {
            return denial
        }
        if let (occurrence, precondition) = existing {
            guard occurrence.originalAnchor != .unknown else { return .unresolvedTarget }
            if let denial = preconditionDenial(precondition) { return denial }
        }
        if case .delete = change {
            guard grant?.operations.contains(.readDetails) == true else {
                return .operationNotAllowed
            }
            guard Set<CalendarField>([.title, .time]).isSubset(of: grant?.readableFields ?? [])
            else { return .fieldNotAllowed }
        }
        return nil
    }

    private static func reminderMutation(_ change: ReminderMutation, policy: ConnectionPolicy)
        -> PolicyDenial?
    {
        let list: ReminderListReference
        var fields: Set<ReminderField> = []
        var precondition: MutationPrecondition?
        switch change {
        case .create(let target, let reminder):
            list = target
            fields = [.title]
            if reminder.notes != nil { fields.insert(.notes) }
            if reminder.due != nil { fields.insert(.due) }
        case .update(let target, let changes, let expected):
            list = target.list
            precondition = expected
            if changes.title.isChanged { fields.insert(.title) }
            if changes.notes.isChanged { fields.insert(.notes) }
        case .setDue(let target, _, let expected):
            list = target.list
            precondition = expected
            fields = [.due]
        case .complete(let target, let expected):
            list = target.list
            precondition = expected
            fields = [.completion]
        case .delete(let target, let expected):
            list = target.list
            precondition = expected
        }
        let grant = policy.reminderLists[list]
        if let denial = write(grant: grant, operation: change.operation, fields: fields) {
            return denial
        }
        if let precondition, let denial = preconditionDenial(precondition) { return denial }
        if case .delete = change {
            guard grant?.operations.contains(.readDetails) == true else {
                return .operationNotAllowed
            }
            guard grant?.readableFields.contains(.title) == true else { return .fieldNotAllowed }
        }
        return nil
    }

    private static func contactMutation(_ change: ContactMutation, policy: ConnectionPolicy)
        -> PolicyDenial?
    {
        let container: ContactContainerReference
        var record: ContactRecordReference?
        var fields: Set<ContactField> = []
        var precondition: MutationPrecondition?
        switch change {
        case .create(let target, let changes):
            container = target
            fields = changes.changedFields
        case .update(let target, let changes, let expected):
            container = target.container
            record = target
            fields = changes.changedFields
            precondition = expected
        case .delete(let target, let expected):
            container = target.container
            record = target
            precondition = expected
        }
        guard let grant = policy.contactContainers[container] else { return .resourceNotSelected }
        if let record {
            guard grant.selection.contains(record.item) else { return .resourceNotSelected }
        } else {
            // A new record is not in an existing explicit subset. Creation needs whole-container consent.
            guard grant.selection == .allRecords else { return .resourceNotSelected }
        }
        if let denial = write(grant: grant.access, operation: change.operation, fields: fields) {
            return denial
        }
        if let precondition, let denial = preconditionDenial(precondition) { return denial }
        if case .delete = change {
            guard grant.access.operations.contains(.readFields) else { return .operationNotAllowed }
            guard grant.access.readableFields.contains(.name) else { return .fieldNotAllowed }
        }
        return nil
    }
}

import CoreDomain

extension PolicyAuthority {
    /// No await between current-policy validation and projection. Call again after provider suspension.
    func filterCalendar(_ snapshot: CalendarSnapshot, permit: PolicyPermit, binding: SessionBinding)
        -> PolicyResult<CalendarSnapshot>
    {
        let policy: ConnectionPolicy
        switch checkedPolicy(permit, binding: binding) {
        case .failure(let denial): return .denied(denial)
        case .success(let current): policy = current
        }
        guard case .calendarRead(let read, let operation, let fields) = permit.request,
            operation == .readDetails || operation == .readSummary, read == snapshot.coverage
        else { return .denied(.responseScopeMismatch) }
        let projected = snapshot.occurrences.map { event in
            let allowed = policy.calendars[event.id.calendar]?.readableFields ?? []
            return CalendarOccurrence(
                id: event.id, time: event.time, occupancy: event.occupancy, status: event.status,
                title: filtered(event.title, field: .title, requested: fields, allowed: allowed),
                location: filtered(
                    event.location, field: .location, requested: fields, allowed: allowed),
                notes: filtered(event.notes, field: .notes, requested: fields, allowed: allowed))
        }
        do {
            return .value(
                try CalendarSnapshot(
                    coverage: snapshot.coverage, occurrences: projected,
                    observation: snapshot.observation))
        } catch {
            return .denied(.responseScopeMismatch)
        }
    }

    func filterAvailability(
        _ snapshot: AvailabilitySnapshot, permit: PolicyPermit, binding: SessionBinding
    )
        -> PolicyResult<PermittedAvailability>
    {
        if case .failure(let reason) = checkedPolicy(permit, binding: binding) {
            return .denied(reason)
        }
        guard case .calendarRead(let read, .checkAvailability, _) = permit.request,
            read == snapshot.coverage
        else { return .denied(.responseScopeMismatch) }
        return .value(
            PermittedAvailability(
                window: read.window, blocks: snapshot.blocks, observation: snapshot.observation))
    }

    func filterReminders(_ reminders: [Reminder], permit: PolicyPermit, binding: SessionBinding)
        -> PolicyResult<[Reminder]>
    {
        let policy: ConnectionPolicy
        switch checkedPolicy(permit, binding: binding) {
        case .failure(let denial): return .denied(denial)
        case .success(let current): policy = current
        }
        guard case .reminderRead(let lists, _, let fields) = permit.request else {
            return .denied(.responseScopeMismatch)
        }
        return .value(
            reminders.filter { lists.contains($0.id.list) }.map { reminder in
                let allowed = policy.reminderLists[reminder.id.list]?.readableFields ?? []
                return Reminder(
                    id: reminder.id,
                    title: filtered(
                        reminder.title, field: .title, requested: fields, allowed: allowed),
                    notes: filtered(
                        reminder.notes, field: .notes, requested: fields, allowed: allowed),
                    due: filtered(reminder.due, field: .due, requested: fields, allowed: allowed),
                    completion: filtered(
                        reminder.completion, field: .completion, requested: fields, allowed: allowed
                    ),
                    recurrence: filtered(
                        reminder.recurrence, field: .recurrence, requested: fields, allowed: allowed
                    ))
            })
    }

    func filterContacts(_ contacts: [Contact], permit: PolicyPermit, binding: SessionBinding)
        -> PolicyResult<[Contact]>
    {
        let policy: ConnectionPolicy
        switch checkedPolicy(permit, binding: binding) {
        case .failure(let denial): return .denied(denial)
        case .success(let current): policy = current
        }
        guard case .contactRead(let query) = permit.request else {
            return .denied(.responseScopeMismatch)
        }
        var output: [Contact] = []
        for contact in contacts {
            // Unified fields cannot be attributed safely to selected underlying records yet.
            guard case .record(let record) = contact.id else { return .denied(.unresolvedTarget) }
            guard query.containers.contains(record.container),
                let grant = policy.contactContainers[record.container],
                grant.selection.contains(record.item)
            else { continue }
            let allowed = grant.access.readableFields
            output.append(
                Contact(
                    id: contact.id, linkedRecords: .notAuthorized,
                    name: filtered(
                        contact.name, field: .name, requested: query.fields, allowed: allowed),
                    emailAddresses: filtered(
                        contact.emailAddresses, field: .emailAddresses, requested: query.fields,
                        allowed: allowed),
                    phoneNumbers: filtered(
                        contact.phoneNumbers, field: .phoneNumbers, requested: query.fields,
                        allowed: allowed),
                    postalAddresses: filtered(
                        contact.postalAddresses, field: .postalAddresses, requested: query.fields,
                        allowed: allowed),
                    organization: filtered(
                        contact.organization, field: .organization, requested: query.fields,
                        allowed: allowed),
                    notes: filtered(
                        contact.notes, field: .notes, requested: query.fields, allowed: allowed)))
        }
        return .value(output)
    }

    func filterCalendarDiscovery(
        _ discovery: ResourceDiscovery<CalendarResource>, permit: PolicyPermit,
        binding: SessionBinding
    ) -> PolicyResult<ResourceDiscovery<CalendarResource>> {
        if case .failure(let reason) = checkedPolicy(permit, binding: binding) {
            return .denied(reason)
        }
        guard case .calendarDiscovery(let calendars) = permit.request else {
            return .denied(.responseScopeMismatch)
        }
        return .value(
            ResourceDiscovery(
                resources: discovery.resources.filter { calendars.contains($0.id) },
                observation: discovery.observation))
    }

    func filterReminderDiscovery(
        _ discovery: ResourceDiscovery<ReminderList>, permit: PolicyPermit, binding: SessionBinding
    ) -> PolicyResult<ResourceDiscovery<ReminderList>> {
        if case .failure(let reason) = checkedPolicy(permit, binding: binding) {
            return .denied(reason)
        }
        guard case .reminderDiscovery(let lists) = permit.request else {
            return .denied(.responseScopeMismatch)
        }
        return .value(
            ResourceDiscovery(
                resources: discovery.resources.filter { lists.contains($0.id) },
                observation: discovery.observation))
    }

    func filterContactDiscovery(
        _ discovery: ResourceDiscovery<ContactContainerReference>, permit: PolicyPermit,
        binding: SessionBinding
    ) -> PolicyResult<ResourceDiscovery<ContactContainerReference>> {
        if case .failure(let reason) = checkedPolicy(permit, binding: binding) {
            return .denied(reason)
        }
        guard case .contactDiscovery(let containers) = permit.request else {
            return .denied(.responseScopeMismatch)
        }
        return .value(
            ResourceDiscovery(
                resources: discovery.resources.filter { containers.contains($0) },
                observation: discovery.observation))
    }

    private func filtered<Value: Hashable & Sendable, Field: Hashable>(
        _ value: FieldValue<Value>, field: Field, requested: Set<Field>, allowed: Set<Field>
    ) -> FieldValue<Value> {
        guard allowed.contains(field) else { return .notAuthorized }
        guard requested.contains(field) else { return .notFetched }
        return value
    }
}

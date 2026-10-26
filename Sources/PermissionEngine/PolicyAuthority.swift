import CoreDomain
import Foundation

struct SessionBinding: Equatable, Sendable {
    let issuer: UUID
    let session: UUID
    let connection: ConnectionID
    let policyGeneration: UUID
    let osGeneration: UUID
}

/// No public constructor/decoder. This is a policy decision receipt, never write approval.
public struct PolicyPermit: Sendable {
    let binding: SessionBinding
    public let request: PolicyRequest

    /// Every mutation still needs the future trusted local approval and precondition gates.
    public var requiresLocalApproval: Bool { request.isMutation }
}

/// Narrow handle given to a bound caller. It cannot configure grants or select another identity.
public struct PolicySession: Sendable {
    let authority: PolicyAuthority
    let binding: SessionBinding

    public func evaluate(_ request: PolicyRequest) async -> PolicyDecision {
        await authority.evaluate(request, binding: binding)
    }

    public func revalidate(_ permit: PolicyPermit) async -> PolicyDecision {
        await authority.revalidate(permit, binding: binding)
    }

    public func filterCalendar(_ snapshot: CalendarSnapshot, using permit: PolicyPermit) async
        -> PolicyResult<CalendarSnapshot>
    {
        await authority.filterCalendar(snapshot, permit: permit, binding: binding)
    }

    public func filterAvailability(_ snapshot: AvailabilitySnapshot, using permit: PolicyPermit)
        async
        -> PolicyResult<PermittedAvailability>
    {
        await authority.filterAvailability(snapshot, permit: permit, binding: binding)
    }

    public func filterReminders(_ reminders: [Reminder], using permit: PolicyPermit) async
        -> PolicyResult<[Reminder]>
    {
        await authority.filterReminders(reminders, permit: permit, binding: binding)
    }

    public func filterContacts(_ contacts: [Contact], using permit: PolicyPermit) async
        -> PolicyResult<[Contact]>
    {
        await authority.filterContacts(contacts, permit: permit, binding: binding)
    }

    public func filterCalendarDiscovery(
        _ discovery: ResourceDiscovery<CalendarResource>, using permit: PolicyPermit
    ) async -> PolicyResult<ResourceDiscovery<CalendarResource>> {
        await authority.filterCalendarDiscovery(discovery, permit: permit, binding: binding)
    }

    public func filterReminderDiscovery(
        _ discovery: ResourceDiscovery<ReminderList>, using permit: PolicyPermit
    ) async -> PolicyResult<ResourceDiscovery<ReminderList>> {
        await authority.filterReminderDiscovery(discovery, permit: permit, binding: binding)
    }

    public func filterContactDiscovery(
        _ discovery: ResourceDiscovery<ContactContainerReference>, using permit: PolicyPermit
    ) async -> PolicyResult<ResourceDiscovery<ContactContainerReference>> {
        await authority.filterContactDiscovery(discovery, permit: permit, binding: binding)
    }
}

/// Trusted app/broker administration only. Never inject this handle into a transport/client.
/// Binding assumes the broker has independently established identity; this is not authentication.
public actor PolicyAuthority {
    struct Entry: Sendable {
        let connection: Connection
        let policy: ConnectionPolicy
        let generation: UUID
    }

    private let issuer = UUID()
    private var entries: [ConnectionID: Entry] = [:]
    private var permissions = OSPermissions()
    private var osGeneration = UUID()

    public init() {}

    /// Every replacement invalidates all existing sessions/permits for this connection.
    public func setConnection(_ connection: Connection, policy: ConnectionPolicy = .init()) {
        entries[connection.id] = Entry(connection: connection, policy: policy, generation: UUID())
    }

    public func removeConnection(_ id: ConnectionID) {
        entries.removeValue(forKey: id)
    }

    /// Revokes immediately in actor order. Re-enabling later never revives old sessions.
    public func revokeConnection(_ id: ConnectionID) {
        guard let entry = entries[id] else { return }
        setConnection(
            Connection(id: id, kind: entry.connection.kind, state: .revoked), policy: entry.policy)
    }

    public func observeOSPermissions(_ current: OSPermissions) {
        guard current != permissions else { return }
        permissions = current
        osGeneration = UUID()
    }

    public func bindTrustedConnection(_ id: ConnectionID) throws -> PolicySession {
        guard let entry = entries[id] else { throw PolicyDenial.unknownConnection }
        return PolicySession(
            authority: self,
            binding: SessionBinding(
                issuer: issuer, session: UUID(), connection: id,
                policyGeneration: entry.generation, osGeneration: osGeneration))
    }

    private func contextDenial(_ binding: SessionBinding) -> PolicyDenial? {
        guard binding.issuer == issuer else { return .foreignPermit }
        guard let entry = entries[binding.connection] else { return .unknownConnection }
        switch entry.connection.state {
        case .disabled: return .disabled
        case .revoked: return .revoked
        case .enabled: break
        }
        guard binding.policyGeneration == entry.generation, binding.osGeneration == osGeneration
        else {
            return .staleContext
        }
        return nil
    }

    func evaluate(_ request: PolicyRequest, binding: SessionBinding) -> PolicyDecision {
        if let denial = contextDenial(binding) { return .denied(denial) }
        guard let entry = entries[binding.connection] else { return .denied(.unknownConnection) }
        if let denial = PolicyRules.denial(
            for: request, connection: entry.connection, policy: entry.policy, os: permissions)
        {
            return .denied(denial)
        }
        return .allowed(PolicyPermit(binding: binding, request: request))
    }

    func revalidate(_ permit: PolicyPermit, binding: SessionBinding) -> PolicyDecision {
        guard permit.binding == binding else { return .denied(.foreignPermit) }
        return evaluate(permit.request, binding: binding)
    }

    func checkedPolicy(_ permit: PolicyPermit, binding: SessionBinding) -> Result<
        ConnectionPolicy, PolicyDenial
    > {
        if case .denied(let reason) = revalidate(permit, binding: binding) {
            return .failure(reason)
        }
        guard let entry = entries[binding.connection] else { return .failure(.unknownConnection) }
        return .success(entry.policy)
    }
}

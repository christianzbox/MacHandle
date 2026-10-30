import CoreDomain
import Foundation

struct ContactMembership: Sendable {
    let ids: [ContactID]
    let truncated: Bool
}
protocol ContactsBackend: Sendable {
    func authorization() async -> OSAuthorization
    func requestAccess() async -> OSAuthorization
    func containers() async throws -> [ContactContainer]
    func identifiers(
        in container: ContactContainerReference, limit: Int,
        check: @Sendable () throws -> Void
    ) async throws -> ContactMembership
    func fetch(
        _ records: [ContactRecordReference], fields: Set<ContactField>,
        check: @Sendable () throws -> Void
    ) async throws -> [Contact]
    func generation() async -> UInt64
    func changes() async -> AsyncStream<Void>
}

/// Native Contacts opt-in, independent from EventKit. No writer or policy administration.
public actor ContactsProvider: ContactDiscovering, ContactReading {
    private let backend: any ContactsBackend
    private var requesting = false
    private var reading = false
    public init() { backend = NativeContactsBackend() }
    init(backend: any ContactsBackend) { self.backend = backend }
    public func authorization() async -> OSAuthorization { await backend.authorization() }
    public func requestAccess() async -> OSAuthorization {
        let current = await authorization()
        guard current == .notDetermined else { return current }
        guard !requesting, !Task.isCancelled else { return .unknown }
        requesting = true
        defer { requesting = false }
        return await backend.requestAccess()
    }
    public func changes() async -> AsyncStream<Void> { await backend.changes() }
    private func inventory() async throws -> [ContactContainer] {
        let result = try await backend.containers()
        guard result.count <= 1000, Set(result.map(\.id)).count == result.count,
            result.allSatisfy({ $0.name.utf8.count <= 1024 })
        else { throw ProviderFailure.invalidData }
        return result
    }
    private func valid(_ generation: UInt64) async throws {
        try Task.checkCancellation()
        guard await authorization() == .fullAccess, await backend.generation() == generation
        else { throw ProviderFailure.unavailable }
        try Task.checkCancellation()
    }
    public func discoverContactContainers() async -> ProviderReadResult<
        ResourceDiscovery<ContactContainer>
    > {
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard await authorization() == .fullAccess else { return .failed(.denied) }
        let epoch = await backend.generation()
        do {
            let result = try await inventory()
            try await valid(epoch)
            return .observed(
                ResourceDiscovery(resources: result, observation: try observation(partial: false)))
        } catch { return .failed(Task.isCancelled ? .cancelled : .unavailable) }
    }
    private func observation(partial: Bool, missing: Bool = false) throws -> ObservationState {
        ObservationState(
            observedAt: try Instant(Date()),
            completeness: missing ? .unknown : (partial ? .partial(.providerLimit) : .complete),
            freshness: .localCache)
    }
    public func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>) async
        -> ProviderReadResult<ContactSnapshot>
    {
        guard !reading, !Task.isCancelled else { return .failed(.cancelled) }
        guard !fields.isEmpty, fields.isSubset(of: ContactReadCapabilities.fields) else {
            return .failed(.invalidData)
        }
        reading = true
        defer { reading = false }
        guard await authorization() == .fullAccess else { return .failed(.denied) }
        let epoch = await backend.generation()
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        let check: @Sendable () throws -> Void = {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw ProviderFailure.unavailable
            }
        }
        do {
            let before = try await inventory().filter { request.scopes[$0.id] != nil }
            guard before.count == request.scopes.count else { throw ProviderFailure.notFound }
            var records: [ContactRecordReference] = []
            var seen: Set<ContactID> = []
            var scanned = 0
            var partial = false
            for container in before.sorted(by: { $0.id.localID.rawValue < $1.id.localID.rawValue })
            {
                try check()
                try await valid(epoch)
                guard scanned < ContactSnapshot.maximumItems else {
                    partial = true
                    break
                }
                let membership = try await backend.identifiers(
                    in: container.id, limit: ContactSnapshot.maximumItems - scanned, check: check)
                guard membership.ids.count <= ContactSnapshot.maximumItems - scanned,
                    Set(membership.ids).count == membership.ids.count
                else { throw ProviderFailure.invalidData }
                scanned += membership.ids.count
                partial = partial || membership.truncated
                for id in membership.ids {
                    guard seen.insert(id).inserted else { throw ProviderFailure.ambiguousIdentity }
                    let ref = ContactRecordReference(container: container.id, item: id)
                    if request.contains(ref) { records.append(ref) }
                }
            }
            try await valid(epoch)
            let contacts =
                records.isEmpty
                ? [] : try await backend.fetch(records, fields: fields, check: check)
            guard Set(contacts.map(\.id)) == Set(records.map { ContactReference.record($0) }),
                contacts.count == records.count
            else {
                throw ProviderFailure.ambiguousIdentity
            }
            // Verify membership again after fetching fields. Never attach a guessed container to unified data.
            for container in before {
                let expected = Set(records.filter { $0.container == container.id }.map(\.item))
                if expected.isEmpty { continue }
                let membership = try await backend.identifiers(
                    in: container.id, limit: ContactSnapshot.maximumItems, check: check)
                guard expected.isSubset(of: Set(membership.ids)) else {
                    throw ProviderFailure.unavailable
                }
            }
            let after = try await inventory().filter { request.scopes[$0.id] != nil }
            guard Set(before) == Set(after) else { throw ProviderFailure.unavailable }
            try check()
            try await valid(epoch)
            return .observed(
                try ContactSnapshot(
                    coverage: request, contacts: contacts,
                    observation: observation(
                        partial: partial, missing: request.item != nil && contacts.isEmpty)))
        } catch { return .failed(Task.isCancelled ? .cancelled : .unavailable) }
    }
}

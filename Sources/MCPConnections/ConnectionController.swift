import CoreDomain
import Foundation
import PermissionEngine

package struct PendingConnection: Sendable {
    fileprivate let issuer: UUID
    fileprivate let channel: UUID
}
package struct PairingReview: Sendable {
    package let connection: SavedConnection
    fileprivate let issuer: UUID
    fileprivate let channel: UUID
    fileprivate let nonce: UUID
    fileprivate let expires: TimeInterval
}
package struct ConnectionAudit: Sendable {
    package enum Action: String, Sendable {
        case requested, peerRejected, expired, paired, closed, disabled, revoked, configured
        case osChanged, storageFailed, readPrepared, readDenied
    }
    package let sequence: UInt64
    package let action: Action
    package let connection: UUID?
    package let operation: ConnectionReadLease.ReadOperation?
}

/// Trusted broker administration, not an MCP tool or a client authentication assertion API.
package actor ConnectionController {
    private struct Pending {
        let channel: ConnectionChannel
        let expires: TimeInterval
        var nonce = UUID()
        var connection: UUID?
    }
    private struct Binding {
        let connection: UUID
        let gate: ReadGate
    }
    private let issuer = UUID()
    private let store: any ConnectionSettingsStore
    private let authority = PolicyAuthority()
    private let readBudget = ReadBudget()
    private let uptime: @Sendable () -> TimeInterval
    private var records: [UUID: SavedConnection]
    private var pending: [UUID: Pending] = [:]
    private var bindings: [UUID: Binding] = [:]
    private var permissions = OSPermissions()
    private var epoch: UInt64 = 0
    private var healthy = true
    private var audit: [ConnectionAudit] = []
    private var sequence: UInt64 = 0

    package init(
        store: any ConnectionSettingsStore,
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) throws {
        let loaded = try store.load()
        try SettingsEnvelope.validate(loaded)
        self.store = store
        self.uptime = uptime
        records = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        // No sessions, channels, enabled state or peer claims are restored from disk.
    }
    package func settings() throws -> [SavedConnection] {
        guard healthy else { throw ConnectionFailure.storage }
        return records.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    package func activity() -> [ConnectionAudit] { audit }
    private func log(
        _ action: ConnectionAudit.Action, _ id: UUID? = nil,
        operation: ConnectionReadLease.ReadOperation? = nil
    ) {
        sequence &+= 1
        audit.append(
            ConnectionAudit(
                sequence: sequence, action: action, connection: id, operation: operation))
        if audit.count > 256 { audit.removeFirst(audit.count - 256) }
    }
    private func expire() {
        let expired = pending.filter { $0.value.expires <= uptime() || !$0.value.channel.isOpen }
            .map(\.key)
        for id in expired {
            pending.removeValue(forKey: id)?.channel.close()
            log(.expired)
        }
    }
    private func closeMatching(_ connection: UUID? = nil) {
        for id in bindings.filter({ connection == nil || $0.value.connection == connection }).map(
            \.key)
        {
            bindings.removeValue(forKey: id)?.gate.invalidate()
        }
        for id in pending.filter({ connection == nil || $0.value.connection == connection }).map(
            \.key)
        {
            pending.removeValue(forKey: id)?.channel.close()
        }
    }
    private func persist(_ updated: [UUID: SavedConnection]) async throws {
        do {
            try store.save(Array(updated.values))
            records = updated
        } catch {
            healthy = false
            epoch &+= 1
            closeMatching()
            log(.storageFailed)
            for record in records.values {
                await authority.revokeConnection(try! ConnectionID(record.id.uuidString))
            }
            throw ConnectionFailure.storage
        }
    }
    package func configure(
        id: UUID? = nil, label: String, grants: [SavedCalendarGrant],
        reminderGrants: [SavedReminderGrant] = []
    )
        async throws -> SavedConnection
    {
        guard healthy else { throw ConnectionFailure.storage }
        if let id {
            guard let record = records[id], !record.revoked else { throw ConnectionFailure.denied }
        }
        let record = try SavedConnection(
            id: id ?? UUID(), label: label, grants: grants, reminderGrants: reminderGrants)
        guard id != nil || records.count < 32 else { throw ConnectionFailure.limit }
        epoch &+= 1
        closeMatching(record.id)
        var updated = records
        updated[record.id] = record
        try await persist(updated)
        await authority.revokeConnection(try! ConnectionID(record.id.uuidString))
        log(.configured, record.id)
        return record
    }
    package func disable(_ id: UUID) async throws { try await stop(id, revoked: false) }
    package func revoke(_ id: UUID) async throws { try await stop(id, revoked: true) }
    private func stop(_ id: UUID, revoked: Bool) async throws {
        guard healthy, let current = records[id] else { throw ConnectionFailure.denied }
        epoch &+= 1
        closeMatching(id)
        var updated = records
        updated[id] = try SavedConnection(
            id: id, label: current.label, grants: current.grants,
            reminderGrants: current.reminderGrants,
            revoked: current.revoked || revoked)
        // Close admission before any persistence or actor suspension, including write failures.
        try await persist(updated)
        await authority.revokeConnection(try! ConnectionID(id.uuidString))
        log(revoked ? .revoked : .disabled, id)
    }
    package func observePermissions(_ value: OSPermissions) async {
        guard permissions != value else { return }
        permissions = value
        epoch &+= 1
        closeMatching()
        log(.osChanged)
        await authority.observeOSPermissions(value)
    }
    package func requestPairing(_ channel: ConnectionChannel) async throws -> PendingConnection {
        expire()
        guard healthy, pending.count < 8, bindings.count + pending.count < 16,
            pending[channel.id] == nil, bindings[channel.id] == nil, channel.isOpen
        else {
            pending.removeValue(forKey: channel.id)?.channel.close()
            bindings.removeValue(forKey: channel.id)?.gate.invalidate()
            channel.close()
            throw ConnectionFailure.denied
        }
        pending[channel.id] = Pending(channel: channel, expires: uptime() + 60)
        guard await channel.verified(), healthy, let request = pending[channel.id],
            request.expires > uptime()
        else {
            pending.removeValue(forKey: channel.id)
            channel.close()
            log(.peerRejected)
            throw ConnectionFailure.denied
        }
        log(.requested)
        return PendingConnection(issuer: issuer, channel: channel.id)
    }
    /// Called only by trusted local review UI. The helper never receives a review or chooses a record.
    package func review(_ request: PendingConnection, connection id: UUID) throws -> PairingReview {
        expire()
        guard healthy, request.issuer == issuer, var waiting = pending[request.channel],
            let record = records[id], !record.revoked
        else { throw ConnectionFailure.denied }
        waiting.nonce = UUID()
        waiting.connection = id
        pending[request.channel] = waiting
        return PairingReview(
            connection: record, issuer: issuer, channel: request.channel, nonce: waiting.nonce,
            expires: waiting.expires)
    }
    package func approve(_ review: PairingReview) async throws -> ConnectionReadLease {
        expire()
        guard healthy, review.issuer == issuer, let waiting = pending[review.channel],
            waiting.nonce == review.nonce, waiting.connection == review.connection.id,
            waiting.expires == review.expires, review.expires > uptime(),
            let record = records[review.connection.id], !record.revoked,
            record.revision == review.connection.revision,
            record.grants.isEmpty || permissions.calendars == .fullAccess,
            record.reminderGrants.isEmpty || permissions.reminders == .fullAccess
        else { throw ConnectionFailure.denied }
        // Consume once, bind one launch, and invalidate any previous launch of this configuration.
        pending.removeValue(forKey: review.channel)
        closeMatching(record.id)
        let gate = ReadGate(channel: waiting.channel, budget: readBudget)
        bindings[review.channel] = Binding(connection: record.id, gate: gate)
        let generation = epoch
        func current() -> Bool {
            healthy && epoch == generation && gate.isOpen && uptime() < review.expires
                && records[record.id]?.revision == record.revision
                && records[record.id]?.revoked == false
                && bindings[review.channel]?.gate === gate
        }
        do {
            guard await waiting.channel.verified(), current() else {
                throw ConnectionFailure.denied
            }
            let id = try ConnectionID(record.id.uuidString)
            await authority.setConnection(
                Connection(id: id, kind: .localMCP, state: .enabled), policy: try record.policy)
            guard current() else { throw ConnectionFailure.stale }
            let session = try await authority.bindTrustedConnection(id)
            guard current() else { throw ConnectionFailure.stale }
            log(.paired, record.id)
            return ConnectionReadLease(
                session: session, selection: Set(try record.grants.map { try $0.reference }),
                reminderSelection: Set(try record.reminderGrants.map { try $0.reference }),
                gate: gate,
                audit: { [self] kind, success in
                    await self.log(
                        success ? .readPrepared : .readDenied, record.id, operation: kind)
                })
        } catch {
            gate.invalidate()
            if bindings[review.channel]?.gate === gate {
                bindings.removeValue(forKey: review.channel)
            }
            log(.peerRejected, record.id)
            throw ConnectionFailure.denied
        }
    }
    package func close(_ request: PendingConnection) async {
        guard request.issuer == issuer else { return }
        pending.removeValue(forKey: request.channel)?.channel.close()
        if let binding = bindings.removeValue(forKey: request.channel) {
            binding.gate.invalidate()
            await authority.revokeConnection(try! ConnectionID(binding.connection.uuidString))
            log(.closed, binding.connection)
        }
    }
    package func shutdown() async {
        healthy = false
        epoch &+= 1
        closeMatching()
        for record in records.values {
            await authority.revokeConnection(try! ConnectionID(record.id.uuidString))
        }
    }
}

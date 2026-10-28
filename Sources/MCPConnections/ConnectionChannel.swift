import CoreDomain
import Foundation
import PermissionEngine

/// Trusted transport adapter only. Verification must cover this exact channel and both shipped peers.
/// No production verifier is composed until signed reachability/requirements are exercised.
package final class ConnectionChannel: @unchecked Sendable {
    let id = UUID()
    private let lock = NSLock()
    private var open = true
    private let verify: @Sendable () async -> Bool
    private let closeTransport: @Sendable () -> Void
    package init(
        verify: @escaping @Sendable () async -> Bool = { false },
        close: @escaping @Sendable () -> Void = {}
    ) {
        self.verify = verify
        closeTransport = close
    }
    var isOpen: Bool { lock.withLock { open } }
    func verified() async -> Bool {
        guard isOpen else { return false }
        return await verify() && isOpen
    }
    func close() {
        let changed = lock.withLock {
            if !open { return false }
            open = false
            return true
        }
        if changed { closeTransport() }
    }
}

/// Shared across launches; cancelled providers retain their slot until they actually return.
final class ReadBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func acquire() throws {
        try lock.withLock {
            guard count < 16 else { throw ConnectionFailure.busy }
            count += 1
        }
    }
    func release() { lock.withLock { count -= 1 } }
}

final class ReadGate: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = true
    private var tasks: [UUID: (@Sendable () -> Void)?] = [:]
    private let channel: ConnectionChannel
    private let budget: ReadBudget
    init(channel: ConnectionChannel, budget: ReadBudget) {
        self.channel = channel
        self.budget = budget
    }
    var isOpen: Bool { lock.withLock { enabled } && channel.isOpen }
    func invalidate() {
        let cancellations = lock.withLock {
            enabled = false
            return tasks.values.compactMap { $0 }
        }
        for cancel in cancellations { cancel() }
        channel.close()
    }
    func perform<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws
        -> T
    {
        let id = UUID()
        try lock.withLock {
            guard enabled, channel.isOpen else { throw ConnectionFailure.closed }
            guard tasks.count < 4 else { throw ConnectionFailure.busy }
            tasks[id] = .some(nil)
        }
        defer { lock.withLock { _ = tasks.removeValue(forKey: id) } }
        try budget.acquire()
        defer { budget.release() }
        let task = Task {
            try Task.checkCancellation()
            guard self.isOpen else { throw ConnectionFailure.closed }
            let result = try await operation()
            try Task.checkCancellation()
            guard self.isOpen else { throw ConnectionFailure.closed }
            return result
        }
        lock.withLock {
            if enabled, channel.isOpen { tasks[id] = { task.cancel() } } else { task.cancel() }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

package struct ConnectionReadLease: Sendable {
    package let session: PolicySession
    package let selection: Set<CalendarReference>
    private let gate: ReadGate
    private let audit: @Sendable (ReadOperation, Bool) async -> Void
    init(
        session: PolicySession, selection: Set<CalendarReference>, gate: ReadGate,
        audit: @escaping @Sendable (ReadOperation, Bool) async -> Void
    ) {
        self.session = session
        self.selection = selection
        self.gate = gate
        self.audit = audit
    }
    package var isOpen: Bool { gate.isOpen }
    package enum ReadOperation: String, Sendable { case discovery, availability, search, detail }
    package func perform<T: Sendable>(
        _ kind: ReadOperation, _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        do {
            let result = try await gate.perform(operation)
            await audit(kind, true)
            guard isOpen else { throw ConnectionFailure.closed }
            return result
        } catch {
            await audit(kind, false)
            throw error
        }
    }
}

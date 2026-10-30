import Foundation

@objc protocol LocalReadWire {
    func hello(reply: @escaping @Sendable (Int) -> Void)
    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void)
}

/// Only an authenticated incoming method can open this gate; closure is permanent.
package final class LocalPeerGate: @unchecked Sendable {
    private let lock = NSLock()
    private var authenticated = false
    private var closed = false
    package var isAuthenticated: Bool { lock.withLock { authenticated && !closed } }
    fileprivate func authenticate() { lock.withLock { if !closed { authenticated = true } } }
    fileprivate func close() { lock.withLock { closed = true } }
}

package struct LocalReadHandler: Sendable {
    package let request: @Sendable (Data) async -> Data
    package let close: @Sendable () async -> Void
    package init(
        request: @escaping @Sendable (Data) async -> Data,
        close: @escaping @Sendable () async -> Void
    ) {
        self.request = request
        self.close = close
    }
}

/// A single-launch listener. launchd owns discovery; no registration or persistent install here.
package final class SignedLocalListener: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let listener: NSXPCListener
    private let factory: @Sendable (LocalPeerGate) async throws -> LocalReadHandler
    private let lock = NSLock()
    private var endpoint: LocalReadEndpoint?
    private var accepted: NSXPCConnection?
    private var stopped = false

    package init(
        service: String, peer: PeerRequirement,
        factory: @escaping @Sendable (LocalPeerGate) async throws -> LocalReadHandler
    ) {
        listener = NSXPCListener(machServiceName: service)
        self.factory = factory
        super.init()
        // macOS enforces this on incoming messages before calling our delegate/endpoint.
        listener.setConnectionCodeSigningRequirement(peer.expression)
        listener.delegate = self
        listener.resume()
    }
    package func listener(
        _ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        lock.withLock {
            guard !stopped, accepted == nil else { return false }
            let endpoint = LocalReadEndpoint(factory: factory)
            self.endpoint = endpoint
            accepted = connection
            connection.exportedInterface = NSXPCInterface(with: LocalReadWire.self)
            connection.exportedObject = endpoint
            connection.invalidationHandler = { [weak self, endpoint] in
                endpoint.close()
                self?.close()
            }
            connection.interruptionHandler = { [weak self, endpoint] in
                endpoint.close()
                self?.close()
            }
            connection.resume()
            return true
        }
    }
    package func close() {
        let values: (NSXPCConnection?, LocalReadEndpoint?)? = lock.withLock {
            guard !stopped else { return nil }
            stopped = true
            return (accepted, endpoint)
        }
        guard let values else { return }
        values.1?.close()
        values.0?.invalidate()
        listener.invalidate()
    }
    deinit {
        endpoint?.close()
        accepted?.invalidate()
        listener.invalidate()
    }
}

/// Four admitted calls, held through suspended work. The factory is invoked once per actual channel.
private final class LocalReadEndpoint: NSObject, LocalReadWire, @unchecked Sendable {
    private let gate = LocalPeerGate()
    private let lock = NSLock()
    private let factory: @Sendable (LocalPeerGate) async throws -> LocalReadHandler
    private var handler: Task<LocalReadHandler, any Error>?
    private var count = 0
    init(factory: @escaping @Sendable (LocalPeerGate) async throws -> LocalReadHandler) {
        self.factory = factory
    }
    // Public, content-free version response. No provider, review or authentication gate is opened.
    func hello(reply: @escaping @Sendable (Int) -> Void) { reply(1) }
    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void) {
        let task: Task<LocalReadHandler, any Error>? = lock.withLock {
            // This method is reached only after XPC's exact-peer requirement succeeds.
            gate.authenticate()
            guard gate.isAuthenticated, data.count <= 16_384, count < 4 else { return nil }
            count += 1
            if handler == nil { handler = Task { try await factory(gate) } }
            return handler
        }
        guard let task else {
            reply(SignedLocalClient.unavailable)
            return
        }
        Task {
            let result: Data
            do {
                let handler = try await task.value
                result =
                    gate.isAuthenticated
                    ? await handler.request(data) : SignedLocalClient.unavailable
            } catch { result = SignedLocalClient.unavailable }
            lock.withLock { count -= 1 }
            reply(
                gate.isAuthenticated && result.count <= 32_768
                    ? result : SignedLocalClient.unavailable)
        }
    }
    func close() {
        gate.close()
        let task = lock.withLock { handler }
        task?.cancel()
        Task { if let handler = try? await task?.value { await handler.close() } }
    }
}

/// Requirement is installed before resume/first message; no unsigned or reconnect fallback.
package final class SignedLocalClient: @unchecked Sendable {
    package static let unavailable = Data(#"{"error":"unavailable"}"#.utf8)
    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var stopped = false
    package var isOpen: Bool { lock.withLock { !stopped } }
    package init(service: String, peer: PeerRequirement) {
        connection = NSXPCConnection(machServiceName: service)
        connection.setCodeSigningRequirement(peer.expression)
        connection.remoteObjectInterface = NSXPCInterface(with: LocalReadWire.self)
        connection.invalidationHandler = { [weak self] in self?.close() }
        connection.interruptionHandler = { [weak self] in self?.close() }
        connection.resume()
    }
    package func close() {
        let needed = lock.withLock {
            guard !stopped else { return false }
            stopped = true
            return true
        }
        if needed { connection.invalidate() }
    }
    deinit { connection.invalidate() }
    package func send(_ data: Data) async -> Data {
        guard data.count <= 16_384, isOpen else { return Self.unavailable }
        let completion = LocalCompletion()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                guard isOpen, !Task.isCancelled else {
                    completion.finish(Self.unavailable)
                    return
                }
                let proxy =
                    connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                        self?.close()
                        completion.finish(Self.unavailable)
                    } as? LocalReadWire
                guard let proxy else {
                    close()
                    completion.finish(Self.unavailable)
                    return
                }
                // XPC requirements check received messages. Authenticate a content-free reply
                // before sending an envelope to this exact connection, on every call.
                proxy.hello { [weak self] version in
                    guard let self, version == 1, self.isOpen, !completion.isFinished else {
                        self?.close()
                        completion.finish(Self.unavailable)
                        return
                    }
                    self.forward(data, completion: completion)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                    completion.finish(Self.unavailable, beforeResume: { self?.close() })
                }
            }
        } onCancel: { [weak self] in
            self?.close()
            completion.finish(Self.unavailable)
        }
    }
    private func forward(_ data: Data, completion: LocalCompletion) {
        guard isOpen, !completion.isFinished else {
            completion.finish(Self.unavailable)
            return
        }
        let proxy =
            connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                self?.close()
                completion.finish(Self.unavailable)
            } as? LocalReadWire
        guard let proxy else {
            close()
            completion.finish(Self.unavailable)
            return
        }
        proxy.request(data) { [weak self] result in
            completion.finish(
                self?.isOpen == true && result.count <= 32_768 ? result : Self.unavailable)
        }
    }
}

private final class LocalCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Data?
    private var continuation: CheckedContinuation<Data, Never>?
    var isFinished: Bool { lock.withLock { result != nil } }
    func install(_ value: CheckedContinuation<Data, Never>) {
        let ready: Data? = lock.withLock {
            if let result { return result }
            continuation = value
            return nil as Data?
        }
        if let ready { value.resume(returning: ready) }
    }
    func finish(_ value: Data, beforeResume: () -> Void = {}) {
        let delivery: (Bool, CheckedContinuation<Data, Never>?) = lock.withLock {
            guard result == nil else { return (false, nil) }
            result = value
            let current = continuation
            continuation = nil
            return (true, current)
        }
        if delivery.0 { beforeResume() }
        delivery.1?.resume(returning: value)
    }
}

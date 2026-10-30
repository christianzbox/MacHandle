import Foundation
import MCPConnections

@objc protocol SampleReadWire {
    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void)
}

/// Fixture-only anonymous endpoint. Never published, registered or treated as signed peer proof.
final class SampleXPCTransport: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let listener = NSXPCListener.anonymous()
    private let lock = NSLock()
    private let broker: NativeReadBroker
    private let channel: ConnectionChannel
    private var accepted: NSXPCConnection?
    private var stopped = false
    private var claimed = false
    private let client: NSXPCConnection

    init(broker: NativeReadBroker, channel: ConnectionChannel) {
        self.broker = broker
        self.channel = channel
        client = NSXPCConnection(listenerEndpoint: listener.endpoint)
        super.init()
        listener.delegate = self
        listener.resume()
        client.remoteObjectInterface = NSXPCInterface(with: SampleReadWire.self)
        client.invalidationHandler = { [weak self] in self?.close() }
        client.interruptionHandler = { [weak self] in self?.close() }
        client.resume()
    }
    deinit {
        client.invalidate()
        accepted?.invalidate()
        listener.invalidate()
        channel.close()
    }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection)
        -> Bool
    {
        lock.withLock {
            guard !stopped, !claimed else { return false }
            claimed = true
            accepted = connection
            connection.exportedInterface = NSXPCInterface(with: SampleReadWire.self)
            connection.exportedObject = SampleReadEndpoint(broker: broker, channel: channel)
            connection.invalidationHandler = { [weak self] in self?.close() }
            connection.interruptionHandler = { [weak self] in self?.close() }
            connection.resume()
            return true
        }
    }
    func close() {
        let shouldClose = lock.withLock {
            guard !stopped else { return false }
            stopped = true
            return true
        }
        guard shouldClose else { return }
        channel.close()
        client.invalidate()
        let server = lock.withLock { accepted }
        server?.invalidate()
        listener.invalidate()
        Task { await broker.close() }
    }
    func send(_ data: Data) async -> Data {
        guard data.count <= 16_384, channel.isOpen else { return NativeReadBroker.unavailable }
        let completion = SampleWireCompletion()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                guard channel.isOpen, !Task.isCancelled else {
                    completion.finish(NativeReadBroker.unavailable)
                    return
                }
                let proxy =
                    client.remoteObjectProxyWithErrorHandler { [weak self] _ in
                        self?.close()
                        completion.finish(NativeReadBroker.unavailable)
                    } as? SampleReadWire
                guard let proxy else {
                    close()
                    completion.finish(NativeReadBroker.unavailable)
                    return
                }
                proxy.request(data) { [channel] result in
                    completion.finish(
                        channel.isOpen && result.count <= 32_768
                            ? result : NativeReadBroker.unavailable)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                    completion.finish(NativeReadBroker.unavailable, beforeResume: { self?.close() })
                }
            }
        } onCancel: { [weak self] in
            self?.close()
            completion.finish(NativeReadBroker.unavailable)
        }
    }
}

/// Limit admission before creating Swift tasks; no unbounded queue of provider work.
private final class SampleReadEndpoint: NSObject, SampleReadWire, @unchecked Sendable {
    private let broker: NativeReadBroker
    private let channel: ConnectionChannel
    private let lock = NSLock()
    private var count = 0
    init(broker: NativeReadBroker, channel: ConnectionChannel) {
        self.broker = broker
        self.channel = channel
    }
    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void) {
        let admitted = lock.withLock {
            guard data.count <= 16_384, channel.isOpen, count < 4 else { return false }
            count += 1
            return true
        }
        guard admitted else {
            reply(NativeReadBroker.unavailable)
            return
        }
        Task {
            let result = await broker.request(data)
            lock.withLock { count -= 1 }
            reply(channel.isOpen ? result : NativeReadBroker.unavailable)
        }
    }
}

/// Cancellation, timeout and XPC replies may race. Resume exactly once, including pre-install cancel.
private final class SampleWireCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Data?
    private var continuation: CheckedContinuation<Data, Never>?
    func install(_ value: CheckedContinuation<Data, Never>) {
        let ready: Data? = lock.withLock {
            if let result { return result }
            continuation = value
            return nil as Data?
        }
        if let ready { value.resume(returning: ready) }
    }
    @discardableResult func finish(_ value: Data, beforeResume: () -> Void = {}) -> Bool {
        let delivery: (Bool, CheckedContinuation<Data, Never>?) = lock.withLock {
            guard result == nil else { return (false, nil) }
            result = value
            let current = continuation
            continuation = nil
            return (true, current)
        }
        if delivery.0 { beforeResume() }
        delivery.1?.resume(returning: value)
        return delivery.0
    }
}

import AppKit
import Foundation
import Network

/// Scheduling hints only; network reachability is not authentication or provider availability.
public struct BackgroundEnvironmentState: Equatable, Sendable {
    public let awake: Bool
    public let sessionActive: Bool
    public let networkAvailable: Bool
}

@MainActor
protocol BackgroundPathMonitoring: AnyObject {
    func start(_ update: @escaping @Sendable (Bool) -> Void)
    func cancel()
}

@MainActor
private final class SystemBackgroundPath: BackgroundPathMonitoring {
    private let monitor = NWPathMonitor()
    func start(_ update: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { update($0.status == .satisfied) }
        monitor.start(queue: DispatchQueue(label: "MacHandle.background-path", qos: .utility))
    }
    func cancel() { monitor.cancel() }
    deinit { monitor.cancel() }
}

/// No polling, permission request or provider reads. The trusted host owns start/stop.
/// Streams carry the entire latest state so coalescing cannot lose an offline/sleep flag.
@MainActor
public final class BackgroundEnvironment {
    private let center: NotificationCenter
    private let makePath: @MainActor () -> any BackgroundPathMonitoring
    private var path: (any BackgroundPathMonitoring)?
    private let observations: BackgroundObservers
    private var continuation: AsyncStream<BackgroundEnvironmentState>.Continuation?
    private var generation: UUID?
    private var awake = true
    private var sessionActive = true
    private var online = false

    public convenience init() {
        self.init(
            center: NSWorkspace.shared.notificationCenter, makePath: { SystemBackgroundPath() })
    }
    init(
        center: NotificationCenter,
        makePath: @escaping @MainActor () -> any BackgroundPathMonitoring
    ) {
        self.center = center
        observations = BackgroundObservers(center: center)
        self.makePath = makePath
    }
    public func start() -> AsyncStream<BackgroundEnvironmentState> {
        stop()
        awake = true
        sessionActive = true
        online = false
        let id = UUID()
        generation = id
        let pair = AsyncStream<BackgroundEnvironmentState>.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        continuation = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                guard self?.generation == id else { return }
                self?.stop()
            }
        }
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.willPowerOffNotification,
        ] {
            observations.add(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, self.generation == id else { return }
                        switch name {
                        case NSWorkspace.willSleepNotification,
                            NSWorkspace.willPowerOffNotification:
                            self.awake = false
                        case NSWorkspace.didWakeNotification: self.awake = true
                        case NSWorkspace.sessionDidResignActiveNotification:
                            self.sessionActive = false
                        case NSWorkspace.sessionDidBecomeActiveNotification:
                            self.sessionActive = true
                        default: break
                        }
                        self.publish()
                    }
                })
        }
        let path = makePath()
        self.path = path
        path.start { [weak self] available in
            Task { @MainActor in
                guard let self, self.generation == id else { return }
                self.online = available
                self.publish()
            }
        }
        publish()
        return pair.stream
    }
    public func stop() {
        generation = nil
        path?.cancel()
        path = nil
        observations.cancel()
        continuation?.finish()
        continuation = nil
    }
    private func publish() {
        continuation?.yield(
            BackgroundEnvironmentState(
                awake: awake, sessionActive: sessionActive, networkAvailable: online))
    }
}

/// NotificationCenter permits removal from any thread. Lock protects cleanup on release.
private final class BackgroundObservers: @unchecked Sendable {
    private let center: NotificationCenter
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []
    init(center: NotificationCenter) { self.center = center }
    func add(_ token: NSObjectProtocol) { lock.withLock { tokens.append(token) } }
    func cancel() {
        let old = lock.withLock {
            let old = tokens
            tokens.removeAll()
            return old
        }
        old.forEach(center.removeObserver)
    }
    deinit { cancel() }
}

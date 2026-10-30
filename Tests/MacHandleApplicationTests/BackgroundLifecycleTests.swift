import AppKit
import Foundation
import Testing

@testable import MacHandleApplication

@MainActor
private final class FakeLoginItem: LoginItemServicing {
    var status: LoginItemStatus = .disabled
    var enables = 0
    var disables = 0
    var fail = false
    var hold = false
    var pending: CheckedContinuation<Void, Never>?
    func enable() throws {
        enables += 1
        if fail { throw CancellationError() }
        status = .requiresApproval
    }
    func disable() async throws {
        disables += 1
        if hold { await withCheckedContinuation { pending = $0 } }
        if fail { throw CancellationError() }
        status = .disabled
    }
}

@Test @MainActor func loginRegistrationRequiresExplicitActionAndReflectsSystemStatus() async {
    let service = FakeLoginItem()
    let model = LoginItemModel(service: service)
    model.refresh()
    #expect(service.enables == 0 && service.disables == 0 && !model.requested)
    await model.setEnabled(true)
    #expect(model.status == .requiresApproval && model.requested)
    await model.setEnabled(true)
    #expect(service.enables == 1)
    service.status = .enabled
    model.refresh()
    #expect(model.status == .enabled)
    service.status = .disabled
    model.refresh()
    #expect(!model.requested && service.enables == 1)
    await model.setEnabled(true)
    await model.setEnabled(false)
    #expect(model.status == .disabled && service.disables == 1)
}

@Test @MainActor func loginFailureDoesNotClaimRegistrationOrRetryAutomatically() async {
    let service = FakeLoginItem()
    service.fail = true
    let model = LoginItemModel(service: service)
    await model.setEnabled(true)
    #expect(model.failed && !model.requested && !model.busy)
    model.refresh()
    #expect(service.enables == 1)
    service.status = .unavailable
    await model.setEnabled(true)
    #expect(model.status == .unavailable && service.enables == 1)
}

@Test @MainActor func loginUnregisterDoesNotOverlapAnEnableRequest() async throws {
    let service = FakeLoginItem()
    service.status = .enabled
    service.hold = true
    let model = LoginItemModel(service: service)
    let task = Task { await model.setEnabled(false) }
    for _ in 0..<1000 {
        if service.pending != nil { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    #expect(model.busy)
    await model.setEnabled(true)
    #expect(service.enables == 0)
    service.pending?.resume()
    await task.value
    #expect(model.status == .disabled && !model.busy)
}

@MainActor
private final class FakeBackgroundPath: BackgroundPathMonitoring {
    var update: (@Sendable (Bool) -> Void)?
    var starts = 0
    var cancellations = 0
    func start(_ update: @escaping @Sendable (Bool) -> Void) {
        self.update = update
        starts += 1
    }
    func cancel() { cancellations += 1 }
}

@Test @MainActor func lifecycleStreamsKeepCombinedStateAndReleaseObservers() async throws {
    let center = NotificationCenter()
    let path = FakeBackgroundPath()
    let environment = BackgroundEnvironment(center: center, makePath: { path })
    #expect(path.starts == 0)
    var iterator = environment.start().makeAsyncIterator()
    #expect(await iterator.next()?.networkAvailable == false)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    center.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
    let suspended = await iterator.next()
    #expect(suspended?.awake == false && suspended?.sessionActive == false)
    path.update?(true)
    let connected = await iterator.next()
    #expect(connected?.networkAvailable == true && connected?.awake == false)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(await iterator.next()?.sessionActive == false)
    center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    #expect(await iterator.next()?.sessionActive == true)
    environment.stop()
    #expect(await iterator.next() == nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(path.cancellations == 1)
}

@Test @MainActor func restartedLifecycleIgnoresOldPathCallbacksAndOldStreamTermination() async {
    let center = NotificationCenter()
    let path = FakeBackgroundPath()
    let environment = BackgroundEnvironment(center: center, makePath: { path })
    let oldStream = environment.start()
    let stale = path.update
    var current = environment.start().makeAsyncIterator()
    #expect(await current.next()?.networkAvailable == false)
    stale?(true)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    let latest = await current.next()
    #expect(latest?.awake == false && latest?.networkAvailable == false)
    var old = oldStream.makeAsyncIterator()
    _ = await old.next()
    #expect(await old.next() == nil)
    environment.stop()
    #expect(path.starts == 2 && path.cancellations == 2)
}

import Foundation
import Testing

@testable import SyncExecution

private final class ManualBackgroundClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time = 0.0
    private var waiting: [UUID: (Double, CheckedContinuation<Void, any Error>)] = [:]
    var clock: BackgroundClock {
        BackgroundClock(now: { self.now }, sleep: { try await self.sleep($0) })
    }
    var now: Double { lock.withLock { time } }
    var timerCount: Int { lock.withLock { waiting.count } }
    var nextDeadline: Double? { lock.withLock { waiting.values.map(\.0).min() } }
    func advance(_ seconds: Double) {
        let ready = lock.withLock {
            time += seconds
            let ready = waiting.filter { $0.value.0 <= time }
            for key in ready.keys { waiting.removeValue(forKey: key) }
            return ready.values.map(\.1)
        }
        for continuation in ready { continuation.resume() }
    }
    private func sleep(_ delay: Double) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                lock.withLock {
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if delay <= 0 {
                        continuation.resume()
                    } else {
                        waiting[id] = (time + delay, continuation)
                    }
                }
            }
        } onCancel: {
            let pending = self.lock.withLock { self.waiting.removeValue(forKey: id) }
            pending?.1.resume(throwing: CancellationError())
        }
    }
}

private actor BackgroundJob: BackgroundSyncRunning {
    var runs = 0
    var active = 0
    var maxActive = 0
    var checksRejected = 0
    var results: [BackgroundRunResult] = [.completed]
    var held = false
    var ignoreGate = false
    var gate: CheckedContinuation<Void, Never>?
    func configure(_ values: [BackgroundRunResult], held: Bool = false, ignoreGate: Bool = false) {
        results = values
        self.held = held
        self.ignoreGate = ignoreGate
    }
    func release() {
        held = false
        gate?.resume()
        gate = nil
    }
    func run(check: @escaping @Sendable () async throws -> Void) async -> BackgroundRunResult {
        runs += 1
        active += 1
        maxActive = max(maxActive, active)
        defer { active -= 1 }
        if held { await withCheckedContinuation { gate = $0 } }
        do { if !ignoreGate { try await check() } } catch {
            checksRejected += 1
            return .needsAttention
        }
        return results.count > 1 ? results.removeFirst() : results[0]
    }
}

private func eventually(_ condition: @escaping () async -> Bool) async throws {
    for _ in 0..<1000 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("Background condition did not settle within one second")
    throw CancellationError()
}

private func ready(_ scheduler: BackgroundSynchronization) async {
    await scheduler.setWriterActive(true)
    await scheduler.setEnvironment(awake: true, online: true)
    await scheduler.resume()
}

@Test func backgroundStartsDisabledAndStandbyCannotRun() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await scheduler.request()
    clock.advance(1000)
    #expect(await job.runs == 0 && clock.timerCount == 0)
    await scheduler.resume()
    await scheduler.setEnvironment(awake: true, online: true)
    #expect(await scheduler.status().phase == .standby)
    #expect(await job.runs == 0 && clock.timerCount == 0)
    await scheduler.setWriterActive(true)
    try await eventually { await scheduler.status().completions == 1 }
    await scheduler.shutdown()
}

@Test func periodicSchedulingDoesNotCatchUpOrOverlap() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await ready(scheduler)
    try await eventually { await scheduler.status().completions == 1 && clock.timerCount == 1 }
    clock.advance(299)
    #expect(await job.runs == 1)
    clock.advance(1)
    try await eventually { await scheduler.status().completions == 2 && clock.timerCount == 1 }
    clock.advance(10000)
    try await eventually { await scheduler.status().completions == 3 && clock.timerCount == 1 }
    #expect(await job.maxActive == 1)
    await scheduler.shutdown()
}

@Test func calendarChangesDebounceAndHaveAMaximumDelay() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await ready(scheduler)
    try await eventually { await scheduler.status().completions == 1 && clock.timerCount == 1 }
    for _ in 0..<9 {
        await scheduler.request()
        try await eventually { clock.timerCount == 1 }
        clock.advance(1)
    }
    #expect(await job.runs == 1)
    await scheduler.request()
    try await eventually { clock.timerCount == 1 }
    clock.advance(1)
    try await eventually { await scheduler.status().completions == 2 }
    await scheduler.shutdown()
}

@Test func sleepOfflineAndStandbyCancelAndAwaitOldWorker() async throws {
    for kind in 0..<3 {
        let clock = ManualBackgroundClock()
        let job = BackgroundJob()
        await job.configure([.completed], held: true)
        let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
        await ready(scheduler)
        try await eventually { await job.active == 1 }
        if kind == 0 {
            await scheduler.setEnvironment(awake: false, online: true)
        } else if kind == 1 {
            await scheduler.setEnvironment(awake: true, online: false)
        } else {
            await scheduler.setWriterActive(false)
        }
        clock.advance(5000)
        #expect(await job.runs == 1)
        await scheduler.setEnvironment(awake: true, online: true)
        await scheduler.setWriterActive(true)
        #expect(await job.runs == 1)
        await job.release()
        try await eventually { await scheduler.status().completions == 1 }
        #expect(await job.checksRejected == 1)
        #expect(await job.maxActive == 1)
        #expect(await job.runs == 2)
        await scheduler.shutdown()
    }
}

@Test func sourceChangeInvalidatesInFlightAuthorityAndDebouncesReplacement() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    await job.configure([.completed], held: true)
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await ready(scheduler)
    try await eventually { await job.active == 1 }
    await scheduler.request()
    await job.release()
    try await eventually { await job.active == 0 && clock.timerCount == 1 }
    #expect(await job.checksRejected == 1)
    clock.advance(2)
    try await eventually { await scheduler.status().completions == 1 }
    #expect(await job.maxActive == 1)
    await scheduler.shutdown()
}

@Test func pauseDrainsBeforeTransferAndCannotResumeDuringDrain() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    await job.configure([.completed], held: true)
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await ready(scheduler)
    try await eventually { await job.active == 1 }
    let pause = Task { await scheduler.pauseAndDrain() }
    try await eventually { await scheduler.status().phase == .paused }
    await scheduler.resume()
    clock.advance(1000)
    #expect(await job.runs == 1)
    await job.release()
    await pause.value
    #expect(await job.active == 0)
    #expect(await scheduler.status().phase == .paused)
    await scheduler.resume()
    try await eventually { await scheduler.status().completions == 1 }
    await scheduler.shutdown()
}

@Test func retryBackoffSurvivesNotificationsAndNetworkFlapping() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    await job.configure([.retry(after: 30), .completed])
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock, jitter: { 0 })
    await ready(scheduler)
    try await eventually { await job.runs == 1 && clock.timerCount == 1 }
    await scheduler.request(immediate: true)
    await scheduler.setEnvironment(awake: true, online: false)
    await scheduler.setEnvironment(awake: true, online: true)
    try await eventually { clock.timerCount == 1 }
    clock.advance(29)
    #expect(await job.runs == 1)
    clock.advance(1)
    try await eventually { await scheduler.status().completions == 1 }
    await scheduler.shutdown()
}

@Test func retryBudgetAndInvalidDelaysRequireAttention() async throws {
    for delay in [Double.nan, Double.infinity, -1, 3601, 0] {
        let clock = ManualBackgroundClock()
        let job = BackgroundJob()
        await job.configure([.retry(after: delay)])
        let scheduler = BackgroundSynchronization(job: job, clock: clock.clock, jitter: { 0 })
        await ready(scheduler)
        if delay == 0 {
            for run in 1...3 {
                try await eventually { await job.runs == run && clock.timerCount == 1 }
                clock.advance(100)
            }
        }
        try await eventually { await scheduler.status().phase == .needsAttention }
        await scheduler.request(immediate: true)
        clock.advance(10000)
        #expect(await job.runs == (delay == 0 ? 4 : 1))
        #expect(clock.timerCount == 0)
        await scheduler.shutdown()
    }
}

@Test func uncertainRunNeverRetriesAndShutdownRemovesChangeSubscription() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    await job.configure([.needsAttention])
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    await scheduler.observeChanges(pair.stream)
    await ready(scheduler)
    try await eventually { await scheduler.status().phase == .needsAttention }
    pair.continuation.yield(())
    clock.advance(10000)
    #expect(await job.runs == 1)
    await scheduler.shutdown()
    await scheduler.resume()
    pair.continuation.yield(())
    #expect(await scheduler.status().phase == .disabled)
    #expect(await job.runs == 1)
    #expect(clock.timerCount == 0)
}

@Test func providerChangeStreamRequestsFreshDebouncedWork() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    await scheduler.observeChanges(pair.stream)
    await ready(scheduler)
    try await eventually { await scheduler.status().completions == 1 && clock.nextDeadline == 300 }
    pair.continuation.yield(())
    try await eventually { clock.nextDeadline == 2 }
    clock.advance(2)
    try await eventually { await scheduler.status().completions == 2 }
    await scheduler.shutdown()
    #expect(clock.timerCount == 0)
}

@Test func concurrentSourceInvalidationCannotEraseReturnedServerBackoff() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    await job.configure([.retry(after: 30), .completed], held: true, ignoreGate: true)
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock, jitter: { 0 })
    await ready(scheduler)
    try await eventually { await job.active == 1 }
    await scheduler.request()
    await job.release()
    try await eventually { clock.nextDeadline == 30 }
    clock.advance(29)
    #expect(await job.runs == 1)
    clock.advance(1)
    try await eventually { await scheduler.status().completions == 1 }
    await scheduler.shutdown()
}

@Test func onboardingSchedulerHandoffWaitsButRetainsQueuedSourceChanges() async throws {
    let clock = ManualBackgroundClock()
    let job = BackgroundJob()
    let scheduler = BackgroundSynchronization(job: job, clock: clock.clock)
    await scheduler.startAfterInitialRun(awake: true, online: true, writer: true)
    try await eventually { clock.nextDeadline == 300 }
    #expect(await job.runs == 0)
    await scheduler.shutdown()
    let changedClock = ManualBackgroundClock()
    let changed = BackgroundSynchronization(job: job, clock: changedClock.clock)
    await changed.request()
    await changed.startAfterInitialRun(awake: true, online: true, writer: true)
    try await eventually { changedClock.nextDeadline == 2 }
    changedClock.advance(2)
    try await eventually { await changed.status().completions == 1 }
    #expect(await job.runs == 1)
    await changed.shutdown()
}

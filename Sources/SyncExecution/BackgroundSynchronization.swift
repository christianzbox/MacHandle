import Foundation

/// A scheduling result never substitutes for executor verification or a durable checkpoint.
enum BackgroundRunResult: Equatable, Sendable {
    case completed
    /// Allowed only before mutation dispatch, after a known transient observation failure.
    case retry(after: Double)
    case needsAttention
}

protocol BackgroundSyncRunning: Sendable {
    func run(check: @escaping @Sendable () async throws -> Void) async -> BackgroundRunResult
}

struct BackgroundClock: Sendable {
    let now: @Sendable () -> Double
    let sleep: @Sendable (Double) async throws -> Void

    static func continuous() -> Self {
        let clock = ContinuousClock()
        let origin = clock.now
        return Self(
            now: {
                let value = origin.duration(to: clock.now).components
                return Double(value.seconds) + Double(value.attoseconds) / 1e18
            },
            sleep: { try await clock.sleep(for: .seconds($0), tolerance: .seconds(0.25)) })
    }
}

/// One coordinator per canonical destination/store. Internal until trusted live composition.
/// Neither timer ticks nor lifecycle signals grant permission to read or mutate resources.
actor BackgroundSynchronization {
    enum Phase: Equatable {
        case disabled, paused, standby, suspended, waiting, running, needsAttention
    }
    struct Status: Equatable {
        let phase: Phase
        let starts: Int
        let completions: Int
    }
    private let job: any BackgroundSyncRunning
    private let clock: BackgroundClock
    private let period: Double
    private let jitter: @Sendable () -> Double
    private var enabled = false
    private var awake = true
    private var online = false
    private var writer = false
    private var stopped = false
    private var drains = 0
    private var draining: Bool { drains > 0 }
    private var attention = false
    private var generation = UUID()
    private var workerID: UUID?
    private var worker: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var timerID: UUID?
    private var changes: Task<Void, Never>?
    private var dirty = false
    private var firstChange: Double?
    private var changeDue: Double?
    private var periodicDue: Double?
    private var retryDue: Double?
    private var retries = 0
    private var starts = 0
    private var completions = 0

    init(
        job: any BackgroundSyncRunning, clock: BackgroundClock = .continuous(),
        period: Double = 300,
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) {
        self.job = job
        self.clock = clock
        self.period = period.isFinite ? min(max(period, 60), 3600) : 300
        self.jitter = jitter
    }

    func status() -> Status {
        let phase: Phase
        if stopped {
            phase = .disabled
        } else if !enabled {
            phase = .paused
        } else if !writer {
            phase = .standby
        } else if !awake || !online {
            phase = .suspended
        } else if attention {
            phase = .needsAttention
        } else {
            phase = worker == nil ? .waiting : .running
        }
        return Status(phase: phase, starts: starts, completions: completions)
    }

    /// Trusted host supplies the authorized provider's bounded, content-free change stream.
    func observeChanges(_ stream: AsyncStream<Void>) {
        guard !stopped, changes == nil else { return }
        changes = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.request()
            }
        }
    }

    /// Explicit local action only; not called on an external signal or automatically at launch.
    func resume() {
        guard !stopped, !draining else { return }
        enabled = true
        attention = false
        retries = 0
        // Keep any server backoff even when the user pauses and resumes.
        request(immediate: true)
    }

    func setWriterActive(_ value: Bool) {
        guard !stopped, writer != value else { return }
        writer = value
        invalidateRun()
        request(immediate: true)
    }

    func setEnvironment(awake: Bool, online: Bool) {
        guard !stopped, self.awake != awake || self.online != online else { return }
        self.awake = awake
        self.online = online
        invalidateRun()
        request(immediate: true)
    }

    /// A trailing two-second debounce capped at ten seconds prevents notification starvation.
    func request(immediate: Bool = false) {
        guard !stopped else { return }
        if worker != nil {
            generation = UUID()
            worker?.cancel()
        }
        dirty = true
        let now = clock.now()
        if firstChange == nil { firstChange = now }
        changeDue = immediate ? now : min(now + 2, (firstChange ?? now) + 10)
        schedule()
    }

    /// Await this before ownership transfer. Cancellation alone is not proof that writes drained.
    func pauseAndDrain() async {
        enabled = false
        drains += 1
        invalidateRun()
        let active = worker
        await active?.value
        drains -= 1
    }

    func shutdown() async {
        stopped = true
        changes?.cancel()
        changes = nil
        await pauseAndDrain()
    }

    private var eligible: Bool {
        enabled && writer && awake && online && !stopped && !draining && !attention
    }

    private func invalidateRun() {
        generation = UUID()
        timer?.cancel()
        timer = nil
        timerID = nil
        worker?.cancel()
    }

    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard eligible, generation == token else { throw CancellationError() }
    }

    private func schedule() {
        timer?.cancel()
        timer = nil
        timerID = nil
        guard eligible, worker == nil else { return }
        let now = clock.now()
        let desired = dirty ? (changeDue ?? now) : (periodicDue ?? now + period)
        let due = max(desired, retryDue ?? desired)
        let id = UUID()
        timerID = id
        let clock = clock
        timer = Task { [weak self] in
            do {
                try await clock.sleep(max(0, due - clock.now()))
                try Task.checkCancellation()
                await self?.fire(id)
            } catch {
                // Cancelled timers never start a job.
            }
        }
    }

    private func fire(_ id: UUID) {
        guard timerID == id, eligible, worker == nil else { return }
        timer = nil
        timerID = nil
        dirty = false
        firstChange = nil
        changeDue = nil
        let token = generation
        let id = UUID()
        workerID = id
        starts += 1
        let job = job
        worker = Task { [weak self] in
            guard let self else { return }
            let result = await job.run(check: { try await self.check(token) })
            await self.finished(id, token: token, result: result)
        }
    }

    private func finished(_ id: UUID, token: UUID, result: BackgroundRunResult) {
        guard workerID == id else { return }
        worker = nil
        workerID = nil
        // A concurrent invalidation cannot erase a server's retry floor.
        if case .retry(let delay) = result {
            recordRetry(delay)
        } else if token != generation {
            // Even a cancellation-ignoring job must finish before its replacement can start.
            dirty = true
            changeDue = changeDue ?? clock.now()
        } else {
            switch result {
            case .completed:
                completions += 1
                retries = 0
                retryDue = nil
                periodicDue = clock.now() + period
            case .needsAttention: attention = true
            case .retry: break
            }
        }
        schedule()
    }

    private func recordRetry(_ delay: Double) {
        guard delay.isFinite, (0...3600).contains(delay), retries < 3 else {
            attention = true
            return
        }
        let noise = jitter()
        let boundedNoise = noise.isFinite ? min(max(noise, 0), 1) : 0
        retryDue = clock.now() + max(delay, pow(2, Double(retries)) * 5) + boundedNoise
        retries += 1
        dirty = true
        changeDue = clock.now()
    }
}

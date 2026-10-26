import CoreDomain
import Observation

public enum CalendarAccessState: Equatable, Sendable {
    case disabled, loading
    case access(OSAuthorization)
    case ready(CalendarCatalog)
    case incomplete, unavailable
}

/// Local discovery choices only, never connection grants or event-read capabilities.
@MainActor @Observable
public final class CalendarAccessStore {
    public private(set) var state: CalendarAccessState = .disabled
    public private(set) var isEnabled = false
    public private(set) var isBusy = false
    @ObservationIgnored private let provider: any CalendarDiscovering
    private var selection: Set<CalendarReference> = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var refreshPending = false

    public init(provider: any CalendarDiscovering) { self.provider = provider }

    public var selectedCalendars: Set<CalendarReference> {
        guard case .ready = state, isEnabled, !isBusy else { return [] }
        return selection
    }

    /// Called only by the explicit local opt-in control, never launch/lifecycle refresh.
    public func enable() async {
        guard !isEnabled, !isBusy else { return }
        isEnabled = true
        await load(requestAccess: true)
    }

    public func disable() {
        generation += 1
        isEnabled = false
        refreshPending = false
        selection = []
        state = .disabled
        // An OS prompt already in flight cannot be withdrawn; its late result is discarded.
    }

    public func refresh() async {
        guard isEnabled else { return }
        if isBusy {
            generation += 1
            state = .loading
            refreshPending = true
            return
        }
        await load(requestAccess: false)
    }

    public func setSelected(_ calendar: CalendarReference, selected: Bool) {
        guard isEnabled, !isBusy, case .ready(let catalog) = state,
            catalog.calendars.contains(where: { $0.id == calendar })
        else { return }
        if selected { selection.insert(calendar) } else { selection.remove(calendar) }
    }

    public func observeChanges() async {
        let stream = await provider.changes()
        for await _ in stream {
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    private func load(requestAccess: Bool) async {
        isBusy = true
        var shouldRequest = requestAccess
        repeat {
            refreshPending = false
            let currentGeneration = generation
            state = .loading
            var status = await provider.authorization()
            if Task.isCancelled { break }
            guard isEnabled, currentGeneration == generation else { continue }
            if shouldRequest && (status == .notDetermined || status == .writeOnly) {
                status = await provider.requestAccess()
            }
            shouldRequest = false
            // Disable during a suspended request must prevent even the subsequent metadata read.
            if Task.isCancelled { break }
            guard isEnabled, currentGeneration == generation else { continue }
            let result: CalendarDiscoveryResult
            if status == .fullAccess {
                result = await provider.discover()
            } else {
                result = .access(status)
            }
            if Task.isCancelled { break }
            guard isEnabled, currentGeneration == generation else { continue }
            switch result {
            case .available(let catalog):
                selection.formIntersection(catalog.calendars.map(\.id))
                state = .ready(catalog)
            case .access(let status):
                selection = []
                state = .access(status)
            case .incomplete:
                selection = []
                state = .incomplete
            case .unavailable:
                selection = []
                state = .unavailable
            }
        } while refreshPending && isEnabled && !Task.isCancelled
        isBusy = false
        if Task.isCancelled {
            selection = []
            state = .unavailable
        }
        if !isEnabled { state = .disabled }
    }
}

import CoreDomain
import Foundation
import Observation
import PermissionEngine

public enum LocalCalendarReadMode: String, CaseIterable, Identifiable, Sendable {
    case availability, titles, details
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .availability: "Availability only"
        case .titles: "Event titles"
        case .details: "Event details"
        }
    }
    var fields: Set<CalendarField> {
        switch self {
        case .availability: [.time, .occupancy]
        case .titles: [.time, .occupancy, .status, .title]
        case .details: [.time, .occupancy, .status, .title, .location, .notes]
        }
    }
    var detailFields: Set<CalendarDetailField> {
        switch self {
        case .availability: []
        case .titles: [.title]
        case .details: [.title, .location, .notes]
        }
    }
    var operation: CalendarOperation { self == .availability ? .checkAvailability : .readDetails }
}

public enum LocalCalendarReadResult: Sendable {
    case events(CalendarSnapshot)
    case availability(PermittedAvailability)
    case failed(ProviderFailure)
    case denied
}

/// Trusted local UI workflow only. Never export this administrative service to a client/transport.
@MainActor @Observable
public final class CalendarReadStore {
    public var mode: LocalCalendarReadMode = .availability { didSet { invalidate() } }
    public var startDate: Date { didSet { invalidate() } }
    public var endDate: Date { didSet { invalidate() } }
    public private(set) var isBusy = false
    private var storedResult: LocalCalendarReadResult?
    private var resultRevision: UInt64 = 0
    private var generation: UInt64 = 0
    private let access: CalendarAccessStore
    @ObservationIgnored private let reader: any CalendarReading
    @ObservationIgnored private let authorization: any CalendarDiscovering
    @ObservationIgnored private let authority: PolicyAuthority

    public init(
        access: CalendarAccessStore, reader: any CalendarReading,
        authorization: any CalendarDiscovering, authority: PolicyAuthority, now: Date = Date()
    ) {
        self.access = access
        self.reader = reader
        self.authorization = authorization
        self.authority = authority
        startDate = now
        endDate = now.addingTimeInterval(7 * 24 * 60 * 60)
        access.invalidateReads = { [weak self] in self?.clear() }
    }

    public var result: LocalCalendarReadResult? {
        guard resultRevision == access.revision else { return nil }
        return storedResult
    }

    public func clear() { invalidate() }

    private func invalidate() {
        generation &+= 1
        storedResult = nil
    }

    public func read() async {
        guard !isBusy else { return }
        invalidate()
        let localGeneration = generation
        let accessRevision = access.revision
        let selected = access.selectedCalendars
        let requestedMode = mode
        func current() -> Bool {
            !Task.isCancelled && generation == localGeneration && access.revision == accessRevision
                && access.selectedCalendars == selected && !selected.isEmpty
        }
        func publish(_ result: LocalCalendarReadResult) async {
            let latest = await authorization.authorization()
            guard current() else { return }
            if latest == .fullAccess {
                storedResult = result
            } else {
                await authority.observeOSPermissions(OSPermissions(calendars: latest))
                if current() { storedResult = .denied }
            }
        }
        resultRevision = accessRevision
        guard !selected.isEmpty else {
            storedResult = .denied
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let request = try CalendarReadRequest(
                calendars: selected,
                window: InstantInterval(start: Instant(startDate), end: Instant(endDate)))
            try CalendarReadLimits.validate(request)
            let id = try ConnectionID("trusted-local-calendar-reader")
            let status = await authorization.authorization()
            guard current() else { return }
            await authority.observeOSPermissions(OSPermissions(calendars: status))
            guard current() else { return }
            let grants = Dictionary(
                uniqueKeysWithValues: selected.map {
                    (
                        $0,
                        CalendarGrant(
                            operations: [requestedMode.operation],
                            readableFields: requestedMode.fields)
                    )
                })
            await authority.setConnection(
                Connection(id: id, kind: .localAutomation, state: .enabled),
                policy: ConnectionPolicy(calendars: grants))
            guard current() else { return }
            let session = try await authority.bindTrustedConnection(id)
            guard current() else { return }
            let decision = await session.evaluate(
                .calendarRead(
                    request, operation: requestedMode.operation, fields: requestedMode.fields))
            guard current() else { return }
            guard case .allowed(let permit) = decision else {
                storedResult = .denied
                return
            }
            let read = await reader.readOccurrences(request, fields: requestedMode.detailFields)
            guard current() else { return }
            let after = await authorization.authorization()
            guard current() else { return }
            await authority.observeOSPermissions(OSPermissions(calendars: after))
            guard current() else { return }
            guard case .allowed = await session.revalidate(permit) else {
                if current() { storedResult = .denied }
                return
            }
            guard current() else { return }
            switch read {
            case .failed(let failure): storedResult = .failed(failure)
            case .observed(let snapshot):
                guard snapshot.coverage == request,
                    snapshot.occurrences.count <= CalendarReadLimits.maximumOccurrences
                else {
                    storedResult = .failed(.invalidData)
                    return
                }
                if requestedMode == .availability {
                    let projection = try CalendarAvailability.project(snapshot)
                    let filtered = await session.filterAvailability(projection, using: permit)
                    guard current() else { return }
                    switch filtered {
                    case .value(let value): await publish(.availability(value))
                    case .denied: storedResult = .denied
                    }
                } else {
                    // All-day scope is validated here too; foreign providers cannot bypass coverage.
                    guard
                        try snapshot.occurrences.allSatisfy({
                            try CalendarTimeResolution.interval(for: $0.time).overlaps(
                                request.window)
                        })
                    else {
                        storedResult = .failed(.invalidData)
                        return
                    }
                    let filtered = await session.filterCalendar(snapshot, using: permit)
                    guard current() else { return }
                    switch filtered {
                    case .value(let value): await publish(.events(value))
                    case .denied: storedResult = .denied
                    }
                }
            }
        } catch {
            if current() { storedResult = .failed(.invalidData) }
        }
    }
}

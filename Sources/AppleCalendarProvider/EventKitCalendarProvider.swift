import CoreDomain
import EventKit
import Foundation

/// EventKit objects stay inside this actor. Only immutable domain values cross its boundary.
public actor EventKitCalendarProvider: CalendarDiscovering, CalendarReading {
    private var store: EKEventStore?
    private var requesting = false

    public init() {}

    public func authorization() -> OSAuthorization {
        Self.mapAuthorization(EKEventStore.authorizationStatus(for: .event))
    }

    public static func mapAuthorization(_ status: EKAuthorizationStatus) -> OSAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .writeOnly: .writeOnly
        case .fullAccess: .fullAccess
        @unknown default: .unknown
        }
    }

    public func requestAccess() async -> OSAuthorization {
        let current = authorization()
        guard current == .notDetermined || current == .writeOnly else { return current }
        guard !requesting else { return .unknown }
        requesting = true
        defer { requesting = false }
        let succeeded: Bool = await withCheckedContinuation { continuation in
            eventStore().requestFullAccessToEvents { _, error in
                // Ignore the callback's grant assertion; always reread current OS status.
                continuation.resume(returning: error == nil)
            }
        }
        guard succeeded else { return .unknown }
        return authorization()
    }

    public func discover() -> CalendarDiscoveryResult {
        let before = authorization()
        guard before == .fullAccess else { return .access(before) }
        let store = eventStore()
        do {
            let provider = try ProviderID("apple-eventkit")
            let storeID = try StoreID(store.eventStoreIdentifier)
            let sources = store.sources
            let accounts = try sources.map { source in
                CalendarAccount(
                    id: AccountReference(
                        provider: provider, store: storeID,
                        account: try AccountID(source.sourceIdentifier)), name: source.title)
            }
            let calendars = try store.calendars(for: .event).map { calendar in
                CalendarResource(
                    id: CalendarReference(
                        account: AccountReference(
                            provider: provider, store: storeID,
                            account: try AccountID(calendar.source.sourceIdentifier)),
                        localID: try DomainID(calendar.calendarIdentifier)), name: calendar.title)
            }
            let after = authorization()
            guard after == .fullAccess else { return .access(after) }
            guard store.eventStoreIdentifier == storeID.rawValue else { return .incomplete }
            let catalog = try CalendarCatalog(accounts: accounts, calendars: calendars)
            // Empty means only "none returned locally", never upstream completeness or deletion proof.
            return .available(catalog)
        } catch {
            // No raw EventKit error, source name or identifier enters logs.
            return .incomplete
        }
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observation = StoreChangeObservation(continuation: continuation)
            continuation.onTermination = { _ in observation.cancel() }
        }
    }

    public func discoverCalendars() -> ProviderReadResult<ResourceDiscovery<CalendarResource>> {
        switch discover() {
        case .available(let catalog):
            guard let instant = try? Instant(Date()) else { return .failed(.invalidData) }
            return .observed(
                ResourceDiscovery(
                    resources: catalog.calendars,
                    observation: ObservationState(
                        observedAt: instant, completeness: .complete, freshness: .localCache)))
        case .access: return .failed(.denied)
        case .incomplete: return .failed(.invalidData)
        case .unavailable: return .failed(.unavailable)
        }
    }

    public func readOccurrences(_ request: CalendarReadRequest, fields: Set<CalendarDetailField>)
        -> ProviderReadResult<CalendarSnapshot>
    {
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard authorization() == .fullAccess else { return .failed(.denied) }
        do {
            try CalendarReadLimits.validate(request)
            let changes = ReadChangeTracker()
            defer { changes.cancel() }
            let store = eventStore()
            let zone = TimeZone.current.identifier
            let calendars = store.calendars(for: .event)
            let references = try calendars.map { try Self.reference($0, store: store) }
            let indices = try CalendarEventNormalization.selectedIndices(
                references, request: request)
            let selected = indices.map { calendars[$0] }
            guard !selected.isEmpty else { return .failed(.invalidData) }
            let predicate = store.predicateForEvents(
                withStart: request.window.start.date,
                end: request.window.end.date, calendars: selected)
            let (records, exceededLimit, invalid) = Self.enumerate(
                store: store, predicate: predicate, fields: fields, zone: zone)
            guard !Task.isCancelled else { return .failed(.cancelled) }
            guard authorization() == .fullAccess else { return .failed(.revoked) }
            guard !invalid else { return .failed(.invalidData) }
            _ = try CalendarEventNormalization.selectedIndices(
                store.calendars(for: .event).map { try Self.reference($0, store: store) },
                request: request)
            guard !changes.changed, TimeZone.current.identifier == zone else {
                return .failed(.unavailable)
            }
            let events = try CalendarEventNormalization.occurrences(records, request: request)
            guard authorization() == .fullAccess else { return .failed(.revoked) }
            guard !changes.changed, TimeZone.current.identifier == zone else {
                return .failed(.unavailable)
            }
            let observed = try Instant(Date())
            return .observed(
                try CalendarSnapshot(
                    coverage: request, occurrences: events,
                    observation: ObservationState(
                        observedAt: observed,
                        completeness: exceededLimit ? .partial(.providerLimit) : .complete,
                        freshness: .localCache)))
        } catch let failure as ProviderFailure { return .failed(failure) } catch {
            return .failed(.invalidData)
        }
    }

    // EventKit documents this enumeration callback as synchronous. Keep the callback and
    // its accumulator in one nonisolated synchronous scope; no actor state crosses it.
    private static func enumerate(
        store: EKEventStore, predicate: NSPredicate,
        fields: Set<CalendarDetailField>, zone: String
    ) -> ([CalendarEventRecord], Bool, Bool) {
        var records: [CalendarEventRecord] = []
        var exceededLimit = false
        var invalid = false
        store.enumerateEvents(matching: predicate) { event, stop in
            if Task.isCancelled {
                stop.pointee = true
                return
            }
            if records.count >= CalendarReadLimits.maximumOccurrences {
                exceededLimit = true
                stop.pointee = true
                return
            }
            guard let calendar = event.calendar, let start = event.startDate,
                let end = event.endDate
            else {
                invalid = true
                stop.pointee = true
                return
            }
            do {
                let calendarRef = try Self.reference(calendar, store: store)
                records.append(
                    CalendarEventRecord(
                        calendar: calendarRef, itemID: event.calendarItemIdentifier,
                        start: start, end: end, allDay: event.isAllDay,
                        timeZone: event.isAllDay ? zone : (event.timeZone?.identifier ?? zone),
                        recurring: event.hasRecurrenceRules || event.isDetached,
                        originalDate: event.occurrenceDate,
                        occupancy: Self.occupancy(event.availability),
                        status: Self.status(event.status),
                        title: fields.contains(.title) ? .value(event.title) : .notFetched,
                        location: fields.contains(.location)
                            ? .value(event.location) : .notFetched,
                        notes: fields.contains(.notes) ? .value(event.notes) : .notFetched))
            } catch {
                invalid = true
                stop.pointee = true
            }
        }
        return (records, exceededLimit, invalid)
    }

    private static func reference(_ calendar: EKCalendar, store: EKEventStore) throws
        -> CalendarReference
    {
        try CalendarReference(
            account: AccountReference(
                provider: ProviderID("apple-eventkit"),
                store: StoreID(store.eventStoreIdentifier),
                account: AccountID(calendar.source.sourceIdentifier)),
            localID: DomainID(calendar.calendarIdentifier))
    }

    private static func occupancy(_ value: EKEventAvailability) -> Occupancy {
        switch value {
        case .free: .free
        case .busy, .unavailable: .busy
        case .tentative: .tentative
        case .notSupported: .unknown
        @unknown default: .unknown
        }
    }

    private static func status(_ value: EKEventStatus) -> EventStatus {
        switch value {
        case .canceled: .cancelled
        case .confirmed, .tentative: .active
        case .none: .unknown
        @unknown default: .unknown
        }
    }

    private func eventStore() -> EKEventStore {
        if let store { return store }
        let created = EKEventStore()
        store = created
        return created
    }
}

/// Foundation observer tokens are not Sendable. The lock protects exactly-once removal;
/// the notification callback captures only the Sendable stream continuation, never EventKit data.
final class StoreChangeObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var token: (any NSObjectProtocol)?

    init(continuation: AsyncStream<Void>.Continuation) {
        token = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: nil
        ) { _ in continuation.yield(()) }
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }

    deinit { cancel() }
}

/// A synchronous query can overlap a notification delivered on another thread.
/// Protect the flag, and remove the observer when that query ends. No resource payload is retained.
final class ReadChangeTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var invalidated = false
    private var token: (any NSObjectProtocol)?
    init() {
        token = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.invalidated = true
            self.lock.unlock()
        }
    }
    var changed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return invalidated
    }
    func cancel() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }
    deinit { cancel() }
}

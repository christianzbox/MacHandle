import CoreDomain
import EventKit
import Foundation

/// Independent Reminders authorization. No Calendar grant, writer, policy administration or MCP dependency.
public actor EventKitRemindersProvider: ReminderDiscovering, ReminderReading {
    private var store: EKEventStore?
    private var requesting = false
    private var active: [UUID: (Any, ReminderFetchBox)] = [:]
    public init() {}
    public static func mapAuthorization(_ value: EKAuthorizationStatus) -> OSAuthorization {
        switch value {
        case .fullAccess: .fullAccess
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied, .writeOnly: .denied
        @unknown default: .unknown
        }
    }
    public func authorization() -> OSAuthorization {
        Self.mapAuthorization(EKEventStore.authorizationStatus(for: .reminder))
    }
    private func eventStore() -> EKEventStore {
        if let store { return store }
        let value = EKEventStore()
        store = value
        return value
    }
    public func requestAccess() async -> OSAuthorization {
        guard authorization() == .notDetermined else { return authorization() }
        guard !requesting, !Task.isCancelled else { return .unknown }
        requesting = true
        defer { requesting = false }
        let success: Bool = await withCheckedContinuation { next in
            eventStore().requestFullAccessToReminders { _, error in
                next.resume(returning: error == nil)
            }
        }
        return success ? authorization() : .unknown
    }
    private static func reference(_ calendar: EKCalendar, store: String) throws
        -> ReminderListReference
    {
        try ReminderListReference(
            account: AccountReference(
                provider: ProviderID("apple-eventkit"),
                store: StoreID(store), account: AccountID(calendar.source.sourceIdentifier)),
            localID: DomainID(calendar.calendarIdentifier))
    }
    public func discoverReminderLists() -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard authorization() == .fullAccess else { return .failed(.denied) }
        let tracker = ReadChangeTracker()
        defer { tracker.cancel() }
        let store = eventStore()
        let storeID = store.eventStoreIdentifier
        do {
            let calendars = store.calendars(for: .reminder)
            guard calendars.count <= 1000 else { return .failed(.invalidData) }
            let lists = try calendars.map {
                ReminderList(
                    id: try Self.reference($0, store: storeID), name: $0.title,
                    accountName: $0.source.title)
            }
            guard Set(lists.map(\.id)).count == lists.count,
                storeID == store.eventStoreIdentifier, !tracker.changed,
                authorization() == .fullAccess, !Task.isCancelled
            else { return .failed(.unavailable) }
            return .observed(
                ResourceDiscovery(resources: lists, observation: try Self.observation()))
        } catch { return .failed(.invalidData) }
    }
    public func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observation = StoreChangeObservation(continuation: continuation)
            continuation.onTermination = { _ in observation.cancel() }
        }
    }
    private static func observation(partial: Bool = false, unknown: Bool = false) throws
        -> ObservationState
    {
        ObservationState(
            observedAt: try Instant(Date()),
            completeness: unknown ? .unknown : (partial ? .partial(.providerLimit) : .complete),
            freshness: .localCache)
    }
    private func selected(_ request: ReminderReadRequest, store: EKEventStore) throws
        -> [EKCalendar]
    {
        let calendars = store.calendars(for: .reminder)
        guard calendars.count <= 1000 else { throw ProviderFailure.invalidData }
        let refs = try calendars.map { try Self.reference($0, store: store.eventStoreIdentifier) }
        guard Set(refs).count == refs.count else { throw ProviderFailure.ambiguousIdentity }
        let indices = refs.indices.filter { request.lists.contains(refs[$0]) }
        guard indices.count == request.lists.count else { throw ProviderFailure.notFound }
        return indices.map { calendars[$0] }
    }
    public func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard authorization() == .fullAccess else { return .failed(.denied) }
        guard active.count < 4 else { return .failed(.unavailable) }
        let tracker = ReadChangeTracker()
        defer { tracker.cancel() }
        let store = eventStore()
        let storeID = store.eventStoreIdentifier
        do {
            let calendars = try selected(request, store: store)
            let result: ProviderReadResult<ReminderSnapshot>
            if let item = request.item {
                if let reminder = store.calendarItem(withIdentifier: item.item.rawValue)
                    as? EKReminder
                {
                    result = Self.project(
                        [reminder], request: request, fields: fields, store: storeID)
                } else {
                    result = .observed(
                        try ReminderSnapshot(
                            coverage: request, reminders: [],
                            observation: Self.observation(unknown: true)))
                }
            } else {
                let id = UUID()
                let box = ReminderFetchBox()
                let token = store.fetchReminders(
                    matching: store.predicateForReminders(in: calendars)
                ) { reminders in
                    box.finish(
                        Self.project(reminders, request: request, fields: fields, store: storeID))
                }
                active[id] = (token, box)
                let timeout = Task {
                    do { try await Task.sleep(for: .seconds(10)) } catch { return }
                    self.cancel(id, failure: .unavailable)
                }
                result = await withTaskCancellationHandler {
                    await box.value()
                } onCancel: {
                    box.finish(.failed(.cancelled))
                    Task { await self.cancel(id, failure: .cancelled) }
                }
                timeout.cancel()
                // Cancel even if a late cancellation task hasn't reached the actor yet.
                if Task.isCancelled { cancel(id, failure: .cancelled) }
                active.removeValue(forKey: id)
            }
            guard !Task.isCancelled else { return .failed(.cancelled) }
            guard authorization() == .fullAccess else { return .failed(.revoked) }
            _ = try selected(request, store: store)
            guard storeID == store.eventStoreIdentifier, !tracker.changed else {
                return .failed(.unavailable)
            }
            return result
        } catch { return .failed(.invalidData) }
    }
    private func cancel(_ id: UUID, failure: ProviderFailure) {
        guard let (token, box) = active.removeValue(forKey: id) else { return }
        store?.cancelFetchRequest(token)
        box.finish(.failed(failure))
    }
    // Callback objects are reduced synchronously; only immutable domain records cross into the actor.
    private static func project(
        _ values: [EKReminder]?, request: ReminderReadRequest,
        fields: Set<ReminderReadField>, store: String
    ) -> ProviderReadResult<ReminderSnapshot> {
        guard let values else { return .failed(.unavailable) }
        do {
            let reminders = try values.prefix(ReminderSnapshot.maximumItems).map {
                value -> Reminder in
                guard let calendar = value.calendar else { throw ProviderFailure.invalidData }
                let id = try ReminderReference(
                    list: reference(calendar, store: store),
                    item: ReminderID(value.calendarItemIdentifier))
                let title: FieldValue<String>
                if fields.contains(.title) {
                    guard let text = value.title, text.utf8.count <= 8192 else {
                        throw ProviderFailure.invalidData
                    }
                    title = .value(text)
                } else {
                    title = .notFetched
                }
                let notes: FieldValue<String?>
                if fields.contains(.notes) {
                    guard value.notes == nil || value.notes!.utf8.count <= 8192 else {
                        throw ProviderFailure.invalidData
                    }
                    notes = .value(value.notes)
                } else {
                    notes = .notFetched
                }
                return try Reminder(
                    id: id, title: title, notes: notes,
                    due: fields.contains(.due)
                        ? .value(ReminderNormalization.due(value.dueDateComponents)) : .notFetched,
                    completion: fields.contains(.completion)
                        ? .value(
                            value.isCompleted
                                ? .completed(at: value.completionDate.map(Instant.init))
                                : .incomplete) : .notFetched,
                    recurrence: fields.contains(.recurrence)
                        ? .value(value.hasRecurrenceRules ? .recurring : .notRecurring)
                        : .notFetched)
            }
            return .observed(
                try ReminderSnapshot(
                    coverage: request, reminders: reminders,
                    observation: observation(partial: values.count > ReminderSnapshot.maximumItems))
            )
        } catch { return .failed(.invalidData) }
    }
}

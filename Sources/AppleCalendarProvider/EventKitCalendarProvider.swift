import CoreDomain
import EventKit
import Foundation

/// EventKit objects stay inside this actor. Only immutable domain values cross its boundary.
public actor EventKitCalendarProvider: CalendarDiscovering {
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

    private func eventStore() -> EKEventStore {
        if let store { return store }
        let created = EKEventStore()
        store = created
        return created
    }
}

/// Foundation observer tokens are not Sendable. The lock protects exactly-once removal;
/// the notification callback captures only the Sendable stream continuation, never EventKit data.
private final class StoreChangeObservation: @unchecked Sendable {
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

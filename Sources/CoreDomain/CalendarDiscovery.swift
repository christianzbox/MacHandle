/// A local EventKit source identity, not proof of a remote account or its freshness.
public struct CalendarAccount: Hashable, Sendable {
    public let id: AccountReference
    public let name: String

    public init(id: AccountReference, name: String) {
        self.id = id
        self.name = name
    }
}

/// A coherent local metadata inventory. This never establishes event-read coverage.
public struct CalendarCatalog: Equatable, Sendable {
    public let accounts: [CalendarAccount]
    public let calendars: [CalendarResource]

    public init(accounts: [CalendarAccount], calendars: [CalendarResource]) throws {
        let accountIDs = Set(accounts.map(\.id))
        guard accountIDs.count == accounts.count,
            Set(calendars.map(\.id)).count == calendars.count,
            calendars.allSatisfy({ accountIDs.contains($0.id.account) })
        else { throw CalendarDiscoveryError.inconsistentInventory }
        self.accounts = accounts
        self.calendars = calendars
    }
}

public enum CalendarDiscoveryError: Error, Sendable {
    case inconsistentInventory
}

public enum CalendarDiscoveryResult: Equatable, Sendable {
    case available(CalendarCatalog)
    case access(OSAuthorization)
    case incomplete
    case unavailable
}

/// Metadata only: no event queries, mutations, external connections or policy administration.
public protocol CalendarDiscovering: Sendable {
    func authorization() async -> OSAuthorization
    func requestAccess() async -> OSAuthorization
    func discover() async -> CalendarDiscoveryResult
    func changes() async -> AsyncStream<Void>
}

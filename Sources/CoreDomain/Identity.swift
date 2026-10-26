import Foundation

/// Opaque, case-sensitive identity. Construction validates shape, never authority.
/// No Codable conformance: future boundary decoders must use validated initializers.
public struct DomainID<Kind: Sendable>: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptyIdentifier
        }
        self.rawValue = rawValue
    }
}

public enum ProviderTag: Sendable {}
public enum AccountTag: Sendable {}
public enum StoreTag: Sendable {}
public enum ConnectionTag: Sendable {}
public enum CredentialTag: Sendable {}
public enum CalendarTag: Sendable {}
public enum EventTag: Sendable {}
public enum ReminderListTag: Sendable {}
public enum ReminderTag: Sendable {}
public enum ContactContainerTag: Sendable {}
public enum ContactTag: Sendable {}
public enum OperationTag: Sendable {}
public enum RevisionTag: Sendable {}

public typealias ProviderID = DomainID<ProviderTag>
public typealias AccountID = DomainID<AccountTag>
public typealias StoreID = DomainID<StoreTag>
public typealias ConnectionID = DomainID<ConnectionTag>
public typealias CredentialHandle = DomainID<CredentialTag>
public typealias EventID = DomainID<EventTag>
public typealias ReminderID = DomainID<ReminderTag>
public typealias ContactID = DomainID<ContactTag>
public typealias OperationID = DomainID<OperationTag>
public typealias ObservedRevision = DomainID<RevisionTag>

/// Store identifies the provider's local identity domain, not a portable cross-Mac ID.
public struct AccountReference: Hashable, Sendable {
    public let provider: ProviderID
    public let store: StoreID
    public let account: AccountID

    public init(provider: ProviderID, store: StoreID, account: AccountID) {
        self.provider = provider
        self.store = store
        self.account = account
    }
}

public struct ResourceReference<Kind: Sendable>: Hashable, Sendable {
    public let account: AccountReference
    public let localID: DomainID<Kind>

    public init(account: AccountReference, localID: DomainID<Kind>) {
        self.account = account
        self.localID = localID
    }
}

public typealias CalendarReference = ResourceReference<CalendarTag>
public typealias ReminderListReference = ResourceReference<ReminderListTag>
public typealias ContactContainerReference = ResourceReference<ContactContainerTag>

/// Unresolved/ambiguous lookups must not silently pick a display-name match.
public enum ReferenceResolution<Value: Hashable & Sendable>: Hashable, Sendable {
    case resolved(Value)
    case missing
    case ambiguous
    case unavailable
}

public enum ConnectionKind: Hashable, Sendable {
    case googleSync, localMCP, localAutomation
}

public enum ConnectionState: Hashable, Sendable {
    case disabled, enabled, revoked
}

/// Configuration only. Even an enabled connection is not authenticated or authorized.
public struct Connection: Hashable, Sendable {
    public let id: ConnectionID
    public let kind: ConnectionKind
    public let state: ConnectionState
    public let credential: CredentialHandle?

    public init(
        id: ConnectionID, kind: ConnectionKind, state: ConnectionState = .disabled,
        credential: CredentialHandle? = nil
    ) {
        self.id = id
        self.kind = kind
        self.state = state
        self.credential = credential
    }
}

/// An OS observation, separate from connection state, policy, and local approval.
public enum OSAuthorization: Hashable, Sendable {
    case notDetermined, denied, restricted, writeOnly, fullAccess, unsupported, unknown
}

public enum DomainValidationError: Error, Equatable, Sendable {
    case emptyIdentifier, invalidInstant, invalidInterval, invalidDate, invalidTime
    case invalidTimeZone, emptySelection, resourceOutsideSelection, intervalOutsideCoverage
    case emptyChange
}

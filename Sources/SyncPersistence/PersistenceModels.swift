import Foundation

public enum PersistenceFailure: Error, Equatable, Sendable {
    case invalidInput, missingStore, alreadyExists, unsafeLocation, busy, incompatibleSchema
    case corrupt, identityMismatch, constraint, stateConflict, unavailable, closed, limitExceeded
}

/// Opaque SHA-256-shaped key/fingerprint. Values are not authentication or encryption.
public struct PersistenceDigest: Equatable, Hashable, Sendable {
    public let value: String
    public init(_ value: String) throws {
        guard value.utf8.count == 64,
            value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { throw PersistenceFailure.invalidInput }
        self.value = value
    }
}

/// Supplied by trusted composition; matching this record does not authenticate a Google account.
public struct PersistenceBinding: Equatable, Sendable {
    public let storeID: UUID
    public let installationID: UUID
    public let clientID: String
    public let accountKey: PersistenceDigest
    public init(
        storeID: UUID, installationID: UUID, clientID: String, accountKey: PersistenceDigest
    ) throws {
        guard clientID.hasSuffix(".apps.googleusercontent.com"), clientID.utf8.count <= 256,
            clientID.utf8.allSatisfy({
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || $0 == 45 || $0 == 46
            })
        else { throw PersistenceFailure.invalidInput }
        self.storeID = storeID
        self.installationID = installationID
        self.clientID = clientID
        self.accountKey = accountKey
    }
}
public enum PersistenceOpenMode: Sendable { case createNew, resume }
public enum PendingOperationKind: String, Sendable {
    case createDestination, insertEvent, updateEvent, deleteEvent
}
public enum PendingOperationState: String, Sendable { case prepared, unknown, completed }

public struct StoredResourceMapping: Sendable, Equatable {
    public let id: UUID
    public let sourceKey: PersistenceDigest
    public let destinationID: String?
    public let ownershipMarker: String
}
public struct StoredEventMapping: Sendable, Equatable {
    public let id: UUID
    public let resourceID: UUID
    public let sourceKey: PersistenceDigest
    public let destinationEventID: String
    public let fingerprint: PersistenceDigest?
    public let etag: String?
    public let deleted: Bool
}
public struct StoredPendingOperation: Sendable, Equatable {
    public let id: UUID
    public let resourceID: UUID
    public let eventID: UUID?
    public let kind: PendingOperationKind
    public let state: PendingOperationState
    public let expectedETag: String?
    public let desiredFingerprint: PersistenceDigest?
}
public struct PersistenceCheckpoint: Sendable, Equatable {
    public let revision: Int64
    public let completedRun: UUID?
}
public enum StoredSyncState: String, Equatable, Sendable { case paused, recoveryRequired }
public enum PersistenceResumeRequirement: Sendable { case remoteVerificationRequired }

/// Candidates for trusted revalidation, never executable capabilities or source-completeness evidence.
public struct PersistenceSnapshot: Sendable {
    public let binding: PersistenceBinding
    public let resources: [StoredResourceMapping]
    public let events: [StoredEventMapping]
    public let operations: [StoredPendingOperation]
    public let syncState: StoredSyncState
    public let checkpoint: PersistenceCheckpoint
    public let resumeRequirement: PersistenceResumeRequirement = .remoteVerificationRequired
}

enum PersistenceValue {
    static func opaque(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 1024,
            !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw PersistenceFailure.invalidInput }
    }
    static func etag(_ value: String) throws {
        guard value.count >= 3, value.utf8.count <= 1024, value.first == "\"", value.last == "\"",
            value.dropFirst().dropLast().utf8.allSatisfy({ $0 >= 33 && $0 <= 126 && $0 != 34 })
        else { throw PersistenceFailure.invalidInput }
    }
}

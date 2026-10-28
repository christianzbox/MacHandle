import Foundation

/// Persistence is not provider authorization. No Google/Apple APIs, tokens, or event bodies enter this module.
public actor SQLiteSyncStore {
    private let database: SQLiteConnection
    private let binding: PersistenceBinding

    public init(directory: URL, binding: PersistenceBinding, mode: PersistenceOpenMode) throws {
        let database = try SQLiteConnection(directory: directory, mode: mode)
        do { try PersistenceSchema.initialize(database, binding: binding, mode: mode) } catch {
            database.close()
            throw error
        }
        self.database = database
        self.binding = binding
    }
    // Failure injection is internal and used only against disposable synthetic stores.
    init(
        directory: URL, binding: PersistenceBinding, mode: PersistenceOpenMode,
        beforeCommit: @escaping () throws -> Void
    ) throws {
        let database = try SQLiteConnection(directory: directory, mode: mode)
        database.beforeCommit = beforeCommit
        do { try PersistenceSchema.initialize(database, binding: binding, mode: mode) } catch {
            database.close()
            throw error
        }
        self.database = database
        self.binding = binding
    }
    public func close() { database.close() }

    public func snapshot() throws -> PersistenceSnapshot {
        try PersistenceSchema.validateIdentity(database, binding: binding)
        guard try database.query("PRAGMA foreign_key_check").isEmpty else {
            throw PersistenceFailure.corrupt
        }
        do {
            let resources = try database.query(
                "SELECT id,source_key,destination_id,marker FROM resources ORDER BY id"
            ).map { row in
                let destination = row[2]
                if let destination {
                    try PersistenceValue.opaque(destination)
                    guard destination.lowercased() != "primary" else {
                        throw PersistenceFailure.corrupt
                    }
                }
                let marker = try text(row[3])
                guard UUID(uuidString: marker) != nil else { throw PersistenceFailure.corrupt }
                return try StoredResourceMapping(
                    id: uuid(row[0]), sourceKey: PersistenceDigest(text(row[1])),
                    destinationID: destination, ownershipMarker: marker)
            }
            let events = try database.query(
                "SELECT id,resource_id,source_key,remote_id,fingerprint,etag,deleted FROM events ORDER BY id"
            ).map { row in
                let remoteID = try text(row[3])
                guard remoteID.count == 32,
                    remoteID.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                    row[6] == "0" || row[6] == "1"
                else { throw PersistenceFailure.corrupt }
                if let etag = row[5] { try PersistenceValue.etag(etag) }
                let fingerprint = try row[4].map(PersistenceDigest.init)
                guard (fingerprint == nil) == (row[5] == nil), row[6] != "1" || fingerprint == nil
                else { throw PersistenceFailure.corrupt }
                return try StoredEventMapping(
                    id: uuid(row[0]), resourceID: uuid(row[1]),
                    sourceKey: PersistenceDigest(text(row[2])), destinationEventID: remoteID,
                    fingerprint: fingerprint, etag: row[5], deleted: row[6] == "1")
            }
            let operations = try database.query(
                "SELECT id,resource_id,event_id,kind,state,expected_etag,fingerprint FROM operations ORDER BY id"
            ).map { row in
                guard let kind = PendingOperationKind(rawValue: try text(row[3])),
                    let state = PendingOperationState(rawValue: try text(row[4]))
                else { throw PersistenceFailure.corrupt }
                if let etag = row[5] { try PersistenceValue.etag(etag) }
                return try StoredPendingOperation(
                    id: uuid(row[0]), resourceID: uuid(row[1]), eventID: row[2].map(uuid),
                    kind: kind, state: state, expectedETag: row[5],
                    desiredFingerprint: row[6].map(PersistenceDigest.init))
            }
            let rows = try database.query(
                "SELECT revision,completed_run FROM checkpoint WHERE singleton=1")
            guard rows.count == 1, let revision = Int64(try text(rows[0][0])), revision >= 0 else {
                throw PersistenceFailure.corrupt
            }
            let checkpoint = try PersistenceCheckpoint(
                revision: revision, completedRun: rows[0][1].map(uuid))
            let statuses = try database.query("SELECT status FROM sync_state WHERE singleton=1")
            guard statuses.count == 1, let raw = statuses[0][0],
                let syncState = StoredSyncState(rawValue: raw),
                (syncState == .recoveryRequired)
                    == operations.contains(where: { $0.state == .unknown })
            else { throw PersistenceFailure.corrupt }
            return PersistenceSnapshot(
                binding: binding, resources: resources, events: events, operations: operations,
                syncState: syncState,
                preferences: try readPreferences(), checkpoint: checkpoint)
        } catch let failure as PersistenceFailure {
            throw failure == .invalidInput ? PersistenceFailure.corrupt : failure
        }
    }

    /// Persists creation intent before any future provider dispatch; a source key cannot be rebound silently.
    public func prepareDestination(sourceKey: PersistenceDigest) throws -> StoredPendingOperation {
        try database.transaction {
            let state = try snapshot()
            guard state.resources.count < 10_000, state.operations.count < 10_000 else {
                throw PersistenceFailure.limitExceeded
            }
            let resource = UUID()
            let operation = UUID()
            try database.execute(
                "INSERT INTO resources VALUES(?,?,NULL,?)",
                [resource.uuidString, sourceKey.value, operation.uuidString])
            try database.execute(
                "INSERT INTO operations VALUES(?,?,NULL,'createDestination','prepared',NULL,NULL)",
                [operation.uuidString, resource.uuidString])
            return try pending(operation)
        }
    }

    /// Commits 'unknown' BEFORE the network action. A crash at any later point requires verification.
    public func beginAttempt(_ operationID: UUID) throws -> StoredPendingOperation {
        try database.transaction {
            let operation = try pending(operationID)
            guard operation.state == .prepared else { throw PersistenceFailure.stateConflict }
            try database.execute(
                "UPDATE operations SET state='unknown' WHERE id=? AND state='prepared'",
                [operationID.uuidString])
            try database.execute(
                "UPDATE sync_state SET status='recoveryRequired' WHERE singleton=1")
            return try pending(operationID)
        }
    }

    /// Records an executor's observation, not an authorization/ownership capability for a provider.
    public func recordDestinationResult(
        _ operationID: UUID, destinationID: String, ownershipMarker: String
    ) throws {
        try PersistenceValue.opaque(destinationID)
        guard destinationID.lowercased() != "primary" else { throw PersistenceFailure.invalidInput }
        try database.transaction {
            let operation = try pending(operationID)
            guard operation.kind == .createDestination, operation.state == .unknown,
                ownershipMarker == operationID.uuidString
            else { throw PersistenceFailure.stateConflict }
            try database.execute(
                "UPDATE resources SET destination_id=? WHERE id=? AND destination_id IS NULL AND marker=?",
                [destinationID, operation.resourceID.uuidString, ownershipMarker])
            try changedOne()
            try complete(operationID)
        }
    }

    public func prepareInsert(
        resourceID: UUID, sourceKey: PersistenceDigest, fingerprint: PersistenceDigest
    ) throws -> StoredPendingOperation {
        try database.transaction {
            let state = try snapshot()
            try requireDestination(resourceID, in: state)
            guard state.events.count < 10_000, state.operations.count < 10_000 else {
                throw PersistenceFailure.limitExceeded
            }
            let event = UUID()
            let remoteID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            let operation = UUID()
            try database.execute(
                "INSERT INTO events(id,resource_id,source_key,remote_id) VALUES(?,?,?,?)",
                [event.uuidString, resourceID.uuidString, sourceKey.value, remoteID])
            try database.execute(
                "INSERT INTO operations VALUES(?,?,?,'insertEvent','prepared',NULL,?)",
                [operation.uuidString, resourceID.uuidString, event.uuidString, fingerprint.value])
            return try pending(operation)
        }
    }

    public func prepareChange(
        eventID: UUID, kind: PendingOperationKind, expectedETag: String,
        desiredFingerprint: PersistenceDigest? = nil
    ) throws -> StoredPendingOperation {
        try PersistenceValue.etag(expectedETag)
        guard
            (kind == .updateEvent && desiredFingerprint != nil)
                || (kind == .deleteEvent && desiredFingerprint == nil)
        else {
            throw PersistenceFailure.invalidInput
        }
        return try database.transaction {
            let state = try snapshot()
            guard state.operations.count < 10_000 else { throw PersistenceFailure.limitExceeded }
            guard let event = state.events.first(where: { $0.id == eventID }), !event.deleted,
                event.etag == expectedETag, event.fingerprint != nil,
                state.operations.contains(where: {
                    $0.eventID == eventID && $0.kind == .insertEvent && $0.state == .completed
                })
            else { throw PersistenceFailure.stateConflict }
            try requireDestination(event.resourceID, in: state)
            let operation = UUID()
            try database.execute(
                "INSERT INTO operations VALUES(?,?,?,?,'prepared',?,?)",
                [
                    operation.uuidString, event.resourceID.uuidString, eventID.uuidString,
                    kind.rawValue, expectedETag, desiredFingerprint?.value,
                ])
            return try pending(operation)
        }
    }

    /// Complete only after remote verification. The storage contract cannot perform that verification itself.
    public func recordEventResult(
        _ operationID: UUID, observedETag: String?, confirmedFingerprint: PersistenceDigest?
    ) throws {
        if let observedETag { try PersistenceValue.etag(observedETag) }
        try database.transaction {
            let operation = try pending(operationID)
            guard operation.state == .unknown, let event = operation.eventID else {
                throw PersistenceFailure.stateConflict
            }
            if operation.kind == .deleteEvent {
                guard observedETag == nil, confirmedFingerprint == nil else {
                    throw PersistenceFailure.invalidInput
                }
                try database.execute(
                    "UPDATE events SET deleted=1,fingerprint=NULL,etag=NULL WHERE id=?",
                    [event.uuidString])
            } else {
                guard operation.kind == .insertEvent || operation.kind == .updateEvent,
                    observedETag != nil, let confirmedFingerprint,
                    confirmedFingerprint == operation.desiredFingerprint
                else {
                    throw PersistenceFailure.stateConflict
                }
                try database.execute(
                    "UPDATE events SET fingerprint=?,etag=? WHERE id=? AND deleted=0",
                    [confirmedFingerprint.value, observedETag, event.uuidString])
            }
            try changedOne()
            try complete(operationID)
        }
    }

    /// Local bookkeeping only. A checkpoint is not a complete source snapshot or permission to delete.
    public func commitCheckpoint(expectedRevision: Int64, completedRun: UUID) throws
        -> PersistenceCheckpoint
    {
        guard expectedRevision >= 0, expectedRevision < Int64.max else {
            throw PersistenceFailure.invalidInput
        }
        return try database.transaction {
            let state = try snapshot()
            guard state.checkpoint.revision == expectedRevision,
                state.operations.allSatisfy({ $0.state == .completed })
            else { throw PersistenceFailure.stateConflict }
            try database.execute(
                "UPDATE checkpoint SET revision=revision+1,completed_run=? WHERE singleton=1 AND revision=?",
                [completedRun.uuidString, String(expectedRevision)])
            try changedOne()
            return try snapshot().checkpoint
        }
    }
    /// Imports metadata into an explicitly created EMPTY replacement store. Never repairs
    /// or overwrites the damaged original, and never grants remote ownership or writer status.
    public func restoreCandidate(_ candidate: PersistenceSnapshot) throws {
        guard candidate.binding.clientID == binding.clientID,
            candidate.binding.accountKey == binding.accountKey,
            candidate.resources.count <= 10_000, candidate.events.count <= 10_000,
            candidate.operations.count <= 10_000
        else { throw PersistenceFailure.identityMismatch }
        try database.transaction {
            let current = try snapshot()
            guard current.resources.isEmpty, current.events.isEmpty, current.operations.isEmpty,
                current.checkpoint.revision == 0
            else { throw PersistenceFailure.stateConflict }
            for resource in candidate.resources {
                try database.execute(
                    "INSERT INTO resources VALUES(?,?,?,?)",
                    [
                        resource.id.uuidString, resource.sourceKey.value, resource.destinationID,
                        resource.ownershipMarker,
                    ])
            }
            for event in candidate.events {
                try database.execute(
                    "INSERT INTO events VALUES(?,?,?,?,?,?,?)",
                    [
                        event.id.uuidString, event.resourceID.uuidString, event.sourceKey.value,
                        event.destinationEventID, event.fingerprint?.value, event.etag,
                        event.deleted ? "1" : "0",
                    ])
            }
            for operation in candidate.operations {
                // A backup may predate dispatch. Restored prepared intent is always uncertain.
                let state = operation.state == .completed ? "completed" : "unknown"
                try database.execute(
                    "INSERT INTO operations VALUES(?,?,?,?,?,?,?)",
                    [
                        operation.id.uuidString, operation.resourceID.uuidString,
                        operation.eventID?.uuidString,
                        operation.kind.rawValue, state, operation.expectedETag,
                        operation.desiredFingerprint?.value,
                    ])
            }
            try database.execute(
                "UPDATE sync_state SET status=CASE WHEN EXISTS(SELECT 1 FROM operations WHERE state='unknown') THEN 'recoveryRequired' ELSE 'paused' END WHERE singleton=1"
            )
            try writePreferences(candidate.preferences)
            // A restored checkpoint is not evidence of a completed run on this installation.
            _ = try snapshot()
        }
    }

    /// Atomic CAS after trusted remote/source verification and explicit local approval.
    /// Remote IDs, creation history, ETags and tombstones remain unchanged.
    public func recoverMetadata(
        expected: PersistenceSnapshot, resourceID: UUID, sourceKey: PersistenceDigest,
        changes: [RecoveryMappingChange]
    ) throws {
        try database.transaction {
            let current = try snapshot()
            guard current == expected, current.operations.allSatisfy({ $0.state == .completed }),
                current.checkpoint.revision < Int64.max
            else { throw PersistenceFailure.stateConflict }
            try requireDestination(resourceID, in: current)
            let events = current.events.filter { $0.resourceID == resourceID }
            guard Set(changes.map(\.eventID)) == Set(events.map(\.id)),
                changes.count == events.count,
                Set(changes.map(\.sourceKey)).count == changes.count
            else { throw PersistenceFailure.invalidInput }
            for change in changes {
                guard let event = events.first(where: { $0.id == change.eventID }),
                    (change.fingerprint == nil) == event.deleted
                else { throw PersistenceFailure.invalidInput }
                try database.execute(
                    "UPDATE events SET source_key=? WHERE id=?",
                    ["recovery:" + change.eventID.uuidString, change.eventID.uuidString])
            }
            if let old = current.resources.first(where: { $0.id == resourceID }),
                let preferences = current.preferences, preferences.sources.contains(old.sourceKey)
            {
                var selected = preferences.sources
                selected.remove(old.sourceKey)
                selected.insert(sourceKey)
                try writePreferences(
                    StoredSyncPreferences(sources: selected, fieldMask: preferences.fieldMask))
            }
            try database.execute(
                "UPDATE resources SET source_key=? WHERE id=?",
                [sourceKey.value, resourceID.uuidString])
            for change in changes {
                try database.execute(
                    "UPDATE events SET source_key=?,fingerprint=? WHERE id=?",
                    [change.sourceKey.value, change.fingerprint?.value, change.eventID.uuidString])
            }
            try database.execute(
                "UPDATE checkpoint SET revision=revision+1,completed_run=NULL WHERE singleton=1")
            _ = try snapshot()
        }
    }

    /// Private account-bound choices; restoring these never resumes scheduling or grants access.
    public func savePreferences(_ value: StoredSyncPreferences?) throws {
        try database.transaction {
            _ = try snapshot()
            try writePreferences(value)
        }
    }
    private func readPreferences() throws -> StoredSyncPreferences? {
        let rows = try database.query(
            "SELECT sources,field_mask FROM sync_preferences WHERE singleton=1")
        guard !rows.isEmpty else { return nil }
        guard rows.count == 1, let encoded = rows[0][0], encoded.utf8.count <= 4096,
            let mask = rows[0][1].flatMap(Int.init),
            let values = try? JSONDecoder().decode([String].self, from: Data(encoded.utf8)),
            Set(values).count == values.count
        else { throw PersistenceFailure.corrupt }
        return try StoredSyncPreferences(
            sources: Set(values.map(PersistenceDigest.init)), fieldMask: mask)
    }
    private func writePreferences(_ value: StoredSyncPreferences?) throws {
        try database.execute("DELETE FROM sync_preferences")
        if let value {
            let encoded = String(
                decoding: try JSONEncoder().encode(value.sources.map(\.value).sorted()),
                as: UTF8.self)
            try database.execute(
                "INSERT INTO sync_preferences VALUES(1,?,?)", [encoded, String(value.fieldMask)])
        }
    }

    private func requireDestination(_ id: UUID, in state: PersistenceSnapshot) throws {
        guard state.resources.contains(where: { $0.id == id && $0.destinationID != nil }),
            state.operations.contains(where: {
                $0.resourceID == id && $0.kind == .createDestination && $0.state == .completed
            })
        else {
            throw PersistenceFailure.stateConflict
        }
    }
    private func pending(_ id: UUID) throws -> StoredPendingOperation {
        guard let operation = try snapshot().operations.first(where: { $0.id == id }) else {
            throw PersistenceFailure.stateConflict
        }
        return operation
    }
    private func complete(_ id: UUID) throws {
        try database.execute(
            "UPDATE operations SET state='completed' WHERE id=? AND state='unknown'",
            [id.uuidString])
        try changedOne()
        try database.execute(
            "UPDATE sync_state SET status=CASE WHEN EXISTS(SELECT 1 FROM operations WHERE state='unknown') THEN 'recoveryRequired' ELSE 'paused' END WHERE singleton=1"
        )
    }
    private func changedOne() throws {
        guard try database.query("SELECT changes()") == [["1"]] else {
            throw PersistenceFailure.stateConflict
        }
    }
    private func text(_ value: String?) throws -> String {
        guard let value else { throw PersistenceFailure.corrupt }
        return value
    }
    private func uuid(_ value: String?) throws -> UUID {
        guard let value, let result = UUID(uuidString: value) else {
            throw PersistenceFailure.corrupt
        }
        return result
    }
}

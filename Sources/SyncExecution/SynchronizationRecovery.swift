import CoreDomain
import Foundation
import GoogleAuthorization
import SyncPersistence
import SyncPlanning

struct RecoveryEventBinding: Equatable, Sendable {
    let eventID: UUID
    let original: OccurrenceReference
    let replacement: OccurrenceReference
    /// Last exported content, including its original zone for a legacy v1 baseline.
    /// Never inferred from current source details or accepted as remote proof.
    let baseline: PlannedEventContent?
}

struct RecoveryReview: Equatable, Sendable {
    let expected: PersistenceSnapshot
    let resourceID: UUID
    let source: CalendarReference
    let events: [RecoveryEventBinding]
}

/// Metadata recovery only. No remote writes or grants; live composition stays denied.
/// Authorization must establish actual account/client, complete source identity continuity,
/// exclusive writer/standby state, and explicit approval of this exact immutable review.
actor SynchronizationRecovery {
    private let store: SQLiteSyncStore
    private let destination: GoogleDurableDestination
    private let authorize: @Sendable (RecoveryReview) async throws -> Void
    private var busy = false

    init(
        store: SQLiteSyncStore, destination: GoogleDurableDestination,
        authorize: @escaping @Sendable (RecoveryReview) async throws -> Void = { _ in
            throw ExecutionFailure.blocked
        }
    ) {
        self.store = store
        self.destination = destination
        self.authorize = authorize
    }

    func recoverMetadata(_ review: RecoveryReview) async throws {
        guard !busy else { throw ExecutionFailure.busy }
        busy = true
        defer { busy = false }
        let state = try await store.snapshot()
        guard state == review.expected,
            state.operations.allSatisfy({ $0.state == .completed }),
            let resource = state.resources.first(where: { $0.id == review.resourceID }),
            resource.destinationID == destination.calendarID,
            resource.ownershipMarker == destination.marker,
            state.operations.contains(where: {
                $0.resourceID == resource.id && $0.kind == .createDestination
                    && $0.state == .completed && $0.id.uuidString == resource.ownershipMarker
            })
        else { throw ExecutionFailure.recoveryRequired }
        let events = state.events.filter { $0.resourceID == resource.id }
        guard review.events.count == events.count,
            Set(review.events.map(\.eventID)) == Set(events.map(\.id)),
            Set(review.events.map(\.replacement)).count == events.count,
            review.events.allSatisfy({ $0.replacement.calendar == review.source })
        else { throw ExecutionFailure.blocked }
        try CalendarOccurrenceIdentity.validate(Set(review.events.map(\.replacement)))
        let check: @Sendable () async throws -> Void = {
            try Task.checkCancellation()
            try await self.authorize(review)
            try Task.checkCancellation()
        }
        try await check()
        let activeIDs = Set(events.filter { !$0.deleted }.map(\.destinationEventID))
        guard try await destination.inventoryIDs(beforeSend: check) == activeIDs else {
            throw ExecutionFailure.recoveryRequired
        }
        var changes: [RecoveryMappingChange] = []
        for binding in review.events {
            guard let event = events.first(where: { $0.id == binding.eventID }),
                PlanningFingerprint.calendar(binding.original.calendar).value
                    == resource.sourceKey.value,
                try PlanningFingerprint.occurrence(binding.original).value == event.sourceKey.value,
                let creation = state.operations.first(where: {
                    $0.eventID == event.id && $0.kind == .insertEvent && $0.state == .completed
                })
            else { throw ExecutionFailure.blocked }
            let fingerprint: PlanningFingerprint?
            let content: GoogleEventContent?
            if event.deleted {
                guard binding.baseline == nil else { throw ExecutionFailure.blocked }
                fingerprint = nil
                content = nil
            } else {
                guard let baseline = binding.baseline, let saved = event.fingerprint else {
                    throw ExecutionFailure.recoveryRequired
                }
                let current = try PlanningFingerprint.content(baseline)
                let legacy = try PlanningFingerprint.legacyContentV1(baseline)
                guard saved.value == current.value || saved.value == legacy.value
                else { throw ExecutionFailure.conflict }
                fingerprint = current
                content = try GoogleContentProjection.convert(baseline)
            }
            try await destination.verifyBaseline(
                GoogleRecoveryBaseline(
                    eventID: event.destinationEventID, creationID: creation.id,
                    etag: event.etag, content: content), beforeSend: check)
            changes.append(
                try RecoveryMappingChange(
                    eventID: event.id,
                    sourceKey: PersistenceDigest(
                        PlanningFingerprint.occurrence(binding.replacement).value),
                    fingerprint: fingerprint.map { try PersistenceDigest($0.value) }))
        }
        // Inventory drift cannot turn a partial backup into a complete reconstruction.
        guard try await destination.inventoryIDs(beforeSend: check) == activeIDs else {
            throw ExecutionFailure.recoveryRequired
        }
        try await check()
        try await store.recoverMetadata(
            expected: state, resourceID: resource.id,
            sourceKey: PersistenceDigest(PlanningFingerprint.calendar(review.source).value),
            changes: changes)
    }

    /// Cooperative handoff only: the original writer must be quiescent and the
    /// journal fully resolved. No clock expiry or force-takeover path exists.
    func transferWriter(
        to recipient: UUID,
        authorizeTransfer: @escaping @Sendable (PersistenceSnapshot, UUID) async throws -> Void = {
            _, _ in
            throw ExecutionFailure.blocked
        }
    ) async throws {
        guard !busy else { throw ExecutionFailure.busy }
        busy = true
        defer { busy = false }
        let state = try await store.snapshot()
        guard recipient != state.binding.installationID,
            state.operations.allSatisfy({ $0.state == .completed }),
            let resource = state.resources.first(where: {
                $0.destinationID == destination.calendarID
            }),
            resource.ownershipMarker == destination.marker,
            state.operations.contains(where: {
                $0.resourceID == resource.id && $0.kind == .createDestination
                    && $0.state == .completed && $0.id.uuidString == resource.ownershipMarker
            })
        else { throw ExecutionFailure.recoveryRequired }
        try await destination.transferWriter(
            to: recipient,
            beforeSend: {
                try Task.checkCancellation()
                try await authorizeTransfer(state, recipient)
                guard try await self.store.snapshot() == state else {
                    throw ExecutionFailure.recoveryRequired
                }
            })
    }

    /// Candidate calendar ID must be separately restored through the Google account adapter.
    /// Lost creation responses are resolved by verified reads, never another calendar POST.
    func recoverDestination(
        operationID: UUID,
        authorizeCreation: @escaping @Sendable (PersistenceSnapshot) async throws -> Void = { _ in
            throw ExecutionFailure.blocked
        }
    ) async throws {
        guard !busy else { throw ExecutionFailure.busy }
        busy = true
        defer { busy = false }
        let state = try await store.snapshot()
        guard let operation = state.operations.first(where: { $0.id == operationID }),
            operation.kind == .createDestination, operation.state == .unknown,
            let resource = state.resources.first(where: { $0.id == operation.resourceID }),
            resource.destinationID == nil, resource.ownershipMarker == destination.marker,
            resource.ownershipMarker == operationID.uuidString,
            !state.events.contains(where: { $0.resourceID == resource.id })
        else { throw ExecutionFailure.recoveryRequired }
        let check: @Sendable () async throws -> Void = {
            try Task.checkCancellation()
            try await authorizeCreation(state)
        }
        try await check()
        guard try await destination.inventoryIDs(beforeSend: check).isEmpty else {
            throw ExecutionFailure.recoveryRequired
        }
        try await check()
        guard try await store.snapshot() == state else { throw ExecutionFailure.recoveryRequired }
        try await store.recordDestinationResult(
            operationID, destinationID: destination.calendarID,
            ownershipMarker: destination.marker)
    }
}

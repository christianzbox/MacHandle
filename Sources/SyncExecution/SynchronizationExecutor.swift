import CoreDomain
import Foundation
import GoogleAuthorization
import SyncPersistence
import SyncPlanning

/// Internal composition only; no public activation or provider authority factory.
actor SynchronizationExecutor {
    private let store: SQLiteSyncStore
    private let binding: PersistenceBinding
    private let destination: GoogleDurableDestination
    private let authority: any ExecutionAuthorizing
    private var busy = false
    init(
        store: SQLiteSyncStore, binding: PersistenceBinding, destination: GoogleDurableDestination,
        authority: any ExecutionAuthorizing = InactiveExecutionAuthority()
    ) {
        self.store = store
        self.binding = binding
        self.destination = destination
        self.authority = authority
    }
    func run(preview: ReconciliationPlan) async -> ExecutionReport {
        guard !busy else { return ExecutionReport(status: .busy, completedOperations: 0) }
        busy = true
        defer { busy = false }
        var completed = 0
        do {
            try Task.checkCancellation()
            let input = try await authority.currentInput()
            let plan = ReconciliationPlanner.plan(input)
            guard plan == preview else { throw ExecutionFailure.stalePreview }
            guard plan.issues.isEmpty else { throw ExecutionFailure.blocked }
            guard
                plan.proposals.allSatisfy({
                    switch $0.action {
                    case .conflict, .manualIntervention: false
                    default: true
                    }
                })
            else { throw ExecutionFailure.conflict }
            let initial = try await store.snapshot()
            let resource = try resource(in: initial, plan: plan)
            guard initial.operations.allSatisfy({ $0.state == .completed }) else {
                throw ExecutionFailure.recoveryRequired
            }
            try validateMappings(input, snapshot: initial, resource: resource)
            try await check(plan, nil, .read)
            for proposal in plan.proposals {
                try Task.checkCancellation()
                if case .noChange = proposal.action { continue }
                try await check(plan, proposal, .write)
                // Validate wire precision before creating persistent intent.
                _ = try payload(proposal)
                let operation = try await prepare(
                    proposal, resource: resource, snapshot: await store.snapshot())
                let mappedID = input.mappings.records.first(where: { $0.source == proposal.source }
                )?.destinationID
                let previous = try input.destination.events.first(where: { $0.id == mappedID }).map
                { try GoogleContentProjection.convert($0.content) }
                let command = try command(
                    proposal, operation: operation, snapshot: await store.snapshot(),
                    previous: previous)
                // After this commit, every interruption is an unknown outcome, never a retry ticket.
                _ = try await store.beginAttempt(operation.id)
                let gate: @Sendable () async throws -> Void = {
                    try await self.check(plan, proposal, .write)
                }
                try await destination.send(command, beforeSend: gate)
                let etag = try await destination.confirm(
                    command, beforeSend: { try await self.check(plan, proposal, .read) })
                try await check(plan, proposal, .commit)
                try await store.recordEventResult(
                    operation.id, observedETag: etag,
                    confirmedFingerprint: operation.desiredFingerprint)
                completed += 1
            }
            try await check(plan, nil, .commit)
            _ = try await store.commitCheckpoint(
                expectedRevision: initial.checkpoint.revision, completedRun: UUID())
            return ExecutionReport(status: .completed, completedOperations: completed)
        } catch { return report(error, completed: completed) }
    }
    /// Read-only remote recovery of exactly one unknown operation. Never resends a mutation or advances a checkpoint.
    /// The trusted authority must still validate the original desired content/confirmation against current state.
    func recover(operationID: UUID, proposal: ReconciliationProposal, preview: ReconciliationPlan)
        async -> ExecutionReport
    {
        guard !busy else { return ExecutionReport(status: .busy, completedOperations: 0) }
        busy = true
        defer { busy = false }
        do {
            try Task.checkCancellation()
            guard preview.issues.isEmpty, preview.proposals.contains(proposal) else {
                throw ExecutionFailure.blocked
            }
            let state = try await store.snapshot()
            let resource = try resource(in: state, plan: preview)
            guard let operation = state.operations.first(where: { $0.id == operationID }),
                operation.resourceID == resource.id, operation.state == .unknown
            else { throw ExecutionFailure.recoveryRequired }
            let command = try command(proposal, operation: operation, snapshot: state)
            try await check(preview, proposal, .read)
            let etag = try await destination.confirm(
                command, beforeSend: { try await self.check(preview, proposal, .read) })
            try await check(preview, proposal, .commit)
            try await store.recordEventResult(
                operation.id, observedETag: etag, confirmedFingerprint: operation.desiredFingerprint
            )
            // Recovery is not run completion; caller must obtain fresh observations and a new preview.
            return ExecutionReport(status: .recovered, completedOperations: 1)
        } catch { return report(error, completed: 0) }
    }
    private func resource(in state: PersistenceSnapshot, plan: ReconciliationPlan) throws
        -> StoredResourceMapping
    {
        guard state.binding == binding,
            plan.scope.destination.localID.rawValue == destination.calendarID,
            let resource = state.resources.first(where: {
                $0.sourceKey.value == PlanningFingerprint.calendar(plan.scope.source).value
            }),
            resource.destinationID == destination.calendarID,
            resource.ownershipMarker == destination.marker,
            state.operations.contains(where: {
                $0.resourceID == resource.id && $0.kind == .createDestination
                    && $0.state == .completed
            })
        else { throw ExecutionFailure.blocked }
        return resource
    }
    private func validateMappings(
        _ input: ReconciliationInput, snapshot: PersistenceSnapshot, resource: StoredResourceMapping
    ) throws {
        let events = snapshot.events.filter { $0.resourceID == resource.id }
        guard events.count == input.mappings.records.count else {
            throw ExecutionFailure.recoveryRequired
        }
        for map in input.mappings.records {
            let key = try PlanningFingerprint.occurrence(map.source).value
            guard let event = events.first(where: { $0.sourceKey.value == key }),
                event.destinationEventID == map.destinationID.rawValue
            else { throw ExecutionFailure.recoveryRequired }
            switch map.disposition {
            case .deleted: guard event.deleted else { throw ExecutionFailure.recoveryRequired }
            case .active(let fingerprint, let revision):
                guard !event.deleted, event.fingerprint?.value == fingerprint.value,
                    event.etag == revision.rawValue
                else { throw ExecutionFailure.recoveryRequired }
            }
        }
    }
    private func prepare(
        _ proposal: ReconciliationProposal, resource: StoredResourceMapping,
        snapshot: PersistenceSnapshot
    ) async throws -> StoredPendingOperation {
        let key = try PersistenceDigest(PlanningFingerprint.occurrence(proposal.source).value)
        switch proposal.action {
        case .create(let content):
            return try await store.prepareInsert(
                resourceID: resource.id, sourceKey: key,
                fingerprint: PersistenceDigest(PlanningFingerprint.content(content).value))
        case .update(let id, let content, let revision):
            guard
                let event = snapshot.events.first(where: {
                    $0.resourceID == resource.id && $0.sourceKey == key
                        && $0.destinationEventID == id.rawValue
                })
            else { throw ExecutionFailure.recoveryRequired }
            return try await store.prepareChange(
                eventID: event.id, kind: .updateEvent, expectedETag: revision.rawValue,
                desiredFingerprint: PersistenceDigest(PlanningFingerprint.content(content).value))
        case .delete(let id, let revision):
            guard
                let event = snapshot.events.first(where: {
                    $0.resourceID == resource.id && $0.sourceKey == key
                        && $0.destinationEventID == id.rawValue
                })
            else { throw ExecutionFailure.recoveryRequired }
            return try await store.prepareChange(
                eventID: event.id, kind: .deleteEvent, expectedETag: revision.rawValue)
        default: throw ExecutionFailure.blocked
        }
    }
    private func payload(_ proposal: ReconciliationProposal) throws -> GoogleEventContent? {
        switch proposal.action {
        case .create(let content), .update(_, let content, _):
            try GoogleContentProjection.convert(content)
        case .delete: nil
        default: throw ExecutionFailure.blocked
        }
    }
    private func command(
        _ proposal: ReconciliationProposal, operation: StoredPendingOperation,
        snapshot: PersistenceSnapshot, previous: GoogleEventContent? = nil
    ) throws -> GoogleDurableCommand {
        guard let event = snapshot.events.first(where: { $0.id == operation.eventID }),
            event.sourceKey.value == (try PlanningFingerprint.occurrence(proposal.source).value),
            let creation = snapshot.operations.first(where: {
                $0.eventID == event.id && $0.kind == .insertEvent
            })
        else { throw ExecutionFailure.recoveryRequired }
        let kind: GoogleDurableKind
        switch proposal.action {
        case .create(let desired):
            guard operation.kind == .insertEvent,
                operation.desiredFingerprint?.value
                    == (try PlanningFingerprint.content(desired).value), operation.id == creation.id
            else { throw ExecutionFailure.recoveryRequired }
            kind = .insert
        case .update(let id, let desired, let version):
            guard operation.kind == .updateEvent, event.destinationEventID == id.rawValue,
                operation.expectedETag == version.rawValue,
                operation.desiredFingerprint?.value
                    == (try PlanningFingerprint.content(desired).value)
            else { throw ExecutionFailure.recoveryRequired }
            kind = .update
        case .delete(let id, let version):
            guard operation.kind == .deleteEvent, event.destinationEventID == id.rawValue,
                operation.expectedETag == version.rawValue
            else { throw ExecutionFailure.recoveryRequired }
            kind = .delete
        default: throw ExecutionFailure.blocked
        }
        return GoogleDurableCommand(
            kind: kind, operationID: operation.id, creationID: creation.id,
            eventID: event.destinationEventID, expectedETag: operation.expectedETag,
            previousContent: previous, content: try payload(proposal))
    }
    private func check(
        _ plan: ReconciliationPlan, _ proposal: ReconciliationProposal?, _ phase: ExecutionPhase
    ) async throws {
        try Task.checkCancellation()
        try await authority.check(
            ExecutionRequest(binding: binding, plan: plan, proposal: proposal, phase: phase))
        try Task.checkCancellation()
    }
    private func report(_ error: Error, completed: Int) -> ExecutionReport {
        let status: ExecutionReport.Status
        if error is CancellationError || Task.isCancelled {
            status = .cancelled
        } else if error is PersistenceFailure {
            status = .storageFailure
        } else if let failure = error as? ExecutionFailure {
            switch failure {
            case .conflict: status = .conflict
            case .recoveryRequired: status = .recoveryRequired
            case .busy: status = .busy
            default: status = .blocked
            }
        } else if let failure = error as? GoogleDestinationFailure {
            switch failure {
            case .conflict: status = .conflict
            case .authorization: status = .blocked
            case .cancelled: status = .cancelled
            default: status = .recoveryRequired
            }
        } else {
            status = .recoveryRequired
        }
        return ExecutionReport(status: status, completedOperations: completed)
    }
}

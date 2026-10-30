import CoreDomain

/// Comparison inputs are observations supplied by trusted composition, never authorization capabilities.
public struct PlanningScope: Hashable, Sendable {
    public let source: CalendarReference
    public let destination: CalendarReference
    public init(source: CalendarReference, destination: CalendarReference) {
        self.source = source
        self.destination = destination
    }
}
public struct PlanningPolicy: Hashable, Sendable {
    public let revision: ObservedRevision
    public let enabled: Bool
    public let fields: Set<CalendarDetailField>
    public init(
        revision: ObservedRevision, enabled: Bool = false, fields: Set<CalendarDetailField> = []
    ) {
        self.revision = revision
        self.enabled = enabled
        self.fields = fields
    }
}
public enum PlanningEvidence: Hashable, Sendable { case unverified, verified }
public enum MappingHealth: Hashable, Sendable { case unverified, verified, missing, corrupt }

/// Full replacement of the allowed mirrored fields; empty strings explicitly clear old details.
/// No guest, invitation, attachment or conference fields exist here.
public struct PlannedEventContent: Hashable, Sendable {
    public let time: EventTime
    public let isFree: Bool
    public let title: String
    public let location: String
    public let notes: String
    public init(
        time: EventTime, isFree: Bool, title: String = "Busy", location: String = "",
        notes: String = ""
    ) {
        self.time = time
        self.isFree = isFree
        self.title = title
        self.location = location
        self.notes = notes
    }
}
public struct DestinationObservation: Hashable, Sendable {
    public let id: EventID
    public let content: PlannedEventContent
    public let revision: ObservedRevision
    public let ownership: PlanningEvidence
    public init(
        id: EventID, content: PlannedEventContent, revision: ObservedRevision,
        ownership: PlanningEvidence = .unverified
    ) {
        self.id = id
        self.content = content
        self.revision = revision
        self.ownership = ownership
    }
}
public struct PlanningDestination: Sendable {
    public let scope: PlanningScope
    public let window: InstantInterval
    public let observation: ObservationState
    public let ownership: PlanningEvidence
    public let events: [DestinationObservation]
    public init(
        scope: PlanningScope, window: InstantInterval, observation: ObservationState,
        ownership: PlanningEvidence = .unverified, events: [DestinationObservation]
    ) {
        self.scope = scope
        self.window = window
        self.observation = observation
        self.ownership = ownership
        self.events = events
    }
}
public enum MappingDisposition: Hashable, Sendable {
    case active(fingerprint: PlanningFingerprint, revision: ObservedRevision)
    case deleted
}
public struct PlanningMapping: Hashable, Sendable {
    public let source: OccurrenceReference
    public let destinationID: EventID
    public let lastSourceInterval: InstantInterval
    public let disposition: MappingDisposition
    public init(
        source: OccurrenceReference, destinationID: EventID, lastSourceInterval: InstantInterval,
        disposition: MappingDisposition
    ) {
        self.source = source
        self.destinationID = destinationID
        self.lastSourceInterval = lastSourceInterval
        self.disposition = disposition
    }
}
public struct PlanningMappings: Sendable {
    public let scope: PlanningScope
    public let health: MappingHealth
    public let hasUnresolvedOperations: Bool
    public let records: [PlanningMapping]
    public init(
        scope: PlanningScope, health: MappingHealth = .unverified,
        hasUnresolvedOperations: Bool = true, records: [PlanningMapping]
    ) {
        self.scope = scope
        self.health = health
        self.hasUnresolvedOperations = hasUnresolvedOperations
        self.records = records
    }
}
public struct ReconciliationInput: Sendable {
    public let scope: PlanningScope
    public let policy: PlanningPolicy
    public let source: CalendarSnapshot
    public let sourceIdentity: PlanningEvidence
    public let destination: PlanningDestination
    public let mappings: PlanningMappings
    /// Requires independent trusted absence verification; absence from a bounded snapshot is insufficient.
    public let confirmedAbsent: Set<OccurrenceReference>
    public init(
        scope: PlanningScope, policy: PlanningPolicy, source: CalendarSnapshot,
        sourceIdentity: PlanningEvidence = .unverified, destination: PlanningDestination,
        mappings: PlanningMappings, confirmedAbsent: Set<OccurrenceReference> = []
    ) {
        self.scope = scope
        self.policy = policy
        self.source = source
        self.sourceIdentity = sourceIdentity
        self.destination = destination
        self.mappings = mappings
        self.confirmedAbsent = confirmedAbsent
    }
}
public enum PlanningIssue: String, Error, Hashable, Sendable {
    case disabled, scopeMismatch, incompleteSource, staleSource, incompleteDestination,
        staleDestination
    case unverifiedIdentity, unverifiedOwnership, missingMappings, corruptMappings, unknownOutcome
    case invalidInput, ambiguousIdentity, untrackedDestination, missingDestination
    case unknownSourceState, unavailableDetail, destinationChanged, absenceUnverified,
        tombstoneConflict
}
public enum ReconciliationAction: Hashable, Sendable {
    case create(PlannedEventContent)
    case update(EventID, PlannedEventContent, expectedRevision: ObservedRevision)
    case delete(EventID, expectedRevision: ObservedRevision)
    case noChange
    case conflict(PlanningIssue)
    case manualIntervention(PlanningIssue)
}
public struct ReconciliationProposal: Hashable, Sendable {
    /// Deterministic comparison identity, not a remote event ID, persisted operation ID, or approval.
    public let id: PlanningFingerprint
    public let source: OccurrenceReference
    public let action: ReconciliationAction
    public var requiresDeletionConfirmation: Bool {
        if case .delete = action { return true }
        return false
    }
}
public struct ReconciliationPlan: Equatable, Sendable {
    public let scope: PlanningScope
    public let policyRevision: ObservedRevision
    public let issues: [PlanningIssue]
    public let proposals: [ReconciliationProposal]
    /// Every proposal requires fresh trusted policy, ownership, version and writer checks before dispatch.
    public let requiresExecutionRevalidation = true
}

import CoreDomain
import Foundation
import SyncPlanning
import Testing

private let zone = try! TimeZoneID("America/Detroit")
private func instant(_ seconds: Double) -> Instant {
    try! Instant(Date(timeIntervalSince1970: seconds))
}
private func interval(_ start: Double = 1000, _ end: Double = 2000) -> InstantInterval {
    try! InstantInterval(start: instant(start), end: instant(end))
}
private func calendar(_ name: String) -> CalendarReference {
    CalendarReference(
        account: AccountReference(
            provider: try! ProviderID("synthetic"), store: try! StoreID("local"),
            account: try! AccountID("account")), localID: try! DomainID(name))
}
private let scope = PlanningScope(source: calendar("source"), destination: calendar("destination"))
private let coverage = try! CalendarReadRequest(
    calendars: [scope.source], window: interval(0, 10000))
private let revision = try! ObservedRevision("synthetic-1")
private let complete = ObservationState(
    observedAt: instant(500), completeness: .complete, freshness: .verifiedThrough(instant(500)))
private func occurrence(
    _ name: String = "one", time: EventTime = .timed(interval(), timeZone: zone),
    status: EventStatus = .active, occupancy: Occupancy = .busy,
    anchor: RecurrenceAnchor = .notRecurring,
    title: FieldValue<String?> = .value("Synthetic title"),
    location: FieldValue<String?> = .value("Synthetic room"),
    notes: FieldValue<String?> = .value("Synthetic notes")
) -> CalendarOccurrence {
    CalendarOccurrence(
        id: OccurrenceReference(
            calendar: scope.source, item: try! EventID(name), originalAnchor: anchor), time: time,
        occupancy: occupancy, status: status, title: title, location: location, notes: notes)
}
private func content(_ source: CalendarOccurrence = occurrence(), detailed: Bool = false)
    -> PlannedEventContent
{
    PlannedEventContent(
        time: source.time, isFree: source.occupancy == .free,
        title: detailed ? "Synthetic title" : "Busy", location: detailed ? "Synthetic room" : "",
        notes: detailed ? "Synthetic notes" : "")
}
private func mapping(
    _ source: CalendarOccurrence = occurrence(), detailed: Bool = false,
    disposition: MappingDisposition? = nil
) -> PlanningMapping {
    PlanningMapping(
        source: source.id, destinationID: try! EventID("remote-" + source.id.item.rawValue),
        lastSourceInterval: try! CalendarTimeResolution.interval(for: source.time),
        disposition: disposition
            ?? .active(
                fingerprint: try! .content(content(source, detailed: detailed)), revision: revision)
    )
}
private func remote(
    _ source: CalendarOccurrence = occurrence(), detailed: Bool = false,
    version: ObservedRevision = revision, ownership: PlanningEvidence = .verified,
    payload: PlannedEventContent? = nil
) -> DestinationObservation {
    DestinationObservation(
        id: mapping(source).destinationID, content: payload ?? content(source, detailed: detailed),
        revision: version, ownership: ownership)
}
private func input(
    _ sources: [CalendarOccurrence] = [occurrence()], records: [PlanningMapping] = [],
    events: [DestinationObservation] = [], fields: Set<CalendarDetailField> = [],
    enabled: Bool = true, health: MappingHealth = .verified, unresolved: Bool = false,
    sourceState: ObservationState = complete, destinationState: ObservationState = complete,
    identity: PlanningEvidence = .verified, ownership: PlanningEvidence = .verified,
    absent: Set<OccurrenceReference> = [], target: PlanningScope = scope,
    policyRevision: ObservedRevision = revision
) throws -> ReconciliationInput {
    ReconciliationInput(
        scope: scope,
        policy: PlanningPolicy(revision: policyRevision, enabled: enabled, fields: fields),
        source: try CalendarSnapshot(
            coverage: coverage, occurrences: sources, observation: sourceState),
        sourceIdentity: identity,
        destination: PlanningDestination(
            scope: target, window: coverage.window, observation: destinationState,
            ownership: ownership, events: events),
        mappings: PlanningMappings(
            scope: scope, health: health, hasUnresolvedOperations: unresolved, records: records),
        confirmedAbsent: absent)
}
private func actions(_ input: ReconciliationInput) -> [ReconciliationAction] {
    ReconciliationPlanner.plan(input).proposals.map(\.action)
}

@Test func availabilityProjectionNeverIncludesUnselectedDetails() throws {
    let plan = ReconciliationPlanner.plan(try input())
    #expect(plan.issues.isEmpty && plan.requiresExecutionRevalidation)
    #expect(plan.proposals.map(\.action) == [.create(content())])
    let hidden = occurrence(
        title: .notAuthorized, location: .notFetched,
        notes: .value(String(repeating: "x", count: 9000)))
    #expect(actions(try input([hidden])) == [.create(content())])
}
@Test func detailsRequireExplicitSelectionAndFetchedValues() throws {
    let projected = PlannedEventContent(
        time: occurrence().time, isFree: false, title: "Synthetic title")
    #expect(actions(try input(fields: [.title])) == [.create(projected)])
    #expect(
        actions(try input([occurrence(title: .notFetched)], fields: [.title])) == [
            .manualIntervention(.unavailableDetail)
        ])
    #expect(
        actions(try input([occurrence(title: .notAuthorized)], fields: [.title])) == [
            .manualIntervention(.unavailableDetail)
        ])
    #expect(
        actions(try input([occurrence(title: .value(nil))], fields: [.title])) == [
            .create(content())
        ])
}
@Test func privacyReductionClearsPreviouslySharedFields() throws {
    #expect(
        actions(try input(records: [mapping(detailed: true)], events: [remote(detailed: true)]))
            == [.update(mapping().destinationID, content(), expectedRevision: revision)])
    let changedRemote = remote(detailed: true, version: try ObservedRevision("changed"))
    #expect(
        actions(try input(records: [mapping(detailed: true)], events: [changedRemote])) == [
            .conflict(.destinationChanged)
        ])
}
@Test func successfulCreateAndUpdateObservationsConvergeToNoWrites() throws {
    #expect(actions(try input()) == [.create(content())])
    #expect(actions(try input(records: [mapping()], events: [remote()])) == [.noChange])
    let moved = occurrence(time: .timed(interval(1200, 2200), timeZone: zone))
    #expect(
        actions(try input([moved], records: [mapping()], events: [remote()])) == [
            .update(mapping().destinationID, content(moved), expectedRevision: revision)
        ])
    #expect(
        actions(try input([moved], records: [mapping(moved)], events: [remote(moved)])) == [
            .noChange
        ])
}
@Test func shuffledInputsYieldIdenticalOrderedPlansAndStableOccurrenceIdentity() throws {
    let first = occurrence("one", anchor: .timed(instant(1000)))
    let second = occurrence("two")
    let a = ReconciliationPlanner.plan(
        try input(
            [first, second], records: [mapping(first), mapping(second)],
            events: [remote(first), remote(second)]))
    let b = ReconciliationPlanner.plan(
        try input(
            [second, first], records: [mapping(second), mapping(first)],
            events: [remote(second), remote(first)]))
    #expect(a == b && a.proposals.count == 2)
    let moved = occurrence(
        "one", time: .timed(interval(1300, 2300), timeZone: zone), anchor: .timed(instant(1000)))
    #expect(
        try PlanningFingerprint.occurrence(first.id) == PlanningFingerprint.occurrence(moved.id))
    #expect(
        ReconciliationPlanner.plan(try input()).proposals
            == ReconciliationPlanner.plan(try input()).proposals)
}
@Test func fingerprintsAreVersionedUnambiguousAndIndependentOfSwiftHasher() throws {
    let first = PlannedEventContent(
        time: occurrence().time, isFree: false, title: "a:bc", location: "d")
    let second = PlannedEventContent(
        time: occurrence().time, isFree: false, title: "a", location: "bc:d")
    #expect(try PlanningFingerprint.content(first) != PlanningFingerprint.content(second))
    #expect(
        try PlanningFingerprint.content(content()).value
            == "7a3c6e2c163e5c0a8a3b756985c4fabea5dee418d93308d548316d5739ce7278")
    #expect(throws: PlanningIssue.invalidInput) { try PlanningFingerprint("invalid") }
}
@Test func incompleteOrStaleSourceNeverProducesWrites() throws {
    for completeness: ReadCompleteness in [
        .unknown, .partial(.morePages), .partial(.interrupted(.revoked)),
    ] {
        let state = ObservationState(observedAt: instant(500), completeness: completeness)
        #expect(
            ReconciliationPlanner.plan(
                try input([], records: [mapping()], events: [remote()], sourceState: state)
            ).issues == [.incompleteSource])
    }
    for freshness: SourceFreshness in [.unknown, .localCache, .verifiedThrough(instant(499))] {
        let state = ObservationState(
            observedAt: instant(500), completeness: .complete, freshness: freshness)
        #expect(ReconciliationPlanner.plan(try input(sourceState: state)).issues == [.staleSource])
    }
    let cachedDestination = ObservationState(
        observedAt: instant(500), completeness: .complete, freshness: .localCache)
    #expect(
        ReconciliationPlanner.plan(try input(destinationState: cachedDestination)).issues == [
            .staleDestination
        ])
    let partial = ObservationState(observedAt: instant(500), completeness: .partial(.morePages))
    #expect(
        ReconciliationPlanner.plan(try input(destinationState: partial)).issues == [
            .incompleteDestination
        ])
}
@Test func disabledPolicyAndMismatchedScopeBlockTheWholePlan() throws {
    #expect(ReconciliationPlanner.plan(try input(enabled: false)).issues == [.disabled])
    let other = PlanningScope(source: scope.source, destination: calendar("other"))
    #expect(ReconciliationPlanner.plan(try input(target: other)).issues == [.scopeMismatch])
    #expect(
        ReconciliationPlanner.plan(try input(identity: .unverified)).issues == [.unverifiedIdentity]
    )
    #expect(
        ReconciliationPlanner.plan(try input(ownership: .unverified)).issues == [
            .unverifiedOwnership
        ])
}
@Test func missingCorruptUnverifiedAndPendingMappingsBlockCreatesAndDeletes() throws {
    for (health, issue): (MappingHealth, PlanningIssue) in [
        (.missing, .missingMappings), (.corrupt, .corruptMappings),
        (.unverified, .unverifiedIdentity),
    ] {
        let plan = ReconciliationPlanner.plan(try input(health: health))
        #expect(plan.issues == [issue] && plan.proposals.isEmpty)
    }
    #expect(ReconciliationPlanner.plan(try input(unresolved: true)).issues == [.unknownOutcome])
}
@Test func duplicateIdentitiesCannotTrapOrChooseAnArbitraryRecord() throws {
    #expect(
        ReconciliationPlanner.plan(try input([occurrence(), occurrence()])).issues == [
            .ambiguousIdentity
        ])
    #expect(
        ReconciliationPlanner.plan(try input(records: [mapping(), mapping()])).issues == [
            .ambiguousIdentity
        ])
    #expect(
        ReconciliationPlanner.plan(try input(records: [mapping()], events: [remote(), remote()]))
            .issues == [.ambiguousIdentity])
    let collision = PlanningMapping(
        source: occurrence("other").id, destinationID: mapping().destinationID,
        lastSourceInterval: interval(), disposition: mapping().disposition)
    #expect(
        ReconciliationPlanner.plan(try input(records: [mapping(), collision])).issues == [
            .ambiguousIdentity
        ])
}
@Test func destinationEditsConflictEvenWhenDesiredPayloadAlreadyMatches() throws {
    #expect(
        actions(
            try input(records: [mapping()], events: [remote(version: try ObservedRevision("v2"))]))
            == [.conflict(.destinationChanged)])
    #expect(
        actions(
            try input(
                records: [mapping()], events: [remote(detailed: true)],
                fields: [.title, .location, .notes])) == [.conflict(.destinationChanged)])
    #expect(
        actions(try input(records: [mapping()], events: [remote(ownership: .unverified)])) == [
            .manualIntervention(.unverifiedOwnership)
        ])
}
@Test func missingAndUntrackedDestinationsNeverCauseReplacementOrCleanup() throws {
    #expect(actions(try input(records: [mapping()])) == [.manualIntervention(.missingDestination)])
    let plan = ReconciliationPlanner.plan(try input(events: [remote()]))
    #expect(plan.issues == [.untrackedDestination] && plan.proposals.isEmpty)
}
@Test func deletionRequiresPositiveEvidenceAndEveryDeleteRequiresConfirmation() throws {
    #expect(
        actions(try input([], records: [mapping()], events: [remote()])) == [
            .manualIntervention(.absenceUnverified)
        ])
    for sources in [[], [occurrence(status: .cancelled)]] {
        let absent: Set<OccurrenceReference> = sources.isEmpty ? [occurrence().id] : []
        let plan = ReconciliationPlanner.plan(
            try input(sources, records: [mapping()], events: [remote()], absent: absent))
        #expect(
            plan.proposals.map(\.action) == [
                .delete(mapping().destinationID, expectedRevision: revision)
            ])
        #expect(plan.proposals.allSatisfy { $0.requiresDeletionConfirmation })
    }
    #expect(
        ReconciliationPlanner.plan(
            try input(records: [mapping()], events: [remote()], absent: [occurrence().id])
        ).issues == [.scopeMismatch])
}
@Test func rollingWindowNeverDeletesMappingsOutsideItsCoverage() throws {
    let old = occurrence(time: .timed(interval(-2000, -1000), timeZone: zone))
    #expect(actions(try input([], records: [mapping(old)], absent: [old.id])) == [.noChange])
    let overlapsBoundary = occurrence(time: .timed(interval(-1000, 1000), timeZone: zone))
    #expect(
        actions(try input([], records: [mapping(overlapsBoundary)], absent: [overlapsBoundary.id]))
            == [.noChange])
}
@Test func tombstonesCannotSilentlyResurrectAnEvent() throws {
    let dead = mapping(disposition: .deleted)
    #expect(actions(try input(records: [dead])) == [.manualIntervention(.tombstoneConflict)])
    #expect(actions(try input([], records: [dead])) == [.noChange])
    #expect(
        actions(try input([], records: [dead], events: [remote()])) == [
            .manualIntervention(.tombstoneConflict)
        ])
    #expect(actions(try input([occurrence(status: .cancelled)])) == [.noChange])
}
@Test func uncertainOccurrenceIdentityAndStateRequireIntervention() throws {
    #expect(
        ReconciliationPlanner.plan(try input([occurrence(anchor: .unknown)])).issues == [
            .ambiguousIdentity
        ])
    #expect(
        actions(try input([occurrence(status: .unknown)])) == [
            .manualIntervention(.unknownSourceState)
        ])
    #expect(
        actions(try input([occurrence(occupancy: .unknown)])) == [
            .manualIntervention(.unknownSourceState)
        ])
}
@Test func allDayFreeAndTentativeSemanticsSurviveProjection() throws {
    // A civil day covering the synthetic window, with explicit exclusive end and zone.
    let utc = try TimeZoneID("UTC")
    let dates = try LocalDateInterval(
        start: LocalDate(year: 1970, month: 1, day: 1), end: LocalDate(year: 1970, month: 1, day: 2)
    )
    let allDay = occurrence(time: .allDay(dates, timeZone: utc), occupancy: .free)
    #expect(actions(try input([allDay])) == [.create(content(allDay))])
    let tentative = occurrence(occupancy: .tentative)
    #expect(actions(try input([tentative])) == [.create(content(tentative))])
    let outside = occurrence(
        time: .allDay(
            try LocalDateInterval(
                start: LocalDate(year: 1971, month: 1, day: 1),
                end: LocalDate(year: 1971, month: 1, day: 2)), timeZone: utc))
    #expect(ReconciliationPlanner.plan(try input([outside])).issues == [.ambiguousIdentity])
}
@Test func policyChangesBindNewProposalIdentityAndOversizedDetailsAreRejected() throws {
    let a = ReconciliationPlanner.plan(try input())
    let b = ReconciliationPlanner.plan(try input(policyRevision: try ObservedRevision("policy-2")))
    #expect(a.proposals.first?.id != b.proposals.first?.id)
    let huge = occurrence(title: .value(String(repeating: "x", count: 8193)))
    #expect(actions(try input([huge], fields: [.title])) == [.manualIntervention(.invalidInput)])
    #expect(
        ReconciliationPlanner.plan(try input(Array(repeating: occurrence(), count: 10001))).issues
            == [.invalidInput])
}

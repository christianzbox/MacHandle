import CoreDomain

/// Pure comparison only. Public evidence values do not grant access to any provider.
public enum ReconciliationPlanner {
    public static func plan(_ input: ReconciliationInput) -> ReconciliationPlan {
        do {
            try validate(input)
            let source = Dictionary(
                uniqueKeysWithValues: input.source.occurrences.map { ($0.id, $0) })
            let mappings = Dictionary(
                uniqueKeysWithValues: input.mappings.records.map { ($0.source, $0) })
            let destination = Dictionary(
                uniqueKeysWithValues: input.destination.events.map { ($0.id, $0) })
            let keys = try Set(source.keys).union(mappings.keys).map {
                ($0, try PlanningFingerprint.occurrence($0).value)
            }.sorted { $0.1 < $1.1 }
            let proposals = try keys.map { reference, key in
                let action = compare(
                    source[reference], mapping: mappings[reference], destination: destination,
                    input: input)
                return ReconciliationProposal(
                    id: try proposalID(key: key, action: action, input: input), source: reference,
                    action: action)
            }
            return ReconciliationPlan(
                scope: input.scope, policyRevision: input.policy.revision, issues: [],
                proposals: proposals)
        } catch let issue as PlanningIssue {
            return ReconciliationPlan(
                scope: input.scope, policyRevision: input.policy.revision, issues: [issue],
                proposals: [])
        } catch {
            return ReconciliationPlan(
                scope: input.scope, policyRevision: input.policy.revision, issues: [.invalidInput],
                proposals: [])
        }
    }
    private static func validate(_ input: ReconciliationInput) throws {
        guard input.policy.enabled else { throw PlanningIssue.disabled }
        guard input.scope == input.destination.scope, input.scope == input.mappings.scope,
            input.source.coverage.calendars == [input.scope.source],
            input.source.coverage.window == input.destination.window,
            input.scope.source != input.scope.destination,
            input.scope.destination.localID.rawValue.lowercased() != "primary"
        else { throw PlanningIssue.scopeMismatch }
        guard input.source.observation.completeness == .complete else {
            throw PlanningIssue.incompleteSource
        }
        // Local EventKit enumeration alone is not upstream freshness evidence.
        guard case .verifiedThrough(let through) = input.source.observation.freshness,
            through >= input.source.observation.observedAt
        else { throw PlanningIssue.staleSource }
        guard input.destination.observation.completeness == .complete else {
            throw PlanningIssue.incompleteDestination
        }
        guard
            case .verifiedThrough(let destinationThrough) = input.destination.observation.freshness,
            destinationThrough >= input.destination.observation.observedAt
        else { throw PlanningIssue.staleDestination }
        guard input.sourceIdentity == .verified else { throw PlanningIssue.unverifiedIdentity }
        guard input.destination.ownership == .verified else {
            throw PlanningIssue.unverifiedOwnership
        }
        switch input.mappings.health {
        case .missing: throw PlanningIssue.missingMappings
        case .corrupt: throw PlanningIssue.corruptMappings
        case .unverified: throw PlanningIssue.unverifiedIdentity
        case .verified: break
        }
        guard !input.mappings.hasUnresolvedOperations else { throw PlanningIssue.unknownOutcome }
        try CalendarReadLimits.validate(input.source.coverage)
        guard input.source.occurrences.count <= 10_000, input.mappings.records.count <= 10_000,
            input.destination.events.count <= 10_000, input.confirmedAbsent.count <= 10_000
        else { throw PlanningIssue.invalidInput }
        let sources = input.source.occurrences.map(\.id)
        let mapped = input.mappings.records.map(\.source)
        let remote = input.destination.events.map(\.id)
        let mappedRemote = input.mappings.records.map(\.destinationID)
        guard Set(sources).count == sources.count, Set(mapped).count == mapped.count,
            Set(remote).count == remote.count, Set(mappedRemote).count == mappedRemote.count
        else { throw PlanningIssue.ambiguousIdentity }
        guard input.confirmedAbsent.isDisjoint(with: sources),
            input.confirmedAbsent.isSubset(of: Set(mapped)),
            mapped.allSatisfy({ $0.calendar == input.scope.source })
        else { throw PlanningIssue.scopeMismatch }
        for reference in sources + mapped { _ = try PlanningFingerprint.occurrence(reference) }
        for event in input.source.occurrences {
            guard
                input.source.coverage.window.overlaps(
                    try CalendarTimeResolution.interval(for: event.time)),
                event.seriesID == nil || event.id.originalAnchor != .notRecurring
            else { throw PlanningIssue.ambiguousIdentity }
        }
        guard Set(remote).isSubset(of: Set(mappedRemote)) else {
            throw PlanningIssue.untrackedDestination
        }
        for event in input.destination.events { _ = try PlanningFingerprint.content(event.content) }
    }
    private static func compare(
        _ source: CalendarOccurrence?, mapping: PlanningMapping?,
        destination: [EventID: DestinationObservation], input: ReconciliationInput
    ) -> ReconciliationAction {
        do {
            if let source, source.status == .unknown || source.occupancy == .unknown {
                return .manualIntervention(.unknownSourceState)
            }
            guard let mapping else {
                guard let source, source.status != .cancelled else { return .noChange }
                return .create(try project(source, policy: input.policy))
            }
            if mapping.disposition == .deleted {
                return source?.status == .active || destination[mapping.destinationID] != nil
                    ? .manualIntervention(.tombstoneConflict) : .noChange
            }
            // A sliding horizon must not clean up events that simply fell outside its coverage.
            if source == nil && !input.source.coverage.window.contains(mapping.lastSourceInterval) {
                return .noChange
            }
            guard let remote = destination[mapping.destinationID] else {
                return .manualIntervention(.missingDestination)
            }
            guard remote.ownership == .verified else {
                return .manualIntervention(.unverifiedOwnership)
            }
            guard case .active(let fingerprint, let revision) = mapping.disposition else {
                throw PlanningIssue.invalidInput
            }
            guard remote.revision == revision,
                try PlanningFingerprint.content(remote.content) == fingerprint
            else {
                return .conflict(.destinationChanged)
            }
            if source == nil || source?.status == .cancelled {
                guard source?.status == .cancelled || input.confirmedAbsent.contains(mapping.source)
                else {
                    return .manualIntervention(.absenceUnverified)
                }
                return .delete(remote.id, expectedRevision: remote.revision)
            }
            guard let source else { throw PlanningIssue.invalidInput }
            let content = try project(source, policy: input.policy)
            if try PlanningFingerprint.content(content) == fingerprint { return .noChange }
            return .update(remote.id, content, expectedRevision: remote.revision)
        } catch let issue as PlanningIssue { return .manualIntervention(issue) } catch {
            return .manualIntervention(.invalidInput)
        }
    }
    private static func project(_ source: CalendarOccurrence, policy: PlanningPolicy) throws
        -> PlannedEventContent
    {
        func field(_ value: FieldValue<String?>, _ field: CalendarDetailField, fallback: String)
            throws -> String
        {
            guard policy.fields.contains(field) else { return fallback }
            guard case .value(let value) = value else { throw PlanningIssue.unavailableDetail }
            return value ?? fallback
        }
        let content = try PlannedEventContent(
            time: source.time, isFree: source.occupancy == .free,
            title: field(source.title, .title, fallback: "Busy"),
            location: field(source.location, .location, fallback: ""),
            notes: field(source.notes, .notes, fallback: ""))
        _ = try PlanningFingerprint.content(content)
        return content
    }
    private static func proposalID(
        key: String, action: ReconciliationAction, input: ReconciliationInput
    ) throws -> PlanningFingerprint {
        var parts =
            ["proposal-v1", key] + PlanningFingerprint.resource(input.scope.destination) + [
                input.policy.revision.rawValue
            ]
        // Include projected field selection even when the current content happens to be identical.
        parts += [.title, .location, .notes].map { input.policy.fields.contains($0) ? "1" : "0" }
        switch action {
        case .create(let content):
            parts += ["create", try PlanningFingerprint.content(content).value]
        case .update(let id, let content, let revision):
            parts += [
                "update", id.rawValue, revision.rawValue,
                try PlanningFingerprint.content(content).value,
            ]
        case .delete(let id, let revision): parts += ["delete", id.rawValue, revision.rawValue]
        case .noChange: parts += ["noChange"]
        case .conflict(let issue): parts += ["conflict", issue.rawValue]
        case .manualIntervention(let issue): parts += ["manual", issue.rawValue]
        }
        return .digest(parts)
    }
}

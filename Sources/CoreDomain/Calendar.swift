public struct CalendarResource: Hashable, Sendable {
    public let id: CalendarReference
    public let name: String

    public init(id: CalendarReference, name: String) {
        self.id = id
        self.name = name
    }
}

/// Equality is an observed provider reference, not a final cross-resync matching algorithm.
public struct OccurrenceReference: Hashable, Sendable {
    public let calendar: CalendarReference
    public let item: EventID
    public let originalAnchor: RecurrenceAnchor

    public init(calendar: CalendarReference, item: EventID, originalAnchor: RecurrenceAnchor) {
        self.calendar = calendar
        self.item = item
        self.originalAnchor = originalAnchor
    }
}

public enum Occupancy: Hashable, Sendable {
    case free, busy, tentative, unknown
}

public enum EventStatus: Hashable, Sendable {
    case active, cancelled, unknown
}

public struct CalendarOccurrence: Hashable, Sendable {
    public let id: OccurrenceReference
    public let seriesID: EventID?
    public let time: EventTime
    public let occupancy: Occupancy
    public let status: EventStatus
    public let title: FieldValue<String?>
    public let location: FieldValue<String?>
    public let notes: FieldValue<String?>
    public let revision: MutationPrecondition

    public init(
        id: OccurrenceReference, seriesID: EventID? = nil, time: EventTime,
        occupancy: Occupancy, status: EventStatus,
        title: FieldValue<String?> = .notFetched, location: FieldValue<String?> = .notFetched,
        notes: FieldValue<String?> = .notFetched, revision: MutationPrecondition = .unknown
    ) {
        self.id = id
        self.seriesID = seriesID
        self.time = time
        self.occupancy = occupancy
        self.status = status
        self.title = title
        self.location = location
        self.notes = notes
        self.revision = revision
    }
}

/// Explicit nonempty selection; an empty/failed selection can never mean all calendars.
public struct CalendarReadRequest: Hashable, Sendable {
    public let calendars: Set<CalendarReference>
    public let window: InstantInterval

    public init(calendars: Set<CalendarReference>, window: InstantInterval) throws {
        guard !calendars.isEmpty else { throw DomainValidationError.emptySelection }
        self.calendars = calendars
        self.window = window
    }
}

public struct CalendarSnapshot: Hashable, Sendable {
    public let coverage: CalendarReadRequest
    public let occurrences: [CalendarOccurrence]
    public let observation: ObservationState

    public init(
        coverage: CalendarReadRequest, occurrences: [CalendarOccurrence],
        observation: ObservationState
    ) throws {
        guard occurrences.allSatisfy({ coverage.calendars.contains($0.id.calendar) }) else {
            throw DomainValidationError.resourceOutsideSelection
        }
        guard
            occurrences.allSatisfy({ occurrence in
                if case .timed(let interval, _) = occurrence.time {
                    return coverage.window.overlaps(interval)
                }
                // Providers validate civil-date coverage after resolving their all-day semantics.
                return true
            })
        else { throw DomainValidationError.intervalOutsideCoverage }
        self.coverage = coverage
        self.occurrences = occurrences
        self.observation = observation
    }
}

/// Deliberately cannot carry event titles, locations, notes, or item identifiers.
public struct AvailabilityBlock: Hashable, Sendable {
    public let interval: InstantInterval
    public let occupancy: Occupancy

    public init(interval: InstantInterval, occupancy: Occupancy) {
        self.interval = interval
        self.occupancy = occupancy
    }
}

public struct AvailabilitySnapshot: Hashable, Sendable {
    public let coverage: CalendarReadRequest
    public let blocks: [AvailabilityBlock]
    public let observation: ObservationState

    public init(
        coverage: CalendarReadRequest, blocks: [AvailabilityBlock], observation: ObservationState
    ) throws {
        guard blocks.allSatisfy({ coverage.window.contains($0.interval) }) else {
            throw DomainValidationError.intervalOutsideCoverage
        }
        self.coverage = coverage
        self.blocks = blocks
        self.observation = observation
    }
}

/// Ownership is evidence recorded by a trusted adapter, not inferred from a name or OAuth scope.
public enum DestinationOwnership: Hashable, Sendable {
    case unknown
    case verifiedAppCreated
    case notOwned
}

public struct CalendarDestination: Hashable, Sendable {
    public let reference: ReferenceResolution<CalendarReference>
    public let ownership: DestinationOwnership

    public init(reference: ReferenceResolution<CalendarReference>, ownership: DestinationOwnership)
    {
        self.reference = reference
        self.ownership = ownership
    }
}

/// Trusted adapter boundary. Application policy must check every request before calling it.
public protocol CalendarReading: Sendable {
    func discoverCalendars() async -> ProviderReadResult<ResourceDiscovery<CalendarResource>>
    func readOccurrences(_ request: CalendarReadRequest) async -> ProviderReadResult<
        CalendarSnapshot
    >
}

/// Sync receives CalendarReading only; writers are never a requirement of that protocol.
/// Future operations must authorize/approve/refetch before invoking this internal boundary.
public protocol CalendarWriting: Sendable {
    func apply(_ change: ProposedChange<CalendarMutation>) async -> MutationResult<
        OccurrenceReference
    >
}

/// A fetched empty value is different from an omitted or unauthorized field.
public enum FieldValue<Value: Hashable & Sendable>: Hashable, Sendable {
    case notFetched
    case notAuthorized
    case value(Value)
}

/// Sanitized categories only; adapters must not put provider payloads in error text.
public enum ProviderFailure: Error, Hashable, Sendable {
    case denied, revoked, unavailable, unsupported, notFound, ambiguousIdentity
    case invalidData, cancelled, rateLimited, authenticationRequired
}

public enum PartialReadReason: Hashable, Sendable {
    case morePages
    case providerLimit
    case interrupted(ProviderFailure)
}

public enum ReadCompleteness: Hashable, Sendable {
    case complete
    case partial(PartialReadReason)
    case unknown
}

/// Local enumeration success is not evidence of upstream freshness.
public enum SourceFreshness: Hashable, Sendable {
    case unknown
    case localCache
    case verifiedThrough(Instant)
}

public struct ObservationState: Hashable, Sendable {
    public let observedAt: Instant
    public let completeness: ReadCompleteness
    public let freshness: SourceFreshness

    public init(
        observedAt: Instant, completeness: ReadCompleteness, freshness: SourceFreshness = .unknown
    ) {
        self.observedAt = observedAt
        self.completeness = completeness
        self.freshness = freshness
    }
}

public enum ProviderReadResult<Value: Sendable>: Sendable {
    case observed(Value)
    case failed(ProviderFailure)
}

public struct ResourceDiscovery<Resource: Sendable>: Sendable {
    public let resources: [Resource]
    public let observation: ObservationState

    public init(resources: [Resource], observation: ObservationState) {
        self.resources = resources
        self.observation = observation
    }
}

/// Neither an opaque revision nor unknown evidence grants permission to mutate.
public enum MutationPrecondition: Hashable, Sendable {
    case revision(ObservedRevision)
    case unknown
}

public enum MutationResult<Value: Sendable>: Sendable {
    case succeeded(Value)
    case conflict
    case failed(ProviderFailure)
    /// The write may have completed. Recovery must verify, not blindly retry a create.
    case unknown
}

import Foundation

/// Local user preferences, never provider authority or proof of account identity.
public struct CalendarSyncConfiguration: Equatable, Sendable {
    public var sources: Set<CalendarReference>
    public var fields: Set<CalendarDetailField>
    public init(sources: Set<CalendarReference> = [], fields: Set<CalendarDetailField> = []) {
        self.sources = sources
        self.fields = fields
    }
}

public enum CalendarSyncPhase: Sendable, Equatable {
    case unconfigured, disconnected, connecting, ready, reviewing, running, waiting, paused
    case suspended, standby, recoveryRequired, signInRequired, unavailable
}

public enum CalendarSyncFailure: Error, Sendable, Equatable {
    case notConfigured, signInRequired, invalidSelection, staleReview, approvalRequired
    case sourceUnavailable, privacyUnverified, recoveryRequired, unavailable, cancelled, busy,
        disconnectIncomplete
}

public struct CalendarSyncStatus: Sendable, Equatable {
    public let phase: CalendarSyncPhase
    public let configuration: CalendarSyncConfiguration
    public let lastSuccess: Date?
    public let failure: CalendarSyncFailure?
    public init(
        phase: CalendarSyncPhase, configuration: CalendarSyncConfiguration = .init(),
        lastSuccess: Date? = nil, failure: CalendarSyncFailure? = nil
    ) {
        self.phase = phase
        self.configuration = configuration
        self.lastSuccess = lastSuccess
        self.failure = failure
    }
}

/// Content is already projected by the trusted planner according to the reviewed field policy.
public struct CalendarSyncPreviewItem: Sendable, Equatable, Identifiable {
    public enum Action: String, Sendable { case create, update, delete, unchanged }
    public let id: String
    public let source: CalendarReference
    public let action: Action
    public let contentTitle: String
    public let location: String
    public let notes: String
    public let time: EventTime?
    public init(
        id: String, source: CalendarReference, action: Action, contentTitle: String,
        time: EventTime?, location: String = "", notes: String = ""
    ) {
        self.id = id
        self.source = source
        self.action = action
        self.contentTitle = contentTitle
        self.location = location
        self.notes = notes
        self.time = time
    }
}

/// The ID identifies a retained server-side review; none of these display values confer authority.
public struct CalendarSyncPreview: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let configuration: CalendarSyncConfiguration
    public let items: [CalendarSyncPreviewItem]
    public let expiresAt: Date
    public init(
        id: UUID, configuration: CalendarSyncConfiguration, items: [CalendarSyncPreviewItem],
        expiresAt: Date
    ) {
        self.id = id
        self.configuration = configuration
        self.items = items
        self.expiresAt = expiresAt
    }
    public var deletionCount: Int { items.filter { $0.action == .delete }.count }
}

/// Trusted local application controls. Never forward this administrative interface through MCP.
/// Implementations must bind approvals to retained reviews and independently revalidate authority.
public protocol CalendarSyncManaging: Sendable {
    func status() async -> CalendarSyncStatus
    func connect() async -> CalendarSyncStatus
    func preview(_ configuration: CalendarSyncConfiguration) async throws -> CalendarSyncPreview
    func confirm(_ reviewID: UUID, approveDeletions: Bool) async -> CalendarSyncStatus
    func pause() async -> CalendarSyncStatus
    func disconnect(revokeGrant: Bool) async -> CalendarSyncStatus
}

public enum SampleConnection: String, CaseIterable, Identifiable, Sendable {
    case google, localMCP
    public var id: String { rawValue }
    public var title: String { self == .google ? "Google Calendar" : "Local MCP" }
    public var subtitle: String {
        self == .google
            ? "One-way calendar synchronization" : "Selected access for local applications"
    }
    public var symbol: String {
        self == .google ? "arrow.triangle.2.circlepath" : "point.3.connected.trianglepath.dotted"
    }
}

public enum SampleCalendar: String, CaseIterable, Identifiable, Sendable {
    case personal, work
    public var id: String { rawValue }
    public var title: String { self == .personal ? "Sample Personal" : "Sample Work" }
}

public enum PreviewState: String, CaseIterable, Identifiable, Sendable {
    case disabled, unconfigured, denied, unavailable, revoked, enabled
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .disabled: "Disabled"
        case .unconfigured: "Not configured"
        case .denied: "Permission denied"
        case .unavailable: "Unavailable"
        case .revoked: "Revoked"
        case .enabled: "Enabled preview"
        }
    }
}

public enum PreviewAccess: String, CaseIterable, Identifiable, Sendable {
    case availability, details
    public var id: String { rawValue }
    public var title: String { self == .availability ? "Availability only" : "Event details" }
    public var description: String {
        self == .availability
            ? "Occupied time only. Titles, locations and notes stay hidden."
            : "Includes sample event titles, locations and notes. No attendee sharing."
    }
}

public struct PreviewConfiguration: Equatable, Sendable {
    public let connection: SampleConnection
    public var state: PreviewState
    public var calendars: Set<SampleCalendar>
    public var access: PreviewAccess

    public init(
        connection: SampleConnection, state: PreviewState = .disabled,
        calendars: Set<SampleCalendar> = [], access: PreviewAccess = .availability
    ) {
        self.connection = connection
        self.state = state
        self.calendars = calendars
        self.access = access
    }
}

/// Presentation only. Allowed means the synthetic policy check passed, never connected/synced/approved.
public enum PreviewOutcome: Equatable, Sendable {
    case allowed, disabled, unconfigured, denied, unavailable, revoked, noSelection, blocked, busy
    public var title: String { self == .allowed ? "Allowed in preview" : "Blocked in preview" }
    public var explanation: String {
        switch self {
        case .allowed:
            "The selected sample read is permitted. No account was connected and no data was accessed."
        case .disabled:
            "This sample connection is disabled. Enable a preview to explore its access settings."
        case .unconfigured:
            "This sample connection has not been configured. No authentication has taken place."
        case .denied:
            "The preview simulates denied Calendar permission. No macOS permission was requested."
        case .unavailable:
            "The preview simulates an unavailable service. An unavailable source is not an empty calendar."
        case .revoked: "This sample connection is revoked. Its previous access is no longer valid."
        case .noSelection:
            "Select at least one sample calendar. An empty selection never grants access to all calendars."
        case .blocked: "The sample request was not permitted. No action was performed."
        case .busy: "Another preview change is being checked. Try again when it finishes."
        }
    }
}

public struct ConnectionPreview: Identifiable, Equatable, Sendable {
    public var id: SampleConnection { configuration.connection }
    public let configuration: PreviewConfiguration
    public let outcome: PreviewOutcome?
}

public struct PreviewActivity: Identifiable, Equatable, Sendable {
    public let id: Int
    public let connection: SampleConnection
    public let state: PreviewState
    public let outcome: PreviewOutcome
}

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case overview, calendars, reminders, contacts, connections, activity, diagnostics
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .overview: "Overview"
        case .calendars: "Apple Calendars"
        case .reminders: "Apple Reminders"
        case .contacts: "Apple Contacts"
        case .connections: "Connections"
        case .activity: "Activity"
        case .diagnostics: "Diagnostics"
        }
    }
    public var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .calendars: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.rectangle"
        case .connections: "link"
        case .activity: "clock.arrow.circlepath"
        case .diagnostics: "stethoscope"
        }
    }
}

public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

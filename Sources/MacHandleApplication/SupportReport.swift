import CoreDomain

/// A closed allowlist, not a redactor. No provider content, identifiers, selections, timestamps,
/// raw errors, paths, credentials, history or store snapshots can be supplied to this value.
public struct SupportReport: Sendable, Equatable {
    public enum LocalReadState: String, Sendable, CaseIterable {
        case off, optedIn, busy
        public init(enabled: Bool, busy: Bool) {
            self = !enabled ? .off : busy ? .busy : .optedIn
        }
        public var title: String {
            switch self {
            case .off: "Off"
            case .optedIn: "Opted in · Permission and selection checked on use"
            case .busy: "Opted in · Operation in progress"
            }
        }
    }
    public let calendars: LocalReadState
    public let reminders: LocalReadState
    public let contacts: LocalReadState
    public let syncPhase: CalendarSyncPhase
    public let syncFailure: CalendarSyncFailure?
    public let syncBusy: Bool

    public init(
        calendars: LocalReadState, reminders: LocalReadState, contacts: LocalReadState,
        syncPhase: CalendarSyncPhase, syncFailure: CalendarSyncFailure?, syncBusy: Bool
    ) {
        self.calendars = calendars
        self.reminders = reminders
        self.contacts = contacts
        self.syncPhase = syncPhase
        self.syncFailure = syncFailure
        self.syncBusy = syncBusy
    }

    /// Reads presentation state synchronously. Never calls providers, requests access or opens stores.
    @MainActor public init(
        calendars: CalendarAccessStore, reminders: RemindersStore, contacts: ContactsStore,
        google: GoogleSyncModel, calendarReadBusy: Bool = false
    ) {
        self.init(
            calendars: .init(
                enabled: calendars.isEnabled, busy: calendars.isBusy || calendarReadBusy),
            reminders: .init(enabled: reminders.isEnabled, busy: reminders.isBusy),
            contacts: .init(enabled: contacts.isEnabled, busy: contacts.isBusy),
            syncPhase: google.status.phase, syncFailure: google.failure, syncBusy: google.isBusy)
    }

    public var text: String {
        """
        MacHandle support report v1
        build=development
        calendar_local_reads=\(calendars.rawValue)
        reminder_local_reads=\(reminders.rawValue)
        contact_local_reads=\(contacts.rawValue)
        google_phase=\(syncPhase.supportCode)
        google_failure=\(syncFailure?.supportCode ?? "none")
        google_operation_pending=\(syncBusy ? "yes" : "no")
        local_mcp=synthetic_only
        remote_mcp=unavailable
        notes=experimental_unavailable
        activity=sample_history_only
        provider_audit=unavailable
        permissions=not_probed
        credentials=not_inspected
        scope=current_ui_state_not_live_verification

        """
    }
}

extension CalendarSyncPhase {
    fileprivate var supportCode: String {
        switch self {
        case .unconfigured: "unconfigured"
        case .disconnected: "disconnected"
        case .connecting: "connecting"
        case .ready: "ready"
        case .reviewing: "reviewing"
        case .running: "running"
        case .waiting: "waiting"
        case .paused: "paused"
        case .suspended: "suspended"
        case .standby: "standby"
        case .recoveryRequired: "recovery_required"
        case .signInRequired: "sign_in_required"
        case .unavailable: "unavailable"
        }
    }
}
extension CalendarSyncFailure {
    fileprivate var supportCode: String {
        switch self {
        case .notConfigured: "not_configured"
        case .signInRequired: "sign_in_required"
        case .invalidSelection: "invalid_selection"
        case .staleReview: "stale_review"
        case .approvalRequired: "approval_required"
        case .sourceUnavailable: "source_unavailable"
        case .privacyUnverified: "privacy_unverified"
        case .recoveryRequired: "recovery_required"
        case .unavailable: "unavailable"
        case .cancelled: "cancelled"
        case .busy: "busy"
        case .disconnectIncomplete: "disconnect_incomplete"
        }
    }
}

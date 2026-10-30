import CoreDomain
import Foundation
import MacHandleApplication
import Testing

private actor DiagnosticProbe: CalendarDiscovering, ReminderDiscovering, ReminderReading,
    ContactDiscovering, ContactReading
{
    var calls = 0
    func authorization() -> OSAuthorization {
        calls += 1
        return .denied
    }
    func requestAccess() -> OSAuthorization {
        calls += 1
        return .denied
    }
    func changes() -> AsyncStream<Void> {
        calls += 1
        return AsyncStream { $0.finish() }
    }
    func discover() -> CalendarDiscoveryResult {
        calls += 1
        return .unavailable
    }
    func discoverReminderLists() -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        calls += 1
        return .failed(.unavailable)
    }
    func discoverContactContainers() -> ProviderReadResult<ResourceDiscovery<ContactContainer>> {
        calls += 1
        return .failed(.unavailable)
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>)
        -> ProviderReadResult<ReminderSnapshot>
    {
        calls += 1
        return .failed(.unavailable)
    }
    func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>)
        -> ProviderReadResult<ContactSnapshot>
    {
        calls += 1
        return .failed(.unavailable)
    }
}

private struct SensitiveSyncFixture: CalendarSyncManaging {
    struct RawFailure: Error { let message = "SYNTHETIC_PRIVATE_ERROR /private/sample-path" }
    let configuration: CalendarSyncConfiguration
    init() throws {
        configuration = try .init(
            sources: [
                CalendarReference(
                    account: AccountReference(
                        provider: ProviderID("SYNTHETIC_PRIVATE_PROVIDER"),
                        store: StoreID("SYNTHETIC_PRIVATE_STORE"),
                        account: AccountID("SYNTHETIC_PRIVATE_ACCOUNT")),
                    localID: DomainID("SYNTHETIC_PRIVATE_RESOURCE"))
            ], fields: [.notes, .title])
    }
    func status() -> CalendarSyncStatus {
        .init(
            phase: .recoveryRequired, configuration: configuration,
            lastSuccess: Date(timeIntervalSince1970: 123_456_789), failure: .recoveryRequired)
    }
    func connect() -> CalendarSyncStatus { status() }
    func preview(_ configuration: CalendarSyncConfiguration) throws -> CalendarSyncPreview {
        throw RawFailure()
    }
    func confirm(_ reviewID: UUID, approveDeletions: Bool) -> CalendarSyncStatus { status() }
    func pause() -> CalendarSyncStatus { status() }
    func disconnect(revokeGrant: Bool) -> CalendarSyncStatus { status() }
}

@Test @MainActor func reportCaptureDoesNotProbeServicesAndCannotExportPrivateModelData()
    async throws
{
    let provider = DiagnosticProbe()
    let calendars = CalendarAccessStore(provider: provider)
    let reminders = RemindersStore(provider: provider)
    let contacts = ContactsStore(provider: provider)
    let google = GoogleSyncModel(service: try SensitiveSyncFixture())
    await google.refresh()
    reminders.query = "SYNTHETIC_PRIVATE_REMINDER_QUERY"
    contacts.query = "SYNTHETIC_PRIVATE_CONTACT_QUERY"
    let report = SupportReport(
        calendars: calendars, reminders: reminders, contacts: contacts, google: google)
    #expect(await provider.calls == 0)
    #expect(report.syncPhase == .recoveryRequired && report.syncFailure == .recoveryRequired)
    #expect(!report.text.contains("SYNTHETIC_PRIVATE"))
    #expect(!report.text.contains("123456789"))
    #expect(report.text.contains("credentials=not_inspected"))
    #expect(report.text.contains("provider_audit=unavailable"))
    await google.preview()
    let failed = SupportReport(
        calendars: calendars, reminders: reminders, contacts: contacts, google: google)
    #expect(failed.syncFailure == .unavailable)
    #expect(!failed.text.contains("SYNTHETIC_PRIVATE") && !failed.text.contains("/private"))
    #expect(await provider.calls == 0)
    #expect(report.syncFailure == .recoveryRequired)  // A preview is an immutable snapshot.
}

@Test @MainActor func reportOptInIsNotPermissionAndDisableWinsOverBusy() async {
    let provider = DiagnosticProbe()
    let calendars = CalendarAccessStore(provider: provider)
    let reminders = RemindersStore(provider: provider)
    let contacts = ContactsStore(provider: provider)
    let google = GoogleSyncModel()
    await reminders.enable()  // Synthetic denial, never a system permission request.
    let count = await provider.calls
    let report = SupportReport(
        calendars: calendars, reminders: reminders, contacts: contacts, google: google)
    #expect(report.reminders == .optedIn)
    #expect(report.calendars == .off && report.contacts == .off)
    #expect(report.text.contains("permissions=not_probed"))
    #expect(await provider.calls == count)
    reminders.disable()
    #expect(
        SupportReport(
            calendars: calendars, reminders: reminders, contacts: contacts, google: google
        ).reminders == .off)
    #expect(SupportReport.LocalReadState(enabled: false, busy: true) == .off)
    #expect(SupportReport.LocalReadState(enabled: true, busy: true) == .busy)
}

@Test func reportSchemaIsBoundedAcrossAllSyncFailuresAndPhases() {
    let phases: [CalendarSyncPhase] = [
        .unconfigured, .disconnected, .connecting, .ready,
        .reviewing, .running, .waiting, .paused, .suspended, .standby, .recoveryRequired,
        .signInRequired, .unavailable,
    ]
    let failures: [CalendarSyncFailure?] = [
        nil, .notConfigured, .signInRequired,
        .invalidSelection, .staleReview, .approvalRequired, .sourceUnavailable,
        .privacyUnverified, .recoveryRequired, .unavailable, .cancelled, .busy,
        .disconnectIncomplete,
    ]
    let keys: Set<String> = [
        "build", "calendar_local_reads", "reminder_local_reads", "contact_local_reads",
        "google_phase", "google_failure", "google_operation_pending", "local_mcp", "remote_mcp",
        "notes", "activity", "provider_audit", "permissions", "credentials", "scope",
    ]
    for phase in phases {
        for failure in failures {
            for local in SupportReport.LocalReadState.allCases {
                let report = SupportReport(
                    calendars: local, reminders: local, contacts: local,
                    syncPhase: phase, syncFailure: failure, syncBusy: true)
                let lines = report.text.split(separator: "\n").dropFirst()
                #expect(lines.count == keys.count)
                #expect(Set(lines.map { String($0.split(separator: "=")[0]) }) == keys)
                #expect(report.text.utf8.count < 1024)
                #expect(lines.allSatisfy { $0.split(separator: "=").count == 2 })
            }
        }
    }
}

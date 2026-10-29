import MacHandleApplication
import SwiftUI
import UniformTypeIdentifiers

struct MainWindow: View {
    @Bindable var state: ApplicationState
    let reads: CalendarReadStore
    let google: GoogleSyncModel
    let reminders: RemindersStore
    let contacts: ContactsStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $state.section) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
                    .padding(.vertical, 4)
            }
            .navigationTitle("MacHandle")
            .navigationSplitViewColumnWidth(min: 175, ideal: 200, max: 230)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Preview build", systemImage: "hammer").font(.caption.weight(.medium))
                    Text("External connections off").font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch state.section ?? .overview {
                    case .overview:
                        OverviewView(
                            state: state, google: google, reminders: reminders, contacts: contacts)
                    case .calendars: CalendarsView(store: state.calendars, reads: reads)
                    case .contacts: ContactsView(store: contacts)
                    case .reminders: RemindersView(store: reminders)
                    case .connections: ConnectionsView(state: state, google: google)
                    case .activity: ActivityView(store: state.connections)
                    case .diagnostics:
                        DiagnosticsView(
                            state: state, reads: reads, google: google, reminders: reminders,
                            contacts: contacts)
                    }
                }
                .padding(28).frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle((state.section ?? .overview).title)
        }
        .frame(minWidth: 900, minHeight: 620)
        .task {
            await state.calendars.refresh()
            await state.calendars.observeChanges()
        }
        .task { await reminders.observeChanges() }
        .task { await contacts.observeChanges() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await state.calendars.refresh()
                    await reminders.refresh()
                    await contacts.refresh()
                }
            }
        }
    }
}

private struct OverviewView: View {
    let state: ApplicationState
    let google: GoogleSyncModel
    let reminders: RemindersStore
    let contacts: ContactsStore
    var body: some View {
        PageHeader(
            title: "Your data. Your choice.",
            subtitle: "Manage what each connection can see and do, one service at a time.")
        Text(
            "Apple Calendar, Reminders and Contacts reads are available on explicit opt-in. External connections below are sample previews."
        )
        .foregroundStyle(.secondary)
        HStack {
            Button("Manage Apple Calendars") { state.section = .calendars }
            Button("Manage Apple Reminders") { state.section = .reminders }
            Button("Manage Apple Contacts") { state.section = .contacts }
        }
        GroupBox {
            VStack(spacing: 12) {
                DetailRow(title: "External connections", value: "None")
                DetailRow(title: "Synchronization", value: google.status.phase.title)
                DetailRow(
                    title: "Last successful sync",
                    value: google.status.lastSuccess?.formatted() ?? "Never")
            }.padding(8)
        } label: {
            Label("At a glance", systemImage: "hand.raised")
        }
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore connections").font(.title3.weight(.semibold)).accessibilityAddTraits(
                .isHeader)
            ForEach(state.connections.previews) { preview in
                Button {
                    state.showConnection(preview.id)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: preview.id.symbol).font(.title2).foregroundStyle(.tint)
                            .frame(width: 30).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(preview.id.title).fontWeight(.semibold).foregroundStyle(.primary)
                            Text(preview.id.subtitle).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(state: preview.configuration.state)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).stroke(
                            Color(nsColor: .separatorColor).opacity(0.35))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Explore \(preview.id.title) sample connection, \(preview.configuration.state.title)"
                )
            }
        }
        GroupBox {
            VStack(spacing: 12) {
                DetailRow(
                    title: "Calendars",
                    value: state.calendars.isEnabled ? "Discovery enabled locally" : "Discovery off"
                )
                DetailRow(
                    title: "Reminders",
                    value: reminders.isEnabled
                        ? "\(reminders.selection.count) lists selected" : "Discovery off")
                DetailRow(
                    title: "Contacts",
                    value: contacts.isEnabled
                        ? "\(contacts.selection.count) address books selected" : "Discovery off")
                NotesAvailabilityView()
            }.padding(8)
        } label: {
            Label("Apple resources", systemImage: "lock.shield")
        }
        Text("Google synchronization and local MCP are independent. Neither will enable the other.")
            .font(.callout).foregroundStyle(.secondary)
    }
}

private struct NotesAvailabilityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailRow(title: "Apple Notes", value: "Experimental · Unavailable")
            Text(
                "Reading and editing are unavailable. Safe access must first be verified with test notes in a separate environment."
            )
            Text("MacHandle does not access your notes or request Notes permission in this build.")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ActivityView: View {
    let store: ConnectionPreviewStore
    var body: some View {
        PageHeader(
            title: "Activity",
            subtitle:
                "Sample policy changes from this session. This is not a history of local reads, provider actions or durable operation journals."
        )
        if store.activity.isEmpty {
            EmptyPanel(
                title: "No preview activity yet",
                message:
                    "Change a sample connection to see its policy result here. This history stays in memory and clears when you quit.",
                symbol: "clock.arrow.circlepath")
        } else {
            GroupBox {
                VStack(spacing: 0) {
                    ForEach(store.activity) { activity in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(activity.connection.title) · \(activity.state.title)")
                                    .fontWeight(.medium)
                                Text(activity.outcome.title).font(.callout).foregroundStyle(
                                    .secondary)
                            }
                            Spacer()
                            Text("Preview \(activity.id)").font(.caption).foregroundStyle(
                                .secondary)
                        }.padding(12)
                        if activity.id != store.activity.last?.id { Divider() }
                    }
                }
            }
            HStack {
                Text("Last 20 preview changes · Not saved to disk").font(.caption).foregroundStyle(
                    .secondary)
                Spacer()
                Button("Clear Preview History") { store.clearActivity() }
            }
        }
    }
}

private struct DiagnosticsView: View {
    let state: ApplicationState
    let reads: CalendarReadStore
    let google: GoogleSyncModel
    let reminders: RemindersStore
    let contacts: ContactsStore
    @State private var report: SupportReportPresentation?

    private var snapshot: SupportReport {
        SupportReport(
            calendars: state.calendars, reminders: reminders, contacts: contacts, google: google,
            calendarReadBusy: reads.isBusy)
    }
    var body: some View {
        PageHeader(
            title: "Diagnostics",
            subtitle:
                "Current app state. Opening this page does not request permission or contact a service."
        )
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                DetailRow(title: "Calendar local reads", value: snapshot.calendars.title)
                DetailRow(title: "Reminders local reads", value: snapshot.reminders.title)
                DetailRow(title: "Contacts local reads", value: snapshot.contacts.title)
                Text(
                    "Opt-in does not prove OS permission, cloud freshness or external access. Review permission and selection on each service page."
                )
                .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Calendar Access") { state.section = .calendars }
                    Button("Reminders Access") { state.section = .reminders }
                    Button("Contacts Access") { state.section = .contacts }
                }
            }.padding(10)
        } label: {
            Label("Local access", systemImage: "lock.shield")
        }
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                DetailRow(title: "Google sync", value: google.status.phase.title)
                DetailRow(title: "Operation pending", value: google.isBusy ? "Yes" : "No")
                if let failure = google.failure { Text(failure.message).font(.callout) }
                Text(
                    "For an uncertain write, keep existing copies and verify the original operation. Do not retry, delete state or reset the database to clear an error."
                )
                .font(.callout).foregroundStyle(.secondary)
                Button("Review Connections") { state.section = .connections }
                DetailRow(
                    title: "Local MCP", value: "Synthetic helper only · Live pairing unavailable")
                DetailRow(title: "Remote MCP", value: "Unavailable")
                NotesAvailabilityView()
            }.padding(10)
        } label: {
            Label("Connections and recovery", systemImage: "arrow.triangle.2.circlepath")
        }
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Activity shows the last 20 sample policy changes in memory. It is not a provider audit. Durable operation journals are separate internal recovery records; no live journal viewer is connected."
                )
                Button("View Sample Activity") { state.section = .activity }
                Text(
                    "Support reports contain only fixed capability codes and current opt-in/sync states. They exclude names, identifiers, selections, content, timestamps, paths, raw errors, credentials and history. Review the exact text before saving; nothing is uploaded."
                )
                Button("Preview Support Report…") {
                    report = SupportReportPresentation(report: snapshot)
                }
                .accessibilityHint(
                    "Review a frozen, content-free report before choosing where to save it.")
            }.font(.callout).padding(10)
        } label: {
            Label("History and support", systemImage: "doc.text")
        }
        .sheet(item: $report) { presentation in
            SupportReportPreview(report: presentation.report)
        }
    }
}

private struct SupportReportPresentation: Identifiable {
    let id = UUID()
    let report: SupportReport
}

private struct SupportReportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    let report: SupportReport
    init(report: SupportReport) { self.report = report }
    init(configuration: ReadConfiguration) throws {
        // Export-only: never import or echo arbitrary file contents.
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(report.text.utf8))
    }
}

private struct SupportReportPreview: View {
    let report: SupportReport
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var result =
        "Snapshot captured when you opened this preview. Nothing has been saved."
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support report preview").font(.title2).accessibilityAddTraits(.isHeader)
            ScrollView {
                Text(report.text).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(result).font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("support-report-result")
            HStack {
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Report…") { exporting = true }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 620, height: 550)
            .fileExporter(
                isPresented: $exporting, document: SupportReportDocument(report: report),
                contentType: .plainText, defaultFilename: "MacHandle-support"
            ) { outcome in
                switch outcome {
                case .success: result = "Report saved to your chosen file. Nothing was uploaded."
                case .failure(let error):
                    result =
                        (error as? CocoaError)?.code == .userCancelled
                        ? "Save cancelled."
                        : "The report could not be saved. Choose another location or cancel."
                }
            }
    }
}

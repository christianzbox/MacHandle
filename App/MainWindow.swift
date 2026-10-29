import MacHandleApplication
import SwiftUI

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
                    case .diagnostics: DiagnosticsView()
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
                DetailRow(title: "Notes", value: "Experimental · Not available")
            }.padding(8)
        } label: {
            Label("Apple resources", systemImage: "lock.shield")
        }
        Text("Google synchronization and local MCP are independent. Neither will enable the other.")
            .font(.callout).foregroundStyle(.secondary)
    }
}

private struct ActivityView: View {
    let store: ConnectionPreviewStore
    var body: some View {
        PageHeader(
            title: "Activity",
            subtitle: "Preview changes from this session. No live actions have run.")
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
    var body: some View {
        PageHeader(title: "Diagnostics", subtitle: "Capabilities of this development build.")
        GroupBox {
            VStack(spacing: 14) {
                DetailRow(title: "Build", value: "Development interface preview")
                DetailRow(
                    title: "Displayed data", value: "Samples; Selected Calendar content on request")
                DetailRow(title: "Live providers", value: "Calendar discovery and local reads")
                DetailRow(title: "macOS permissions", value: "Calendar request only on opt-in")
                DetailRow(title: "Credentials", value: "None stored")
                DetailRow(title: "Background sync", value: "Not running")
                DetailRow(title: "Preview settings", value: "Choices reset when you quit")
            }.padding(10)
        } label: {
            Label("Current capabilities", systemImage: "checklist")
        }
        Text(
            "Policy previews check sample access rules. They do not authenticate a connection, approve a change, or run a synchronization."
        )
        .foregroundStyle(.secondary)
    }
}

import MacHandleApplication
import SwiftUI

struct MainWindow: View {
    @Bindable var state: ApplicationState

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
                    Text("No accounts connected").font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch state.section ?? .overview {
                    case .overview: OverviewView(state: state)
                    case .connections: ConnectionsView(state: state)
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
    }
}

private struct OverviewView: View {
    let state: ApplicationState
    var body: some View {
        PageHeader(
            title: "Your data. Your choice.",
            subtitle: "Manage what each connection can see and do, one service at a time.")
        PreviewNotice()
        GroupBox {
            VStack(spacing: 12) {
                DetailRow(title: "Live connections", value: "None")
                DetailRow(title: "Synchronization", value: "Not configured")
                DetailRow(title: "Last successful sync", value: "Never")
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
                DetailRow(title: "Calendars", value: "Permission not requested")
                DetailRow(title: "Reminders", value: "Permission not requested")
                DetailRow(title: "Contacts", value: "Permission not requested")
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
        PageHeader(title: "Diagnostics", subtitle: "Capabilities of this interface preview.")
        GroupBox {
            VStack(spacing: 14) {
                DetailRow(title: "Build", value: "Development interface preview")
                DetailRow(title: "Displayed data", value: "Synthetic samples only")
                DetailRow(title: "Live providers", value: "Not implemented")
                DetailRow(title: "macOS permissions", value: "Not requested")
                DetailRow(title: "Credentials", value: "None stored")
                DetailRow(title: "Background sync", value: "Not running")
                DetailRow(title: "Preview settings", value: "Reset when you quit")
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

import GoogleAuthorization
import MacHandleApplication
import SwiftUI

struct ConnectionsView: View {
    @Bindable var state: ApplicationState
    let google: GoogleConnectionModel
    private var store: ConnectionPreviewStore { state.connections }

    var body: some View {
        PageHeader(
            title: "Connections",
            subtitle: "Manage Google authentication and explore sample connection policies.")
        GoogleSignInView(model: google)
        PreviewNotice()
        Picker("Sample connection", selection: $state.selectedConnection) {
            ForEach(SampleConnection.allCases) { connection in
                Text(connection.title).tag(connection)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("sample-connection-picker")
        if let preview = store.previews.first(where: { $0.id == state.selectedConnection }) {
            connectionDetail(preview)
        }
    }

    @ViewBuilder
    private func connectionDetail(_ preview: ConnectionPreview) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Label(preview.id.title, systemImage: preview.id.symbol).font(
                    .title2.weight(.semibold))
                Text(preview.id.subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(state: preview.configuration.state)
        }
        GroupBox {
            VStack(spacing: 12) {
                DetailRow(title: "Authentication", value: "Not connected · Sample only")
                DetailRow(title: "Resource type", value: "Calendars only")
                DetailRow(title: "Write operations", value: "Not allowed")
                DetailRow(title: "Action approvals", value: "No actions can run in this preview")
                DetailRow(title: "Last activity", value: "No live activity")
            }.padding(8)
        } label: {
            Text("Connection details")
        }
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Picker(
                    "Preview state",
                    selection: Binding(
                        get: { preview.configuration.state },
                        set: { newValue in change(preview) { $0.state = newValue } }
                    )
                ) {
                    ForEach(PreviewState.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("preview-state-picker")
                Divider()
                VStack(alignment: .leading, spacing: 9) {
                    Text("Selected sample calendars").fontWeight(.medium)
                    ForEach(SampleCalendar.allCases) { calendar in
                        Toggle(
                            calendar.title,
                            isOn: Binding(
                                get: { preview.configuration.calendars.contains(calendar) },
                                set: { selected in
                                    change(preview) {
                                        if selected {
                                            $0.calendars.insert(calendar)
                                        } else {
                                            $0.calendars.remove(calendar)
                                        }
                                    }
                                }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("sample-calendar-\(calendar.rawValue)")
                    }
                    Text("No selection means no access.").font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Picker(
                    "Read access",
                    selection: Binding(
                        get: { preview.configuration.access },
                        set: { newValue in change(preview) { $0.access = newValue } }
                    )
                ) {
                    ForEach(PreviewAccess.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("preview-access-picker")
                Text(preview.configuration.access.description).font(.callout).foregroundStyle(
                    .secondary)
            }.padding(8)
                .disabled(store.isUpdating)
        } label: {
            Text("Preview controls")
        }
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                if let outcome = preview.outcome {
                    Image(systemName: outcome == .allowed ? "checkmark.shield" : "lock.shield")
                        .font(.title2).foregroundStyle(
                            outcome == .allowed ? Color.accentColor : Color.secondary
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(outcome.title).fontWeight(.semibold)
                        Text(outcome.explanation).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("policy-preview-result")
                } else {
                    ProgressView().controlSize(.small)
                    Text("Checking the sample policy…").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Policy preview")
        }
        HStack {
            Button("Reset Preview") {
                Task { await store.apply(PreviewConfiguration(connection: preview.id)) }
            }
            Spacer()
            Button("Revoke Preview Access", role: .destructive) {
                change(preview) { $0.state = .revoked }
            }
            .disabled(preview.configuration.state == .revoked)
        }
        .disabled(store.isUpdating)
    }

    private func change(_ preview: ConnectionPreview, update: (inout PreviewConfiguration) -> Void)
    {
        var configuration = preview.configuration
        update(&configuration)
        Task { await store.apply(configuration) }
    }
}

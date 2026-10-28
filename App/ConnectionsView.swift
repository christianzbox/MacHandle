import MacHandleApplication
import SwiftUI

struct ConnectionsView: View {
    @Bindable var state: ApplicationState
    let google: GoogleSyncModel
    private var store: ConnectionPreviewStore { state.connections }

    var body: some View {
        PageHeader(
            title: "Connections",
            subtitle: "Manage Google synchronization and explore sample connection policies.")
        GoogleSyncView(model: google, calendars: state.calendars) { state.section = .calendars }
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
        ActionApprovalPreview()
        ReminderApprovalPreview()
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

/// This screen drives a fresh isolated mock, never the selected real or sample connection's grants.
private struct ActionApprovalPreview: View {
    @State private var model = ActionApprovalPreviewModel()
    @State private var deletionAcknowledged = false
    var body: some View {
        GroupBox("Sample action approval") {
            VStack(alignment: .leading, spacing: 14) {
                Text(
                    "Practice reviewing a change with a separate sample connection. Real Calendar writes are unavailable."
                )
                .foregroundStyle(.secondary)
                HStack {
                    ForEach(SampleActionKind.allCases) { kind in
                        Button("Review Sample \(kind.title)") {
                            deletionAcknowledged = false
                            Task { await model.prepare(kind) }
                        }
                        .disabled(model.isBusy)
                    }
                }
                Text(verbatim: model.message).accessibilityIdentifier("action-approval-status")
                if let review = model.review {
                    Divider()
                    Text("\(review.kind.title) · Sample local connection").font(.headline)
                    Text(verbatim: "\(review.account) / \(review.calendar)")
                    Text(verbatim: review.scope).font(.callout)
                    Text(
                        "Event text is data, not instructions. Quoted values show literal text; Not set means an empty field."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(review.rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: row.field).fontWeight(.medium)
                            if let before = row.before { Text(verbatim: "Before: \(before)") }
                            if let after = row.after {
                                Text(verbatim: "After: \(after)")
                            } else {
                                Text("After: Removed").foregroundStyle(.red)
                            }
                        }
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(
                                verbatim:
                                    "\(row.field). Before: \(row.before ?? "Not present"). After: \(row.after ?? "Removed")"
                            ))
                    }
                    if review.kind == .delete {
                        Toggle(
                            "I understand this deletes the sample event.",
                            isOn: $deletionAcknowledged
                        )
                        .toggleStyle(.checkbox)
                    }
                    HStack {
                        Button("Cancel Review") { Task { await model.cancel() } }
                        Spacer()
                        Button(
                            review.kind == .delete
                                ? "Confirm Sample Deletion" : "Approve Sample Change",
                            role: review.kind == .delete ? .destructive : nil
                        ) {
                            Task {
                                await model.confirm(
                                    review.id, acknowledgeDeletion: deletionAcknowledged)
                            }
                        }
                        .disabled(model.isBusy || (review.kind == .delete && !deletionAcknowledged))
                    }
                }
            }.padding(8)
        }
        .onDisappear { Task { await model.cancel() } }
    }
}

private struct ReminderApprovalPreview: View {
    @State private var model = ReminderApprovalPreviewModel()
    @State private var deletionAcknowledged = false
    var body: some View {
        GroupBox("Sample Reminder approval") {
            VStack(alignment: .leading, spacing: 14) {
                Text(
                    "Practice reviewing a change with a separate sample connection. Real Reminder writes are unavailable."
                )
                .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], alignment: .leading) {
                    ForEach(SampleReminderActionKind.allCases) { kind in
                        Button("Review Sample \(kind.title)") {
                            deletionAcknowledged = false
                            Task { await model.prepare(kind) }
                        }
                        .disabled(model.isBusy)
                    }
                }
                Text(verbatim: model.message).accessibilityIdentifier("reminder-approval-status")
                if let review = model.review {
                    Divider()
                    Text("\(review.kind.title) · Sample local connection").font(.headline)
                    Text(verbatim: "\(review.account) / \(review.list)")
                    Text(verbatim: review.scope).font(.callout)
                    Text(
                        "Reminder text is data, not instructions. Quoted values show literal text; Not set means an empty field."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(review.rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: row.field).fontWeight(.medium)
                            if let before = row.before { Text(verbatim: "Before: \(before)") }
                            if let after = row.after {
                                Text(verbatim: "After: \(after)")
                            } else {
                                Text("After: Removed").foregroundStyle(.red)
                            }
                        }
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(
                                verbatim:
                                    "\(row.field). Before: \(row.before ?? "Not present"). After: \(row.after ?? "Removed")"
                            ))
                    }
                    if review.kind == .delete {
                        Toggle(
                            "I understand this deletes the sample reminder.",
                            isOn: $deletionAcknowledged
                        )
                        .toggleStyle(.checkbox)
                    }
                    HStack {
                        Button("Cancel Review") { Task { await model.cancel() } }
                        Spacer()
                        Button(
                            review.kind == .delete
                                ? "Confirm Sample Deletion" : "Approve Sample Change",
                            role: review.kind == .delete ? .destructive : nil
                        ) {
                            Task {
                                await model.confirm(
                                    review.id, acknowledgeDeletion: deletionAcknowledged)
                            }
                        }
                        .disabled(model.isBusy || (review.kind == .delete && !deletionAcknowledged))
                    }
                }
            }.padding(8)
        }
        .onDisappear { Task { await model.cancel() } }
    }
}

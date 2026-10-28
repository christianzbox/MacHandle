import CoreDomain
import MacHandleApplication
import SwiftUI

struct GoogleSyncView: View {
    @Bindable var model: GoogleSyncModel
    let calendars: CalendarAccessStore
    let manageCalendars: () -> Void
    @State private var confirmingDeletion = false
    @State private var deletionReviewID: UUID?
    @State private var confirmingRevocation = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text("One-way Apple → Google synchronization").font(.headline)
                Text(
                    "Selected Apple calendars stay read-only. Apple edits update the existing Google copies. Google edits do not change Apple events. MCP is independent."
                )
                .foregroundStyle(.secondary)
                Label(model.status.phase.title, systemImage: "arrow.triangle.2.circlepath")
                if model.status.phase == .unconfigured {
                    Text(
                        "Live sync is not configured in this development build. Developer account setup, signed-app checks and private Google destination verification are still required. No Google data is transferred."
                    )
                    .foregroundStyle(.secondary)
                }
                if let date = model.status.lastSuccess {
                    Text("Last successful sync: \(date.formatted())").font(.caption)
                } else {
                    Text("Last successful sync: Never").font(.caption)
                }
                if let failure = model.failure { Text(failure.message).foregroundStyle(.secondary) }
                Button("Connect Google") { Task { await model.connect() } }
                    .disabled(model.isBusy || !canConnect)
                Divider()
                Text("Source calendars").font(.headline)
                Text(
                    "Choose sources specifically for Google. Local calendar selections do not grant Google access."
                )
                .font(.caption).foregroundStyle(.secondary)
                if case .ready(let catalog) = calendars.state {
                    ForEach(catalog.calendars, id: \.id) { calendar in
                        Toggle(
                            calendar.name,
                            isOn: Binding(
                                get: { model.configuration.sources.contains(calendar.id) },
                                set: { selected in
                                    change { value in
                                        if selected {
                                            value.sources.insert(calendar.id)
                                        } else {
                                            value.sources.remove(calendar.id)
                                        }
                                    }
                                }))
                    }
                    if catalog.calendars.isEmpty { Text("No source calendars available.") }
                } else {
                    Text(
                        "Enable Apple Calendar access to discover sources. Opening this screen does not request permission."
                    )
                    .foregroundStyle(.secondary)
                }
                Button("Manage Apple Calendar Access", action: manageCalendars)
                Divider()
                Text("Privacy").font(.headline)
                Toggle(
                    "Include selected event details",
                    isOn: Binding(
                        get: { !model.configuration.fields.isEmpty },
                        set: { enabled in change { $0.fields = enabled ? [.title] : [] } }))
                Text(
                    "Availability-only is the default: times and busy/free status, with a generic Busy title. Times can still reveal personal patterns."
                )
                .font(.caption).foregroundStyle(.secondary)
                if !model.configuration.fields.isEmpty {
                    fieldToggle("Title", .title)
                    fieldToggle("Location", .location)
                    fieldToggle("Notes", .notes)
                }
                Text(
                    "Removing a detail clears it from existing Google copies on the next confirmed sync. Pausing does not erase data already copied."
                )
                .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.status.phase == .paused ? "Review and Resume" : "Review Changes") {
                        Task { await model.preview() }
                    }.disabled(model.isBusy || model.configuration.sources.isEmpty || !canReview)
                    Button("Pause") { Task { await model.pause() } }
                        .disabled(
                            model.status.phase == .unconfigured
                                || model.status.phase == .disconnected)
                    if model.isBusy { ProgressView().controlSize(.small) }
                }
                if let review = model.review { preview(review) }
                Divider()
                Button("Disconnect This Mac") { Task { await model.disconnect() } }
                    .disabled(
                        model.status.phase == .unconfigured || model.status.phase == .disconnected)
                Text(
                    "Stops and drains local sync, clears saved sync choices and removes local authorization. Google calendars and events remain."
                )
                .font(.caption).foregroundStyle(.secondary)
                Button("Revoke Google Grant…", role: .destructive) { confirmingRevocation = true }
                    .disabled(model.isBusy || model.status.phase == .unconfigured)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Google Calendar", systemImage: "calendar")
        }
        .task {
            await model.refresh()
            while model.status.phase != .unconfigured && !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
                await model.refresh()
            }
        }
        .confirmationDialog("Delete the reviewed Google copies?", isPresented: $confirmingDeletion)
        {
            Button("Confirm Sync and Deletions", role: .destructive) {
                Task { await model.confirm(reviewID: deletionReviewID, approveDeletions: true) }
            }
        } message: {
            Text(
                "This confirms every deletion in the current preview. Apple events are not changed. A changed or expired review must be generated again."
            )
        }
        .confirmationDialog("Revoke the Google grant?", isPresented: $confirmingRevocation) {
            Button("Revoke Grant and Disconnect", role: .destructive) {
                Task { await model.disconnect(revokeGrant: true) }
            }
        } message: {
            Text(
                "This can affect other installations using the same Google project. Remote calendars and events remain. Revocation may take time to propagate."
            )
        }
    }

    private var canConnect: Bool {
        [.disconnected, .signInRequired, .unavailable].contains(model.status.phase)
    }
    private var canReview: Bool {
        [.ready, .reviewing, .paused, .waiting, .suspended, .recoveryRequired].contains(
            model.status.phase)
    }
    private func change(_ edit: (inout CalendarSyncConfiguration) -> Void) {
        var value = model.configuration
        edit(&value)
        confirmingDeletion = false
        Task { await model.configure(value) }
    }
    private func fieldToggle(_ title: String, _ field: CalendarDetailField) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { model.configuration.fields.contains(field) },
                set: { enabled in
                    change { value in
                        if enabled {
                            value.fields.insert(field)
                        } else {
                            value.fields.remove(field)
                        }
                    }
                }))
    }
    private func preview(_ review: CalendarSyncPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review before syncing").font(.headline)
            Text(
                "\(review.items.count) changes and unchanged items · \(review.deletionCount) deletions"
            )
            Text("Review expires \(review.expiresAt.formatted(date: .omitted, time: .standard)).")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(review.items) { item in
                HStack {
                    Text(item.action.rawValue.capitalized).frame(width: 90, alignment: .leading)
                    VStack(alignment: .leading) {
                        Text(item.contentTitle)
                        if !item.location.isEmpty { Text(item.location).font(.caption) }
                        if !item.notes.isEmpty { Text(item.notes).font(.caption) }
                        Text(sourceName(item.source)).font(.caption).foregroundStyle(.secondary)
                        if let time = item.time { Text(describe(time)).font(.caption) }
                    }
                }.accessibilityElement(children: .combine)
            }
            Button("Confirm and Start Sync") {
                if review.deletionCount > 0 {
                    deletionReviewID = review.id
                    confirmingDeletion = true
                } else {
                    Task { await model.confirm(reviewID: review.id) }
                }
            }.disabled(model.isBusy)
        }
    }
    private func sourceName(_ source: CalendarReference) -> String {
        guard case .ready(let catalog) = calendars.state else { return "Selected source" }
        return catalog.calendars.first { $0.id == source }?.name ?? "Selected source"
    }
    private func describe(_ time: EventTime) -> String {
        switch time {
        case .timed(let interval, let zone):
            "\(interval.start.date.formatted()) – \(interval.end.date.formatted()) (displayed in this Mac’s time zone; source \(zone.rawValue))"
        case .allDay(let dates, _):
            "All day: \(dates.start.year)-\(dates.start.month)-\(dates.start.day) through \(dates.end.year)-\(dates.end.month)-\(dates.end.day) (exclusive end)"
        }
    }
}

extension CalendarSyncPhase {
    var title: String {
        switch self {
        case .unconfigured: "Not configured"
        case .disconnected: "Disconnected"
        case .connecting: "Connecting Google…"
        case .ready: "Ready to review"
        case .reviewing: "Waiting for confirmation"
        case .running: "Syncing…"
        case .waiting: "Sync enabled"
        case .paused: "Paused · Review before resuming"
        case .suspended: "Waiting for this Mac and network"
        case .standby: "Standby · Another writer may be active"
        case .recoveryRequired: "Recovery needs attention"
        case .signInRequired: "Sign in again"
        case .unavailable: "Unavailable"
        }
    }
}
extension CalendarSyncFailure {
    fileprivate var message: String {
        switch self {
        case .notConfigured: "Google setup has not been completed."
        case .signInRequired: "Google authorization is unavailable. Connect again."
        case .invalidSelection: "Select between 1 and 32 available source calendars."
        case .staleReview: "The preview changed or expired. Review changes again."
        case .approvalRequired: "Confirm the entire reviewed deletion set before continuing."
        case .sourceUnavailable:
            "A complete, current source read could not be verified. Sync is stopped."
        case .privacyUnverified:
            "The Google destination’s privacy could not be verified. Sync is stopped."
        case .recoveryRequired:
            "An unresolved write or conflict needs review. Automatic replay is blocked. Keep the existing Google copies; the recovery procedure must verify their original identities before resuming."
        case .unavailable:
            "The operation could not be completed. Sync is stopped; check authorization and retry."
        case .disconnectIncomplete:
            "Sync is stopped locally, but removing saved authorization or revoking the Google grant could not be confirmed. Retry disconnect and review Google Account access."
        case .cancelled: "The operation was cancelled."
        case .busy: "Another operation is still stopping. Try again once it finishes."
        }
    }
}

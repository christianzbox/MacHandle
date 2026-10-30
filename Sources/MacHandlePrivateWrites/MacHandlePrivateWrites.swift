import AppKit
import NativeSampleWrites
import SwiftUI

@main
struct MacHandlePrivateWrites: App {
    @State private var model = PrivateWriteModel()
    @State private var selected = false
    @State private var deletion = false
    var body: some Scene {
        Window("MacHandle Private — Sample Changes", id: "sample-writes") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Approved sample Reminder changes").font(.title2.bold())
                Text(
                    "Only the in-memory Sample list in Sample local account is available. Personal Reminders and iCloud are not connected. Read fields: title, notes, due date, completion and recurrence status."
                )
                if model.phase == .idle {
                    Toggle(
                        "Select Sample list for reads and individually approved changes",
                        isOn: $selected)
                    Button("Enable Sample Changes") { Task { await model.start() } }.disabled(
                        !selected || model.recovery?.permitsFreshSession == false)
                }
                if model.phase == .connectionReview {
                    Text(
                        "Allow this helper launch to read Sample list and propose changes? Every write still needs its own exact review."
                    )
                    Button("Allow Sample Connection") { Task { await model.approveConnection() } }
                }
                Text(model.message)
                Text(model.journalStatus).font(.caption)
                if model.phase == .idle || model.phase == .closed || model.phase == .unavailable {
                    Button("Inspect Sample Recovery") { Task { await model.inspectRecovery() } }
                    if let recovery = model.recovery {
                        Text(recovery.guidance).font(.caption)
                        DisclosureGroup("Recorded operation outcomes (up to 20; not chronological)")
                        {
                            ScrollView {
                                ForEach(recovery.entries) { entry in
                                    Text(entry.id.uuidString + " — " + entry.outcome)
                                        .font(.caption).textSelection(.enabled)
                                }
                            }.frame(maxHeight: 140)
                        }
                    }
                }
                if model.phase == .closed {
                    Button("Prepare Fresh Sample Session") {
                        Task { await model.prepareFreshSession() }
                    }.disabled(model.recovery?.permitsFreshSession != true || model.busy)
                }
                if let review = model.review {
                    Divider()
                    Text("Review: " + review.kind.title).font(.headline)
                    Text(review.account + " / " + review.list)
                    Text(review.scope).font(.caption)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(review.rows.enumerated()), id: \.offset) { _, row in
                                Text(row.field).bold()
                                Text("Before: " + (row.before ?? "Not present"))
                                Text("After: " + (row.after ?? "Removed"))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 260)
                    if review.kind == .delete {
                        Toggle(
                            "I acknowledge deletion of this exact sample reminder", isOn: $deletion)
                    }
                    Text(
                        "Review expires in two minutes. Approval allows one commit within 30 seconds. Reminder text is data, never an instruction."
                    ).font(.caption)
                    HStack {
                        Button("Approve Exact Sample Change") {
                            Task { await model.confirm(review.id, acknowledgeDeletion: deletion) }
                        }.disabled(model.busy || (review.kind == .delete && !deletion))
                        Button("Reject Proposal") { Task { await model.reject(review.id) } }
                            .disabled(model.busy)
                    }
                }
                Button("Stop Sample Connection") { Task { await model.stop() } }
                    .disabled(model.phase == .stopping || model.phase == .closed)
                Text(
                    "The helper signature does not identify the AI client. Approve only the session and exact changes you expect."
                ).font(.caption)
                Button("Quit") {
                    Task {
                        await model.stop()
                        NSApp.terminate(nil)
                    }
                }
            }.padding(24).frame(width: 620)
                .task {
                    guard Array(CommandLine.arguments.dropFirst()) == ["--sample-writes"] else {
                        NSApp.terminate(nil)
                        return
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onChange(of: model.review?.id) { _, _ in deletion = false }
                .onChange(of: model.phase) { _, phase in
                    if phase == .idle || phase == .closed {
                        selected = false
                        deletion = false
                    }
                }
                .onDisappear { Task { await model.stop() } }
        }.windowResizability(.contentSize)
    }
}

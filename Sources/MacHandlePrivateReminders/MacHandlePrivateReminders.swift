import AppKit
import AppleCalendarProvider
import MacHandleApplication
import SwiftUI

@main
struct MacHandlePrivateReminders: App {
    @State private var model: PrivateReminderReadModel?
    @State private var acknowledged = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        Window("MacHandle Private — Selected Reminders", id: "selected-reminders") {
            Group {
                if let model {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            model.isolated
                                ? "Isolated Reminders reads" : "Selected sample Reminders"
                        ).font(.title2.bold())
                        if model.isolated {
                            Text(
                                "Use only a separate macOS test account with no personal or synced data. List selection cannot isolate the OS permission: Apple's Reminders access permits reading and writing. MacHandle exposes reads only."
                            )
                            Toggle(
                                "I am using an isolated test account with only sample reminders",
                                isOn: $acknowledged
                            )
                            .disabled(
                                model.enabled || model.busy || model.connection.phase != .idle)
                        } else {
                            Text(
                                "Injected sample data only. No Apple permission or personal iCloud access."
                            )
                        }
                        Text(model.status)
                        if !model.enabled && model.connection.phase == .idle {
                            Button(
                                model.isolated ? "Enable Isolated Reminders" : "Load Sample Lists"
                            ) {
                                Task { await model.enable(isolationAcknowledged: acknowledged) }
                            }.disabled(model.busy || (model.isolated && !acknowledged))
                        }
                        if model.enabled {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    ForEach(model.lists, id: \.id) { list in
                                        Toggle(
                                            list.accountName.map { list.name + " — " + $0 }
                                                ?? list.name,
                                            isOn: Binding(
                                                get: { model.selected.contains(list.id) },
                                                set: { model.select(list.id, enabled: $0) }))
                                    }
                                }
                            }.frame(maxHeight: 150)
                                .disabled(model.busy || model.connection.phase != .idle)
                            Text("Fields shared with the helper")
                            ForEach(PrivateReminderReadModel.Field.allCases, id: \.self) { field in
                                Toggle(
                                    field.rawValue.capitalized,
                                    isOn: Binding(
                                        get: { model.fields.contains(field) },
                                        set: { model.select(field, enabled: $0) })
                                )
                                .disabled(model.busy || model.connection.phase != .idle)
                            }
                            Button("Start Selected Connection") { Task { await model.connect() } }
                                .disabled(!model.canConnect)
                        }
                        switch model.connection.phase {
                        case .listening:
                            Text(
                                "Start the local helper. Reads remain blocked until approval here.")
                        case .review:
                            Text(
                                "Allow this helper launch to read the selected lists and fields? Review expires in 60 seconds."
                            )
                            Button("Allow Selected Reads") {
                                Task { await model.connection.approve() }
                            }
                            .disabled(model.connection.reviewID == nil)
                        case .connected: Text("Selected reads allowed for this launch.")
                        case .unavailable:
                            Text("Signed package unavailable. Rebuild before trying again.")
                        case .closed: Text("Connection closed.")
                        case .idle: EmptyView()
                        }
                        Button("Stop and Clear Selection") { Task { await model.stop() } }
                        Text(
                            "The helper identity does not identify the AI client. Only approve a session you started. No writes are available."
                        ).font(.caption)
                        Button("Quit") {
                            Task {
                                await model.stop()
                                NSApp.terminate(nil)
                            }
                        }
                    }.padding(24).frame(width: 570)
                } else {
                    Text("Checking private package…").padding()
                }
            }
            .task {
                let args = Array(CommandLine.arguments.dropFirst())
                let isolated = args == ["--isolated-reminders"]
                guard isolated || args == ["--selected-sample"],
                    PrivateReminderReadModel.validPackage(isolated: isolated)
                else {
                    NSApp.terminate(nil)
                    return
                }
                // A sample launch never constructs the EventKit provider.
                if isolated {
                    model = PrivateReminderReadModel(
                        source: EventKitRemindersProvider(), isolated: true)
                } else {
                    model = try? PrivateReminderReadModel.sample()
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            .onDisappear { Task { await model?.stop() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model?.refreshAuthorization() } }
            }
        }.windowResizability(.contentSize)
    }
}

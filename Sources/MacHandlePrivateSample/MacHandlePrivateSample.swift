import AppKit
import MacHandleApplication
import SwiftUI

@main
struct MacHandlePrivateSample: App {
    @State private var connection = PrivateConnectionModel()
    var body: some Scene {
        Window("MacHandle Private — Sample Reminders", id: "private-sample") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Sample Reminders connection").font(.title2.bold())
                Text(
                    "Only the sample list is available. Your personal Reminders and iCloud are not connected."
                )
                switch connection.phase {
                case .idle: Text("Starting sample session…")
                case .listening: Text("Waiting for the local helper. Reads start disabled.")
                case .review:
                    Text("Allow this helper launch to read the sample list?").font(.headline)
                    Text(
                        "Access: list name, reminder titles and completion status. No notes or changes. This review expires in 60 seconds."
                    )
                    HStack {
                        Button("Allow Sample Reads") { Task { await connection.approve() } }
                            .disabled(connection.reviewID == nil)
                        Button("Reject") { Task { await connection.stop() } }
                    }
                case .connected:
                    Text("Sample reads allowed for this launch.").font(.headline)
                    Button("Revoke Sample Access") { Task { await connection.stop() } }
                case .closed: Text("Connection closed. A new session requires a new review.")
                case .unavailable:
                    Text("Private sample package unavailable. Rebuild the local sample package.")
                }
                Divider()
                Text(
                    "The helper's identity does not identify the AI client using it. Approve only the sample session you started."
                ).font(.caption)
                Button("Quit Sample App") {
                    Task {
                        await connection.stop()
                        NSApp.terminate(nil)
                    }
                }
            }
            .padding(28).frame(width: 520)
            .task {
                guard Array(CommandLine.arguments.dropFirst()) == ["--private-sample"] else {
                    NSApp.terminate(nil)
                    return
                }
                connection.start()
                NSApp.activate(ignoringOtherApps: true)
            }
            .onDisappear { Task { await connection.stop() } }
        }
        .windowResizability(.contentSize)
    }
}

import AppKit
import AppleCalendarProvider
import MacHandleApplication
import MacHandleFoundation
import PermissionEngine
import SwiftUI

@main
struct MacHandleApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    // Activation stays disabled until identity, Google console and signed Keychain gates are met.
    private let googleSynchronization = GoogleSyncModel()
    @State private var loginItem = LoginItemModel()
    private let calendarReads: CalendarReadStore
    @State private var state: ApplicationState

    init() {
        let preview = PreviewPolicyService(google: PolicyAuthority(), localMCP: PolicyAuthority())
        let provider = EventKitCalendarProvider()
        let calendars = CalendarAccessStore(provider: provider)
        calendarReads = CalendarReadStore(
            access: calendars, reader: provider, authorization: provider,
            authority: PolicyAuthority())
        _state = State(
            initialValue: ApplicationState(
                connections: ConnectionPreviewStore(evaluator: preview),
                calendars: calendars))
    }

    var body: some Scene {
        Window(BuildInfo.productName, id: "main") {
            MainWindow(state: state, reads: calendarReads, google: googleSynchronization)
                .preferredColorScheme(state.appearance.colorScheme)
        }
        .defaultSize(width: 1080, height: 740)
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            CommandMenu("Navigate") {
                Button("Overview") { state.section = .overview }.keyboardShortcut("1")
                Button("Apple Calendars") { state.section = .calendars }.keyboardShortcut("5")
                Button("Connections") { state.section = .connections }.keyboardShortcut("2")
                Button("Activity") { state.section = .activity }.keyboardShortcut("3")
                Button("Diagnostics") { state.section = .diagnostics }.keyboardShortcut("4")
            }
        }
        Settings {
            SettingsView(state: state, loginItem: loginItem)
                .preferredColorScheme(state.appearance.colorScheme)
        }
        MenuBarExtra(BuildInfo.productName, systemImage: "hand.raised.fill") {
            MenuContent(state: state, google: googleSynchronization)
        }
    }
}

@MainActor
final class AppLifecycle: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct MenuContent: View {
    let state: ApplicationState
    let google: GoogleSyncModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Interface preview")
        Text("Google sync: \(google.status.phase.title)")
        Text("Enabled previews: \(state.connections.enabledPreviewCount)")
        Text("Last successful sync: \(google.status.lastSuccess?.formatted() ?? "Never")")
        Divider()
        Button("Open MacHandle") { show(.overview) }
        Button("Apple Calendars") { show(.calendars) }
        Button("Manage Connections") { show(.connections) }
        Button("Activity History") { show(.activity) }
        Button("Diagnostics") { show(.diagnostics) }
        Divider()
        Button("Review Sync Changes") { show(.connections) }
        Button("Pause Sync") { Task { await google.pause() } }
            .disabled(google.status.phase == .unconfigured || google.status.phase == .disconnected)
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit MacHandle") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    private func show(_ section: AppSection) {
        state.section = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

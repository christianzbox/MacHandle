import AppKit
import MacHandleApplication
import SwiftUI

struct SettingsView: View {
    @Bindable var state: ApplicationState
    let loginItem: LoginItemModel
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color scheme", selection: $state.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearance-picker")
                Text("Applies to MacHandle windows. This preview setting resets when you quit.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("App behavior") {
                Text(
                    "Closing the window keeps MacHandle in the menu bar. Use Quit MacHandle to exit."
                )
                Text(
                    "No synchronization runs. Calendar metadata refreshes while discovery is enabled."
                )
                .foregroundStyle(.secondary)
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { loginItem.requested },
                        set: { value in Task { await loginItem.setEnabled(value) } })
                )
                .disabled(loginItem.busy || loginItem.status == .unavailable)
                .accessibilityIdentifier("launch-at-login")
                Text(loginStatus)
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("No external connections", systemImage: "lock.shield")
                Text(
                    "Calendar discovery loads names after opt-in. Local reads require selected calendars and a separate action; availability omits event details. Results and selections stay in memory and clear on access changes or quit. Nothing is shared externally."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 520, height: 640)
        .onAppear { loginItem.refresh() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            loginItem.refresh()
        }
    }
    private var loginStatus: String {
        if loginItem.failed {
            return
                "Could not change launch at login. Check Login Items in System Settings and try again."
        }
        switch loginItem.status {
        case .disabled:
            return "Off. Opening at login does not enable synchronization or grant access."
        case .enabled: return "MacHandle will open when you log in. Quit stops all app activity."
        case .requiresApproval:
            return
                "Allow MacHandle in System Settings → General → Login Items. It will not register again automatically."
        case .unavailable: return "Launch at login is unavailable for this installation."
        }
    }
}

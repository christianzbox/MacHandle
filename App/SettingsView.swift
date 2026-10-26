import MacHandleApplication
import SwiftUI

struct SettingsView: View {
    @Bindable var state: ApplicationState
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
                Toggle("Launch at login", isOn: .constant(false)).disabled(true)
                    .help("Launch at login is not implemented in this preview.")
                Text("Launch at login will require a separate opt-in when it is available.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("No external connections", systemImage: "lock.shield")
                Text(
                    "Calendar discovery reads account and calendar names only after opt-in. Selections and preview history stay in memory and reset on quit. No credentials are stored."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 520, height: 600)
    }
}

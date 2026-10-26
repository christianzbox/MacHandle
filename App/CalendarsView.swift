import CoreDomain
import MacHandleApplication
import SwiftUI

struct CalendarsView: View {
    let store: CalendarAccessStore

    var body: some View {
        PageHeader(
            title: "Apple Calendars",
            subtitle: "Choose which calendars you may want to use with MacHandle.")
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Calendar discovery is optional").fontWeight(.semibold)
                Text(
                    "macOS requires full Calendar access to list calendars. That OS permission includes reads and writes; this version only lists account and calendar names. It does not read events or make changes."
                )
                Text(
                    "Selecting calendars does not enable Google or MCP, or authorize sharing. Your choices stay in memory and reset when you quit. Nothing is sent off this Mac."
                )
                .foregroundStyle(.secondary)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
        status
        HStack {
            if store.isEnabled {
                Button("Refresh Calendars") { Task { await store.refresh() } }
                    .disabled(store.isBusy)
                Spacer()
                Button("Disable Calendar Discovery", role: .destructive) { store.disable() }
            } else {
                Button("Enable Calendar Discovery") { Task { await store.enable() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("enable-calendar-discovery")
            }
        }
        Text(
            "Disabling clears the displayed names and selections. To revoke the OS grant, use System Settings → Privacy & Security → Calendars."
        )
        .font(.callout).foregroundStyle(.secondary)
    }

    @ViewBuilder private var status: some View {
        switch store.state {
        case .disabled:
            EmptyPanel(
                title: "Calendar discovery is off",
                message:
                    "Enable it when you are ready. No calendar metadata is loaded while it is off.",
                symbol: "calendar.badge.minus")
        case .loading:
            HStack {
                ProgressView().controlSize(.small)
                Text("Checking Calendar access…")
            }
        case .access(let authorization):
            EmptyPanel(
                title: title(authorization), message: explanation(authorization),
                symbol: "lock.shield")
        case .unavailable:
            EmptyPanel(
                title: "Calendar service unavailable",
                message:
                    "No current inventory is available. Selections have been cleared. Try Refresh Calendars again.",
                symbol: "exclamationmark.triangle")
        case .incomplete:
            EmptyPanel(
                title: "Calendar inventory changed or is incomplete",
                message:
                    "The returned metadata could not be validated. Selections have been cleared; refresh to try again. This is not an empty-calendar result.",
                symbol: "exclamationmark.triangle")
        case .ready(let catalog):
            if catalog.calendars.isEmpty {
                EmptyPanel(
                    title: "No calendars returned locally",
                    message:
                        "Check your Calendar accounts, then refresh. This does not establish that remote sources are empty or up to date.",
                    symbol: "calendar")
            } else {
                Text("\(store.selectedCalendars.count) selected · No external access granted")
                    .font(.headline)
                ForEach(catalog.accounts, id: \.id) { account in
                    let calendars = catalog.calendars.filter { $0.id.account == account.id }
                    if !calendars.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(calendars, id: \.id) { calendar in
                                    Toggle(
                                        calendar.name,
                                        isOn: Binding(
                                            get: { store.selectedCalendars.contains(calendar.id) },
                                            set: { store.setSelected(calendar.id, selected: $0) })
                                    )
                                    .toggleStyle(.checkbox)
                                }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text(account.name)
                        }
                    }
                }
                Text(
                    "Names come from your local Calendar accounts. An empty selection grants nothing. Local discovery does not prove that remote calendars are up to date."
                )
                .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func title(_ status: OSAuthorization) -> String {
        switch status {
        case .notDetermined: "Calendar permission not granted yet"
        case .denied: "Calendar permission denied"
        case .restricted: "Calendar permission restricted"
        case .writeOnly: "Write-only permission cannot list calendars"
        case .fullAccess: "Calendar discovery needs a refresh"
        case .unsupported: "Calendar access is unsupported"
        case .unknown: "Calendar access could not be confirmed"
        }
    }

    private func explanation(_ status: OSAuthorization) -> String {
        switch status {
        case .denied, .restricted:
            "MacHandle cannot list calendars. Review Calendar permission in System Settings, then refresh. Organization restrictions may require your administrator."
        case .writeOnly, .notDetermined:
            "No calendar metadata was loaded. Disable and enable discovery to request full Calendar access, or review permission in System Settings."
        case .fullAccess, .unsupported, .unknown:
            "No usable inventory is available. Selections have been cleared. Refresh after checking Calendar access; no error details are logged."
        }
    }
}

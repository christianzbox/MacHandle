import CoreDomain
import MacHandleApplication
import SwiftUI

struct CalendarsView: View {
    let store: CalendarAccessStore
    let reads: CalendarReadStore

    var body: some View {
        PageHeader(
            title: "Apple Calendars",
            subtitle: "Choose which calendars you may want to use with MacHandle.")
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Calendar discovery is optional").fontWeight(.semibold)
                Text(
                    "macOS requires full Calendar access to list calendars. That OS permission includes reads and writes; discovery lists account and calendar names. A separate Read action below reads only your selected calendars and chosen fields. MacHandle never modifies them."
                )
                Text(
                    "Selecting calendars does not enable Google or MCP, or authorize sharing. Your choices stay in memory and reset when you quit. Nothing is sent off this Mac."
                )
                .foregroundStyle(.secondary)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
        status
        if !store.selectedCalendars.isEmpty { CalendarReadsView(store: reads) }
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

struct RemindersView: View {
    @Bindable var store: RemindersStore
    var body: some View {
        PageHeader(
            title: "Apple Reminders",
            subtitle: "Read selected lists locally. Calendar access does not enable Reminders.")
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reminders access is optional").font(.headline)
                Text(
                    "Enable to request macOS permission and discover lists. Select lists before reading. External connections and Reminder changes remain off."
                )
                HStack {
                    if store.isEnabled {
                        Button("Disable Reminders", role: .destructive) { store.disable() }
                    } else {
                        Button("Enable Reminders…") { Task { await store.enable() } }.disabled(
                            store.isBusy)
                    }
                    Button("Refresh lists") { Task { await store.refresh() } }.disabled(
                        !store.isEnabled || store.isBusy)
                    if store.isBusy { ProgressView().controlSize(.small) }
                }
                Text(verbatim: store.status).foregroundStyle(.secondary)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
        if store.isEnabled {
            GroupBox("Selected lists") {
                VStack(alignment: .leading, spacing: 10) {
                    if store.lists.isEmpty {
                        Text("No verified lists available.").foregroundStyle(.secondary)
                    }
                    ForEach(store.lists, id: \.id) { list in
                        Toggle(
                            isOn: Binding(
                                get: { store.selection.contains(list.id) },
                                set: { store.select(list.id, selected: $0) })
                        ) {
                            VStack(alignment: .leading) {
                                Text(verbatim: list.name)
                                if let account = list.accountName {
                                    Text(verbatim: account).font(.caption).foregroundStyle(
                                        .secondary)
                                }
                            }
                        }.disabled(store.isBusy)
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            TextField("Search permitted titles (empty lists all)", text: $store.query)
                .textFieldStyle(.roundedBorder)
            Toggle("Include notes when opening details", isOn: $store.includeNotes)
            Button("Search selected lists") { Task { await store.search() } }
                .disabled(store.isBusy || store.selection.isEmpty)
            ForEach(store.results, id: \.id) { reminder in
                Button {
                    Task { await store.showDetails(reminder.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: title(reminder)).font(.headline)
                        Text(verbatim: due(reminder)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.disabled(store.isBusy)
            }
            if let detail = store.detail {
                GroupBox("Reminder details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: title(detail)).font(.headline)
                        Text(verbatim: due(detail))
                        if case .value(let completion) = detail.completion {
                            switch completion {
                            case .incomplete: Text("Incomplete")
                            case .completed: Text("Completed")
                            }
                        }
                        if case .value(let recurrence) = detail.recurrence {
                            Text(
                                recurrence == .recurring
                                    ? "Repeats (rule details not shown)" : "Does not repeat")
                        }
                        if case .value(let notes) = detail.notes {
                            Text(verbatim: notes ?? "No notes").textSelection(.enabled)
                        }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    private func title(_ value: Reminder) -> String {
        if case .value(let text) = value.title { return text }
        return "Title unavailable"
    }
    private func due(_ value: Reminder) -> String {
        guard case .value(let due) = value.due else { return "Due date unavailable" }
        guard let due else { return "No due date" }
        func date(_ d: LocalDate) -> String {
            String(format: "%04d-%02d-%02d", d.year, d.month, d.day)
        }
        switch due {
        case .date(let d): return "Due \(date(d)) (date only)"
        case .localDateTime(let d, let t, let zone):
            return
                "Due \(date(d)) \(String(format: "%02d:%02d:%02d", t.hour, t.minute, t.second)) · \(zone?.rawValue ?? "floating time")"
        }
    }
}

struct ContactsView: View {
    @Bindable var store: ContactsStore
    private let choices: [(String, ContactField)] = [
        ("Email addresses", .emailAddresses), ("Phone numbers", .phoneNumbers),
        ("Postal addresses", .postalAddresses), ("Organization", .organization),
    ]
    var body: some View {
        PageHeader(
            title: "Apple Contacts",
            subtitle: "Choose address books and the fields you want to read locally.")
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "macOS Contacts permission includes read and write access. MacHandle reads only your selections and does not modify contacts or enable external connections."
                )
                HStack {
                    if store.isEnabled {
                        Button("Disable Contacts") { store.disable() }
                    } else {
                        Button("Enable Contacts…") { Task { await store.enable() } }.disabled(
                            store.isBusy)
                    }
                    Button("Refresh") { Task { await store.refresh() } }.disabled(
                        !store.isEnabled || store.isBusy)
                    if store.isBusy { ProgressView().controlSize(.small) }
                }
                Text(verbatim: store.status).accessibilityIdentifier("contacts-status")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        if store.isEnabled {
            GroupBox("Address books") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Nothing is selected automatically. Linked contacts are shown as separate underlying records; names do not establish identity."
                    ).font(.caption)
                    ForEach(store.containers, id: \.id) { container in
                        Toggle(
                            isOn: Binding(
                                get: { store.selection.contains(container.id) },
                                set: { store.select(container.id, selected: $0) })
                        ) {
                            Text(
                                verbatim: container.name.isEmpty
                                    ? "Unnamed address book" : container.name)
                        }.toggleStyle(.checkbox).disabled(store.isBusy)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Search and detail fields") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Search reads names only. Choose additional fields for opening a contact's details. Contact notes are unavailable."
                    ).font(.caption)
                    ForEach(choices.indices, id: \.self) { index in
                        Toggle(
                            choices[index].0,
                            isOn: Binding(
                                get: { store.fields.contains(choices[index].1) },
                                set: { store.setField(choices[index].1, enabled: $0) })
                        )
                        .toggleStyle(.checkbox)
                    }
                    HStack {
                        TextField(
                            "Search names (empty lists selected contacts)", text: $store.query)
                        Button("Search") { Task { await store.search() } }.disabled(
                            store.isBusy || store.selection.isEmpty)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(store.results, id: \.id) { contact in
                if case .record(let ref) = contact.id {
                    Button {
                        Task { await store.showDetails(ref) }
                    } label: {
                        Text(verbatim: name(contact)).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }.disabled(store.isBusy)
                }
            }
            if let contact = store.detail {
                GroupBox("Selected contact details") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: name(contact)).font(.headline)
                        if case .value(let values) = contact.emailAddresses {
                            DetailRow(title: "Email", value: labeled(values))
                        }
                        if case .value(let values) = contact.phoneNumbers {
                            DetailRow(title: "Phone", value: labeled(values))
                        }
                        if case .value(let values) = contact.postalAddresses {
                            DetailRow(
                                title: "Postal addresses",
                                value: values.map {
                                    [
                                        $0.value.street, $0.value.city, $0.value.region,
                                        $0.value.postalCode, $0.value.country,
                                    ].filter { !$0.isEmpty }.joined(separator: ", ")
                                }.joined(separator: "\n"))
                        }
                        if case .value(let value) = contact.organization {
                            DetailRow(title: "Organization", value: value ?? "Not set")
                        }
                        Text(
                            "Local record only. No linked records, notes or mutation permission are included."
                        ).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
            }
        }
    }
    private func name(_ contact: Contact) -> String {
        guard case .value(let value) = contact.name else { return "Name not fetched" }
        let name = [value.given, value.family].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Unnamed contact" : name
    }
    private func labeled(_ values: [LabeledValue<String>]) -> String {
        values.isEmpty
            ? "None"
            : values.map { [$0.label, $0.value].compactMap { $0 }.joined(separator: ": ") }.joined(
                separator: "\n")
    }
}

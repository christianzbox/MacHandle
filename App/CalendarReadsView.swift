import CoreDomain
import MacHandleApplication
import SwiftUI

struct CalendarReadsView: View {
    @Bindable var store: CalendarReadStore

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Read fields", selection: $store.mode) {
                    ForEach(LocalCalendarReadMode.allCases) { Text($0.title).tag($0) }
                }
                Text(
                    "Availability reads occupied or uncertain times only. Titles and details require choosing a different mode. No data leaves this Mac."
                )
                .foregroundStyle(.secondary)
                DatePicker("From", selection: $store.startDate)
                DatePicker("Until (exclusive)", selection: $store.endDate)
                Text(
                    "Choose a range of up to 400 days. Changing access, selection, fields or dates clears previous results."
                )
                .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Read Selected Calendars") { Task { await store.read() } }
                        .disabled(store.isBusy)
                    if store.isBusy { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Clear Results") { store.clear() }
                }
                if let result = store.result { resultView(result) }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Read locally")
        }
    }

    @ViewBuilder private func resultView(_ result: LocalCalendarReadResult) -> some View {
        switch result {
        case .denied:
            Label(
                "Read blocked. Check current Calendar access and selection, then retry.",
                systemImage: "lock.shield")
        case .failed(let failure):
            Label(failureMessage(failure), systemImage: "exclamationmark.triangle")
        case .availability(let value):
            observation(value.observation)
            Text("\(value.blocks.count) occupied or uncertain blocks returned").font(.headline)
            Text(
                "Missing blocks are not proof of free time. Results reflect a local observation, not guaranteed remote freshness."
            )
            .foregroundStyle(.secondary)
            ForEach(Array(value.blocks.prefix(100).enumerated()), id: \.offset) { _, block in
                Text(
                    "\(block.interval.start.date.formatted()) – \(block.interval.end.date.formatted()) · \(occupancy(block.occupancy))"
                )
            }
            if value.blocks.count > 100 {
                Text("Showing the first 100 blocks. Narrow the date range for fewer results.")
            }
        case .events(let snapshot):
            observation(snapshot.observation)
            Text("\(snapshot.occurrences.count) occurrences returned").font(.headline)
            ForEach(Array(snapshot.occurrences.prefix(100).enumerated()), id: \.offset) {
                _, event in
                VStack(alignment: .leading, spacing: 5) {
                    Text(field(event.title, empty: "Untitled event")).fontWeight(.medium)
                    Text(time(event.time)).font(.callout)
                    Text("\(occupancy(event.occupancy)) · \(status(event.status))")
                        .font(.caption).foregroundStyle(.secondary)
                    if case .value(let location) = event.location, let location, !location.isEmpty {
                        Text(location)
                    }
                    if case .value(let notes) = event.notes, let notes, !notes.isEmpty {
                        Text(notes)
                    }
                }.textSelection(.enabled).padding(.vertical, 6)
            }
            if snapshot.occurrences.count > 100 {
                Text("Showing the first 100 occurrences. Narrow the date range for fewer results.")
            }
            if snapshot.occurrences.isEmpty {
                Text(
                    "None returned in this local observation. This does not prove remote calendars are empty."
                )
            }
        }
    }

    private func observation(_ value: ObservationState) -> some View {
        let completeness: String
        switch value.completeness {
        case .complete: completeness = "Local query completed"
        case .partial: completeness = "Partial result — do not treat missing events as absent"
        case .unknown: completeness = "Coverage is unknown"
        }
        return Text(
            "\(completeness). Observed \(value.observedAt.date.formatted()). Remote freshness is not verified."
        )
        .font(.callout).foregroundStyle(.secondary)
    }

    private func field(_ value: FieldValue<String?>, empty: String) -> String {
        switch value {
        case .value(let text): text ?? empty
        case .notFetched: "Title not requested"
        case .notAuthorized: "Title not authorized"
        }
    }
    private func time(_ value: EventTime) -> String {
        switch value {
        case .timed(let range, let zone):
            "\(range.start.date.formatted()) – \(range.end.date.formatted()) (event zone: \(zone.rawValue))"
        case .allDay(let dates, let zone):
            "All day: \(dates.start.year)-\(dates.start.month)-\(dates.start.day) to \(dates.end.year)-\(dates.end.month)-\(dates.end.day) (exclusive, \(zone.rawValue))"
        }
    }
    private func occupancy(_ value: Occupancy) -> String {
        switch value {
        case .free: "Free"
        case .busy: "Busy"
        case .tentative: "Tentative"
        case .unknown: "Unknown availability"
        }
    }
    private func status(_ value: EventStatus) -> String {
        switch value {
        case .active: "Active"
        case .cancelled: "Cancelled"
        case .unknown: "Unknown status"
        }
    }
    private func failureMessage(_ value: ProviderFailure) -> String {
        switch value {
        case .invalidData:
            "Invalid range or event data. Choose an ordered range of at most 400 days and refresh discovery."
        case .denied, .revoked: "Calendar permission is no longer available. Refresh discovery."
        case .notFound, .ambiguousIdentity:
            "A selected calendar or event could not be resolved safely. Refresh discovery and reselect."
        case .cancelled: "The read was cancelled. No result was retained."
        default:
            "The source changed or is unavailable. Refresh discovery and retry; no empty result is assumed."
        }
    }
}

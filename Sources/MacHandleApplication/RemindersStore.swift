import CoreDomain
import Foundation
import Observation
import PermissionEngine

/// Trusted local opt-in UI only. Selection is not a grant to external clients.
@MainActor @Observable
public final class RemindersStore {
    public private(set) var isEnabled = false
    public private(set) var isBusy = false
    public private(set) var lists: [ReminderList] = []
    public private(set) var selection: Set<ReminderListReference> = []
    public private(set) var results: [Reminder] = []
    public private(set) var detail: Reminder?
    public private(set) var status = "Reminders access is off."
    public var query = "" { didSet { invalidate() } }
    public var includeNotes = false { didSet { invalidate() } }
    @ObservationIgnored private let provider: any ReminderReading & ReminderDiscovering
    @ObservationIgnored private let authority = PolicyAuthority()
    @ObservationIgnored private var readTask: Task<ProviderReadResult<ReminderSnapshot>, Never>?
    private var generation: UInt64 = 0
    public init(provider: any ReminderReading & ReminderDiscovering) { self.provider = provider }
    private func invalidate() {
        generation &+= 1
        readTask?.cancel()
        results = []
        detail = nil
    }
    public func disable() {
        invalidate()
        isEnabled = false
        lists = []
        selection = []
        status = "Reminders access is off."
    }
    public func select(_ list: ReminderListReference, selected: Bool) {
        guard isEnabled, !isBusy, lists.contains(where: { $0.id == list }) else { return }
        guard !selected || selection.contains(list) || selection.count < 32 else {
            status = "Select at most 32 lists."
            return
        }
        invalidate()
        if selected { selection.insert(list) } else { selection.remove(list) }
    }
    public func enable() async {
        guard !isEnabled, !isBusy else { return }
        isEnabled = true
        await load(requestAccess: true)
    }
    public func refresh() async {
        guard isEnabled else { return }
        invalidate()
        guard !isBusy else {
            lists = []
            selection = []
            status = "Refresh required after the current operation finishes."
            return
        }
        await load(requestAccess: false)
    }
    public func observeChanges() async {
        for await _ in await provider.changes() {
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }
    private func load(requestAccess: Bool) async {
        invalidate()
        isBusy = true
        defer { isBusy = false }
        let expected = generation
        func current() -> Bool { isEnabled && generation == expected && !Task.isCancelled }
        var access = await provider.authorization()
        guard current() else { return }
        if requestAccess && access == .notDetermined { access = await provider.requestAccess() }
        guard current() else { return }
        guard access == .fullAccess else {
            lists = []
            selection = []
            status = "Reminders permission is unavailable. Review access in System Settings."
            return
        }
        let result = await provider.discoverReminderLists()
        let latest = await provider.authorization()
        guard current() else { return }
        guard latest == .fullAccess, case .observed(let inventory) = result,
            inventory.resources.count <= 1000,
            Set(inventory.resources.map(\.id)).count == inventory.resources.count
        else {
            lists = []
            selection = []
            status = "Reminder lists could not be verified. Refresh to try again."
            return
        }
        lists = inventory.resources
        selection.formIntersection(lists.map(\.id))
        status = "Choose lists to read locally. External connections remain off."
    }
    public func search() async { await read(nil) }
    public func showDetails(_ reference: ReminderReference) async {
        guard results.contains(where: { $0.id == reference }) else { return }
        await read(reference)
    }
    private func read(_ item: ReminderReference?) async {
        guard isEnabled, !isBusy, !selection.isEmpty, query.utf8.count <= 256 else { return }
        let selected = item.map { Set([$0.list]) } ?? selection
        guard selected.isSubset(of: selection) else { return }
        generation &+= 1
        let expected = generation
        let query = self.query
        detail = nil
        if item == nil { results = [] }
        isBusy = true
        defer {
            isBusy = false
            readTask = nil
        }
        func current() -> Bool {
            isEnabled && expected == generation && selected.isSubset(of: selection)
                && !Task.isCancelled
        }
        do {
            let os = await provider.authorization()
            guard current(), os == .fullAccess else {
                if current() {
                    results = []
                    detail = nil
                    lists = []
                    selection = []
                    status = "Reminders access is unavailable."
                }
                return
            }
            let fields: Set<ReminderField> =
                item != nil && includeNotes
                ? [.title, .due, .completion, .recurrence, .notes]
                : [.title, .due, .completion, .recurrence]
            let operation: ReminderOperation = item == nil ? .readSummary : .readDetails
            let id = try ConnectionID("local-reminders-ui")
            await authority.setConnection(
                Connection(id: id, kind: .localMCP, state: .enabled),
                policy: ConnectionPolicy(
                    reminderLists: Dictionary(
                        uniqueKeysWithValues: selected.map {
                            ($0, ReminderGrant(operations: [operation], readableFields: fields))
                        })))
            await authority.observeOSPermissions(OSPermissions(reminders: os))
            guard current() else { return }
            let session = try await authority.bindTrustedConnection(id)
            guard
                case .allowed(let permit) = await session.evaluate(
                    .reminderRead(selected, operation: operation, fields: fields)), current()
            else { return }
            let request = try ReminderReadRequest(lists: selected, item: item)
            let fetch: Set<ReminderReadField> =
                includeNotes && item != nil
                ? [.title, .due, .completion, .recurrence, .notes]
                : [.title, .due, .completion, .recurrence]
            let task = Task { [provider] in await provider.readReminders(request, fields: fetch) }
            readTask = task
            let result = await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
            let latest = await provider.authorization()
            await authority.observeOSPermissions(OSPermissions(reminders: latest))
            guard current() else { return }
            guard latest == .fullAccess, case .observed(let snapshot) = result,
                snapshot.coverage == request,
                case .value(let filtered) = await session.filterReminders(
                    snapshot.reminders, using: permit), current()
            else {
                results = []
                detail = nil
                status = "The read could not be verified. No absence or deletion is inferred."
                return
            }
            if item != nil {
                detail = filtered.first
            } else {
                guard
                    query.isEmpty
                        || filtered.allSatisfy({
                            if case .value = $0.title { return true }
                            return false
                        })
                else { throw ProviderFailure.invalidData }
                results = Array(
                    filtered.filter { value in
                        guard !query.isEmpty else { return true }
                        guard case .value(let title) = value.title else { return false }
                        return title.range(
                            of: query, options: .caseInsensitive,
                            locale: Locale(identifier: "en_US_POSIX")) != nil
                    }.prefix(100))
            }
            status =
                "Local read finished (up to 100 results). Provider coverage: \(snapshot.observation.completeness == .complete ? "complete local enumeration" : "incomplete or unknown"). This does not prove cloud freshness."
        } catch {
            if current() {
                results = []
                detail = nil
                status = "The read is unavailable."
            }
        }
    }
}

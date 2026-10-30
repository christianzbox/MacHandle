import CoreDomain
import Foundation
import Observation
import PermissionEngine

/// Trusted local opt-in UI only. Selection is not a grant to external clients.
@MainActor @Observable
public final class ContactsStore {
    public private(set) var isEnabled = false
    public private(set) var isBusy = false
    public private(set) var containers: [ContactContainer] = []
    public private(set) var selection: Set<ContactContainerReference> = []
    public private(set) var results: [Contact] = []
    public private(set) var detail: Contact?
    public private(set) var status = "Contacts access is off."
    public var query = "" { didSet { invalidate() } }
    public private(set) var fields: Set<ContactField> = [.name] { didSet { invalidate() } }
    @ObservationIgnored private let provider: any ContactReading & ContactDiscovering
    @ObservationIgnored private let authority = PolicyAuthority()
    @ObservationIgnored private var readTask: Task<ProviderReadResult<ContactSnapshot>, Never>?
    private var generation: UInt64 = 0
    public init(provider: any ContactReading & ContactDiscovering) { self.provider = provider }
    private func invalidate() {
        generation &+= 1
        readTask?.cancel()
        results = []
        detail = nil
    }
    public func setField(_ field: ContactField, enabled: Bool) {
        guard field != .name, ContactReadCapabilities.fields.contains(field) else { return }
        if enabled { fields.insert(field) } else { fields.remove(field) }
    }
    public func disable() {
        invalidate()
        isEnabled = false
        containers = []
        selection = []
        status = "Contacts access is off."
    }
    public func select(_ container: ContactContainerReference, selected: Bool) {
        guard isEnabled, !isBusy, containers.contains(where: { $0.id == container }) else { return }
        guard !selected || selection.contains(container) || selection.count < 32 else {
            status = "Select at most 32 containers."
            return
        }
        invalidate()
        if selected { selection.insert(container) } else { selection.remove(container) }
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
            containers = []
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
            containers = []
            selection = []
            status = "Contacts permission is unavailable. Review access in System Settings."
            return
        }
        let result = await provider.discoverContactContainers()
        let latest = await provider.authorization()
        guard current() else { return }
        guard latest == .fullAccess, case .observed(let inventory) = result,
            inventory.resources.count <= 1000,
            Set(inventory.resources.map(\.id)).count == inventory.resources.count
        else {
            containers = []
            selection = []
            status = "Contact containers could not be verified. Refresh to try again."
            return
        }
        containers = inventory.resources
        selection.formIntersection(containers.map(\.id))
        status = "Choose containers to read locally. External connections remain off."
    }
    public func search() async { await read(nil) }
    public func showDetails(_ reference: ContactRecordReference) async {
        guard results.contains(where: { $0.id == .record(reference) }) else { return }
        await read(reference)
    }
    private func read(_ item: ContactRecordReference?) async {
        guard isEnabled, !isBusy, !selection.isEmpty, query.utf8.count <= 256 else { return }
        let selected = item.map { Set([$0.container]) } ?? selection
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
                    containers = []
                    selection = []
                    status = "Contacts access is unavailable."
                }
                return
            }
            let fields: Set<ContactField> = item == nil ? [.name] : self.fields
            let operation: ContactOperation = item == nil ? .search : .readFields
            let id = try ConnectionID("local-contacts-ui")
            await authority.setConnection(
                Connection(id: id, kind: .localMCP, state: .enabled),
                policy: ConnectionPolicy(
                    contactContainers: Dictionary(
                        uniqueKeysWithValues: selected.map {
                            (
                                $0,
                                ContactGrant(
                                    selection: .allRecords,
                                    access: ResourceGrant(
                                        operations: [operation], readableFields: fields))
                            )
                        })))
            await authority.observeOSPermissions(OSPermissions(contacts: os))
            guard current() else { return }
            let session = try await authority.bindTrustedConnection(id)
            guard
                case .allowed(let permit) = await session.evaluate(
                    .contactRead(
                        ContactQuery(
                            containers: selected, operation: operation, fields: fields,
                            searchFields: item == nil ? [.name] : []))), current()
            else { return }
            let request = try ContactReadRequest(
                scopes: Dictionary(
                    uniqueKeysWithValues: selected.map { ($0, ContactReadScope.allRecords) }),
                item: item)
            let task = Task { [provider] in await provider.readContacts(request, fields: fields) }
            readTask = task
            let result = await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
            let latest = await provider.authorization()
            await authority.observeOSPermissions(OSPermissions(contacts: latest))
            guard current() else { return }
            guard latest == .fullAccess, case .observed(let snapshot) = result,
                snapshot.coverage == request,
                case .value(let filtered) = await session.filterContacts(
                    snapshot.contacts, using: permit), current()
            else {
                results = []
                detail = nil
                status = "The read could not be verified. No absence or deletion is inferred."
                return
            }
            if item != nil {
                detail = filtered.first
            } else {
                results = Array(
                    try filtered.filter {
                        try ContactSearch.matches($0, query: query, fields: [.name])
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

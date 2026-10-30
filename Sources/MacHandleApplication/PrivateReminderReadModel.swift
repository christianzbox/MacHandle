import CoreDomain
import Foundation
import NativeMCPBridge
import Observation

/// Native setup owns permission requests and selection. No external caller receives these methods.
@Observable @MainActor
public final class PrivateReminderReadModel {
    public enum Field: String, CaseIterable, Sendable {
        case title, completion, due, recurrence, notes
        var domain: ReminderReadField {
            switch self {
            case .title: .title
            case .completion: .completion
            case .due: .due
            case .recurrence: .recurrence
            case .notes: .notes
            }
        }
    }
    public let connection = PrivateConnectionModel()
    public let isolated: Bool
    public private(set) var enabled = false
    public private(set) var busy = false
    public private(set) var lists: [ReminderList] = []
    public private(set) var selected: Set<ReminderListReference> = []
    public private(set) var fields: Set<Field> = []
    public private(set) var status = "Access is off. Nothing is selected."
    @ObservationIgnored private let source: any ReminderDiscovering & ReminderReading
    @ObservationIgnored private var observer: Task<Void, Never>?
    private var generation = UUID()
    public init(source: any ReminderDiscovering & ReminderReading, isolated: Bool) {
        self.source = source
        self.isolated = isolated
    }
    public static func sample() throws -> PrivateReminderReadModel {
        PrivateReminderReadModel(source: try PrivateSampleBridge.sampleSource(), isolated: false)
    }
    public static func validPackage(isolated: Bool) -> Bool {
        PrivateSampleBridge.validSelectedPackage(isolated: isolated)
    }
    public var canConnect: Bool {
        enabled && !busy && !selected.isEmpty && !fields.isEmpty && connection.phase == .idle
    }
    public func select(_ reference: ReminderListReference, enabled: Bool) {
        guard self.enabled, !busy, connection.phase == .idle,
            lists.contains(where: { $0.id == reference }), !enabled || selected.count < 32
        else { return }
        if enabled { selected.insert(reference) } else { selected.remove(reference) }
    }
    public func select(_ field: Field, enabled: Bool) {
        guard self.enabled, !busy, connection.phase == .idle else { return }
        if enabled { fields.insert(field) } else { fields.remove(field) }
    }
    /// The isolation acknowledgement is an operator prerequisite, never proof of OS isolation.
    public func enable(isolationAcknowledged: Bool = false) async {
        guard !enabled, !busy, connection.phase == .idle, !isolated || isolationAcknowledged else {
            return
        }
        busy = true
        let expected = generation
        defer {
            busy = false
            if !enabled {
                observer?.cancel()
                observer = nil
            }
        }
        var permission = await source.authorization()
        guard expected == generation, !Task.isCancelled else { return }
        if permission == .notDetermined { permission = await source.requestAccess() }
        guard expected == generation, !Task.isCancelled else { return }
        guard permission == .fullAccess else {
            status = "Reminders permission unavailable. No lists or reads are exposed."
            return
        }
        let stream = await source.changes()
        guard expected == generation, !Task.isCancelled else { return }
        observer = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.stop()
                return
            }
        }
        let result = await source.discoverReminderLists()
        let latest = await source.authorization()
        guard expected == generation, !Task.isCancelled else { return }
        guard latest == .fullAccess, case .observed(let inventory) = result,
            inventory.observation.completeness == .complete, inventory.resources.count <= 1000,
            Set(inventory.resources.map(\.id)).count == inventory.resources.count
        else {
            observer?.cancel()
            observer = nil
            status = "List discovery incomplete or unavailable. No selection was granted."
            return
        }
        lists = inventory.resources
        enabled = true
        status =
            "Choose lists and fields, then start the helper connection. Writes are unavailable."
    }
    func prepareSelection() async throws -> PrivateReminderSelection {
        guard canConnect else { throw ProviderFailure.denied }
        busy = true
        defer { busy = false }
        let expected = generation
        let selection = try PrivateReminderSelection(
            lists: selected, fields: Set(fields.map(\.domain)))
        let reader = SelectedReminderReader(source: source, selection: selection)
        guard case .observed = await reader.discoverReminderLists(), expected == generation,
            enabled, !Task.isCancelled
        else { throw ProviderFailure.unavailable }
        return selection
    }
    public func connect() async {
        do {
            let selection = try await prepareSelection()
            connection.start(source: source, selection: selection, isolated: isolated)
            status =
                "Selection locked for this launch. Approve the helper separately in this window."
        } catch {
            await stop()
        }
    }
    public func refreshAuthorization() async {
        guard enabled else { return }
        let expected = generation
        let access = await source.authorization()
        guard expected == generation, enabled else { return }
        if access != .fullAccess { await stop() }
    }
    public func stop() async {
        generation = UUID()
        observer?.cancel()
        observer = nil
        enabled = false
        lists = []
        selected = []
        fields = []
        status = "Access closed. Relaunch to discover and select again."
        await connection.stop()
    }
    deinit { observer?.cancel() }
}

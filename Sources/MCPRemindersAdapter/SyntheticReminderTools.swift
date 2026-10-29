import ActionApprovals
import CoreDomain
import Foundation
import MCPConnections
import MCPServer
import PermissionEngine

package enum SyntheticReminderTools {
    package static func make() async throws -> [MCPTool] {
        let reads = try await SyntheticReminderFixture.make().adapter.tools()
        let seed = try await SyntheticReminderActionFixture.make()
        let engine = ReminderApprovalEngine(
            session: seed.session, provider: seed.provider, authorized: { true })
        let mutations = ReminderMutationAdapter(
            engine: engine,
            resolve: { token, create in
                guard token == (create ? "sample-list" : "sample-reminder") else {
                    throw ReminderReadFailure.unavailable
                }
                return (seed.list, create ? nil : seed.reminder.id)
            }, authorized: { true })
        return reads + mutations.tools()
    }
}
struct SyntheticReminderFixture {
    let controller: ConnectionController
    let record: SavedConnection
    let lease: ConnectionReadLease
    let source: SyntheticReminderSource
    let adapter: ReminderReadAdapter
    static func make(fields: [SavedReminderGrant.Field] = [.title, .due, .completion, .recurrence])
        async throws -> Self
    {
        let source = try SyntheticReminderSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: source.list, operations: [.discover, .summary, .details], fields: fields)
        let record = try await controller.configure(
            label: "Synthetic Reminders reader", grants: [], reminderGrants: [grant])
        // Explicit fixture only; no live peer claim.
        let channel = ConnectionChannel(verify: { true })
        let pending = try await controller.requestPairing(channel)
        let review = try await controller.review(pending, connection: record.id)
        let lease = try await controller.approve(review)
        let adapter = try ReminderReadAdapter(
            lease: lease, reader: source, authorization: { .fullAccess })
        return Self(
            controller: controller, record: record, lease: lease, source: source, adapter: adapter)
    }
}
struct SyntheticReminderSource: ReminderReading, ReminderDiscovering {
    let list: ReminderListReference
    let hidden: ReminderListReference
    let reminder: Reminder
    let observation: ObservationState
    init() throws {
        let account = try AccountReference(
            provider: ProviderID("synthetic-private"), store: StoreID("synthetic-private"),
            account: AccountID("synthetic-private"))
        list = try ReminderListReference(
            account: account, localID: DomainID("synthetic-list-private"))
        hidden = try ReminderListReference(
            account: account, localID: DomainID("synthetic-hidden-private"))
        reminder = try Reminder(
            id: ReminderReference(list: list, item: ReminderID("synthetic-reminder-private")),
            title: .value("Synthetic grocery reminder"),
            notes: .value("synthetic-hidden-reminder-canary"),
            due: .value(.date(LocalDate(year: 2027, month: 1, day: 15))),
            completion: .value(.incomplete), recurrence: .value(.notRecurring))
        observation = ObservationState(
            observedAt: try Instant(Date(timeIntervalSince1970: 1_800_000_000)),
            completeness: .complete, freshness: .localCache)
    }
    func authorization() -> OSAuthorization { .fullAccess }
    func requestAccess() -> OSAuthorization { .fullAccess }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverReminderLists() -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        .observed(
            ResourceDiscovery(
                resources: [
                    ReminderList(id: list, name: "Synthetic selected list"),
                    ReminderList(id: hidden, name: "Hidden list"),
                ], observation: observation))
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>)
        -> ProviderReadResult<ReminderSnapshot>
    {
        do {
            // Deliberate over-return of hidden fields tests independent projection.
            return .observed(
                try ReminderSnapshot(
                    coverage: request,
                    reminders: request.lists.contains(list)
                        && (request.item == nil || request.item == reminder.id) ? [reminder] : [],
                    observation: observation))
        } catch { return .failed(.invalidData) }
    }
}

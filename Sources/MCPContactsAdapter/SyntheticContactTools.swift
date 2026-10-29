import CoreDomain
import Foundation
import MCPConnections
import MCPServer
import PermissionEngine

package enum SyntheticContactTools {
    package static func make() async throws -> [MCPTool] {
        try await SyntheticContactFixture.make().adapter.tools()
    }
}
struct SyntheticContactFixture {
    let controller: ConnectionController
    let record: SavedConnection
    let lease: ConnectionReadLease
    let source: SyntheticContactSource
    let adapter: ContactReadAdapter
    static func make(
        fields: [SavedContactGrant.Field] = [.name, .organization], subset: Bool = false
    ) async throws -> Self {
        let source = try SyntheticContactSource()
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(contacts: .fullAccess))
        let grant = try SavedContactGrant(
            reference: source.container,
            selection: subset ? .records([source.ref.item]) : .allRecords,
            operations: [.discover, .search, .details], fields: fields)
        let record = try await controller.configure(
            label: "Synthetic Contacts reader", grants: [], contactGrants: [grant])
        let channel = ConnectionChannel(verify: { true })
        let pending = try await controller.requestPairing(channel)
        let review = try await controller.review(pending, connection: record.id)
        let lease = try await controller.approve(review)
        return Self(
            controller: controller, record: record, lease: lease, source: source,
            adapter: try ContactReadAdapter(
                lease: lease, reader: source, authorization: { .fullAccess }))
    }
}
struct SyntheticContactSource: ContactReading, ContactDiscovering {
    let container: ContactContainerReference
    let hidden: ContactContainerReference
    let ref: ContactRecordReference
    let contact: Contact
    let observation: ObservationState
    init() throws {
        let account = try AccountReference(
            provider: ProviderID("synthetic-private"), store: StoreID("synthetic-private"),
            account: AccountID("synthetic-private"))
        container = try ContactContainerReference(
            account: account, localID: DomainID("synthetic-container-private"))
        hidden = try ContactContainerReference(
            account: account, localID: DomainID("synthetic-hidden-private"))
        ref = try ContactRecordReference(
            container: container, item: ContactID("synthetic-contact-private"))
        contact = Contact(
            id: .record(ref), linkedRecords: .value([ref]),
            name: .value(ContactName(given: "Synthetic Ada", family: "Example")),
            emailAddresses: .value([
                LabeledValue(
                    label: "Sample", value: "synthetic-hidden-contact-canary@example.invalid")
            ]),
            phoneNumbers: .value([]), postalAddresses: .value([]),
            organization: .value("Sample organization"),
            notes: .value("synthetic-hidden-contact-notes"))
        observation = ObservationState(
            observedAt: try Instant(Date(timeIntervalSince1970: 1_800_000_000)),
            completeness: .complete, freshness: .localCache)
    }
    func authorization() -> OSAuthorization { .fullAccess }
    func requestAccess() -> OSAuthorization { .fullAccess }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverContactContainers() -> ProviderReadResult<ResourceDiscovery<ContactContainer>> {
        .observed(
            ResourceDiscovery(
                resources: [
                    ContactContainer(id: container, name: "Synthetic selected container"),
                    ContactContainer(id: hidden, name: "Hidden container"),
                ], observation: observation))
    }
    func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>)
        -> ProviderReadResult<ContactSnapshot>
    {
        do {
            return .observed(
                try ContactSnapshot(
                    coverage: request, contacts: request.contains(ref) ? [contact] : [],
                    observation: observation))
        } catch { return .failed(.invalidData) }
    }
}

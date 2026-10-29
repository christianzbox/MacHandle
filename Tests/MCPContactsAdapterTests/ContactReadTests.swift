import CoreDomain
import Foundation
import MCPConnections
import PermissionEngine
import Testing

@testable import MCPContactsAdapter
@testable import MCPServer

private actor Gate {
    var entered = false
    var waiting: CheckedContinuation<Void, Never>?
    var held: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiting?.resume()
        waiting = nil
        await withCheckedContinuation { held = $0 }
    }
    func wait() async { if !entered { await withCheckedContinuation { waiting = $0 } } }
    func release() {
        held?.resume()
        held = nil
    }
}
private actor Source: ContactReading, ContactDiscovering {
    let base: SyntheticContactSource
    var gate: Gate?
    var empty = false
    var partial = false
    var access: OSAuthorization = .fullAccess
    var reads = 0
    var cancelled = false
    var fetched: Set<ContactField> = []
    init(_ base: SyntheticContactSource) { self.base = base }
    func configure(
        gate: Gate? = nil, empty: Bool = false, partial: Bool = false,
        access: OSAuthorization = .fullAccess
    ) {
        self.gate = gate
        self.empty = empty
        self.partial = partial
        self.access = access
    }
    func authorization() -> OSAuthorization { access }
    func requestAccess() -> OSAuthorization { access }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func discoverContactContainers() async -> ProviderReadResult<
        ResourceDiscovery<ContactContainer>
    > {
        base.discoverContactContainers()
    }
    func readContacts(_ request: ContactReadRequest, fields: Set<ContactField>) async
        -> ProviderReadResult<ContactSnapshot>
    {
        reads += 1
        fetched = fields
        if let gate { await gate.enter() }
        cancelled = Task.isCancelled
        do {
            return .observed(
                try ContactSnapshot(
                    coverage: request, contacts: empty ? [] : [base.contact],
                    observation: ObservationState(
                        observedAt: base.observation.observedAt,
                        completeness: partial ? .partial(.providerLimit) : .complete,
                        freshness: .localCache)))
        } catch { return .failed(.invalidData) }
    }
}
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 0
    func now() -> TimeInterval { lock.withLock { time } }
    func expire() { lock.withLock { time += 301 } }
}
private func args(
    _ adapter: ContactReadAdapter, query: String = "Ada", fields: [String] = ["name"]
) async throws -> [String: MCPJSON] {
    let result = try await adapter.discover()
    let id = try #require(result.value["containers"]?.array?.first?["containerId"]?.string)
    return [
        "containerIds": .array([.string(id)]), "query": .string(query),
        "fields": .array(fields.map(MCPJSON.string)), "searchFields": .array([.string("name")]),
        "limit": .number(10),
    ]
}
private func token(_ result: MCPToolResult) throws -> String {
    try #require(result.value["contacts"]?.array?.first?["contactId"]?.string)
}
struct ContactReadTests {
    @Test func scopedDiscoverySearchAndDetailDoNotExportHiddenFieldsOrIdentity() async throws {
        let f = try await SyntheticContactFixture.make(subset: true)
        let search = try await f.adapter.search(args(f.adapter))
        #expect(search.value["contacts"]?.array?.count == 1)
        let detail = try await f.adapter.detail([
            "contactId": .string(token(search)), "fields": .array([.string("organization")]),
        ])
        #expect(detail.value["contact"]?["fields"]?.object?.keys.sorted() == ["organization"])
        for result in [try await f.adapter.discover(), search, detail] {
            let text = String(decoding: try result.value.encoded(), as: UTF8.self)
            #expect(
                !text.contains("private") && !text.contains("canary")
                    && !text.contains("linkedRecords") && !text.contains("notes"))
        }
    }
    @Test func fieldSearchPermissionIsCheckedBeforeFetchAndHiddenEmailCannotMatch() async throws {
        let f = try await SyntheticContactFixture.make()
        let source = Source(f.source)
        let adapter = try ContactReadAdapter(
            lease: f.lease, reader: source, authorization: { .fullAccess })
        var input = try await args(adapter)
        input["searchFields"] = .array([.string("emailAddresses")])
        input["fields"] = .array([.string("name"), .string("emailAddresses")])
        await #expect(throws: (any Error).self) { try await adapter.search(input) }
        #expect(await source.reads == 0)
        let hidden = try await adapter.search(
            args(adapter, query: "synthetic-hidden-contact-canary"))
        #expect(hidden.value["contacts"]?.array?.isEmpty == true)
        #expect(await source.fetched == [.name])
    }
    @Test func foreignHandlesAndUnprovenOrDeniedOSCannotRead() async throws {
        let f = try await SyntheticContactFixture.make()
        let other = try await SyntheticContactFixture.make()
        let id = try token(await f.adapter.search(args(f.adapter)))
        await #expect(throws: (any Error).self) {
            try await other.adapter.detail([
                "contactId": .string(id), "fields": .array([.string("name")]),
            ])
        }
        for access in [OSAuthorization.denied, .notDetermined, .unknown] {
            let adapter = try ContactReadAdapter(
                lease: f.lease, reader: f.source, authorization: { access })
            await #expect(throws: (any Error).self) { try await adapter.discover() }
        }
        let closed = try ContactReadAdapter(lease: f.lease, reader: f.source)
        await #expect(throws: (any Error).self) { try await closed.discover() }
    }
    @Test func partialAndMissingContactsNeverClaimDeletionOrUpstreamFreshness() async throws {
        let f = try await SyntheticContactFixture.make()
        let source = Source(f.source)
        let adapter = try ContactReadAdapter(
            lease: f.lease, reader: source, authorization: { .fullAccess })
        await source.configure(partial: true)
        let search = try await adapter.search(args(adapter))
        #expect(search.value["observation"]?["completeness"]?.string == "partial")
        await source.configure(empty: true)
        let detail = try await adapter.detail([
            "contactId": .string(token(search)), "fields": .array([.string("name")]),
        ])
        #expect(detail.value["status"]?.string == "notObserved")
        #expect(detail.value["absenceProvesDeletion"] == .bool(false))
        #expect(detail.value["observation"]?["freshness"]?.string == "localCache")
    }
    @Test func queuedContactOutputRechecksLeaseAndHandleExpiry() async throws {
        for revoke in [false, true] {
            let f = try await SyntheticContactFixture.make()
            let clock = Clock()
            let adapter = try ContactReadAdapter(
                lease: f.lease, reader: f.source, authorization: { .fullAccess },
                uptime: { clock.now() })
            let search = try await adapter.search(args(adapter))
            let detail = try await adapter.detail([
                "contactId": .string(token(search)), "fields": .array([.string("name")]),
            ])
            if revoke { try await f.controller.revoke(f.record.id) } else { clock.expire() }
            await #expect(throws: (any Error).self) { try await detail.validate() }
        }
    }
    @Test func revocationCancelsInFlightContactToolAndSuppressesLateResults() async throws {
        let f = try await SyntheticContactFixture.make()
        let source = Source(f.source)
        let gate = Gate()
        let adapter = try ContactReadAdapter(
            lease: f.lease, reader: source, authorization: { .fullAccess })
        let input = try await args(adapter)
        let tool = try #require(adapter.tools().first { $0.name == "search_contacts" })
        await source.configure(gate: gate)
        let task = Task { try await tool.execute(input) }
        await gate.wait()
        try await f.controller.revoke(f.record.id)
        await gate.release()
        await #expect(throws: (any Error).self) { try await task.value }
        #expect(await source.cancelled)
    }
    @Test func currentOSIsCheckedAfterFetchAndUnsupportedNotesAreDenied() async throws {
        let f = try await SyntheticContactFixture.make()
        let source = Source(f.source)
        let gate = Gate()
        let adapter = try ContactReadAdapter(
            lease: f.lease, reader: source, authorization: { await source.authorization() })
        let input = try await args(adapter)
        await source.configure(gate: gate)
        let task = Task { try await adapter.search(input) }
        await gate.wait()
        await source.configure(access: .denied)
        await gate.release()
        await #expect(throws: (any Error).self) { try await task.value }
        let search = try await f.adapter.search(args(f.adapter))
        await #expect(throws: (any Error).self) {
            try await f.adapter.detail([
                "contactId": .string(token(search)), "fields": .array([.string("notes")]),
            ])
        }
    }
}

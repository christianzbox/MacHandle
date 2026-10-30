import CoreDomain
import Foundation
import NativeMCPBridge
import Testing

@testable import MacHandleApplication

private actor SelectionSource: ReminderDiscovering, ReminderReading {
    let fixture: any ReminderDiscovering & ReminderReading
    var access: OSAuthorization = .notDetermined
    var requested: OSAuthorization = .fullAccess
    var requests = 0
    var discoveries = 0
    var reads = 0
    var incomplete = false
    var removed = false
    var pause = false
    var entered = false
    let changeStream = AsyncStream<Void>.makeStream()
    var suspended: CheckedContinuation<Void, Never>?
    init() throws { fixture = try PrivateSampleBridge.sampleSource() }
    func configure(
        access: OSAuthorization = .fullAccess, incomplete: Bool = false, removed: Bool = false,
        pause: Bool = false
    ) {
        self.access = access
        self.incomplete = incomplete
        self.removed = removed
        self.pause = pause
    }
    func denyRequest() { requested = .denied }
    func authorization() -> OSAuthorization { access }
    func requestAccess() -> OSAuthorization {
        requests += 1
        access = requested
        return access
    }
    func changes() -> AsyncStream<Void> { changeStream.stream }
    func change() { changeStream.continuation.yield(()) }
    func discoverReminderLists() async -> ProviderReadResult<ResourceDiscovery<ReminderList>> {
        discoveries += 1
        if pause {
            entered = true
            await withCheckedContinuation { suspended = $0 }
        }
        guard case .observed(let value) = await fixture.discoverReminderLists() else {
            return .failed(.unavailable)
        }
        return .observed(
            ResourceDiscovery(
                resources: removed ? [] : value.resources,
                observation: ObservationState(
                    observedAt: value.observation.observedAt,
                    completeness: incomplete ? .unknown : .complete, freshness: .localCache)))
    }
    func release() {
        suspended?.resume()
        suspended = nil
    }
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
    {
        reads += 1
        return await fixture.readReminders(request, fields: fields)
    }
}

@MainActor struct PrivateReminderReadTests {
    @Test func isolatedOptInIsRequiredAndSelectionIsNeverImplicit() async throws {
        let source = try SelectionSource()
        let model = PrivateReminderReadModel(source: source, isolated: true)
        await model.enable()
        #expect(await source.requests == 0)
        #expect(await source.discoveries == 0)
        await model.enable(isolationAcknowledged: true)
        #expect(await source.requests == 1)
        #expect(model.lists.count == 2 && model.selected.isEmpty && model.fields.isEmpty)
        await #expect(throws: (any Error).self) { try await model.prepareSelection() }
        let list = try #require(model.lists.first)
        model.select(list.id, enabled: true)
        await #expect(throws: (any Error).self) { try await model.prepareSelection() }
        model.select(.title, enabled: true)
        let selection = try await model.prepareSelection()
        #expect(selection.lists == [list.id] && selection.fields == [.title])
        #expect(await source.reads == 0)
        await model.stop()
        #expect(model.lists.isEmpty && model.fields.isEmpty && model.selected.isEmpty)
    }
    @Test func deniedRequestAndIncompleteDiscoveryCannotPrepareAConnection() async throws {
        let denied = try SelectionSource()
        await denied.denyRequest()
        let model = PrivateReminderReadModel(source: denied, isolated: false)
        await model.enable()
        #expect(!model.enabled && model.lists.isEmpty)
        #expect(await denied.discoveries == 0)
        let partial = try SelectionSource()
        await partial.configure(incomplete: true)
        let other = PrivateReminderReadModel(source: partial, isolated: false)
        await other.enable()
        #expect(!other.enabled && other.lists.isEmpty && !other.canConnect)
    }
    @Test func removedSelectionAndPermissionLossDenyConnectionPreparation() async throws {
        let source = try SelectionSource()
        let model = PrivateReminderReadModel(source: source, isolated: false)
        await model.enable()
        model.select(try #require(model.lists.first).id, enabled: true)
        model.select(.completion, enabled: true)
        await source.configure(removed: true)
        await #expect(throws: (any Error).self) { try await model.prepareSelection() }
        await source.configure(access: .denied)
        await #expect(throws: (any Error).self) { try await model.prepareSelection() }
        #expect(await source.reads == 0)
    }
    @Test func stopDuringDiscoveryCannotRestoreListsOrGrant() async throws {
        let source = try SelectionSource()
        await source.configure(pause: true)
        let model = PrivateReminderReadModel(source: source, isolated: false)
        let task = Task { await model.enable() }
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await source.entered) && ContinuousClock.now < deadline { await Task.yield() }
        #expect(await source.entered)
        await model.stop()
        await source.release()
        await task.value
        #expect(!model.enabled && model.lists.isEmpty && !model.canConnect)
        #expect(model.connection.phase == .closed)
    }
    @Test func nativePermissionRefreshAndStoreChangeClearSelection() async throws {
        for revoke in [true, false] {
            let source = try SelectionSource()
            let model = PrivateReminderReadModel(source: source, isolated: false)
            await model.enable()
            model.select(try #require(model.lists.first).id, enabled: true)
            model.select(.title, enabled: true)
            if revoke {
                await source.configure(access: .denied)
                await model.refreshAuthorization()
            } else {
                await source.change()
                let deadline = ContinuousClock.now + .seconds(3)
                while model.enabled && ContinuousClock.now < deadline { await Task.yield() }
            }
            #expect(!model.enabled && model.selected.isEmpty && model.fields.isEmpty)
            #expect(model.connection.phase == .closed)
        }
    }

}

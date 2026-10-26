import CoreDomain
import Foundation
import MacHandleApplication
import PermissionEngine
import Testing

private actor RecordingEvaluator: PreviewEvaluating {
    var calls = 0
    func evaluate(_ configuration: PreviewConfiguration) -> PreviewOutcome {
        calls += 1
        return .allowed
    }
}

private actor SuspendedEvaluator: PreviewEvaluating {
    private var started = false
    private var calls = 0
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var resultWaiter: CheckedContinuation<PreviewOutcome, Never>?
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func evaluate(_ configuration: PreviewConfiguration) async -> PreviewOutcome {
        calls += 1
        if calls == 1 { return .allowed }
        started = true
        startWaiter?.resume()
        startWaiter = nil
        return await withCheckedContinuation { resultWaiter = $0 }
    }
    func finish() {
        resultWaiter?.resume(returning: .allowed)
        resultWaiter = nil
    }
}

private func service() -> PreviewPolicyService {
    PreviewPolicyService(google: PolicyAuthority(), localMCP: PolicyAuthority())
}

private func sampleRequest(_ calendars: [String], details: Bool = false) throws -> PolicyRequest {
    let account = try AccountReference(
        provider: ProviderID("synthetic"), store: StoreID("preview-store"),
        account: AccountID("preview-account"))
    let refs = try Set(
        calendars.map { try CalendarReference(account: account, localID: DomainID($0)) })
    let window = try InstantInterval(
        start: Instant(Date(timeIntervalSince1970: 0)),
        end: Instant(Date(timeIntervalSince1970: 3600)))
    return .calendarRead(
        try CalendarReadRequest(calendars: refs, window: window),
        operation: details ? .readDetails : .checkAvailability,
        fields: details
            ? [.time, .occupancy, .status, .title, .location, .notes] : [.time, .occupancy])
}

@Test @MainActor func startupIsDisabledAndDoesNotEvaluateOrPersistConnections() async {
    let evaluator = RecordingEvaluator()
    let store = ConnectionPreviewStore(evaluator: evaluator)
    #expect(
        store.previews.allSatisfy {
            $0.configuration.state == .disabled && $0.configuration.calendars.isEmpty
        })
    #expect(store.enabledPreviewCount == 0)
    #expect(await evaluator.calls == 0)
    await store.apply(.init(connection: .google, state: .enabled, calendars: [.personal]))
    let fresh = ConnectionPreviewStore(evaluator: evaluator)
    #expect(fresh.enabledPreviewCount == 0)
    #expect(fresh.activity.isEmpty)
    #expect(await evaluator.calls == 1)
}

@Test @MainActor func configurationUpdatesRemoveOldAllowAndRejectOverlappingActions() async {
    let evaluator = SuspendedEvaluator()
    let store = ConnectionPreviewStore(evaluator: evaluator)
    await store.apply(.init(connection: .google, state: .enabled, calendars: [.personal]))
    #expect(store.previews.first?.outcome == .allowed)
    let first = Task {
        await store.apply(.init(connection: .google, state: .enabled, calendars: [.work]))
    }
    await evaluator.waitUntilStarted()
    #expect(store.isUpdating)
    #expect(store.previews.first?.outcome == nil)
    let second = await store.apply(.init(connection: .google, state: .revoked))
    #expect(!second)
    #expect(store.previews.first?.configuration.state == .enabled)
    await evaluator.finish()
    #expect(await first.value)
    #expect(!store.isUpdating)
    #expect(store.activity.count == 2)
}

@Test func allSampleStatesHaveExplicitOutcomesWithoutAccounts() async {
    let evaluator = service()
    let cases: [(PreviewState, PreviewOutcome)] = [
        (.disabled, .disabled), (.unconfigured, .unconfigured), (.denied, .denied),
        (.unavailable, .unavailable), (.revoked, .revoked), (.enabled, .allowed),
    ]
    for (state, outcome) in cases {
        #expect(
            await evaluator.evaluate(
                .init(connection: .localMCP, state: state, calendars: [.personal])) == outcome)
    }
    #expect(await evaluator.evaluate(.init(connection: .localMCP, state: .enabled)) == .noSelection)
}

@Test func changedPreviewInvalidatesOldReceiptAndBindsCurrentPolicy() async throws {
    let google = PolicyAuthority()
    let evaluator = PreviewPolicyService(google: google, localMCP: PolicyAuthority())
    #expect(
        await evaluator.evaluate(
            .init(connection: .google, state: .enabled, calendars: [.personal])) == .allowed)
    let id = try ConnectionID("preview-google")
    let old = try await google.bindTrustedConnection(id)
    guard case .allowed(let receipt) = await old.evaluate(try sampleRequest(["personal"])) else {
        Issue.record("Expected initial synthetic allow")
        return
    }
    #expect(
        await evaluator.evaluate(
            .init(connection: .google, state: .enabled, calendars: [.work], access: .details))
            == .allowed)
    guard case .denied(.staleContext) = await old.revalidate(receipt) else {
        Issue.record("Preview retained a stale receipt")
        return
    }
    let fresh = try await google.bindTrustedConnection(id)
    guard case .denied(.resourceNotSelected) = await fresh.evaluate(try sampleRequest(["personal"]))
    else {
        Issue.record("Removed sample calendar remained selected")
        return
    }
    guard case .allowed = await fresh.evaluate(try sampleRequest(["work"], details: true)) else {
        Issue.record("Updated preview was not rebound to current policy")
        return
    }
    #expect(await evaluator.evaluate(.init(connection: .google, state: .revoked)) == .revoked)
    guard case .denied(.revoked) = await fresh.evaluate(try sampleRequest(["work"], details: true))
    else {
        Issue.record("Preview revocation did not reach policy authority")
        return
    }
}

@Test func deniedSimulationAndConnectionIsolationReachPolicyEngine() async throws {
    let google = PolicyAuthority()
    let local = PolicyAuthority()
    let evaluator = PreviewPolicyService(google: google, localMCP: local)
    #expect(
        await evaluator.evaluate(
            .init(connection: .google, state: .enabled, calendars: [.personal])) == .allowed)
    #expect(
        await evaluator.evaluate(
            .init(connection: .localMCP, state: .denied, calendars: [.personal])) == .denied)
    let denied = try await local.bindTrustedConnection(ConnectionID("preview-localMCP"))
    guard case .denied(.osDenied) = await denied.evaluate(try sampleRequest(["personal"])) else {
        Issue.record("Denied preview did not configure a denied observation")
        return
    }
    let unaffected = try await google.bindTrustedConnection(ConnectionID("preview-google"))
    guard case .allowed = await unaffected.evaluate(try sampleRequest(["personal"])) else {
        Issue.record("One sample scenario changed another sample's policy")
        return
    }
}

@Test func previewsNeverGrantWritesEvenWhenDetailReadsAreEnabled() async throws {
    let local = PolicyAuthority()
    let evaluator = PreviewPolicyService(google: PolicyAuthority(), localMCP: local)
    #expect(
        await evaluator.evaluate(
            .init(connection: .localMCP, state: .enabled, calendars: [.personal], access: .details))
            == .allowed)
    let connection = try ConnectionID("preview-localMCP")
    let session = try await local.bindTrustedConnection(connection)
    guard case .calendarRead(let request, _, _) = try sampleRequest(["personal"]) else { return }
    let target = try #require(request.calendars.first)
    let draft = try EventDraft(
        title: "Synthetic event", time: .timed(request.window, timeZone: TimeZoneID("UTC")),
        occupancy: .busy)
    let proposal = try ProposedChange(
        id: OperationID("sample-write"), connection: connection,
        change: CalendarMutation.create(in: target, event: draft))
    guard case .denied(.operationNotAllowed) = await session.evaluate(.calendarMutation(proposal))
    else {
        Issue.record("UI preview unexpectedly granted a write")
        return
    }
}

@Test @MainActor func historyIsBoundedAndClearingDoesNotChangePermissions() async {
    let store = ConnectionPreviewStore(evaluator: service())
    for _ in 0..<25 {
        await store.apply(.init(connection: .google, state: .enabled, calendars: [.personal]))
    }
    #expect(store.activity.count == 20)
    #expect(store.activity.first?.id == 25)
    let configuration = store.previews.first?.configuration
    store.clearActivity()
    #expect(store.activity.isEmpty)
    #expect(store.previews.first?.configuration == configuration)
    #expect(store.previews.first?.outcome == .allowed)
}

@Test @MainActor func navigationAndAppearanceDoNotEnableConnections() async {
    let evaluator = RecordingEvaluator()
    let state = ApplicationState(
        connections: ConnectionPreviewStore(evaluator: evaluator),
        calendars: CalendarAccessStore(provider: CalendarProviderStub()))
    state.showConnection(.localMCP)
    state.appearance = .dark
    state.section = .diagnostics
    #expect(state.connections.enabledPreviewCount == 0)
    #expect(await evaluator.calls == 0)
}

import Foundation
import Testing

@testable import GoogleAuthorization

private final class CalendarCredentials: GoogleCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: GoogleCredential?
    init() throws { value = try credential() }
    func load() -> GoogleCredential? { lock.withLock { value } }
    func save(_ value: GoogleCredential) { lock.withLock { self.value = value } }
    func delete() { lock.withLock { value = nil } }
}
private actor CalendarTokens: GoogleTokenExchanging, GoogleBrowserAuthorizing {
    private(set) var refreshes = 0
    var wait = false
    var started = false
    var releaseWaiter: CheckedContinuation<Void, Never>?
    var startWaiter: CheckedContinuation<Void, Never>?
    func suspend() { wait = true }
    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
    func refresh(_ credential: GoogleCredential) async throws -> GoogleCredential {
        refreshes += 1
        started = true
        startWaiter?.resume()
        startWaiter = nil
        if wait { await withCheckedContinuation { releaseWaiter = $0 } }
        return GoogleCredential(
            version: 1, clientID: credential.clientID, accessToken: "synthetic-fresh-access",
            refreshToken: "synthetic-fresh-refresh",
            expiresAt: syntheticNow.addingTimeInterval(3600), scope: GoogleOAuthConfiguration.scope)
    }
    func exchange(code: String, verifier: String, redirect: URL) throws -> GoogleCredential {
        try credential()
    }
    func revoke(_ token: String) {}
    func authorize(configuration: GoogleOAuthConfiguration, attempt: OAuthAttempt) -> (
        code: String, redirect: URL
    ) {
        ("synthetic-code", redirect)
    }
}
private actor CalendarHTTP: OAuthHTTPSending {
    private(set) var requests: [URLRequest] = []
    var wait = false
    var status = 200
    var started = false
    var releaseWaiter: CheckedContinuation<Void, Never>?
    var startWaiter: CheckedContinuation<Void, Never>?
    func configure(wait: Bool = false, status: Int = 200) {
        self.wait = wait
        self.status = status
    }
    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
    func send(_ request: URLRequest) async -> OAuthHTTPResponse {
        requests.append(request)
        started = true
        startWaiter?.resume()
        startWaiter = nil
        // Intentionally ignores cancellation to prove the post-response generation fence.
        if wait { await withCheckedContinuation { releaseWaiter = $0 } }
        return .init(status: status, data: Data("{}".utf8))
    }
}
private func calendarAuth() throws -> (
    GoogleAuthentication, CalendarCredentials, CalendarTokens, CalendarHTTP
) {
    let store = try CalendarCredentials()
    let tokens = CalendarTokens()
    let http = CalendarHTTP()
    let auth = try GoogleAuthentication(
        configuration: config(), credentials: store, tokens: tokens,
        browser: tokens, now: { syntheticNow }, calendarHTTP: http)
    return (auth, store, tokens, http)
}

@Test func calendarRequestsRequireExplicitConnectAndKeepCredentialsInsideTransport() async throws {
    let (auth, _, _, http) = try calendarAuth()
    await #expect(throws: GoogleDestinationFailure.authorization) { try await auth.calendarLease() }
    #expect(await http.requests.isEmpty)
    await auth.connect()
    let lease = try await auth.calendarLease()
    let request = try GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination")
    _ = try await auth.sendCalendar(request, lease: lease)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(
        await http.requests.first?.value(forHTTPHeaderField: "Authorization")
            == "Bearer synthetic-access")
    var foreign = URLRequest(url: URL(string: "https://example.invalid/calendar/v3/calendars")!)
    foreign.httpMethod = "GET"
    await #expect(throws: GoogleDestinationFailure.authorization) {
        try await auth.sendCalendar(foreign, lease: lease)
    }
    #expect(await http.requests.count == 1)
}

@Test func concurrentCalendarRequestsUseOnePersistedRefresh() async throws {
    let (auth, store, tokens, http) = try calendarAuth()
    await auth.connect()
    let lease = try await auth.calendarLease()
    store.save(try credential(expired: true))
    await tokens.suspend()
    let request = try GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination")
    let first = Task { try await auth.sendCalendar(request, lease: lease) }
    await tokens.waitForStart()
    let second = Task { try await auth.sendCalendar(request, lease: lease) }
    await tokens.release()
    _ = try await first.value
    _ = try await second.value
    #expect(await tokens.refreshes == 1)
    #expect(store.load()?.refreshToken == "synthetic-fresh-refresh")
    #expect(await http.requests.count == 2)
    #expect(
        await http.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-fresh-access"
        })
}

@Test func disconnectDiscardsLateCalendarResponseAndRejectsOldLeaseAfterReconnect() async throws {
    let (auth, _, _, http) = try calendarAuth()
    await auth.connect()
    let lease = try await auth.calendarLease()
    let request = try GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination")
    await http.configure(wait: true)
    let pending = Task { try await auth.sendCalendar(request, lease: lease) }
    await http.waitForStart()
    await auth.disconnect()
    await http.release()
    await #expect(throws: GoogleDestinationFailure.authorization) { try await pending.value }
    await auth.connect()
    await #expect(throws: GoogleDestinationFailure.authorization) {
        try await auth.sendCalendar(request, lease: lease)
    }
    #expect(await http.requests.count == 1)
}

@Test func disconnectDuringRefreshPreventsCalendarDispatch() async throws {
    let (auth, store, tokens, http) = try calendarAuth()
    await auth.connect()
    let lease = try await auth.calendarLease()
    store.save(try credential(expired: true))
    await tokens.suspend()
    let request = try GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination")
    let pending = Task { try await auth.sendCalendar(request, lease: lease) }
    await tokens.waitForStart()
    await auth.disconnect()
    await tokens.release()
    await #expect(throws: GoogleDestinationFailure.authorization) { try await pending.value }
    #expect(await http.requests.isEmpty)
    #expect(store.load() == nil)
}

@Test func rejectedAccessTokenDisablesAuthWithoutReplayingAPIRequest() async throws {
    let (auth, store, _, http) = try calendarAuth()
    await auth.connect()
    let lease = try await auth.calendarLease()
    await http.configure(status: 401)
    await #expect(throws: GoogleDestinationFailure.authorization) {
        try await auth.sendCalendar(
            GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination"),
            lease: lease)
    }
    #expect(await auth.status() == .requiresSignIn)
    #expect(await http.requests.count == 1)
    #expect(store.load() == nil)
}

@Test func changedScopeAndCallerCancellationCannotReturnCalendarData() async throws {
    let (auth, store, _, http) = try calendarAuth()
    await auth.connect()
    let lease = try await auth.calendarLease()
    store.save(
        GoogleCredential(
            version: 1, clientID: try config().clientID, accessToken: "synthetic-access",
            refreshToken: "synthetic-refresh", expiresAt: syntheticNow.addingTimeInterval(3600),
            scope: "unexpected-scope"))
    let request = try GoogleCalendarRequest.make(method: "GET", calendar: "synthetic-destination")
    await #expect(throws: GoogleDestinationFailure.authorization) {
        try await auth.sendCalendar(request, lease: lease)
    }
    #expect(await http.requests.isEmpty)
    store.save(try credential())
    await auth.connect()
    let freshLease = try await auth.calendarLease()
    await http.configure(wait: true)
    let pending = Task { try await auth.sendCalendar(request, lease: freshLease) }
    await http.waitForStart()
    pending.cancel()
    await http.release()
    await #expect(throws: GoogleDestinationFailure.cancelled) { try await pending.value }
}

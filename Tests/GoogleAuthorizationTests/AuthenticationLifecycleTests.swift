import Foundation
import Testing

@testable import GoogleAuthorization

private final class MemoryCredentials: GoogleCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: GoogleCredential?
    private var unavailable = false
    private var denyDelete = false
    private var loads = 0
    init(_ value: GoogleCredential? = nil) { self.value = value }
    func load() throws -> GoogleCredential? {
        try lock.withLock {
            loads += 1
            if unavailable { throw GoogleAuthFailure.keychainUnavailable }
            return value
        }
    }
    func save(_ credential: GoogleCredential) throws {
        try lock.withLock {
            if unavailable { throw GoogleAuthFailure.keychainUnavailable }
            value = credential
        }
    }
    func delete() throws {
        try lock.withLock {
            if unavailable || denyDelete { throw GoogleAuthFailure.keychainUnavailable }
            value = nil
        }
    }
    func configure(unavailable: Bool = false, denyDelete: Bool = false) {
        lock.withLock {
            self.unavailable = unavailable
            self.denyDelete = denyDelete
        }
    }
    var loadCount: Int { lock.withLock { loads } }
}
private actor AuthFixture: GoogleTokenExchanging, GoogleBrowserAuthorizing {
    private(set) var browserCalls = 0
    private(set) var refreshCalls = 0
    private(set) var exchangeCalls = 0
    private(set) var revokeCalls = 0
    var suspend = false
    var failure: GoogleAuthFailure?
    private var waiting: CheckedContinuation<Void, Never>?
    private var signal: CheckedContinuation<Void, Never>?
    private var started = false
    func configure(suspend: Bool = false, failure: GoogleAuthFailure? = nil) {
        self.suspend = suspend
        self.failure = failure
        started = false
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { signal = $0 }
    }
    func release() {
        waiting?.resume()
        waiting = nil
    }
    private func finish() async throws -> GoogleCredential {
        started = true
        signal?.resume()
        signal = nil
        if suspend { await withCheckedContinuation { waiting = $0 } }
        if let failure { throw failure }
        return try credential(refresh: "synthetic-rotated")
    }
    func authorize(configuration: GoogleOAuthConfiguration, attempt: OAuthAttempt) -> (
        code: String, redirect: URL
    ) {
        browserCalls += 1
        return ("synthetic-code", redirect)
    }
    func exchange(code: String, verifier: String, redirect: URL) async throws -> GoogleCredential {
        exchangeCalls += 1
        return try await finish()
    }
    func refresh(_ credential: GoogleCredential) async throws -> GoogleCredential {
        refreshCalls += 1
        return try await finish()
    }
    func revoke(_ token: String) throws {
        revokeCalls += 1
        if let failure { throw failure }
    }
}
private func service(_ store: MemoryCredentials, _ fixture: AuthFixture) throws
    -> GoogleAuthentication
{
    try GoogleAuthentication(
        configuration: config(), credentials: store, tokens: fixture, browser: fixture,
        now: { syntheticNow })
}

@Test func authenticationIsDormantUntilExplicitConnectAndCanResumeSavedGrant() async throws {
    let store = MemoryCredentials(try credential())
    let fixture = AuthFixture()
    let auth = try service(store, fixture)
    #expect(store.loadCount == 0)
    #expect(await auth.status() == .disconnected)
    await auth.checkAuthorization()
    #expect(store.loadCount == 0)
    await auth.connect()
    #expect(await auth.status() == .connected)
    #expect(await fixture.browserCalls == 0)
    await auth.disconnect()
    #expect(try store.load() == nil)
    #expect(await fixture.revokeCalls == 0)
}

@Test func newSignInPersistsOnlyAfterSuccessfulExchangeAndNeverDuplicatesBrowser() async throws {
    let store = MemoryCredentials()
    let fixture = AuthFixture()
    await fixture.configure(suspend: true)
    let auth = try service(store, fixture)
    let pending = Task { await auth.connect() }
    await fixture.waitUntilStarted()
    await auth.connect()
    #expect(await fixture.browserCalls == 1)
    #expect(try store.load() == nil)
    await fixture.release()
    await pending.value
    #expect(await auth.status() == .connected)
    #expect(try store.load()?.refreshToken == "synthetic-rotated")
}

@Test func lockedStoreStopsBeforeBrowserAndFailedPersistenceNeverConnects() async throws {
    let store = MemoryCredentials()
    let fixture = AuthFixture()
    store.configure(unavailable: true)
    let auth = try service(store, fixture)
    await auth.connect()
    #expect(await auth.status() == .failed(.keychainUnavailable))
    #expect(await fixture.browserCalls == 0)
    store.configure()
    await fixture.configure(suspend: true)
    let pending = Task { await auth.connect() }
    await fixture.waitUntilStarted()
    store.configure(unavailable: true)
    await fixture.release()
    await pending.value
    #expect(await auth.status() == .failed(.keychainUnavailable))
}

@Test func disconnectFencesLateExchangeAndCancellationFencesLateSignIn() async throws {
    for disconnect in [true, false] {
        let store = MemoryCredentials()
        let fixture = AuthFixture()
        await fixture.configure(suspend: true)
        let auth = try service(store, fixture)
        let pending = Task { await auth.connect() }
        await fixture.waitUntilStarted()
        if disconnect { await auth.disconnect() } else { await auth.cancelSignIn() }
        await fixture.release()
        await pending.value
        #expect(await auth.status() == .disconnected)
        #expect(try store.load() == nil)
    }
}

@Test func callerCancellationCannotPersistLateCredential() async throws {
    let store = MemoryCredentials()
    let fixture = AuthFixture()
    await fixture.configure(suspend: true)
    let auth = try service(store, fixture)
    let pending = Task { await auth.connect() }
    await fixture.waitUntilStarted()
    pending.cancel()
    await fixture.release()
    await pending.value
    #expect(await auth.status() == .failed(.cancelled))
    #expect(try store.load() == nil)
}

@Test func refreshIsCoalescedAndDisconnectFencesLateRotation() async throws {
    let store = MemoryCredentials(try credential())
    let fixture = AuthFixture()
    let auth = try service(store, fixture)
    await auth.connect()
    try store.save(credential(expired: true))
    await fixture.configure(suspend: true)
    let first = Task { await auth.checkAuthorization() }
    await fixture.waitUntilStarted()
    let second = Task { await auth.checkAuthorization() }
    await auth.disconnect()
    await fixture.release()
    await first.value
    await second.value
    #expect(await fixture.refreshCalls == 1)
    #expect(try store.load() == nil)
    #expect(await auth.status() == .disconnected)
}

@Test func invalidGrantDeletesCredentialsButTransientFailureDoesNot() async throws {
    for failure in [GoogleAuthFailure.reauthenticationRequired, .network] {
        let store = MemoryCredentials(try credential(expired: true))
        let fixture = AuthFixture()
        await fixture.configure(failure: failure)
        let auth = try service(store, fixture)
        await auth.connect()
        if failure == .reauthenticationRequired {
            #expect(await auth.status() == .requiresSignIn)
            #expect(try store.load() == nil)
        } else {
            #expect(await auth.status() == .failed(.network))
            #expect(try store.load() != nil)
        }
        #expect(await fixture.refreshCalls == 1)
    }
}

@Test func revocationFailureNeverRestoresLocalCredentialAndDeleteFailureIsVisible() async throws {
    let store = MemoryCredentials(try credential())
    let fixture = AuthFixture()
    let auth = try service(store, fixture)
    await auth.connect()
    await fixture.configure(failure: .network)
    await auth.disconnect(revokeGoogleGrant: true)
    #expect(await auth.status() == .failed(.revocationFailed))
    #expect(try store.load() == nil)
    #expect(await fixture.revokeCalls == 1)
    await auth.disconnect(revokeGoogleGrant: true)
    #expect(await auth.status() == .failed(.revocationFailed))
    try store.save(credential())
    store.configure(denyDelete: true)
    await auth.disconnect()
    #expect(await auth.status() == .failed(.keychainUnavailable))
    await auth.checkAuthorization()
    #expect(await fixture.refreshCalls == 0)
    store.configure()
    await auth.disconnect()
    #expect(try store.load() == nil)
}

@Test func configurationBoundCredentialsCannotBeReusedByDifferentClient() async throws {
    let saved = GoogleCredential(
        version: 1, clientID: "another.apps.googleusercontent.com", accessToken: "synthetic",
        refreshToken: "synthetic", expiresAt: syntheticNow, scope: GoogleOAuthConfiguration.scope)
    let store = MemoryCredentials(saved)
    let fixture = AuthFixture()
    let auth = try service(store, fixture)
    await auth.connect()
    #expect(await auth.status() == .failed(.corruptCredential))
    #expect(await fixture.browserCalls == 0)
    #expect(await fixture.refreshCalls == 0)
}

@Test @MainActor func unconfiguredUIHasNoServiceAndDoesNotStartAuthentication() async {
    let model = GoogleConnectionModel()
    #expect(!model.isConfigured)
    await model.connect()
    await model.checkAuthorization()
    await model.disconnect()
    #expect(model.state == .disconnected && !model.isBusy)
}

@Test @MainActor func presentationDropsLateConnectStateAfterDisconnect() async throws {
    let store = MemoryCredentials()
    let fixture = AuthFixture()
    await fixture.configure(suspend: true)
    let model = GoogleConnectionModel(service: try service(store, fixture))
    let pending = Task { await model.connect() }
    await fixture.waitUntilStarted()
    await model.disconnect()
    await fixture.release()
    await pending.value
    #expect(model.state == .disconnected && !model.isBusy)
}

@Test func successfulRefreshPersistsRotationWithoutReopeningBrowser() async throws {
    let store = MemoryCredentials(try credential())
    let fixture = AuthFixture()
    let auth = try service(store, fixture)
    await auth.connect()
    try store.save(credential(expired: true))
    await auth.checkAuthorization()
    #expect(await auth.status() == .connected)
    #expect(try store.load()?.refreshToken == "synthetic-rotated")
    await auth.checkAuthorization()
    #expect(await fixture.refreshCalls == 1)
    #expect(await fixture.browserCalls == 0)
}

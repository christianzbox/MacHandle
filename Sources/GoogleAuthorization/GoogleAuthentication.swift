import Foundation

public enum GoogleAuthenticationState: Equatable, Sendable {
    case disconnected, authorizing, connected, refreshing, disconnecting, requiresSignIn
    case failed(GoogleAuthFailure)
}

/// Owns credentials and serializes all persistence. No token-returning API is exported to views.
public actor GoogleAuthentication {
    private let configuration: GoogleOAuthConfiguration
    private let credentials: any GoogleCredentialStoring
    private let tokens: any GoogleTokenExchanging
    private let browser: any GoogleBrowserAuthorizing
    private let now: @Sendable () -> Date
    private var state: GoogleAuthenticationState = .disconnected
    private var generation: UInt64 = 0
    private var enabled = false
    private var authentication: Task<GoogleCredential, Error>?
    private var refreshTask: Task<GoogleCredential, Error>?
    private var disconnecting = false

    /// Invoke only after the maintainer's identity/console/signed-runtime activation gates are met.
    public init(configuration: GoogleOAuthConfiguration) {
        self.configuration = configuration
        credentials = KeychainGoogleCredentialStore(namespace: configuration.credentialNamespace)
        tokens = GoogleTokenHTTPClient(configuration: configuration)
        browser = SystemGoogleBrowser()
        now = { Date() }
    }
    init(
        configuration: GoogleOAuthConfiguration, credentials: any GoogleCredentialStoring,
        tokens: any GoogleTokenExchanging, browser: any GoogleBrowserAuthorizing,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.credentials = credentials
        self.tokens = tokens
        self.browser = browser
        self.now = now
    }
    public func status() -> GoogleAuthenticationState { state }

    /// Explicit user action only. Startup does not inspect Keychain, refresh, or open a browser.
    public func connect() async {
        guard authentication == nil, refreshTask == nil, !disconnecting else { return }
        generation &+= 1
        let current = generation
        enabled = false
        state = .authorizing
        let task = Task { [configuration, credentials, tokens, browser, now] in
            try Task.checkCancellation()
            // A locked or malformed store must fail before any browser/HTTP work.
            if let saved = try credentials.load() {
                try Task.checkCancellation()
                try saved.validate(clientID: configuration.clientID)
                if saved.expiresAt > now().addingTimeInterval(60) { return saved }
                return try await tokens.refresh(saved)
            }
            try Task.checkCancellation()
            let attempt = try OAuthAttempt()
            let result = try await browser.authorize(configuration: configuration, attempt: attempt)
            try Task.checkCancellation()
            return try await tokens.exchange(
                code: result.code, verifier: attempt.verifier, redirect: result.redirect)
        }
        authentication = task
        do {
            let value = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard generation == current, !Task.isCancelled else {
                throw GoogleAuthFailure.cancelled
            }
            try value.validate(clientID: configuration.clientID)
            try credentials.save(value)
            enabled = true
            state = .connected
        } catch {
            if generation == current { handle(error) }
        }
        if generation == current { authentication = nil }
    }

    public func cancelSignIn() {
        guard authentication != nil else { return }
        generation &+= 1
        authentication?.cancel()
        authentication = nil
        enabled = false
        state = .disconnected
    }

    /// Exercises validity/refresh without exposing credentials or starting any Calendar API work.
    public func checkAuthorization() async {
        guard enabled, !disconnecting, authentication == nil else { return }
        let current = generation
        if let task = refreshTask {
            // Coalesce concurrent callers; the owner persists/updates state once.
            _ = await task.result
            return
        }
        do {
            guard let saved = try credentials.load() else {
                throw GoogleAuthFailure.reauthenticationRequired
            }
            try saved.validate(clientID: configuration.clientID)
            if saved.expiresAt > now().addingTimeInterval(60) {
                state = .connected
                return
            }
            state = .refreshing
            let task = Task { [tokens] in try await tokens.refresh(saved) }
            refreshTask = task
            defer { if generation == current { refreshTask = nil } }
            let refreshed = try await task.value
            guard generation == current, enabled else { return }
            try refreshed.validate(clientID: configuration.clientID)
            try credentials.save(refreshed)
            state = .connected
        } catch {
            if generation == current { handle(error) }
        }
    }

    /// Disables local use before suspension. Remote revoke is a separate, explicit user choice.
    public func disconnect(revokeGoogleGrant: Bool = false) async {
        guard !disconnecting else { return }
        disconnecting = true
        defer { disconnecting = false }
        generation &+= 1
        enabled = false
        authentication?.cancel()
        authentication = nil
        refreshTask?.cancel()
        refreshTask = nil
        state = .disconnecting
        var revocationToken: String?
        var readFailure: GoogleAuthFailure?
        if revokeGoogleGrant {
            do { revocationToken = try credentials.load()?.refreshToken } catch {
                readFailure = sanitized(error)
            }
        }
        do { try credentials.delete() } catch {
            state = .failed(.keychainUnavailable)
            return
        }
        // No retained token can be restored by a late browser/refresh completion.
        state = .disconnected
        if let readFailure {
            state = .failed(readFailure)
            return
        }
        if revokeGoogleGrant, revocationToken == nil {
            state = .failed(.revocationFailed)
            return
        }
        if let revocationToken {
            do { try await tokens.revoke(revocationToken) } catch {
                state = .failed(.revocationFailed)
            }
        }
    }

    private func handle(_ error: any Error) {
        let failure = sanitized(error)
        enabled = false
        if failure == .reauthenticationRequired {
            do {
                try credentials.delete()
                state = .requiresSignIn
            } catch { state = .failed(.keychainUnavailable) }
        } else {
            state = .failed(failure)
        }
    }
    private func sanitized(_ error: any Error) -> GoogleAuthFailure {
        if error is CancellationError { return .cancelled }
        return error as? GoogleAuthFailure ?? .network
    }
}

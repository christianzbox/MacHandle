import CryptoKit
import Foundation
import Security

public enum GoogleAuthFailure: Error, Equatable, Sendable {
    case configuration, cancelled, timedOut, invalidCallback, refused, invalidResponse
    case scopeMismatch, reauthenticationRequired, network, keychainUnavailable, corruptCredential
    case busy, browserUnavailable, revocationFailed
}

/// Trusted build configuration, never caller-supplied OAuth endpoints or scopes.
public struct GoogleOAuthConfiguration: Sendable {
    public static let scope = "https://www.googleapis.com/auth/calendar.app.created"
    let clientID: String
    let credentialNamespace: String

    public init(clientID: String, credentialNamespace: String) throws {
        guard clientID.hasSuffix(".apps.googleusercontent.com"), clientID.count <= 256,
            clientID.utf8.allSatisfy({ Self.identifierByte($0) }),
            !credentialNamespace.isEmpty, credentialNamespace.count <= 256,
            credentialNamespace.utf8.allSatisfy({ Self.identifierByte($0) })
        else { throw GoogleAuthFailure.configuration }
        self.clientID = clientID
        self.credentialNamespace = credentialNamespace
    }
    private static func identifierByte(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
            || byte == 45 || byte == 46
    }
}

struct OAuthAttempt: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let state: String
    let verifier: String
    var description: String { "OAuthAttempt(<redacted>)" }
    var debugDescription: String { description }
    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    init() throws {
        state = try Self.random()
        verifier = try Self.random()
    }
    init(state: String, verifier: String) {
        self.state = state
        self.verifier = verifier
    }
    private static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw GoogleAuthFailure.configuration
        }
        return base64URL(Data(bytes))
    }
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    func authorizationURL(configuration: GoogleOAuthConfiguration, redirect: URL) throws -> URL {
        try Self.validateRedirect(redirect)
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: redirect.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfiguration.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return url.url!
    }
    static func validateRedirect(_ url: URL) throws {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
            parts.scheme == "http", parts.host == "127.0.0.1",
            let port = parts.port, (1...65535).contains(port),
            parts.percentEncodedPath == "/oauth/callback", parts.query == nil,
            parts.fragment == nil, parts.user == nil, parts.password == nil
        else { throw GoogleAuthFailure.invalidCallback }
    }
    func code(from callback: URL, redirect: URL) throws -> String {
        try Self.validateRedirect(redirect)
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
            parts.fragment == nil, parts.user == nil, parts.password == nil,
            var base = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        else { throw GoogleAuthFailure.invalidCallback }
        base.query = nil
        guard base.url == redirect, let items = parts.queryItems, items.count <= 12 else {
            throw GoogleAuthFailure.invalidCallback
        }
        var values: [String: String] = [:]
        for item in items {
            guard values[item.name] == nil, let value = item.value, value.utf8.count <= 4096 else {
                throw GoogleAuthFailure.invalidCallback
            }
            values[item.name] = value
        }
        guard values["state"] == state else { throw GoogleAuthFailure.invalidCallback }
        if let error = values["error"] {
            guard values["code"] == nil else { throw GoogleAuthFailure.invalidCallback }
            throw error == "access_denied" ? GoogleAuthFailure.refused : .invalidCallback
        }
        guard let code = values["code"], !code.isEmpty else {
            throw GoogleAuthFailure.invalidCallback
        }
        return code
    }
}

/// Secrets never become UI state or diagnostics. Codable is used only inside the Keychain adapter.
struct GoogleCredential: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let version: Int
    let clientID: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scope: String
    var description: String { "GoogleCredential(<redacted>)" }
    var debugDescription: String { description }
    func validate(clientID: String) throws {
        guard version == 1, self.clientID == clientID,
            Self.validSecret(accessToken), Self.validSecret(refreshToken),
            expiresAt.timeIntervalSince1970.isFinite,
            scope == GoogleOAuthConfiguration.scope
        else { throw GoogleAuthFailure.corruptCredential }
    }
    static func validSecret(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 16_384
            && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }
            )
    }
}

// Internal injectable dependencies: views cannot load/export tokens or choose HTTP destinations.
protocol GoogleCredentialStoring: Sendable {
    func load() throws -> GoogleCredential?
    func save(_ credential: GoogleCredential) throws
    func delete() throws
}
protocol GoogleTokenExchanging: Sendable {
    func exchange(code: String, verifier: String, redirect: URL) async throws -> GoogleCredential
    func refresh(_ credential: GoogleCredential) async throws -> GoogleCredential
    func revoke(_ token: String) async throws
}
protocol GoogleBrowserAuthorizing: Sendable {
    func authorize(configuration: GoogleOAuthConfiguration, attempt: OAuthAttempt) async throws
        -> (code: String, redirect: URL)
}

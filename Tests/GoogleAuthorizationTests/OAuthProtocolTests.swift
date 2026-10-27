import Foundation
import LocalAuthentication
import Security
import Testing

@testable import GoogleAuthorization

func config() throws -> GoogleOAuthConfiguration {
    try GoogleOAuthConfiguration(
        clientID: "synthetic.apps.googleusercontent.com",
        credentialNamespace: "synthetic.machandle.oauth")
}
let syntheticNow = Date(timeIntervalSince1970: 1_000_000)
func credential(expired: Bool = false, refresh: String = "synthetic-refresh") throws
    -> GoogleCredential
{
    GoogleCredential(
        version: 1, clientID: try config().clientID, accessToken: "synthetic-access",
        refreshToken: refresh, expiresAt: syntheticNow.addingTimeInterval(expired ? -1 : 3600),
        scope: GoogleOAuthConfiguration.scope)
}
let redirect = URL(string: "http://127.0.0.1:54321/oauth/callback")!
let attempt = OAuthAttempt(
    state: "synthetic-state", verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

@Test func pkceUsesRFC7636VectorAndFreshRandomState() throws {
    #expect(attempt.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    let first = try OAuthAttempt()
    let second = try OAuthAttempt()
    #expect(first.state != second.state && first.verifier != second.verifier)
    #expect(first.state.count == 43 && first.verifier.count == 43)
    let url = try attempt.authorizationURL(configuration: config(), redirect: redirect)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
    #expect(url.host == "accounts.google.com")
    #expect(values["scope"] == GoogleOAuthConfiguration.scope)
    #expect(values["code_challenge_method"] == "S256")
    #expect(values["access_type"] == "offline")
    #expect(values["client_secret"] == nil)
    #expect(!url.absoluteString.contains(attempt.verifier))
}

@Test func callbacksRejectWrongStateRedirectDuplicateAndAmbiguousParameters() throws {
    let valid = URL(string: redirect.absoluteString + "?state=synthetic-state&code=synthetic-code")!
    #expect(try attempt.code(from: valid, redirect: redirect) == "synthetic-code")
    for suffix in [
        "?state=wrong&code=synthetic-code", "?state=synthetic-state&code=a&code=b",
        "?state=synthetic-state&state=synthetic-state&code=a",
        "?state=synthetic-state&code=a&error=access_denied", "?state=synthetic-state&code=",
        "?state=synthetic-state&code=a#fragment", "?code=a",
    ] {
        #expect(throws: GoogleAuthFailure.invalidCallback) {
            try attempt.code(
                from: URL(string: redirect.absoluteString + suffix)!, redirect: redirect)
        }
    }
    for invalid in [
        "http://localhost:54321/oauth/callback", "http://127.0.0.1:54322/oauth/callback",
        "http://127.0.0.1:54321/wrong", "https://127.0.0.1:54321/oauth/callback",
        "http://user@127.0.0.1:54321/oauth/callback",
    ] {
        #expect(throws: GoogleAuthFailure.invalidCallback) {
            try attempt.code(
                from: URL(string: invalid + "?state=synthetic-state&code=a")!, redirect: redirect)
        }
    }
    #expect(throws: GoogleAuthFailure.refused) {
        try attempt.code(
            from: URL(
                string: redirect.absoluteString + "?state=synthetic-state&error=access_denied")!,
            redirect: redirect)
    }
}

@Test func httpCallbackRejectsRebindingSmugglingAndOversizedInput() throws {
    let good =
        "GET /oauth/callback?state=synthetic-state&code=a%2Bb+c HTTP/1.1\r\nHost: 127.0.0.1:54321\r\n\r\n"
    let url = try LoopbackAuthorization.callbackURL(request: Data(good.utf8), redirect: redirect)
    #expect(try attempt.code(from: url, redirect: redirect) == "a+b c")
    for bad in [
        good.replacingOccurrences(of: "GET ", with: "POST "),
        good.replacingOccurrences(of: "Host: 127.0.0.1:54321", with: "Host: attacker.invalid"),
        good.replacingOccurrences(of: "Host:", with: "Host: 127.0.0.1:54321\r\nHost:"),
        good.replacingOccurrences(of: "\r\n\r\n", with: "\r\nTransfer-Encoding: chunked\r\n\r\n"),
        good.replacingOccurrences(of: "\r\n\r\n", with: "\r\nContent-Length: 1\r\n\r\n"),
        good.replacingOccurrences(of: "%2B", with: "%ZZ"),
        good + "body", String(repeating: "a", count: 8193),
    ] {
        #expect(throws: GoogleAuthFailure.invalidCallback) {
            try LoopbackAuthorization.callbackURL(request: Data(bad.utf8), redirect: redirect)
        }
    }
}

@Test func credentialsAndAttemptDescriptionsAreRedactedAndKeychainQueryIsPrivate() throws {
    let secret = try credential()
    #expect(!String(describing: secret).contains(secret.refreshToken))
    #expect(!String(reflecting: secret).contains(secret.accessToken))
    #expect(!String(describing: attempt).contains(attempt.verifier))
    let query = KeychainGoogleCredentialStore(namespace: "synthetic.private").query
    #expect(query[kSecAttrService as String] as? String == "synthetic.private")
    #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
    #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    #expect(query[kSecAttrAccessGroup as String] == nil)
    #expect(
        (query[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed == true
    )
    // Inspect dictionary construction only: no real Keychain API is called.
}

private actor HTTPFixture: OAuthHTTPSending {
    var response: OAuthHTTPResponse
    private(set) var last: URLRequest?
    init(_ json: String) { response = OAuthHTTPResponse(status: 200, data: Data(json.utf8)) }
    init(_ status: Int, _ json: String) {
        response = OAuthHTTPResponse(status: status, data: Data(json.utf8))
    }
    func send(_ request: URLRequest) -> OAuthHTTPResponse {
        last = request
        return response
    }
}
private func tokenJSON(
    refresh: String = ",\"refresh_token\":\"synthetic-new-refresh\"",
    scope: String? = GoogleOAuthConfiguration.scope, expires: String = "3600",
    type: String = "Bearer"
) -> String {
    "{\"access_token\":\"synthetic-new-access\",\"token_type\":\"\(type)\",\"expires_in\":\(expires)\(refresh)\(scope.map { ",\"scope\":\"\($0)\"" } ?? "")}"
}

@Test func exchangeUsesFormHTTPSPKCEAndNarrowScope() async throws {
    let http = HTTPFixture(tokenJSON())
    let client = GoogleTokenHTTPClient(
        configuration: try config(), http: http, now: { syntheticNow })
    let result = try await client.exchange(
        code: "synthetic+code&value", verifier: attempt.verifier, redirect: redirect)
    #expect(result.refreshToken == "synthetic-new-refresh")
    #expect(result.expiresAt == syntheticNow.addingTimeInterval(3600))
    let request = try #require(await http.last)
    #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
    #expect(request.httpMethod == "POST")
    let body = String(data: request.httpBody!, encoding: .utf8)!
    #expect(body.contains("code=synthetic%2Bcode%26value"))
    #expect(body.contains("code_verifier="))
    #expect(!body.contains("client_secret"))
    #expect(request.url?.query == nil)
}

@Test func tokenValidationRejectsUnexpectedScopesAndMalformedValues() async throws {
    for json in [
        tokenJSON(scope: "https://www.googleapis.com/auth/calendar"),
        tokenJSON(scope: GoogleOAuthConfiguration.scope + " email"), tokenJSON(scope: nil),
        tokenJSON(expires: "0"), tokenJSON(type: "unknown"), tokenJSON(refresh: ""), "{}",
    ] {
        let client = GoogleTokenHTTPClient(configuration: try config(), http: HTTPFixture(json))
        await #expect(throws: (any Error).self) {
            try await client.exchange(
                code: "synthetic", verifier: attempt.verifier, redirect: redirect)
        }
    }
}

@Test func refreshRetainsOrRotatesTokenAndMapsInvalidGrantWithoutRawErrors() async throws {
    for rotation in [false, true] {
        let client = GoogleTokenHTTPClient(
            configuration: try config(),
            http: HTTPFixture(
                tokenJSON(
                    refresh: rotation ? ",\"refresh_token\":\"synthetic-rotated\"" : "", scope: nil)
            ))
        let result = try await client.refresh(credential(expired: true))
        #expect(result.refreshToken == (rotation ? "synthetic-rotated" : "synthetic-refresh"))
    }
    let client = GoogleTokenHTTPClient(
        configuration: try config(),
        http: HTTPFixture(
            400, "{\"error\":\"invalid_grant\",\"error_description\":\"synthetic private text\"}"))
    await #expect(throws: GoogleAuthFailure.reauthenticationRequired) {
        try await client.refresh(credential())
    }
    let redirected = GoogleTokenHTTPClient(configuration: try config(), http: HTTPFixture(302, ""))
    await #expect(throws: GoogleAuthFailure.invalidResponse) {
        try await redirected.refresh(credential())
    }
}

@Test func revocationPostsTokenInBodyAndRequiresSuccessfulResponse() async throws {
    let http = HTTPFixture(200, "")
    let client = GoogleTokenHTTPClient(configuration: try config(), http: http)
    try await client.revoke("synthetic-revoke")
    #expect(await http.last?.url?.absoluteString == "https://oauth2.googleapis.com/revoke")
    #expect(await http.last?.httpBody == Data("token=synthetic-revoke".utf8))
    let failed = GoogleTokenHTTPClient(configuration: try config(), http: HTTPFixture(503, ""))
    await #expect(throws: GoogleAuthFailure.revocationFailed) {
        try await failed.revoke("synthetic")
    }
}

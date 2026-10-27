import Foundation

struct OAuthHTTPResponse: Sendable {
    let status: Int
    let data: Data
    var retryAfter: String? = nil
}
protocol OAuthHTTPSending: Sendable {
    func send(_ request: URLRequest) async throws -> OAuthHTTPResponse
}

/// Ephemeral, cookie-free, cache-free HTTPS only. Redirects never forward a credential body.
struct OAuthHTTPSession: OAuthHTTPSending {
    func send(_ request: URLRequest) async throws -> OAuthHTTPResponse {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        let session = URLSession(
            configuration: config, delegate: NoOAuthRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.url == request.url,
                response.expectedContentLength <= 65_536
            else { throw GoogleAuthFailure.invalidResponse }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 65_536 else { throw GoogleAuthFailure.invalidResponse }
                data.append(byte)
            }
            return OAuthHTTPResponse(
                status: http.statusCode, data: data,
                retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        } catch let failure as GoogleAuthFailure { throw failure } catch is CancellationError {
            throw GoogleAuthFailure.cancelled
        } catch { throw GoogleAuthFailure.network }
    }
}
private final class NoOAuthRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) { completionHandler(nil) }
}

struct GoogleTokenHTTPClient: GoogleTokenExchanging {
    let configuration: GoogleOAuthConfiguration
    let http: any OAuthHTTPSending
    let now: @Sendable () -> Date
    init(
        configuration: GoogleOAuthConfiguration, http: any OAuthHTTPSending = OAuthHTTPSession(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.http = http
        self.now = now
    }

    func exchange(code: String, verifier: String, redirect: URL) async throws -> GoogleCredential {
        try OAuthAttempt.validateRedirect(redirect)
        return try await token(
            fields: [
                "client_id": configuration.clientID, "code": code,
                "code_verifier": verifier, "redirect_uri": redirect.absoluteString,
                "grant_type": "authorization_code",
            ], previous: nil)
    }
    func refresh(_ credential: GoogleCredential) async throws -> GoogleCredential {
        try credential.validate(clientID: configuration.clientID)
        return try await token(
            fields: [
                "client_id": configuration.clientID, "refresh_token": credential.refreshToken,
                "grant_type": "refresh_token",
            ], previous: credential)
    }
    func revoke(_ token: String) async throws {
        let response = try await http.send(
            Self.request(
                endpoint: URL(string: "https://oauth2.googleapis.com/revoke")!,
                fields: ["token": token]))
        guard response.status == 200 else { throw GoogleAuthFailure.revocationFailed }
    }
    static func request(endpoint: URL, fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        request.httpBody = fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").data(using: .utf8)
        return request
    }
    private func token(fields: [String: String], previous: GoogleCredential?) async throws
        -> GoogleCredential
    {
        let response = try await http.send(
            Self.request(
                endpoint: URL(string: "https://oauth2.googleapis.com/token")!, fields: fields))
        guard response.data.count <= 65_536 else { throw GoogleAuthFailure.invalidResponse }
        if response.status != 200 {
            let error = try? JSONDecoder().decode(TokenError.self, from: response.data)
            if response.status == 400, error?.error == "invalid_grant" {
                throw GoogleAuthFailure.reauthenticationRequired
            }
            throw response.status == 429 || response.status >= 500
                ? GoogleAuthFailure.network : .invalidResponse
        }
        guard let result = try? JSONDecoder().decode(TokenResponse.self, from: response.data),
            result.tokenType.lowercased() == "bearer", result.expiresIn.isFinite,
            result.expiresIn > 60, result.expiresIn <= 86_400,
            GoogleCredential.validSecret(result.accessToken),
            let refresh = result.refreshToken ?? previous?.refreshToken,
            GoogleCredential.validSecret(refresh)
        else { throw GoogleAuthFailure.invalidResponse }
        let scope = result.scope ?? previous?.scope
        guard let scope,
            Set(scope.split(separator: " ").map(String.init)) == [GoogleOAuthConfiguration.scope]
        else {
            throw GoogleAuthFailure.scopeMismatch
        }
        return GoogleCredential(
            version: 1, clientID: configuration.clientID, accessToken: result.accessToken,
            refreshToken: refresh, expiresAt: now().addingTimeInterval(result.expiresIn),
            scope: GoogleOAuthConfiguration.scope)
    }
    private struct TokenError: Decodable { let error: String }
    private struct TokenResponse: Decodable {
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
            case scope
        }
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Double
        let tokenType: String
        let scope: String?
    }
}

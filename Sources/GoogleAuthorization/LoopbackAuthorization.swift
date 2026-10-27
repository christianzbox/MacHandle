import AppKit
import Foundation
import Network

struct SystemGoogleBrowser: GoogleBrowserAuthorizing {
    func authorize(configuration: GoogleOAuthConfiguration, attempt: OAuthAttempt) async throws
        -> (code: String, redirect: URL)
    {
        let receiver = LoopbackAuthorization(attempt: attempt)
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let redirect = try await receiver.start()
                let url = try attempt.authorizationURL(
                    configuration: configuration, redirect: redirect)
                try Task.checkCancellation()
                let opened = await MainActor.run { NSWorkspace.shared.open(url) }
                guard opened else { throw GoogleAuthFailure.browserUnavailable }
                let code = try await receiver.waitForCode()
                return (code, redirect)
            } catch {
                await receiver.cancel()
                throw error
            }
        } onCancel: {
            Task { await receiver.cancel() }
        }
    }
}

/// One attempt, loopback IP only, bounded HTTP input/connections, no logs or resource endpoint.
actor LoopbackAuthorization {
    private let attempt: OAuthAttempt
    private let timeout: Duration
    private let queue = DispatchQueue(label: "MacHandle.OAuthCallback")
    private var listener: NWListener?
    private var redirect: URL?
    private var starting: CheckedContinuation<URL, Error>?
    private var waiting: CheckedContinuation<String, Error>?
    private var outcome: Result<String, Error>?
    private var deadline: Task<Void, Never>?
    private var connections: [UUID: NWConnection] = [:]
    private var buffers: [UUID: Data] = [:]
    private var requestCount = 0

    init(attempt: OAuthAttempt, timeout: Duration = .seconds(180)) {
        self.attempt = attempt
        self.timeout = timeout
    }
    func start() async throws -> URL {
        guard listener == nil, outcome == nil else { throw GoogleAuthFailure.cancelled }
        try Task.checkCancellation()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        parameters.allowLocalEndpointReuse = false
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.changed(state) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        deadline = Task { [weak self, timeout] in
            do { try await Task.sleep(for: timeout) } catch { return }
            await self?.finish(.failure(GoogleAuthFailure.timedOut))
        }
        return try await withCheckedThrowingContinuation { continuation in
            starting = continuation
            listener.start(queue: queue)
        }
    }
    func waitForCode() async throws -> String {
        if let outcome { return try outcome.get() }
        guard waiting == nil else { throw GoogleAuthFailure.busy }
        return try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func cancel() { finish(.failure(GoogleAuthFailure.cancelled)) }

    private func changed(_ state: NWListener.State) {
        guard outcome == nil else { return }
        switch state {
        case .ready:
            guard let port = listener?.port,
                let url = URL(string: "http://127.0.0.1:\(port.rawValue)/oauth/callback")
            else {
                finish(.failure(GoogleAuthFailure.invalidCallback))
                return
            }
            redirect = url
            starting?.resume(returning: url)
            starting = nil
        case .failed: finish(.failure(GoogleAuthFailure.network))
        case .cancelled: finish(.failure(GoogleAuthFailure.cancelled))
        default: break
        }
    }
    private func accept(_ connection: NWConnection) {
        guard outcome == nil, redirect != nil, connections.count < 8, requestCount < 32 else {
            connection.cancel()
            return
        }
        requestCount += 1
        let id = UUID()
        connections[id] = connection
        buffers[id] = Data()
        connection.start(queue: queue)
        receive(id)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await self?.close(id)
        }
    }
    private func receive(_ id: UUID) {
        connections[id]?.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
            [weak self] data, _, complete, error in
            Task { await self?.received(id, data: data, complete: complete, failed: error != nil) }
        }
    }
    private func received(_ id: UUID, data: Data?, complete: Bool, failed: Bool) {
        guard outcome == nil, connections[id] != nil, let redirect else {
            close(id)
            return
        }
        if failed {
            close(id)
            return
        }
        if let data { buffers[id, default: Data()].append(data) }
        guard let buffer = buffers[id], buffer.count <= 8192 else {
            respond(id, accepted: false)
            return
        }
        guard buffer.range(of: Data("\r\n\r\n".utf8)) != nil else {
            if complete { close(id) } else { receive(id) }
            return
        }
        do {
            let callback = try Self.callbackURL(request: buffer, redirect: redirect)
            let code = try attempt.code(from: callback, redirect: redirect)
            respond(id, accepted: true)
            finish(.success(code))
        } catch GoogleAuthFailure.refused {
            respond(id, accepted: true)
            finish(.failure(GoogleAuthFailure.refused))
        } catch {
            // Invalid state/path/headers are not an authorization result. Keep waiting within limits.
            respond(id, accepted: false)
        }
    }
    private func respond(_ id: UUID, accepted: Bool) {
        guard let connection = connections.removeValue(forKey: id) else { return }
        buffers.removeValue(forKey: id)
        let body = accepted ? "Return to MacHandle to continue." : "Invalid callback."
        let status = accepted ? "200 OK" : "400 Bad Request"
        let response =
            "HTTP/1.1 \(status)\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Security-Policy: default-src 'none'\r\n\r\n\(body)"
        connection.send(
            content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() }
        )
    }
    private func close(_ id: UUID) {
        connections.removeValue(forKey: id)?.cancel()
        buffers.removeValue(forKey: id)
    }
    private func finish(_ result: Result<String, Error>) {
        guard outcome == nil else { return }
        outcome = result
        listener?.cancel()
        listener = nil
        deadline?.cancel()
        deadline = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        buffers.removeAll()
        if let starting { starting.resume(throwing: Self.failure(result)) }
        starting = nil
        waiting?.resume(with: result)
        waiting = nil
    }
    private static func failure(_ result: Result<String, Error>) -> any Error {
        if case .failure(let error) = result { return error }
        return GoogleAuthFailure.invalidCallback
    }

    static func callbackURL(request: Data, redirect: URL) throws -> URL {
        try OAuthAttempt.validateRedirect(redirect)
        guard request.count <= 8192, request.allSatisfy({ $0 < 128 }),
            let text = String(data: request, encoding: .ascii), text.hasSuffix("\r\n\r\n")
        else { throw GoogleAuthFailure.invalidCallback }
        let lines = text.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ", omittingEmptySubsequences: false)
        guard first.count == 3, first[0] == "GET", first[2] == "HTTP/1.1",
            first[1].hasPrefix("/oauth/callback?"), !first[1].contains("#"),
            !first[1].contains("\\")
        else { throw GoogleAuthFailure.invalidCallback }
        var headers: [String: String] = [:]
        for line in lines.dropFirst().dropLast(2) {
            guard let colon = line.firstIndex(of: ":") else {
                throw GoogleAuthFailure.invalidCallback
            }
            let name = line[..<colon].lowercased()
            guard !name.isEmpty, headers[name] == nil,
                name.utf8.allSatisfy({ (97...122).contains($0) || $0 == 45 })
            else { throw GoogleAuthFailure.invalidCallback }
            headers[name] = String(line[line.index(after: colon)...]).trimmingCharacters(
                in: .whitespaces)
        }
        guard headers["host"] == "127.0.0.1:\(redirect.port!)",
            headers["transfer-encoding"] == nil,
            headers["content-length"] == nil || headers["content-length"] == "0"
        else { throw GoogleAuthFailure.invalidCallback }
        let target = String(first[1])
        let bytes = Array(target.utf8)
        for index in bytes.indices where bytes[index] == 37 {
            guard index + 2 < bytes.count,
                bytes[(index + 1)...(index + 2)].allSatisfy({
                    (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
                })
            else { throw GoogleAuthFailure.invalidCallback }
        }
        // OAuth query parameters use form encoding; a literal plus must be percent-encoded.
        guard
            let url = URL(
                string: "http://127.0.0.1:\(redirect.port!)"
                    + target.replacingOccurrences(of: "+", with: "%20"))
        else {
            throw GoogleAuthFailure.invalidCallback
        }
        return url
    }
}

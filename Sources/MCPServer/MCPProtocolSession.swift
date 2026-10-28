import Foundation

/// No credential/provider/policy dependencies. Client metadata is inert, unauthenticated input.
actor MCPProtocolSession {
    static let modern = "2026-07-28"
    static let legacy = "2025-11-25"
    private enum Phase { case fresh, initializing, ready, closed }
    private struct Pending {
        let token: UUID
        let task: Task<Void, Never>
        var cancelled = false
        var responding = false
    }
    private var phase: Phase = .fresh
    private var pending: [String: Pending] = [:]
    private var legacyIDs: Set<String> = []
    private let tools: [MCPTool]
    private let output: @Sendable (Data) async throws -> Void
    private let onOutputFailure: @Sendable () -> Void

    init(
        tools: [MCPTool] = MCPTool.synthetic,
        output: @escaping @Sendable (Data) async throws -> Void,
        onOutputFailure: @escaping @Sendable () -> Void = {}
    ) throws {
        guard tools.count <= 32, Set(tools.map(\.name)).count == tools.count,
            tools.allSatisfy({ $0.validRegistration })
        else { throw MCPWireFailure.limit }
        self.tools = tools.sorted { $0.name < $1.name }
        self.output = output
        self.onOutputFailure = onOutputFailure
    }
    /// Caller supplies frames serially; completion tasks may return while the next frame is read.
    func receive(_ data: Data) async -> Bool {
        guard phase != .closed else { return false }
        let value: MCPJSON
        do {
            var parser = try MCPJSONParser(data)
            value = try parser.parse()
        } catch {
            await sendError(nil, -32700, "Invalid JSON frame")
            return phase != .closed
        }
        guard let object = value.object else {
            await sendError(nil, -32600, "Requests must be objects; batches are unsupported")
            return phase != .closed
        }
        let rawID = object["id"]
        let id = rawID.flatMap(Self.identifier)
        guard object["jsonrpc"] == .string("2.0"), let method = object["method"]?.string,
            !method.isEmpty, method.utf8.count <= 128,
            Set(object.keys).isSubset(of: ["jsonrpc", "id", "method", "params"]),
            rawID == nil || id != nil
        else {
            await sendError(nil, -32600, "Invalid request")
            return phase != .closed
        }
        guard let params = (object["params"] ?? .object([:])).object else {
            if rawID != nil { await sendError(rawID, -32602, "Invalid parameters") }
            return phase != .closed
        }
        guard let id, let rawID else {
            await notification(method, params)
            return phase != .closed
        }
        if let response = pending[id], response.responding { await response.task.value }
        guard phase != .closed else { return false }
        guard pending[id] == nil else {
            await sendError(nil, -32600, "Duplicate active request identifier")
            await shutdown()
            return false
        }
        let meta = params["_meta"]?.object
        let version = meta?["io.modelcontextprotocol/protocolVersion"]?.string
        let modern =
            method == "server/discover"
            || meta?.keys.contains(where: {
                [
                    "io.modelcontextprotocol/protocolVersion", "io.modelcontextprotocol/clientInfo",
                    "io.modelcontextprotocol/clientCapabilities",
                ].contains($0)
            }) == true
        if params["_meta"] != nil && meta == nil {
            await sendError(rawID, -32602, "Invalid metadata")
            return true
        }
        if modern {
            guard let version else {
                await sendError(rawID, -32602, "Missing per-request protocol version")
                return phase != .closed
            }
            guard version == Self.modern else {
                await sendError(
                    rawID, -32022, "Unsupported protocol version",
                    extra: .object([
                        "supported": .array([.string(Self.modern), .string(Self.legacy)]),
                        "requested": .string(version),
                    ]))
                return phase != .closed
            }
            if let client = meta?["io.modelcontextprotocol/clientInfo"],
                client["name"]?.string == nil || client["version"]?.string == nil
            {
                await sendError(rawID, -32602, "Invalid per-request client metadata")
                return phase != .closed
            }
            guard meta?["io.modelcontextprotocol/clientCapabilities"]?.object != nil else {
                await sendError(rawID, -32602, "Missing per-request capabilities")
                return phase != .closed
            }
        } else {
            guard !legacyIDs.contains(id), legacyIDs.count < 4096 else {
                await sendError(nil, -32600, "Legacy identifier reuse or session limit")
                await shutdown()
                return false
            }
            legacyIDs.insert(id)
        }
        if method == "initialize", !modern {
            guard phase == .fresh, params["protocolVersion"]?.string != nil,
                params["capabilities"]?.object != nil,
                let info = params["clientInfo"]?.object,
                info["name"]?.string != nil, info["version"]?.string != nil
            else {
                await sendError(rawID, -32602, "Invalid initialization")
                return phase != .closed
            }
            phase = .initializing
            await result(
                rawID,
                .object([
                    "protocolVersion": .string(Self.legacy), "capabilities": Self.capabilities,
                    "serverInfo": Self.info,
                    "instructions": .string(
                        "Synthetic tools only. No personal data or app authorization."),
                ]), modern: false)
            return phase != .closed
        }
        if method == "ping" {
            guard Set(params.keys).isSubset(of: ["_meta"]) else {
                await sendError(rawID, -32602, "Invalid ping parameters")
                return phase != .closed
            }
            await result(rawID, .object([:]), modern: modern)
            return phase != .closed
        }
        guard modern || phase == .ready else {
            await sendError(rawID, -32600, "Initialize and send notifications/initialized first")
            return phase != .closed
        }
        switch method {
        case "server/discover" where modern:
            guard Set(params.keys).isSubset(of: ["_meta"]) else {
                await sendError(rawID, -32602, "Invalid discovery parameters")
                return phase != .closed
            }
            await result(
                rawID,
                .object([
                    "supportedVersions": .array([.string(Self.modern), .string(Self.legacy)]),
                    "capabilities": Self.capabilities,
                ]), modern: true, cacheable: true)
        case "tools/list":
            guard Set(params.keys).isSubset(of: ["_meta"]) else {
                await sendError(rawID, -32602, "Invalid tool-list parameters")
                return phase != .closed
            }
            await result(
                rawID, .object(["tools": .array(tools.map(\.definition))]), modern: modern,
                cacheable: true)
        case "tools/call":
            guard Set(params.keys).isSubset(of: ["name", "arguments", "_meta"]),
                let name = params["name"]?.string,
                let tool = tools.first(where: { $0.name == name })
            else {
                await sendError(rawID, -32602, "Unknown tool or invalid parameters")
                return phase != .closed
            }
            let arguments: [String: MCPJSON]
            do { arguments = try tool.arguments(params["arguments"] ?? .object([:])) } catch {
                await sendError(rawID, -32602, "Invalid tool arguments")
                return phase != .closed
            }
            guard pending.count < 4 else {
                await sendError(rawID, -32603, "Request capacity reached")
                return phase != .closed
            }
            let token = UUID()
            let task = Task { [weak self] in
                let response: MCPJSON
                var validate: @Sendable () async throws -> Void = {}
                do {
                    let result = try await tool.execute(arguments)
                    let value = result.value
                    validate = result.validate
                    try Task.checkCancellation()
                    response = .object([
                        "content": .array([
                            .object([
                                "type": .string("text"),
                                "text": .string(
                                    String(decoding: try value.encoded(), as: UTF8.self)),
                            ])
                        ]),
                        "structuredContent": value, "isError": .bool(false),
                    ])
                } catch is CancellationError {
                    await self?.finished(
                        id, token: token, rawID: rawID, response: nil, modern: modern)
                    return
                } catch {
                    response = .object([
                        "content": .array([
                            .object([
                                "type": .string("text"),
                                "text": .string("Operation unavailable"),
                            ])
                        ]), "isError": .bool(true),
                    ])
                }
                await self?.finished(
                    id, token: token, rawID: rawID, response: response, modern: modern,
                    validate: validate)
            }
            pending[id] = Pending(token: token, task: task)
        default: await sendError(rawID, -32601, "Method not supported")
        }
        return phase != .closed
    }
    private func notification(_ method: String, _ params: [String: MCPJSON]) async {
        if method == "notifications/initialized", phase == .initializing { phase = .ready }
        if method == "notifications/cancelled", let raw = params["requestId"],
            let id = Self.identifier(raw),
            var request = pending[id]
        {
            request.cancelled = true
            pending[id] = request
            request.task.cancel()
        }
    }
    private func finished(
        _ id: String, token: UUID, rawID: MCPJSON, response: MCPJSON?, modern: Bool,
        validate: @Sendable () async throws -> Void = {}
    ) async {
        guard let request = pending[id], request.token == token else { return }
        if !request.cancelled, phase != .closed, var response {
            do { try await validate() } catch is CancellationError {
                pending.removeValue(forKey: id)
                return
            } catch {
                response = .object([
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Operation unavailable"),
                        ])
                    ]), "isError": .bool(true),
                ])
            }
            if pending[id]?.cancelled == false, phase != .closed, !Task.isCancelled {
                pending[id]?.responding = true
                await result(rawID, response, modern: modern)
            }
        }
        if pending[id]?.token == token { pending.removeValue(forKey: id) }
    }
    func shutdown() async {
        phase = .closed
        let tasks = pending.values.map(\.task)
        for task in tasks { task.cancel() }
        // Do not await the current completion task from its own failed-output path.
        for task in tasks { await task.value }
        pending.removeAll()
    }
    private func result(_ id: MCPJSON, _ value: MCPJSON, modern: Bool, cacheable: Bool = false)
        async
    {
        var fields = value.object ?? [:]
        if modern {
            if cacheable {
                fields["ttlMs"] = .number(0)
                fields["cacheScope"] = .string("private")
            }
            fields["resultType"] = .string("complete")
            fields["_meta"] = .object(["io.modelcontextprotocol/serverInfo": Self.info])
        }
        await emit(.object(["jsonrpc": .string("2.0"), "id": id, "result": .object(fields)]))
    }
    private func sendError(_ id: MCPJSON?, _ code: Int, _ message: String, extra: MCPJSON? = nil)
        async
    {
        var fields: [String: MCPJSON] = [
            "code": .number(Double(code)), "message": .string(message),
        ]
        if let extra { fields["data"] = extra }
        await emit(
            .object(["jsonrpc": .string("2.0"), "id": id ?? .null, "error": .object(fields)]))
    }
    private func emit(_ value: MCPJSON) async {
        guard phase != .closed else { return }
        do {
            let data = try value.encoded()
            guard data.count <= 65_536 else { throw MCPWireFailure.limit }
            try await output(data + Data([10]))
        } catch is CancellationError {
            // No new response is emitted after cancellation; partial writes close the channel.
        } catch {
            phase = .closed
            onOutputFailure()
            for request in pending.values { request.task.cancel() }
        }
    }
    private static func identifier(_ value: MCPJSON) -> String? {
        if let s = value.string, !s.isEmpty, s.utf8.count <= 128 { return "s:" + s }
        if let n = value.integer { return "n:" + String(n) }
        return nil
    }
    private static let info = MCPJSON.object([
        "name": .string("MacHandle synthetic MCP"), "version": .string("0.1.0"),
    ])
    private static let capabilities = MCPJSON.object([
        "tools": .object(["listChanged": .bool(false)])
    ])
}

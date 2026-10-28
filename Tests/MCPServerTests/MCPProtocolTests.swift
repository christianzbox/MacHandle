import Foundation
import Testing

@testable import MCPServer

private actor Sink {
    var frames: [MCPJSON] = []
    func send(_ data: Data) throws {
        #expect(data.last == 10 && data.dropLast().contains(10) == false)
        frames.append(try JSONDecoder().decode(MCPJSON.self, from: data))
    }
    func count() -> Int { frames.count }
    func last() -> MCPJSON? { frames.last }
}
private func message(
    _ method: String, id: Int? = 1, params: [String: MCPJSON] = [:], modern: Bool = true
) throws -> Data {
    var params = params
    if modern {
        params["_meta"] = .object([
            "io.modelcontextprotocol/protocolVersion": .string("2026-07-28"),
            "io.modelcontextprotocol/clientCapabilities": .object([:]),
        ])
    }
    var value: [String: MCPJSON] = [
        "jsonrpc": .string("2.0"), "method": .string(method), "params": .object(params),
    ]
    if let id { value["id"] = .number(Double(id)) }
    return try MCPJSON.object(value).encoded()
}
private func initialized(_ session: MCPProtocolSession, version: String = "2025-11-25") async throws
{
    _ = await session.receive(
        try message(
            "initialize",
            params: [
                "protocolVersion": .string(version),
                "clientInfo": .object([
                    "name": .string("Synthetic client"), "version": .string("1"),
                ]),
                "capabilities": .object([:]),
            ], modern: false))
    _ = await session.receive(try message("notifications/initialized", id: nil, modern: false))
}
private func waitFor(_ count: Int, _ sink: Sink) async throws {
    for _ in 0..<1000 {
        if await sink.count() >= count { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("Synthetic response did not arrive")
    throw CancellationError()
}

@Test func mcpFramingBoundsChunksAndPreservesSplitUnicode() throws {
    var framer = MCPLineFramer()
    let wire = Array("{\"text\":\"☃\"}\r\n{}\n".utf8)
    var frames: [Data] = []
    for byte in wire { frames += try framer.append(Data([byte])) }
    #expect(frames == [Data("{\"text\":\"☃\"}".utf8), Data("{}".utf8)])
    #expect(!framer.hasPartialFrame)
    _ = try framer.append(Data("{partial".utf8))
    #expect(framer.hasPartialFrame)
    var oversized = MCPLineFramer()
    for _ in 0..<16 { _ = try oversized.append(Data(repeating: 32, count: 4096)) }
    #expect(throws: MCPWireFailure.self) { try oversized.append(Data([32])) }
}

@Test func mcpParserRejectsAmbiguityDepthAndInvalidEncoding() throws {
    let invalid = [
        Data([255]), Data("{\"a\":1,\"\\u0061\":2}".utf8),
        Data((String(repeating: "[", count: 40) + "0" + String(repeating: "]", count: 40)).utf8),
        Data("{\"a\":NaN}".utf8), Data("[1,]".utf8), Data("{\"a\":1}garbage".utf8),
        Data("{\"a\":1e999}".utf8),
    ]
    for data in invalid {
        #expect(throws: (any Error).self) {
            var parser = try MCPJSONParser(data)
            return try parser.parse()
        }
    }
    var valid = try MCPJSONParser(Data("{\"a\":[null,true,false,-2,1.25,\"escaped\\ntext\"]}".utf8))
    #expect(try valid.parse()["a"] != nil)
}

@Test func mcpModernRequestsAreIndependentAndMetadataNeverAuthorizes() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    _ = await session.receive(try message("server/discover"))
    #expect(await sink.last()?["result"]?["resultType"] == .string("complete"))
    #expect(
        await sink.last()?["result"]?["supportedVersions"]
            == .array([.string("2026-07-28"), .string("2025-11-25")]))
    _ = await session.receive(try message("tools/list", id: 2))
    #expect(await sink.last()?["result"]?["tools"]?.object == nil)
    _ = await session.receive(
        try message(
            "tools/call", id: 3,
            params: [
                "name": .string("list_calendars"),
                "arguments": .object(["approved": .bool(true)]),
            ]))
    #expect(await sink.last()?["error"]?["code"] == .number(-32602))
    let missing = Data(
        "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\"}}}"
            .utf8)
    _ = await session.receive(missing)
    #expect(await sink.last()?["error"]?["code"] == .number(-32602))
    await session.shutdown()
}

@Test func mcpLegacyInitializationNegotiatesWithoutGrantingAuthority() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    _ = await session.receive(try message("tools/list", id: 20, modern: false))
    #expect(await sink.last()?["error"]?["code"] == .number(-32600))
    _ = await session.receive(
        try message(
            "initialize",
            params: [
                "protocolVersion": .string("unknown"),
                "clientInfo": .object(["name": .string("Administrator"), "version": .string("1")]),
                "capabilities": .object([:]),
            ], modern: false))
    #expect(await sink.last()?["result"]?["protocolVersion"] == .string("2025-11-25"))
    _ = await session.receive(try message("tools/list", id: 21, modern: false))
    #expect(await sink.last()?["error"] != nil)
    _ = await session.receive(try message("notifications/initialized", id: nil, modern: false))
    _ = await session.receive(try message("tools/list", id: 22, modern: false))
    #expect(await sink.last()?["result"]?["resultType"] == nil)
    _ = await session.receive(try message("initialize", id: 23, modern: false))
    #expect(await sink.last()?["error"] != nil)
    await session.shutdown()
}

@Test func mcpUnknownModernVersionCannotDowngradeIntoLegacySession() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    try await initialized(session)
    let data = Data(
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"unknown\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}"
            .utf8)
    _ = await session.receive(data)
    #expect(await sink.last()?["error"]?["code"] == .number(-32022))
    let malformed = Data(
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/clientCapabilities\":{}}}}"
            .utf8)
    _ = await session.receive(malformed)
    #expect(await sink.last()?["error"]?["code"] == .number(-32602))
    await session.shutdown()
}

@Test func mcpTypedToolSchemasAndExecutionErrorsStaySeparate() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    let invalid: [[String: MCPJSON]] = [
        ["a": .bool(true), "b": .number(1)],
        ["a": .number(1.5), "b": .number(1)], ["a": .number(1_000_001), "b": .number(1)],
        ["a": .number(1)], ["a": .number(1), "b": .number(2), "approved": .bool(true)],
    ]
    for arguments in invalid {
        _ = await session.receive(
            try message(
                "tools/call",
                params: ["name": .string("mock_add"), "arguments": .object(arguments)]))
        #expect(await sink.last()?["error"]?["code"] == .number(-32602))
    }
    _ = await session.receive(
        try message(
            "tools/call",
            params: [
                "name": .string("mock_add"),
                "arguments": .object(["a": .number(2), "b": .number(3)]),
            ]))
    try await waitFor(6, sink)
    #expect(await sink.last()?["result"]?["structuredContent"] == .object(["sum": .number(5)]))
    _ = await session.receive(try message("tools/call", params: ["name": .string("mock_fail")]))
    try await waitFor(7, sink)
    #expect(await sink.last()?["result"]?["isError"] == .bool(true))
    await session.shutdown()
}

@Test func mcpInvalidRequestsAndNotificationsDoNotLeakInput() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    for data in [
        "[{}]", "{\"jsonrpc\":\"2.0\",\"id\":true,\"method\":\"ping\"}",
        "{\"jsonrpc\":\"2.0\",\"id\":null,\"method\":\"ping\"}", "{\"secretSynthetic\":",
    ] {
        _ = await session.receive(Data(data.utf8))
        #expect(await sink.last()?["error"] != nil)
        #expect(try await sink.last()?.encoded().range(of: Data("secretSynthetic".utf8)) == nil)
    }
    let before = await sink.count()
    _ = await session.receive(try message("unknown/notification", id: nil))
    _ = await session.receive(
        try message("tools/call", id: nil, params: ["name": .string("mock_status")]))
    #expect(await sink.count() == before)
    await session.shutdown()
}

private actor Barrier {
    var arrived = false
    var waiter: CheckedContinuation<Void, Never>?
    var held: CheckedContinuation<Void, Never>?
    func enter() async {
        arrived = true
        waiter?.resume()
        waiter = nil
        await withCheckedContinuation { held = $0 }
    }
    func wait() async { if !arrived { await withCheckedContinuation { waiter = $0 } } }
    func release() {
        held?.resume()
        held = nil
    }
}

@Test func mcpCancelledIgnoringHandlerCannotEmitLateSuccess() async throws {
    let sink = Sink()
    let barrier = Barrier()
    let tool = MCPTool(
        name: "held", description: "Synthetic", fields: [], outputSchema: .object([:]),
        execute: { _ in
            await barrier.enter()
            return .object(["synthetic": .bool(true)])
        })
    let session = try MCPProtocolSession(tools: [tool], output: { try await sink.send($0) })
    _ = await session.receive(try message("tools/call", params: ["name": .string("held")]))
    await barrier.wait()
    _ = await session.receive(
        try message(
            "notifications/cancelled", id: nil,
            params: ["requestId": .number(1), "reason": .string("Synthetic private text")]))
    await barrier.release()
    await session.shutdown()
    #expect(await sink.count() == 0)
}

@Test func mcpCapacityRemainsBoundedAndShutdownCancelsAllCalls() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    for id in 1...4 {
        _ = await session.receive(
            try message(
                "tools/call", id: id,
                params: [
                    "name": .string("mock_wait"),
                    "arguments": .object(["milliseconds": .number(1000)]),
                ]))
    }
    _ = await session.receive(
        try message("tools/call", id: 5, params: ["name": .string("mock_status")]))
    #expect(await sink.last()?["error"]?["code"] == .number(-32603))
    await session.shutdown()
    #expect(await sink.count() == 1)
    #expect(await session.receive(try message("ping", id: 6)) == false)
}

@Test func mcpDuplicateActiveIDClosesAndCompletedModernIDMayBeReused() async throws {
    let sink = Sink()
    let session = try MCPProtocolSession(output: { try await sink.send($0) })
    _ = await session.receive(try message("tools/call", params: ["name": .string("mock_status")]))
    try await waitFor(1, sink)
    #expect(await session.receive(try message("ping")))
    _ = await session.receive(
        try message(
            "tools/call", id: 2,
            params: [
                "name": .string("mock_wait"), "arguments": .object(["milliseconds": .number(1000)]),
            ]))
    #expect(await session.receive(try message("ping", id: 2)) == false)
    #expect(await sink.last()?["error"]?["code"] == .number(-32600))
}

@Test func mcpOutputFailureClosesSessionWithoutSecondResponse() async throws {
    let session = try MCPProtocolSession(output: { _ in throw MCPWireFailure.io })
    #expect(await session.receive(try message("ping")) == false)
    await session.shutdown()
}

@Test func mcpRegistryRejectsDuplicateNamesAndFields() throws {
    #expect(throws: MCPWireFailure.self) {
        try MCPProtocolSession(
            tools: [MCPTool.synthetic[0], MCPTool.synthetic[0]], output: { _ in })
    }
    let tool = MCPTool(
        name: "invalid tool", description: "Synthetic", fields: [],
        outputSchema: .object([:]), execute: { _ in .object([:]) })
    #expect(throws: MCPWireFailure.self) { try MCPProtocolSession(tools: [tool], output: { _ in }) }
    let fields = MCPTool(
        name: "duplicate", description: "Synthetic",
        fields: [.init(name: "a", range: 0...1), .init(name: "a", range: 0...1)],
        outputSchema: .object([:]), execute: { _ in .object([:]) })
    #expect(throws: MCPWireFailure.self) {
        try MCPProtocolSession(tools: [fields], output: { _ in })
    }
}

private final class FailureSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func mark() { lock.withLock { value = true } }
    var marked: Bool { lock.withLock { value } }
}
@Test func mcpOversizedOutputClosesIdleTransportWithoutSendingContent() async throws {
    let failure = FailureSignal()
    let sink = Sink()
    let tool = MCPTool(
        name: "oversized", description: "Synthetic", fields: [],
        outputSchema: .object([:]),
        execute: { _ in .object(["value": .string(String(repeating: "x", count: 70_000))]) })
    let session = try MCPProtocolSession(
        tools: [tool], output: { try await sink.send($0) },
        onOutputFailure: { failure.mark() })
    _ = await session.receive(try message("tools/call", params: ["name": .string("oversized")]))
    for _ in 0..<1000 {
        if failure.marked { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    #expect(failure.marked)
    #expect(await sink.count() == 0)
    #expect(await session.receive(try message("ping", id: 2)) == false)
    await session.shutdown()
}

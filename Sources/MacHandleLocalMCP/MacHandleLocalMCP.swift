import Darwin
import Foundation
import LocalBridgeTransport
import MCPServer
import ReminderMCPContract

/// Local stdio relay. No provider, credentials, policy administration or approval method.
@main
struct MacHandleLocalMCP {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard
            args == ["--private-sample"] || args == ["--private-reminders"]
                || args == ["--sample-writes"]
        else { exit(64) }
        do {
            let configuration = try PrivateBridgeConfiguration.load(helper: true)
            guard (configuration.mode == .sample) == (args == ["--private-sample"]) else {
                exit(64)
            }
            guard (configuration.mode == .sampleWrites) == (args == ["--sample-writes"]) else {
                exit(64)
            }
            let client = SignedLocalClient(service: configuration.service, peer: configuration.peer)
            defer { client.close() }
            // Start native per-launch review. This public discovery envelope cannot approve itself.
            let introduction = try MCPJSON.object([
                "version": .number(1), "tool": .string("list_reminder_lists"),
                "arguments": .object([:]),
            ]).encoded()
            _ = await client.send(introduction)
            guard client.isOpen else { exit(1) }
            let forward: @Sendable (String, [String: MCPJSON]) async throws -> MCPToolResult = {
                name, arguments in
                let envelope = try MCPJSON.object([
                    "version": .number(1), "tool": .string(name), "arguments": .object(arguments),
                ]).encoded()
                var parser = try MCPJSONParser(await client.send(envelope))
                guard let value = try parser.parse()["result"], client.isOpen else {
                    throw LocalBridgeFailure.unavailable
                }
                return MCPToolResult(
                    value: value,
                    validate: {
                        try Task.checkCancellation()
                        guard client.isOpen else { throw LocalBridgeFailure.unavailable }
                    })
            }
            let tools =
                ReminderReadTools.make(execute: forward)
                + (configuration.mode == .sampleWrites
                    ? ReminderMutationTools.make(privateSession: true, execute: forward) : [])
            let status = await MCPStdioServer.run(
                tools: tools,
                profile: configuration.mode == .sample
                    ? .privateSample
                    : (configuration.mode == .sampleWrites ? .privateWrites : .privateReminders))
            client.close()
            exit(status)
        } catch { exit(1) }
    }
}

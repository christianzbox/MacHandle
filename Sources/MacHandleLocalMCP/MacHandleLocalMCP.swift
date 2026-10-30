import Darwin
import Foundation
import LocalBridgeTransport
import MCPServer
import ReminderMCPContract

/// Local stdio relay. No provider, credentials, policy administration or approval method.
@main
struct MacHandleLocalMCP {
    static func main() async {
        guard Array(CommandLine.arguments.dropFirst()) == ["--private-sample"] else { exit(64) }
        do {
            let configuration = try PrivateBridgeConfiguration.load(helper: true)
            let client = SignedLocalClient(service: configuration.service, peer: configuration.peer)
            defer { client.close() }
            // Start native per-launch review. This public discovery envelope cannot approve itself.
            let introduction = try MCPJSON.object([
                "version": .number(1), "tool": .string("list_reminder_lists"),
                "arguments": .object([:]),
            ]).encoded()
            _ = await client.send(introduction)
            guard client.isOpen else { exit(1) }
            let tools = ReminderReadTools.make { name, arguments in
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
            let status = await MCPStdioServer.run(tools: tools, profile: .privateSample)
            client.close()
            exit(status)
        } catch { exit(1) }
    }
}

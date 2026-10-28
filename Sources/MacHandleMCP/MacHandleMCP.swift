import Darwin
import MCPCalendarAdapter
import MCPServer

@main
struct MacHandleMCP {
    static func main() async {
        guard CommandLine.arguments.dropFirst() == ["--synthetic"] else {
            let message = "Usage: machandle-mcp --synthetic (stdio pipes; synthetic tools only)\n"
            _ = message.withCString { Darwin.write(STDERR_FILENO, $0, message.utf8.count) }
            exit(64)
        }
        do {
            let tools = MCPTool.synthetic + (try await SyntheticCalendarTools.make())
            exit(await MCPSyntheticServer.run(tools: tools))
        } catch { exit(1) }
    }
}

import Darwin
import Foundation
import LocalBridgeTransport

/// Bounded newline read-envelope probe, not an MCP server or a production helper configuration.
@main
struct BridgeProbe {
    static func main() async {
        signal(SIGPIPE, SIG_IGN)
        do {
            let args = try FixtureArguments(Array(CommandLine.arguments.dropFirst()), broker: false)
            for fd in [STDIN_FILENO, STDOUT_FILENO] {
                var info = stat()
                guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFIFO,
                    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) == 0
                else { throw LocalBridgeFailure.unavailable }
            }
            let client = SignedLocalClient(service: args.service, peer: args.peer)
            defer { client.close() }
            var pending = Data()
            var count = 0
            while count < 16 {
                var byte: UInt8 = 0
                try ready(STDIN_FILENO, Int16(POLLIN))
                let amount = Darwin.read(STDIN_FILENO, &byte, 1)
                if amount == 0 {
                    if !pending.isEmpty { throw LocalBridgeFailure.unavailable }
                    return
                }
                guard amount == 1 else { throw LocalBridgeFailure.unavailable }
                if byte == 10 {
                    count += 1
                    var response = await client.send(pending)
                    pending.removeAll(keepingCapacity: true)
                    response.append(10)
                    try response.withUnsafeBytes { bytes in
                        var offset = 0
                        while offset < bytes.count {
                            try ready(STDOUT_FILENO, Int16(POLLOUT))
                            let sent = Darwin.write(
                                STDOUT_FILENO, bytes.baseAddress!.advanced(by: offset),
                                bytes.count - offset)
                            guard sent > 0 else { throw LocalBridgeFailure.unavailable }
                            offset += sent
                        }
                    }
                } else {
                    guard pending.count < 16_384 else { throw LocalBridgeFailure.unavailable }
                    pending.append(byte)
                }
            }
        } catch { exit(1) }
    }
    private static func ready(_ fd: Int32, _ events: Int16) throws {
        var descriptor = pollfd(fd: fd, events: events, revents: 0)
        guard poll(&descriptor, 1, 5_000) > 0, descriptor.revents & Int16(POLLERR | POLLNVAL) == 0
        else {
            throw LocalBridgeFailure.unavailable
        }
    }
}

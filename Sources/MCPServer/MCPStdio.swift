import Darwin
import Dispatch
import Foundation

/// One read and bounded concurrent writes; the writer queue never interleaves JSON frames.
/// Pipe/local-socket endpoints avoid changing terminal or regular-file descriptor flags.
final class MCPStdioChannel: @unchecked Sendable {
    private let input: Int32
    private let output: Int32
    private let wakeRead: Int32
    private let wakeWrite: Int32
    private let lock = NSLock()
    private var stopped = false
    private var failed = false
    private let reader = DispatchQueue(label: "MacHandle.MCP.read")
    private let writer = DispatchQueue(label: "MacHandle.MCP.write")
    init(input: Int32 = STDIN_FILENO, output: Int32 = STDOUT_FILENO) throws {
        guard Self.isLocalStream(input), Self.isLocalStream(output) else {
            throw MCPWireFailure.io
        }
        let readFD = dup(input)
        guard readFD >= 0 else { throw MCPWireFailure.io }
        let writeFD = dup(output)
        guard writeFD >= 0 else {
            Darwin.close(readFD)
            throw MCPWireFailure.io
        }
        var wake: [Int32] = [0, 0]
        guard pipe(&wake) == 0 else {
            Darwin.close(readFD)
            Darwin.close(writeFD)
            throw MCPWireFailure.io
        }
        for fd in [readFD, writeFD, wake[0], wake[1]] {
            guard fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) == 0,
                fcntl(fd, F_SETFD, FD_CLOEXEC) == 0
            else {
                for handle in [readFD, writeFD, wake[0], wake[1]] { Darwin.close(handle) }
                throw MCPWireFailure.io
            }
        }
        self.input = readFD
        self.output = writeFD
        wakeRead = wake[0]
        wakeWrite = wake[1]
    }
    deinit { for fd in [input, output, wakeRead, wakeWrite] { Darwin.close(fd) } }
    func close(failed: Bool = false) {
        lock.withLock {
            self.failed = self.failed || failed
            guard !stopped else { return }
            stopped = true
            var byte: UInt8 = 1
            _ = Darwin.write(wakeWrite, &byte, 1)
        }
    }
    private var isClosed: Bool { lock.withLock { stopped } }
    var didFail: Bool { lock.withLock { failed } }
    private static func isLocalStream(_ fd: Int32) -> Bool {
        var info = stat()
        guard fstat(fd, &info) == 0 else { return false }
        if info.st_mode & S_IFMT == S_IFIFO { return true }
        guard info.st_mode & S_IFMT == S_IFSOCK else { return false }
        var kind: Int32 = 0
        var kindSize = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_TYPE, &kind, &kindSize) == 0, kind == SOCK_STREAM else {
            return false
        }
        var address = sockaddr_un()
        var size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &size) }
        }
        return result == 0 && address.sun_family == AF_UNIX
    }
    func read() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            reader.async {
                do {
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    while true {
                        try self.wait(self.input, events: Int16(POLLIN), timeout: -1)
                        let count = Darwin.read(self.input, &buffer, buffer.count)
                        if count >= 0 {
                            continuation.resume(returning: Data(buffer.prefix(count)))
                            return
                        }
                        if errno != EINTR && errno != EAGAIN { throw MCPWireFailure.io }
                    }
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    func write(_ data: Data) async throws {
        let cancellation = WriteCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                writer.async {
                    var offset = 0
                    do {
                        let deadline = ProcessInfo.processInfo.systemUptime + 2
                        try data.withUnsafeBytes { bytes in
                            while offset < bytes.count {
                                try cancellation.check()
                                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                                guard remaining > 0 else { throw MCPWireFailure.io }
                                try self.wait(
                                    self.output, events: Int16(POLLOUT),
                                    timeout: Int32(remaining * 1000))
                                try cancellation.check()
                                let count = Darwin.write(
                                    self.output, bytes.baseAddress!.advanced(by: offset),
                                    bytes.count - offset)
                                if count > 0 {
                                    offset += count
                                } else if count == 0 || (errno != EINTR && errno != EAGAIN) {
                                    throw MCPWireFailure.io
                                }
                            }
                        }
                        continuation.resume()
                    } catch is CancellationError {
                        if offset > 0 { self.close(failed: true) }
                        continuation.resume(throwing: CancellationError())
                    } catch MCPWireFailure.closed {
                        continuation.resume(throwing: MCPWireFailure.closed)
                    } catch {
                        self.close(failed: true)
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
    private func wait(_ fd: Int32, events: Int16, timeout: Int32) throws {
        guard !isClosed else { throw MCPWireFailure.closed }
        var descriptors = [
            pollfd(fd: fd, events: events, revents: 0),
            pollfd(fd: wakeRead, events: Int16(POLLIN), revents: 0),
        ]
        let result = poll(&descriptors, 2, timeout)
        guard !isClosed else { throw MCPWireFailure.closed }
        if result < 0 && errno == EINTR { return }
        guard result > 0 else { throw MCPWireFailure.io }
        // POLLHUP on input still permits draining buffered bytes, followed by EOF.
        guard descriptors[0].revents & Int16(POLLNVAL | POLLERR) == 0 else {
            throw MCPWireFailure.io
        }
    }
}

/// Bounded stdio execution with explicitly composed tools; no provider or policy dependencies.
package enum MCPStdioServer {
    package static func run(
        tools: [MCPTool] = MCPTool.synthetic, profile: MCPServerProfile = .synthetic
    ) async -> Int32 {
        signal(SIGPIPE, SIG_IGN)
        do {
            let channel = try MCPStdioChannel()
            let session = try MCPProtocolSession(
                tools: tools, profile: profile, output: { try await channel.write($0) },
                onOutputFailure: { channel.close(failed: true) })
            signal(SIGTERM, SIG_IGN)
            signal(SIGINT, SIG_IGN)
            let signals = [SIGTERM, SIGINT].map { number in
                let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
                source.setEventHandler { channel.close() }
                source.resume()
                return source
            }
            var framer = MCPLineFramer()
            var failed = false
            do {
                loop: while true {
                    let chunk = try await channel.read()
                    if chunk.isEmpty {
                        failed = framer.hasPartialFrame
                        break
                    }
                    for frame in try framer.append(chunk) {
                        if !(await session.receive(frame)) {
                            failed = true
                            break loop
                        }
                    }
                }
            } catch MCPWireFailure.closed {
                // EOF/signal/output closure stops the connection; no input or errors are logged.
            } catch { failed = true }
            channel.close()
            await session.shutdown()
            for source in signals { source.cancel() }
            return failed || channel.didFail ? 1 : 0
        } catch { return 1 }
    }
}

private final class WriteCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}

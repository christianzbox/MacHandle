import Darwin
import Foundation
import LocalBridgeTransport
import NativeMCPBridge

/// launchd-managed sample process; no EventKit, accounts, persistence or permission prompts.
@main
struct SampleBroker {
    static func main() {
        do {
            let args = try FixtureArguments(Array(CommandLine.arguments.dropFirst()), broker: true)
            let listener = SignedLocalListener(service: args.service, peer: args.peer) { gate in
                // Fixed marker in the task-owned harness log proves whether a request reached us.
                // Never print input, response, identifiers, errors or provider content.
                let marker = "sample-channel\n"
                _ = marker.withCString { Darwin.write(STDOUT_FILENO, $0, marker.utf8.count) }
                return try await ExternalSampleBroker.make(gate: gate, approved: args.approved)
            }
            // A fixture cannot remain indefinitely if its supervising test crashes.
            DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
                listener.close()
                exit(0)
            }
            withExtendedLifetime(listener) { RunLoop.current.run() }
        } catch { exit(64) }
    }
}

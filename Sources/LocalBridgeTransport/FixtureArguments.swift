import Foundation

/// Only for the opt-in probe executables. No app factory loads caller-provided signing policy.
package struct FixtureArguments: Sendable {
    package let service: String
    package let peer: PeerRequirement
    package let approved: Bool
    package init(_ arguments: [String], broker: Bool) throws {
        guard arguments.count == (broker ? 6 : 5), arguments[0] == "--fixture",
            arguments[1].hasPrefix("dev.machandle.fixture."), arguments[1].utf8.count <= 100,
            arguments[1].utf8.allSatisfy({
                (97...122).contains($0) || (48...57).contains($0) || [45, 46].contains($0)
            }),
            arguments[4] == "--sample-only",
            !broker || ["approved", "denied"].contains(arguments[5])
        else { throw LocalBridgeFailure.invalidConfiguration }
        service = arguments[1]
        peer = try .fixtureCodeHash(arguments[2], identifier: arguments[3])
        approved = broker && arguments[5] == "approved"
    }
}

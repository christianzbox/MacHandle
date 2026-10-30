import Foundation
import Security

/// Trusted composition chooses a requirement. No wire method or caller claim can replace it.
package struct PeerRequirement: Sendable {
    let expression: String

    /// Future team-signed composition; constructing this is not evidence of a signed deployment.
    package static func appleTeam(_ team: String, identifier: String) throws -> Self {
        guard team.count == 10,
            team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) })
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        return try make(
            "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(try checkedIdentifier(identifier))\""
        )
    }

    /// Account-free fixture only: exact code hash plus identifier, never identifier alone.
    package static func fixtureCodeHash(_ hash: String, identifier: String) throws -> Self {
        guard hash.count == 40,
            hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        return try make(
            "cdhash H\"\(hash)\" and identifier \"\(try checkedIdentifier(identifier))\"")
    }
    private static func checkedIdentifier(_ value: String) throws -> String {
        guard (1...128).contains(value.utf8.count),
            value.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                    || [45, 46].contains($0)
            })
        else { throw LocalBridgeFailure.invalidConfiguration }
        return value
    }
    private static func make(_ expression: String) throws -> Self {
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(expression as CFString, [], &parsed) == errSecSuccess,
            parsed != nil
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        // Parse first because the Foundation setter raises an ObjC exception for malformed syntax.
        return Self(expression: expression)
    }
}

package enum LocalBridgeFailure: Error { case invalidConfiguration, unavailable }

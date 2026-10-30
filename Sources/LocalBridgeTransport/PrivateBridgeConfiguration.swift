import CryptoKit
import Foundation
import Security

/// A private build owns its local certificate. No Keychain or Apple developer account lookup occurs.
package struct PrivateBridgeConfiguration: Sendable {
    private static let identifierPrefix = "org.machandle.private-sample."
    package let service: String
    package let peer: PeerRequirement
    package let sandboxCanary: URL?

    package static func load(app: Bundle = .main, helper: Bool) throws -> Self {
        var ownCode: SecCode?
        guard SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        var ownStaticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(ownCode, [], &ownStaticCode) == errSecSuccess, let ownStaticCode
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                ownStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess,
            let info = information as? [String: Any],
            let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
            let leaf = certificates.first,
            let ownID = info[kSecCodeInfoIdentifier as String] as? String,
            ownID.hasPrefix(identifierPrefix), ownID.hasSuffix(helper ? ".helper" : ".app")
        else { throw LocalBridgeFailure.invalidConfiguration }
        let suffix = ownID.dropFirst(identifierPrefix.count).split(separator: ".")
        guard suffix.count == 2, suffix[0].count == 32,
            suffix[0].utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        let root = identifierPrefix + suffix[0]
        let appIdentifier = root + ".app"
        let helperIdentifier = root + ".helper"
        let fingerprint = Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
            .map { String(format: "%02x", $0) }.joined()
        // Bind disk signing metadata back to this running code, not a PID/path assertion.
        let ownRequirement = try PeerRequirement.localCertificate(fingerprint, identifier: ownID)
        var parsedOwnRequirement: SecRequirement?
        guard
            SecRequirementCreateWithString(
                ownRequirement.expression as CFString, [], &parsedOwnRequirement) == errSecSuccess,
            SecCodeCheckValidity(ownCode, [], parsedOwnRequirement) == errSecSuccess
        else {
            throw LocalBridgeFailure.invalidConfiguration
        }
        let appRequirement = try PeerRequirement.localCertificate(
            fingerprint, identifier: appIdentifier)
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard app.bundleIdentifier == appIdentifier,
            SecStaticCodeCreateWithPath(app.bundleURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecRequirementCreateWithString(appRequirement.expression as CFString, [], &requirement)
                == errSecSuccess,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate),
                requirement) == errSecSuccess,
            let url = app.url(forResource: "PrivateBridge", withExtension: "json"),
            let data = try? Data(contentsOf: url), data.count <= 4096,
            let document = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            Set(document.keys).isSubset(of: ["service", "mode", "sandboxCanary"]),
            document["mode"] == "synthetic-reminders-only", let service = document["service"],
            service.hasPrefix("dev.machandle.fixture."), service.utf8.count <= 100,
            service.utf8.allSatisfy({
                (97...122).contains($0) || (48...57).contains($0) || [45, 46].contains($0)
            })
        else { throw LocalBridgeFailure.invalidConfiguration }
        return Self(
            service: service,
            peer: try .localCertificate(
                fingerprint, identifier: helper ? appIdentifier : helperIdentifier),
            sandboxCanary: document["sandboxCanary"].map { URL(fileURLWithPath: $0) })
    }
}

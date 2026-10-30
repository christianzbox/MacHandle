import Foundation
import Testing

@testable import LocalBridgeTransport

@Test func peerRequirementsRejectUntrustedSyntax() throws {
    let hash = String(repeating: "a", count: 40)
    #expect(throws: LocalBridgeFailure.self) {
        try PeerRequirement.fixtureCodeHash("", identifier: "fixture")
    }
    #expect(throws: LocalBridgeFailure.self) {
        try PeerRequirement.fixtureCodeHash(hash, identifier: "x\" or true")
    }
    #expect(throws: LocalBridgeFailure.self) {
        try PeerRequirement.fixtureCodeHash(
            String(repeating: "g", count: 40), identifier: "fixture")
    }
    #expect(throws: LocalBridgeFailure.self) {
        try PeerRequirement.appleTeam("", identifier: "fixture")
    }
    let fixture = try PeerRequirement.fixtureCodeHash(
        hash, identifier: "dev.machandle.fixture.helper")
    #expect(fixture.expression.contains("cdhash"))
    let team = try PeerRequirement.appleTeam(
        "SAMPLE0000", identifier: "dev.machandle.fixture.helper")
    #expect(team.expression.contains("anchor apple generic"))
    #expect(team.expression.contains("certificate leaf[subject.OU]"))
}

@Test func fixtureConfigurationNeverDefaultsToTrust() throws {
    let hash = String(repeating: "a", count: 40)
    #expect(throws: LocalBridgeFailure.self) { try FixtureArguments([], broker: false) }
    #expect(throws: LocalBridgeFailure.self) {
        try FixtureArguments(
            ["--fixture", "other.service", hash, "fixture", "--sample-only"], broker: false)
    }
    #expect(throws: LocalBridgeFailure.self) {
        try FixtureArguments(
            ["--fixture", "dev.machandle.fixture.sample", hash, "fixture", "--sample-only", "yes"],
            broker: true)
    }
    let config = try FixtureArguments(
        ["--fixture", "dev.machandle.fixture.sample", hash, "fixture", "--sample-only", "denied"],
        broker: true)
    #expect(!config.approved)
}

@Test func absentBrokerIsUnavailableAndDoesNotReconnect() async throws {
    let peer = try PeerRequirement.fixtureCodeHash(
        String(repeating: "a", count: 40), identifier: "fixture")
    let client = SignedLocalClient(
        service: "dev.machandle.fixture.\(UUID().uuidString.lowercased())", peer: peer)
    #expect(await client.send(Data("{}".utf8)) == SignedLocalClient.unavailable)
    #expect(!client.isOpen)
    #expect(await client.send(Data("{}".utf8)) == SignedLocalClient.unavailable)
}

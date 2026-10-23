import Foundation
import MacHandleFoundation
import Testing

/// Verifies package linkage and bundled synthetic test resources; not integration coverage.
@Test func foundationLoadsSyntheticFixture() throws {
    struct Fixture: Decodable {
        let _synthetic: Bool
        let productName: String
        let developmentNotice: String
    }

    let url = try #require(
        Bundle.module.url(
            forResource: "foundation", withExtension: "json", subdirectory: "Fixtures")
    )
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    #expect(fixture._synthetic)
    #expect(fixture.productName == BuildInfo.productName)
    #expect(fixture.developmentNotice == BuildInfo.developmentNotice)
}

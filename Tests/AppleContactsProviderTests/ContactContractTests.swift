import CoreDomain
import Foundation
import Testing

@testable import AppleContactsProvider

@Test func contactRequestsRejectEmptyAndForeignOrUnifiedResults() throws {
    let container = try ContactContainerReference(
        account: AccountReference(
            provider: ProviderID("synthetic"), store: StoreID("fixture"),
            account: AccountID("fixture")), localID: DomainID("selected"))
    #expect(throws: (any Error).self) { try ContactReadRequest(scopes: [:]) }
    #expect(throws: (any Error).self) { try ContactReadRequest(scopes: [container: .records([])]) }
    let request = try ContactReadRequest(scopes: [container: .records([ContactID("selected")])])
    let observation = ObservationState(
        observedAt: try Instant(Date(timeIntervalSince1970: 1_800_000_000)),
        completeness: .complete, freshness: .localCache)
    for contact in [
        try Contact(
            id: .record(ContactRecordReference(container: container, item: ContactID("foreign")))),
        try Contact(
            id: .unified(
                provider: ProviderID("synthetic"), store: StoreID("fixture"),
                item: ContactID("selected"))),
    ] {
        #expect(throws: (any Error).self) {
            try ContactSnapshot(coverage: request, contacts: [contact], observation: observation)
        }
    }
}

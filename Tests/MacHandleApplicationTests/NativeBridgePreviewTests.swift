import Foundation
import Testing

@testable import MacHandleApplication

@Test @MainActor func nativeBridgePreviewRequiresReviewAndClearsDataOnRevoke() async throws {
    let model = NativeBridgePreviewModel()
    #expect(model.phase == .idle)
    await model.read()
    #expect(model.titles.isEmpty)
    await model.start()
    #expect(model.phase == .review)
    let id = try #require(model.reviewID)
    await model.approve(UUID())
    #expect(model.phase == .review)
    await model.approve(id)
    #expect(model.phase == .connected)
    await model.read()
    #expect(model.titles == ["Synthetic grocery reminder"])
    await model.stop(revoke: true)
    #expect(model.phase == .closed && model.titles.isEmpty && model.reviewID == nil)
    await model.read()
    #expect(model.titles.isEmpty)
    await model.start()
    #expect(model.phase == .review && model.reviewID != id)
    await model.approve(id)
    #expect(model.phase == .review)
    await model.stop()
}

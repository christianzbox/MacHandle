import Foundation
import Testing

@testable import MacHandleApplication

@Test @MainActor func sampleActionReviewRejectsStaleAndForeignUISelections() async throws {
    let model = ActionApprovalPreviewModel()
    await model.prepare(.update)
    let first = try #require(model.review)
    await model.prepare(.delete)
    let current = try #require(model.review)
    await model.confirm(first.id, acknowledgeDeletion: true)
    #expect(model.review?.id == current.id)
    await model.confirm(UUID(), acknowledgeDeletion: true)
    #expect(model.review?.id == current.id)
    await model.confirm(current.id, acknowledgeDeletion: false)
    #expect(model.review == nil)
    #expect(model.message.contains("rejected"))
}
@Test @MainActor func sampleActionApprovalExecutesOnlyMockAndClearsDismissedReview() async throws {
    let model = ActionApprovalPreviewModel()
    await model.prepare(.create)
    let review = try #require(model.review)
    await model.confirm(review.id, acknowledgeDeletion: false)
    #expect(model.review == nil && !model.isBusy)
    #expect(model.message.contains("No real calendar was changed"))
    await model.prepare(.update)
    let dismissed = try #require(model.review)
    await model.cancel()
    await model.confirm(dismissed.id, acknowledgeDeletion: true)
    #expect(model.review == nil && model.message.contains("dismissed"))
}

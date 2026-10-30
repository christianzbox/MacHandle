import MacHandleApplication
import Testing

@Test @MainActor func unsignedPresentationCannotActivatePrivateBridgeOrApproveItself() async {
    let model = PrivateConnectionModel()
    #expect(model.phase == .idle)
    model.start()
    #expect(model.phase == .unavailable)
    #expect(model.reviewID == nil)
    await model.approve()
    #expect(model.phase == .unavailable)
    await model.stop()
    #expect(model.phase == .closed)
}

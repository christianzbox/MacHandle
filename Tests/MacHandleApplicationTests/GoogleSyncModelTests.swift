import CoreDomain
import Foundation
import MacHandleApplication
import Testing

private let syncSource = CalendarReference(
    account: AccountReference(
        provider: try! ProviderID("synthetic"), store: try! StoreID("local"),
        account: try! AccountID("account")), localID: try! DomainID("calendar"))

private actor ReviewService: CalendarSyncManaging {
    var current = CalendarSyncStatus(phase: .ready)
    var held: CheckedContinuation<CalendarSyncPreview, any Error>?
    var waiter: CheckedContinuation<Void, Never>?
    var started = false
    var confirms: [(UUID, Bool)] = []
    var revocations: [Bool] = []
    var value: CalendarSyncConfiguration?
    func setStatus(_ value: CalendarSyncStatus) { current = value }
    func status() -> CalendarSyncStatus { current }
    func connect() -> CalendarSyncStatus { current }
    func preview(_ configuration: CalendarSyncConfiguration) async throws -> CalendarSyncPreview {
        value = configuration
        started = true
        waiter?.resume()
        waiter = nil
        return try await withCheckedThrowingContinuation { held = $0 }
    }
    func wait() async { if !started { await withCheckedContinuation { waiter = $0 } } }
    func release(mismatch: Bool = false) {
        let config = mismatch ? CalendarSyncConfiguration() : value!
        held?.resume(
            returning: .init(
                id: UUID(), configuration: config, items: [],
                expiresAt: Date().addingTimeInterval(300)))
        held = nil
    }
    func confirm(_ reviewID: UUID, approveDeletions: Bool) -> CalendarSyncStatus {
        confirms.append((reviewID, approveDeletions))
        return .init(phase: .waiting)
    }
    func pause() -> CalendarSyncStatus {
        current = .init(phase: .paused)
        return current
    }
    func disconnect(revokeGrant: Bool) -> CalendarSyncStatus {
        revocations.append(revokeGrant)
        current = .init(phase: .disconnected)
        return current
    }
}

@Test @MainActor func syncModelDefaultDoesNotActivateAnything() async {
    let model = GoogleSyncModel()
    await model.refresh()
    #expect(model.status.phase == .unconfigured && model.configuration.fields.isEmpty)
    await model.connect()
    await model.preview()
    #expect(model.failure == .notConfigured && model.review == nil && !model.isBusy)
}

@Test @MainActor func syncModelLatePreviewCannotUndoPrivacyChangeOrDisconnect() async {
    let service = ReviewService()
    let model = GoogleSyncModel(service: service)
    await model.configure(.init(sources: [syncSource], fields: [.title]))
    let task = Task { await model.preview() }
    await service.wait()
    await model.configure(.init(sources: [syncSource]))
    await model.disconnect()
    await service.release()
    await task.value
    #expect(model.review == nil && model.configuration.sources.isEmpty)
    #expect(model.status.phase == .disconnected && !model.isBusy)
    #expect(await service.confirms.isEmpty)
    #expect(await service.revocations == [false])
}

@Test @MainActor func syncModelRejectsMismatchedPreviewAndObsoleteDialog() async throws {
    let service = ReviewService()
    let model = GoogleSyncModel(service: service)
    await model.configure(.init(sources: [syncSource]))
    let first = Task { await model.preview() }
    await service.wait()
    await service.release(mismatch: true)
    await first.value
    #expect(model.review == nil && model.failure == .staleReview)
    let another = ReviewService()
    let other = GoogleSyncModel(service: another)
    await other.configure(.init(sources: [syncSource]))
    let task = Task { await other.preview() }
    await another.wait()
    await another.release()
    await task.value
    let review = try #require(other.review)
    await other.confirm(reviewID: UUID(), approveDeletions: true)
    #expect(await another.confirms.isEmpty)
    await other.confirm(reviewID: review.id)
    #expect(await another.confirms.count == 1)
    await other.confirm(reviewID: review.id, approveDeletions: true)
    #expect(await another.confirms.count == 1)
}

@Test @MainActor func syncModelRefreshDoesNotRestoreUserDeselectedSources() async {
    let service = ReviewService()
    let saved = CalendarSyncConfiguration(sources: [syncSource], fields: [.title])
    await service.setStatus(.init(phase: .paused, configuration: saved))
    let model = GoogleSyncModel(service: service)
    await model.refresh()
    #expect(model.configuration == saved)
    await model.configure(.init())
    await service.setStatus(.init(phase: .paused, configuration: saved))
    await model.refresh()
    #expect(model.configuration.sources.isEmpty && model.configuration.fields.isEmpty)
}

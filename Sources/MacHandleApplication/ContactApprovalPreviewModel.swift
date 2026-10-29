import ActionApprovals
import Foundation
import Observation

// Public presentation types only; the live approval authority stays package internal.
public typealias SampleContactActionKind = ContactActionKind
public typealias SampleContactActionReview = ContactReviewDisplay

@Observable @MainActor
public final class ContactApprovalPreviewModel {
    public private(set) var review: SampleContactActionReview?
    public private(set) var isBusy = false
    public private(set) var message = "Try a sample action. Nothing is sent to a real contact."
    private var engine: ContactApprovalEngine?
    private var pending: ContactReview?
    private var generation = UUID()
    public init() {}
    public func prepare(_ kind: SampleContactActionKind) async {
        guard !isBusy else { return }
        isBusy = true
        let old = engine
        engine = nil
        pending = nil
        review = nil
        generation = UUID()
        let expected = generation
        defer { isBusy = false }
        await old?.invalidate()
        do {
            let fixture = try await SyntheticContactActionFixture.make()
            let controller = ContactApprovalEngine(
                session: fixture.session, provider: fixture.provider, authorized: { true })
            let result = try await controller.prepare(fixture.change(kind))
            guard expected == generation, !Task.isCancelled else {
                await controller.invalidate()
                return
            }
            engine = controller
            pending = result
            review = result.display
            message = "Review the exact sample change. This review expires after two minutes."
        } catch {
            if expected == generation { message = "The sample review could not be prepared." }
        }
    }
    public func confirm(_ reviewID: UUID, acknowledgeDeletion: Bool, deletionPhrase: String = "")
        async
    {
        guard !isBusy, let pending, pending.display.id == reviewID, let engine else { return }
        isBusy = true
        self.pending = nil
        review = nil
        let expected = generation
        defer { isBusy = false }
        do {
            let confirmation = try await engine.confirm(
                pending, acknowledgeDeletion: acknowledgeDeletion, deletionPhrase: deletionPhrase)
            let result = await engine.commit(confirmation)
            if expected == generation {
                message =
                    result == .applied
                    ? "Sample contact changed. No real Contact was modified."
                    : (result == .unknown
                        ? "Outcome unknown. Further changes are blocked; do not retry."
                        : "Sample change not applied. Prepare a new review.")
            }
        } catch {
            if expected == generation {
                message = "Approval was rejected or expired. Prepare a new sample review."
            }
        }
    }
    public func cancel() async {
        generation = UUID()
        let old = engine
        engine = nil
        pending = nil
        review = nil
        message = "Sample review dismissed. An action already dispatched may still finish."
        await old?.invalidate()
    }
}

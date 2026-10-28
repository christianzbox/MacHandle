import ActionApprovals
import Foundation
import Observation

// Public presentation types only; the live approval authority stays package internal.
public typealias SampleActionKind = ActionKind
public typealias SampleActionReview = ActionReviewDisplay

@Observable @MainActor
public final class ActionApprovalPreviewModel {
    public private(set) var review: SampleActionReview?
    public private(set) var isBusy = false
    public private(set) var message = "Try a sample action. Nothing is sent to a real calendar."
    private var engine: CalendarApprovalEngine?
    private var pending: ActionReview?
    private var generation = UUID()
    public init() {}
    public func prepare(_ kind: SampleActionKind) async {
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
            let fixture = try await SyntheticActionFixture.make()
            let controller = CalendarApprovalEngine(
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
    public func confirm(_ reviewID: UUID, acknowledgeDeletion: Bool) async {
        guard !isBusy, let pending, pending.display.id == reviewID, let engine else { return }
        isBusy = true
        self.pending = nil
        review = nil
        let expected = generation
        defer { isBusy = false }
        do {
            let confirmation = try await engine.confirm(
                pending, acknowledgeDeletion: acknowledgeDeletion)
            let result = await engine.commit(confirmation)
            if expected == generation { message = result.message }
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

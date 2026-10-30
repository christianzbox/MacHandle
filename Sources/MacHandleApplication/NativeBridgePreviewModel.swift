import Foundation
import NativeMCPBridge
import Observation

/// Fixed sample session only. No native provider, saved grant or OS permission is accessed.
@Observable @MainActor
public final class NativeBridgePreviewModel {
    public enum Phase: Sendable { case idle, review, connected, closed }
    public private(set) var phase: Phase = .idle
    public private(set) var isBusy = false
    public private(set) var reviewID: UUID?
    public private(set) var titles: [String] = []
    public private(set) var message = "Start a sample launch to review a local read connection."
    private var session: SampleBridgeSession?
    private var generation = UUID()
    public init() {}

    public func start() async {
        guard !isBusy, phase == .idle || phase == .closed else { return }
        let expected = begin()
        defer { finish(expected) }
        do {
            let newSession = try await SampleBridgeSession.make()
            guard current(expected) else {
                await newSession.close()
                return
            }
            session = newSession
            let review = try await newSession.broker.prepareReview()
            guard current(expected) else {
                await newSession.close()
                return
            }
            reviewID = review.id
            phase = .review
            message =
                "Allow this sample launch to read the selected sample list? Review expires in 60 seconds."
        } catch { await fail(expected) }
    }
    public func approve(_ id: UUID) async {
        guard !isBusy, phase == .review, reviewID == id, let session else { return }
        let expected = begin()
        defer { finish(expected) }
        reviewID = nil
        do {
            try await session.broker.approve(id)
            guard current(expected) else {
                await session.close()
                return
            }
            phase = .connected
            message = "Sample launch paired. Read-only access lasts until this sample session ends."
        } catch { await fail(expected) }
    }
    public func read() async {
        guard !isBusy, phase == .connected, let session else { return }
        let expected = begin()
        defer { finish(expected) }
        titles = []
        do {
            let result = try await session.readSampleTitles()
            guard current(expected) else { return }
            titles = result
            message = "Sample results received through XPC. No personal Reminders were read."
        } catch { await fail(expected) }
    }
    public func stop(revoke: Bool = false) async {
        generation = UUID()
        isBusy = false
        let old = session
        session = nil
        reviewID = nil
        titles = []
        phase = .closed
        message =
            revoke
            ? "Sample connection revoked. A new sample launch needs a new review."
            : "Sample connection closed. A new sample launch needs a new review."
        await old?.close(revoke: revoke)
    }
    private func begin() -> UUID {
        generation = UUID()
        isBusy = true
        return generation
    }
    private func current(_ expected: UUID) -> Bool { generation == expected && !Task.isCancelled }
    private func finish(_ expected: UUID) { if generation == expected { isBusy = false } }
    private func fail(_ expected: UUID) async {
        guard generation == expected else { return }
        generation = UUID()
        let old = session
        session = nil
        isBusy = false
        reviewID = nil
        titles = []
        phase = .closed
        message = "Sample connection unavailable or review expired. Start a new sample launch."
        await old?.close()
    }
}

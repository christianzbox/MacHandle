import CoreDomain
import Foundation
import Observation

/// This public default has no runtime factory, provider, credential store or side effects.
private struct UnconfiguredSync: CalendarSyncManaging {
    func status() async -> CalendarSyncStatus {
        .init(phase: .unconfigured, failure: .notConfigured)
    }
    func connect() async -> CalendarSyncStatus { await status() }
    func preview(_ configuration: CalendarSyncConfiguration) async throws -> CalendarSyncPreview {
        throw CalendarSyncFailure.notConfigured
    }
    func confirm(_ reviewID: UUID, approveDeletions: Bool) async -> CalendarSyncStatus {
        await status()
    }
    func pause() async -> CalendarSyncStatus { await status() }
    func disconnect(revokeGrant: Bool) async -> CalendarSyncStatus { await status() }
}

/// Local UI only. Late results cannot restore a review after selection/privacy/pause/disconnect.
@Observable @MainActor
public final class GoogleSyncModel {
    public private(set) var status = CalendarSyncStatus(phase: .unconfigured)
    public private(set) var configuration = CalendarSyncConfiguration()
    public private(set) var review: CalendarSyncPreview?
    public private(set) var isBusy = false
    public private(set) var failure: CalendarSyncFailure?
    private let service: any CalendarSyncManaging
    private var generation = UUID()
    private var hasDraft = false

    public init(service: (any CalendarSyncManaging)? = nil) {
        self.service = service ?? UnconfiguredSync()
    }
    public func refresh() async {
        guard !isBusy else { return }
        let token = generation
        let value = await service.status()
        guard token == generation else { return }
        status = value
        failure = value.failure
        // Restored candidates are displayed but never auto-connect or auto-resume.
        if !hasDraft, review == nil { configuration = value.configuration }
        if value.phase != .reviewing { review = nil }
    }
    public func configure(_ value: CalendarSyncConfiguration) async {
        guard value != configuration else { return }
        hasDraft = true
        configuration = value
        await pause()
    }
    public func connect() async {
        guard !isBusy else { return }
        let token = begin()
        let value = await service.connect()
        finish(token, value)
    }
    public func preview() async {
        guard !isBusy else { return }
        let token = begin()
        let requested = configuration
        do {
            let result = try await service.preview(requested)
            guard generation == token else { return }
            guard result.configuration == requested else { throw CalendarSyncFailure.staleReview }
            review = result
            status = .init(
                phase: .reviewing, configuration: requested, lastSuccess: status.lastSuccess)
            isBusy = false
        } catch {
            guard generation == token else { return }
            let failure = error as? CalendarSyncFailure ?? .unavailable
            let value = await service.status()
            guard generation == token else { return }
            self.failure = failure
            status = value
            isBusy = false
        }
    }
    public func confirm(reviewID: UUID? = nil, approveDeletions: Bool = false) async {
        guard !isBusy, let review, review.configuration == configuration,
            reviewID == nil || reviewID == review.id
        else { return }
        let token = begin()
        let value = await service.confirm(review.id, approveDeletions: approveDeletions)
        finish(token, value)
    }
    public func pause() async {
        let token = begin()
        finish(token, await service.pause())
    }
    public func disconnect(revokeGrant: Bool = false) async {
        let token = begin()
        hasDraft = true
        configuration = .init()
        finish(token, await service.disconnect(revokeGrant: revokeGrant))
    }
    private func begin() -> UUID {
        generation = UUID()
        review = nil
        failure = nil
        isBusy = true
        return generation
    }
    private func finish(_ token: UUID, _ value: CalendarSyncStatus) {
        guard generation == token else { return }
        status = value
        failure = value.failure
        isBusy = false
    }
}

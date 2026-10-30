import CoreDomain
import Foundation
import PermissionEngine

package struct ActionReview: Sendable {
    package let display: ActionReviewDisplay
    fileprivate let issuer: UUID
    fileprivate let nonce: UUID
}
package struct ActionConfirmation: Sendable {
    fileprivate let issuer: UUID
    fileprivate let review: UUID
    fileprivate let nonce: UUID
}

/// Trusted local administration only. Never supply this actor or confirmation methods to an MCP client.
package actor CalendarApprovalEngine {
    private struct Entry {
        let proposal: ProposedChange<CalendarMutation>
        let snapshot: CalendarActionSnapshot
        let permits: [PolicyPermit]
        let reviewNonce: UUID
        let expires: TimeInterval
        var confirmation: UUID?
        var confirmationExpiry: TimeInterval?
    }
    private let issuer = UUID()
    private let session: PolicySession
    private let provider: any CalendarActionProvider
    private let authorized: @Sendable () async -> Bool
    private let uptime: @Sendable () -> TimeInterval
    private var entries: [UUID: Entry] = [:]
    private var preparing = 0
    private var executing = false
    private var closed = false
    private var unresolved = false
    private var generation = UUID()
    private var audit: [ActionAudit] = []
    private var sequence: UInt64 = 0

    package init(
        session: PolicySession, provider: any CalendarActionProvider,
        authorized: @escaping @Sendable () async -> Bool = { false },
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.session = session
        self.provider = provider
        self.authorized = authorized
        self.uptime = uptime
    }
    package func activity() -> [ActionAudit] { audit }
    private func log(_ phase: ActionAudit.Phase, _ id: OperationID? = nil) {
        sequence &+= 1
        audit.append(
            ActionAudit(
                sequence: sequence, operation: id, connection: session.connectionID, phase: phase))
        if audit.count > 128 { audit.removeFirst(audit.count - 128) }
    }
    private func prune() { entries = entries.filter { $0.value.expires > uptime() } }
    private func available(_ expected: UUID) throws {
        try Task.checkCancellation()
        guard !closed, generation == expected else { throw ActionFailure.stale }
        guard !unresolved else { throw ActionFailure.unresolved }
    }
    private func check(_ permits: [PolicyPermit], generation expected: UUID, expires: TimeInterval)
        async throws
    {
        try available(expected)
        guard uptime() < expires else { throw ActionFailure.expired }
        guard await authorized() else { throw ActionFailure.denied }
        try available(expected)
        for permit in permits {
            guard case .allowed = await session.revalidate(permit) else {
                throw ActionFailure.denied
            }
            try available(expected)
        }
        guard uptime() < expires else { throw ActionFailure.expired }
    }
    package func prepare(_ change: CalendarMutation) async throws -> ActionReview {
        prune()
        try available(generation)
        guard !executing, preparing < 4 else { throw ActionFailure.busy }
        guard entries.count + preparing < 16 else { throw ActionFailure.capacity }
        try CalendarActionReview.validate(change)
        preparing += 1
        defer { preparing -= 1 }
        let expected = generation
        let expires = uptime() + 120
        let proposal = ProposedChange(
            id: try OperationID(UUID().uuidString), connection: session.connectionID, change: change
        )
        do {
            guard await authorized() else { throw ActionFailure.denied }
            try available(expected)
            guard case .allowed(let mutation) = await session.evaluate(.calendarMutation(proposal))
            else { throw ActionFailure.denied }
            var permits = [mutation]
            if !change.reviewFields.isEmpty {
                guard
                    case .allowed(let read) = await session.evaluate(
                        .calendarMutationReview(proposal, fields: change.reviewFields))
                else { throw ActionFailure.denied }
                permits.append(read)
            }
            try await check(permits, generation: expected, expires: expires)
            let snapshot = CalendarActionReview.project(
                try await provider.inspect(change, fields: change.reviewFields),
                fields: change.reviewFields)
            try await check(permits, generation: expected, expires: expires)
            let id = UUID()
            let display = try CalendarActionReview.make(id: id, change: change, snapshot: snapshot)
            let nonce = UUID()
            entries[id] = Entry(
                proposal: proposal, snapshot: snapshot, permits: permits,
                reviewNonce: nonce, expires: expires)
            log(.prepared, proposal.id)
            return ActionReview(display: display, issuer: issuer, nonce: nonce)
        } catch {
            log(.rejected, proposal.id)
            throw ActionFailure.denied
        }
    }
    /// Local user interaction only. Deletion requires a separate explicit acknowledgement.
    package func confirm(_ review: ActionReview, acknowledgeDeletion: Bool = false) async throws
        -> ActionConfirmation
    {
        prune()
        guard review.issuer == issuer, var entry = entries[review.display.id],
            entry.reviewNonce == review.nonce, entry.confirmation == nil,
            entry.proposal.change.kind != .delete || acknowledgeDeletion
        else { throw ActionFailure.denied }
        // Reserve before suspension: concurrent clicks cannot issue two confirmations.
        let nonce = UUID()
        entry.confirmation = nonce
        entry.confirmationExpiry = min(entry.expires, uptime() + 30)
        entries[review.display.id] = entry
        let expected = generation
        do {
            try await check(entry.permits, generation: expected, expires: entry.confirmationExpiry!)
            guard entries[review.display.id]?.confirmation == nonce else {
                throw ActionFailure.stale
            }
            log(.confirmed, entry.proposal.id)
            return ActionConfirmation(issuer: issuer, review: review.display.id, nonce: nonce)
        } catch {
            entries.removeValue(forKey: review.display.id)
            log(.rejected, entry.proposal.id)
            throw ActionFailure.denied
        }
    }
    package func reject(_ review: ActionReview) {
        guard review.issuer == issuer, let entry = entries[review.display.id],
            entry.reviewNonce == review.nonce
        else { return }
        entries.removeValue(forKey: review.display.id)
        log(.rejected, entry.proposal.id)
    }
    package func invalidate() {
        closed = true
        generation = UUID()
        entries.removeAll()
        log(.invalidated)
        // An already dispatched write may finish. It must report its actual outcome, not a rollback claim.
    }
    package func commit(_ confirmation: ActionConfirmation) async -> ActionOutcome {
        guard confirmation.issuer == issuer, let entry = entries[confirmation.review],
            entry.confirmation == confirmation.nonce
        else { return .notApplied }
        // Consume exactly once with serialized admission, before every suspension and all failure paths.
        entries.removeValue(forKey: confirmation.review)
        guard !executing else {
            log(.rejected, entry.proposal.id)
            return .notApplied
        }
        executing = true
        defer { executing = false }
        let expected = generation
        do {
            try await check(
                entry.permits, generation: expected, expires: entry.confirmationExpiry ?? 0)
            let current = CalendarActionReview.project(
                try await provider.inspect(
                    entry.proposal.change, fields: entry.proposal.change.reviewFields),
                fields: entry.proposal.change.reviewFields)
            guard current == entry.snapshot else { throw ActionFailure.stale }
            try await check(
                entry.permits, generation: expected, expires: entry.confirmationExpiry ?? 0)
        } catch {
            log(.notApplied, entry.proposal.id)
            return .notApplied
        }
        log(.dispatched, entry.proposal.id)
        let outcome: ActionOutcome
        do {
            let receipt = try await provider.apply(
                AuthorizedCalendarAction(
                    proposal: entry.proposal,
                    expected: entry.snapshot, fields: entry.proposal.change.reviewFields,
                    authorization: {
                        do {
                            try await self.check(
                                entry.permits, generation: expected,
                                expires: entry.confirmationExpiry ?? 0)
                            return true
                        } catch { return false }
                    }))
            switch receipt {
            case .applied(let id): outcome = id == entry.proposal.id ? .applied : .unknown
            case .notApplied: outcome = .notApplied
            case .unknown: outcome = .unknown
            }
        } catch { outcome = .unknown }
        if outcome == .unknown {
            unresolved = true
            entries.removeAll()
        }
        switch outcome {
        case .applied: log(.applied, entry.proposal.id)
        case .notApplied: log(.notApplied, entry.proposal.id)
        case .unknown: log(.unknown, entry.proposal.id)
        }
        return outcome
    }
}

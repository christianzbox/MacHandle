import ActionApprovals
import CoreDomain
import Foundation
import PermissionEngine
import SyncPersistence

/// Backend is internal: neither callers nor the UI may manufacture a live writer.
protocol ContactMutationBackend: Sendable {
    func inspect(_ change: ContactMutation, fields: Set<ContactField>) async throws
        -> ContactActionSnapshot
    func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt
}

/// Durable admission shared across engines. Never stores arguments, personal identifiers or event text.
package actor JournaledContactProvider: ContactActionProvider {
    private let backend: any ContactMutationBackend
    private let journal: ContactMutationJournal
    private var executing = false
    private var unresolved = false

    init(backend: any ContactMutationBackend, journal: ContactMutationJournal) {
        self.backend = backend
        self.journal = journal
    }
    /// Closed until signed peer/OS/grant wiring, isolated live acceptance and conflict semantics pass.
    /// No caller boolean, environment variable, build flag or public constructor overrides this gate.
    package static func live(journal: ContactMutationJournal) throws -> JournaledContactProvider {
        throw ActionFailure.denied
    }
    package func inspect(_ change: ContactMutation, fields: Set<ContactField>) async throws
        -> ContactActionSnapshot
    {
        guard !executing, !unresolved else { throw ActionFailure.unresolved }
        try await journal.requireReady()
        guard !executing, !unresolved else { throw ActionFailure.unresolved }
        return try await backend.inspect(change, fields: fields)
    }
    package func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt {
        guard !executing, !unresolved,
            let id = UUID(uuidString: action.proposal.id.rawValue)
        else { return .notApplied }
        executing = true
        defer { executing = false }
        do { try await journal.begin(id) } catch {
            // Persistence failure happens before dispatch; nevertheless latch this instance closed.
            unresolved = true
            return .notApplied
        }
        let receipt: ContactActionReceipt
        let permitted = await action.revalidate()
        if Task.isCancelled || !permitted {
            receipt = .notApplied
        } else {
            do { receipt = try await backend.apply(action) } catch { receipt = .unknown }
        }
        let state: ContactMutationState
        switch receipt {
        case .applied(let operation): state = operation == action.proposal.id ? .applied : .unknown
        case .notApplied: state = .notApplied
        case .unknown: state = .unknown
        }
        // Accepted effects are not rolled back on cancellation. Persist the actual receipt first.
        do { try await journal.finish(id, state: state) } catch {
            unresolved = true
            return .unknown
        }
        if state == .unknown {
            unresolved = true
            return .unknown
        }
        return receipt
    }
}

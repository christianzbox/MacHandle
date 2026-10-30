import ActionApprovals
import CoreDomain
import Foundation
import MCPConnections
import MCPRemindersAdapter
import MCPServer
import NativeMCPBridge
import PermissionEngine
import ReminderMutations
import SyncPersistence

/// Fixed sample source only; no caller-selected provider or live-writer factory.
package struct SampleWriteComposition: Sendable {
    package let source: SyntheticReminderActionProvider
    package let list: ReminderListReference
    package let actions: SampleWriteActions
    package static func make(
        journal: ReminderMutationJournal,
        onReview: @escaping @Sendable (String?, ReminderReviewDisplay?) async -> Void = { _, _ in },
        onOutcome: @escaping @Sendable (ActionOutcome) async -> Void = { _ in }
    ) async throws -> Self {
        try await journal.requireReady()
        let seed = try await SyntheticReminderActionFixture.make()
        return Self(
            source: seed.provider, list: seed.list,
            actions: SampleWriteActions(
                source: seed.provider, list: seed.list, journal: journal,
                onReview: onReview, onOutcome: onOutcome))
    }
    package func broker(channel: ConnectionChannel) async throws -> NativeReadBroker {
        let controller = try ConnectionController(store: MemoryConnectionSettings())
        await controller.observePermissions(OSPermissions(reminders: .fullAccess))
        let grant = try SavedReminderGrant(
            reference: list, operations: [.discover, .summary, .details],
            fields: [.title, .notes, .due, .completion, .recurrence])
        let record = try await controller.configure(
            label: "Native sample changes", grants: [], reminderGrants: [grant])
        return NativeReadBroker(
            controller: controller, channel: channel, record: record,
            reader: source, authorization: { await source.authorization() },
            additionalTools: { lease, reads in try await actions.bind(lease: lease, reads: reads) },
            closeAdditional: { await actions.close() })
    }
}

package actor SampleWriteActions {
    private let source: SyntheticReminderActionProvider
    private let list: ReminderListReference
    private let journal: ReminderMutationJournal
    private let onReview: @Sendable (String?, ReminderReviewDisplay?) async -> Void
    private let onOutcome: @Sendable (ActionOutcome) async -> Void
    private var adapter: ReminderMutationAdapter?
    private var closed = false
    private var binding = false
    init(
        source: SyntheticReminderActionProvider, list: ReminderListReference,
        journal: ReminderMutationJournal,
        onReview: @escaping @Sendable (String?, ReminderReviewDisplay?) async -> Void,
        onOutcome: @escaping @Sendable (ActionOutcome) async -> Void
    ) {
        self.source = source
        self.list = list
        self.journal = journal
        self.onReview = onReview
        self.onOutcome = onOutcome
    }
    package func bind(lease: ConnectionReadLease, reads: ReminderReadAdapter) async throws
        -> [MCPTool]
    {
        guard !closed, !binding, adapter == nil, lease.isOpen, lease.reminderSelection == [list]
        else { throw ActionFailure.denied }
        binding = true
        defer { binding = false }
        try await journal.requireReady()
        // Independent native write grant; the read lease still supplies channel identity/liveness.
        let authority = PolicyAuthority()
        await authority.observeOSPermissions(OSPermissions(reminders: .fullAccess))
        let id = lease.session.connectionID
        await authority.setConnection(
            Connection(id: id, kind: .localMCP, state: .enabled),
            policy: ConnectionPolicy(reminderLists: [
                list: ReminderGrant(
                    operations: [
                        .readDetails, .create, .update, .changeDueDate, .complete, .uncomplete,
                        .delete,
                    ],
                    readableFields: [.title, .notes, .due, .completion, .recurrence],
                    writableFields: [.title, .notes, .due, .completion])
            ]))
        let session = try await authority.bindTrustedConnection(id)
        let engine = ReminderApprovalEngine(
            session: session,
            provider: JournaledReminderProvider.sample(source: source, journal: journal),
            authorized: { lease.isOpen })
        let candidate = ReminderMutationAdapter(
            engine: engine, privateSession: true,
            onReview: onReview, onOutcome: onOutcome,
            resolve: { token, create in try await reads.resolveForMutation(token, create: create) },
            authorized: { lease.isOpen })
        guard !closed, lease.isOpen else {
            await candidate.close()
            throw ActionFailure.denied
        }
        adapter = candidate
        return candidate.tools()
    }
    package func confirm(_ token: String, deletion: Bool) async throws {
        guard !closed, let adapter else { throw ActionFailure.denied }
        try await adapter.confirmLocally(token, acknowledgeDeletion: deletion)
    }
    package func reject(_ token: String) async { await adapter?.rejectLocally(token) }
    package func close() async {
        closed = true
        await adapter?.close()
        adapter = nil
    }
}

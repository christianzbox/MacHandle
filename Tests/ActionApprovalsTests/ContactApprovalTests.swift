import CoreDomain
import Foundation
import PermissionEngine
import Testing

@testable import ActionApprovals

private final class ContactClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    func now() -> TimeInterval { lock.withLock { value } }
    func advance() { lock.withLock { value += 121 } }
}
private actor ContactSpy: ContactActionProvider {
    let base: SyntheticContactActionProvider
    var reads = 0
    var snapshot: ContactActionSnapshot?
    init(_ base: SyntheticContactActionProvider) { self.base = base }
    func override(_ snapshot: ContactActionSnapshot) { self.snapshot = snapshot }
    func inspect(_ change: ContactMutation, fields: Set<ContactField>) async throws
        -> ContactActionSnapshot
    {
        reads += 1
        if let snapshot { return snapshot }
        return try await base.inspect(change, fields: fields)
    }
    func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt {
        try await base.apply(action)
    }
}
struct ContactApprovalTests {
    @Test func threeOperationsRequireExactLocalConfirmationAndCannotReplay() async throws {
        for kind in ContactActionKind.allCases {
            let f = try await SyntheticContactActionFixture.make()
            let engine = ContactApprovalEngine(
                session: f.session, provider: f.provider, authorized: { true })
            let review = try await engine.prepare(f.change(kind))
            #expect(!String(describing: review.display.rows).contains("canary"))
            if kind == .delete {
                await #expect(throws: (any Error).self) { try await engine.confirm(review) }
                await #expect(throws: (any Error).self) {
                    try await engine.confirm(review, acknowledgeDeletion: true)
                }
                await #expect(throws: (any Error).self) {
                    try await engine.confirm(review, deletionPhrase: "DELETE")
                }
            }
            let confirmation = try await engine.confirm(
                review, acknowledgeDeletion: true, deletionPhrase: "DELETE")
            #expect(await engine.commit(confirmation) == .applied)
            #expect(await engine.commit(confirmation) == .notApplied)
            let after = try await f.provider.inspect(
                f.change(.delete), fields: ContactReadCapabilities.fields)
            if kind == .delete { #expect(after.contact == nil) }
            if kind == .update {
                #expect(after.contact?.organization == .value("Sample revised organization"))
                #expect(after.contact?.emailAddresses == f.contact.emailAddresses)
            }
            if kind == .create { #expect(after.contact?.name == f.contact.name) }
        }
    }
    @Test func independentFieldsSubsetAndGoogleAreDeniedBeforeObservation() async throws {
        for reason in 0..<5 {
            let f = try await SyntheticContactActionFixture.make()
            let spy = ContactSpy(f.provider)
            let engine = ContactApprovalEngine(
                session: f.session, provider: spy, authorized: { true })
            let fields: Set<ContactField> = reason == 0 ? [.name] : ContactReadCapabilities.fields
            await f.authority.setConnection(
                Connection(
                    id: f.session.connectionID, kind: reason == 4 ? .googleSync : .localMCP,
                    state: .enabled),
                policy: ConnectionPolicy(contactContainers: [
                    f.container: ContactGrant(
                        selection: reason == 1 ? .records([]) : .allRecords,
                        access: ResourceGrant(
                            operations: reason == 2 ? [.readFields] : [.readFields, .update],
                            readableFields: fields, writableFields: reason == 3 ? [] : fields))
                ]))
            let fresh = try await f.authority.bindTrustedConnection(f.session.connectionID)
            let active = ContactApprovalEngine(session: fresh, provider: spy, authorized: { true })
            await #expect(throws: (any Error).self) { try await active.prepare(f.change(.update)) }
            #expect(await spy.reads == 0)
            await engine.invalidate()
        }
    }
    @Test func observationNeverConfersMutationPermissionAndCreateNeedsWholeContainer() async throws
    {
        let f = try await SyntheticContactActionFixture.make()
        let proposal = ProposedChange(
            id: try OperationID("observation"), connection: f.session.connectionID,
            change: try f.change(.update))
        guard
            case .allowed = await f.session.evaluate(
                .contactMutationObservation(proposal, fields: proposal.change.reviewFields))
        else {
            Issue.record("Expected scoped observation")
            return
        }
        guard
            case .denied(.missingPrecondition) = await f.session.evaluate(
                .contactMutation(proposal))
        else {
            Issue.record("Observation became write authority")
            return
        }
        await f.authority.setConnection(
            Connection(id: f.session.connectionID, kind: .localMCP, state: .enabled),
            policy: ConnectionPolicy(contactContainers: [
                f.container: ContactGrant(
                    selection: .records([f.record.item]),
                    access: ResourceGrant(
                        operations: [.create], readableFields: [.name], writableFields: [.name]))
            ]))
        let session = try await f.authority.bindTrustedConnection(f.session.connectionID)
        let engine = ContactApprovalEngine(
            session: session, provider: f.provider, authorized: { true })
        await #expect(throws: (any Error).self) { try await engine.prepare(f.change(.create)) }
    }
    @Test func staleTargetUnknownRevisionUnifiedRecordAndHiddenFieldsCannotBeApproved() async throws
    {
        for mode in 0..<4 {
            let f = try await SyntheticContactActionFixture.make()
            let spy = ContactSpy(f.provider)
            let contact = Contact(
                id: mode == 0
                    ? .unified(
                        provider: f.container.account.provider, store: f.container.account.store,
                        item: f.record.item)
                    : .record(
                        mode == 1
                            ? ContactRecordReference(
                                container: f.container, item: try ContactID("foreign")) : f.record),
                name: f.contact.name,
                organization: mode == 3 ? .notFetched : f.contact.organization,
                revision: mode == 2 ? .unknown : f.contact.revision)
            await spy.override(
                ContactActionSnapshot(
                    container: f.container, accountLabel: "Sample", containerLabel: "Sample",
                    writable: true, contact: contact))
            let engine = ContactApprovalEngine(
                session: f.session, provider: spy, authorized: { true })
            await #expect(throws: (any Error).self) { try await engine.prepare(f.change(.update)) }
        }
    }
    @Test func expiryRevocationAndChangedObservationInvalidateReviewedAction() async throws {
        for mode in 0..<3 {
            let f = try await SyntheticContactActionFixture.make()
            let spy = ContactSpy(f.provider)
            let clock = ContactClock()
            let engine = ContactApprovalEngine(
                session: f.session, provider: spy, authorized: { true }, uptime: { clock.now() })
            let review = try await engine.prepare(f.change(.update))
            let confirmation = try await engine.confirm(review)
            if mode == 0 { clock.advance() }
            if mode == 1 {
                await f.authority.observeOSPermissions(OSPermissions(contacts: .denied))
            }
            if mode == 2 {
                await spy.override(
                    ContactActionSnapshot(
                        container: f.container, accountLabel: "Moved", containerLabel: "Changed",
                        writable: false, contact: f.contact))
            }
            #expect(await engine.commit(confirmation) == .notApplied)
        }
    }
    @Test func noOpRestrictedNotesAndForeignConfirmationFailClosed() async throws {
        let f = try await SyntheticContactActionFixture.make()
        let engine = ContactApprovalEngine(
            session: f.session, provider: f.provider, authorized: { true })
        await #expect(throws: (any Error).self) {
            try await engine.prepare(
                .update(
                    f.record, changes: ContactChanges(organization: .set("Sample organization")),
                    precondition: .unknown))
        }
        await #expect(throws: (any Error).self) {
            try await engine.prepare(
                .update(
                    f.record, changes: ContactChanges(notes: .set("never")), precondition: .unknown)
            )
        }
        let review = try await engine.prepare(f.change(.update))
        let other = ContactApprovalEngine(
            session: f.session, provider: f.provider, authorized: { true })
        await #expect(throws: (any Error).self) { try await other.confirm(review) }
        let confirmation = try await engine.confirm(review)
        #expect(await other.commit(confirmation) == .notApplied)
        #expect(await engine.commit(confirmation) == .applied)
        let audit = await engine.activity()
        #expect(!String(describing: audit).contains("Sample organization"))
    }
}

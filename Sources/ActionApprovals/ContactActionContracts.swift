import CoreDomain
import Foundation
import PermissionEngine

public enum ContactActionKind: String, CaseIterable, Identifiable, Sendable {
    case create, update, delete
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}
public struct ContactReviewDisplay: Sendable, Identifiable {
    public let id: UUID
    public let kind: ContactActionKind
    public let account: String
    public let container: String
    public let rows: [ActionReviewDisplay.Row]
    public let scope: String
}
package struct ContactActionSnapshot: Equatable, Sendable {
    package let container: ContactContainerReference
    package let accountLabel: String
    package let containerLabel: String
    package let writable: Bool
    package let contact: Contact?
    package init(
        container: ContactContainerReference, accountLabel: String, containerLabel: String,
        writable: Bool, contact: Contact? = nil
    ) {
        self.container = container
        self.accountLabel = accountLabel
        self.containerLabel = containerLabel
        self.writable = writable
        self.contact = contact
    }
}
package protocol ContactActionProvider: Sendable {
    func inspect(_ change: ContactMutation, fields: Set<ContactField>) async throws
        -> ContactActionSnapshot
    func apply(_ action: AuthorizedContactAction) async throws -> ContactActionReceipt
}
package struct AuthorizedContactAction: Sendable {
    package let proposal: ProposedChange<ContactMutation>
    package let expected: ContactActionSnapshot
    package let fields: Set<ContactField>
    private let authorization: @Sendable () async -> Bool
    init(
        proposal: ProposedChange<ContactMutation>, expected: ContactActionSnapshot,
        fields: Set<ContactField>, authorization: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.proposal = proposal
        self.expected = expected
        self.fields = fields
        self.authorization = authorization
    }
    package func revalidate() async -> Bool { await authorization() }
}
package enum ContactActionReceipt: Sendable {
    case applied(OperationID)
    case notApplied, unknown
}
extension ContactMutation {
    package var target: ContactContainerReference {
        switch self {
        case .create(let c, _): c
        case .update(let r, _, _), .delete(let r, _): r.container
        }
    }
    package var item: ContactRecordReference? {
        switch self {
        case .create: nil
        case .update(let r, _, _), .delete(let r, _): r
        }
    }
    package var precondition: MutationPrecondition? {
        switch self {
        case .create: nil
        case .update(_, _, let p), .delete(_, let p): p
        }
    }
    package var changes: ContactChanges? {
        switch self {
        case .create(_, let p), .update(_, let p, _): p
        case .delete: nil
        }
    }
    package func observed(_ revision: MutationPrecondition) -> ContactMutation {
        switch self {
        case .create: self
        case .update(let r, let p, _): .update(r, changes: p, precondition: revision)
        case .delete(let r, _): .delete(r, precondition: revision)
        }
    }
    package var kind: ContactActionKind {
        switch self {
        case .create: .create
        case .update: .update
        case .delete: .delete
        }
    }
    package var reviewFields: Set<ContactField> {
        switch self {
        case .create: []
        case .update(_, let p, _): p.changedFields.union([.name])
        case .delete: ContactReadCapabilities.fields
        }
    }
}

import CoreDomain
import Foundation

package enum ContactActionReview {
    private static func text(_ value: String) throws -> String {
        try CalendarActionReview.text(value, limit: 4096, multiline: true)
    }
    package static func validate(_ change: ContactMutation) throws {
        guard let patch = change.changes else { return }
        guard !patch.notes.isChanged else { throw ActionFailure.invalid }
        if change.kind == .create {
            guard case .set(let name) = patch.name,
                !(name.given + name.family).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw ActionFailure.invalid }
        }
        // One shared field renderer validates both proposed and observed values, without hidden fields.
        let proposed = applying(
            patch,
            to: Contact(
                id: .record(
                    ContactRecordReference(
                        container: change.target, item: try ContactID("validation")))))
        for field in patch.changedFields { _ = try display(proposed, field: field) }
    }
    package static func applying(
        _ patch: ContactChanges, to old: Contact, revision: MutationPrecondition? = nil
    ) -> Contact {
        func apply<T>(_ change: ValueChange<T>, _ value: FieldValue<T>) -> FieldValue<T> {
            if case .set(let updated) = change { return .value(updated) }
            return value
        }
        return Contact(
            id: old.id, name: apply(patch.name, old.name),
            emailAddresses: apply(patch.emailAddresses, old.emailAddresses),
            phoneNumbers: apply(patch.phoneNumbers, old.phoneNumbers),
            postalAddresses: apply(patch.postalAddresses, old.postalAddresses),
            organization: apply(patch.organization, old.organization), notes: old.notes,
            revision: revision ?? old.revision)
    }
    package static func project(_ snapshot: ContactActionSnapshot, fields: Set<ContactField>)
        -> ContactActionSnapshot
    {
        let contact = snapshot.contact.map { value in
            Contact(
                id: value.id, name: fields.contains(.name) ? value.name : .notFetched,
                emailAddresses: fields.contains(.emailAddresses)
                    ? value.emailAddresses : .notFetched,
                phoneNumbers: fields.contains(.phoneNumbers) ? value.phoneNumbers : .notFetched,
                postalAddresses: fields.contains(.postalAddresses)
                    ? value.postalAddresses : .notFetched,
                organization: fields.contains(.organization) ? value.organization : .notFetched,
                revision: value.revision)
        }
        return ContactActionSnapshot(
            container: snapshot.container, accountLabel: snapshot.accountLabel,
            containerLabel: snapshot.containerLabel, writable: snapshot.writable, contact: contact)
    }
    private static func value<T>(_ field: FieldValue<T>) throws -> T {
        guard case .value(let value) = field else { throw ActionFailure.invalid }
        return value
    }
    package static let orderedFields: [ContactField] = [
        .name, .emailAddresses, .phoneNumbers, .postalAddresses, .organization,
    ]
    package static func label(_ field: ContactField) -> String {
        switch field {
        case .name: "Given and family name"
        case .emailAddresses: "Email addresses (replace entire field)"
        case .phoneNumbers: "Phone numbers (replace entire field)"
        case .postalAddresses: "Postal addresses (replace entire field)"
        case .organization: "Organization"
        case .notes: "Unavailable"
        }
    }
    package static func display(_ contact: Contact, field: ContactField) throws -> String {
        func quote(_ string: String) throws -> String {
            try CalendarActionReview.displayText(text(string), multiline: true)
        }
        func labeled<T>(_ values: [LabeledValue<T>], encode: (T) throws -> String) throws -> String
        {
            guard values.count <= 32 else { throw ActionFailure.capacity }
            if values.isEmpty { return "None" }
            let result = try values.map {
                try "\(quote($0.label ?? "Unlabeled")): \(encode($0.value))"
            }.joined(separator: "\n")
            guard result.utf8.count <= 8192 else { throw ActionFailure.capacity }
            return result
        }
        switch field {
        case .name:
            let name = try value(contact.name)
            return try "Given: \(quote(name.given))\nFamily: \(quote(name.family))"
        case .emailAddresses: return try labeled(value(contact.emailAddresses), encode: quote)
        case .phoneNumbers: return try labeled(value(contact.phoneNumbers), encode: quote)
        case .postalAddresses:
            return try labeled(value(contact.postalAddresses)) { address in
                try [
                    address.street, address.city, address.region, address.postalCode,
                    address.country,
                ].map(quote).joined(separator: " | ")
            }
        case .organization:
            return try CalendarActionReview.displayText(
                value(contact.organization).map(text), multiline: true)
        case .notes: throw ActionFailure.invalid
        }
    }
    static func make(id: UUID, change: ContactMutation, snapshot: ContactActionSnapshot) throws
        -> ContactReviewDisplay
    {
        guard snapshot.container == change.target, snapshot.writable else {
            throw ActionFailure.denied
        }
        let account = try CalendarActionReview.text(snapshot.accountLabel, limit: 256)
        let container = try CalendarActionReview.text(snapshot.containerLabel, limit: 256)
        guard !account.isEmpty, !container.isEmpty else { throw ActionFailure.invalid }
        var rows: [ActionReviewDisplay.Row] = []
        if case .create(_, let patch) = change {
            guard snapshot.contact == nil else { throw ActionFailure.invalid }
            let proposed = applying(
                patch,
                to: Contact(
                    id: .record(
                        ContactRecordReference(container: change.target, item: try ContactID("new"))
                    )))
            for field in orderedFields where patch.changedFields.contains(field) {
                rows.append(.init(label(field), nil, try display(proposed, field: field)))
            }
        } else {
            guard let contact = snapshot.contact, case .record(let ref) = contact.id,
                ref == change.item,
                case .revision = contact.revision, contact.revision == change.precondition
            else { throw ActionFailure.stale }
            let proposed = change.changes.map { applying($0, to: contact) }
            for field in orderedFields where change.reviewFields.contains(field) {
                rows.append(
                    .init(
                        label(field), try display(contact, field: field),
                        try proposed.map { try display($0, field: field) }))
            }
            guard rows.contains(where: { $0.before != $0.after }) else {
                throw ActionFailure.invalid
            }
        }
        guard
            rows.reduce(0, { $0 + ($1.before?.utf8.count ?? 0) + ($1.after?.utf8.count ?? 0) })
                <= 32768
        else { throw ActionFailure.capacity }
        return ContactReviewDisplay(
            id: id, kind: change.kind, account: account, container: container, rows: rows,
            scope: change.kind == .delete
                ? "Deletes one entire underlying record, including properties not displayed (such as photos and notes). No undo is promised."
                : "One underlying record only. Listed arrays are full replacements. Unchanged fields stay untouched; no linking, merge, group or container move."
        )
    }
}

import ActionApprovals
import CoreDomain
import Foundation
import MCPServer

/// Trusted composition supplies a bound engine and target resolver. No live factory or wire approval.
actor ContactMutationAdapter {
    private struct Entry {
        let review: ContactReview
        let expires: TimeInterval
        var confirmation: ContactConfirmation?
    }
    private let engine: ContactApprovalEngine
    private let resolve:
        @Sendable (String, Bool) async throws -> (
            ContactContainerReference, ContactRecordReference?
        )
    private let authorized: @Sendable () async -> Bool
    private let uptime: @Sendable () -> TimeInterval
    private var entries: [String: Entry] = [:]
    private var preparing = 0
    init(
        engine: ContactApprovalEngine,
        resolve:
            @escaping @Sendable (String, Bool) async throws -> (
                ContactContainerReference, ContactRecordReference?
            ),
        authorized: @escaping @Sendable () async -> Bool = { false },
        uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.engine = engine
        self.resolve = resolve
        self.authorized = authorized
        self.uptime = uptime
    }
    nonisolated func tools() -> [MCPTool] {
        [
            MCPTool(
                name: "propose_contact_change",
                description:
                    "Prepare a Contact create/update/delete for local review. Does not execute or approve. This synthetic helper uses a separate sample connection: targetId sample-container for create or sample-contact otherwise. No real data. Names require both givenName and familyName. Email/phone arrays replace the entire field with unlabeled values; empty organization clears it. No notes, postal edits, links, groups or container moves.",
                parameters: [
                    .init("operation", kind: .string(maximum: 10)),
                    .init("targetId", kind: .string(maximum: 36)),
                    .init("givenName", kind: .string(maximum: 512), required: false),
                    .init("familyName", kind: .string(maximum: 512), required: false),
                    .init("organization", kind: .string(maximum: 4096), required: false),
                    .init(
                        "emailAddresses",
                        kind: .strings(maximum: 32, itemMaximum: 256, choices: nil), required: false
                    ),
                    .init(
                        "phoneNumbers", kind: .strings(maximum: 32, itemMaximum: 256, choices: nil),
                        required: false),
                ],
                outputSchema: ContactJSON.object([
                    "actionId": ContactJSON.string,
                    "status": ContactJSON.choice(["pendingLocalApproval"]),
                ]),
                execute: { try await self.propose($0) }),
            MCPTool(
                name: "commit_contact_change",
                description:
                    "Execute exactly one previously locally confirmed Contact action. An action ID is not approval. The standalone synthetic helper has no native approval channel, so its proposals cannot execute. Never retry an unknown result.",
                parameters: [.init("actionId", kind: .string(maximum: 36))],
                outputSchema: ContactJSON.object([
                    "status": ContactJSON.choice([
                        "notApproved", "applied", "notApplied", "unknown",
                    ])
                ]),
                mutating: true, execute: { try await self.commit($0) }),
        ]
    }
    private func access() async throws {
        try Task.checkCancellation()
        guard await authorized() else { throw ContactReadFailure.unavailable }
        try Task.checkCancellation()
    }
    private func reply(_ value: MCPJSON) async throws -> MCPToolResult {
        try await access()
        return MCPToolResult(value: value, validate: { try await self.access() })
    }
    func propose(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        entries = entries.filter { $0.value.expires > uptime() }
        guard preparing < 4, entries.count + preparing < 16,
            let raw = args["operation"]?.string, let kind = ContactActionKind(rawValue: raw),
            let token = args["targetId"]?.string
        else { throw ContactReadFailure.unavailable }
        preparing += 1
        defer { preparing -= 1 }
        let allowed: Set<String> =
            kind == .delete
            ? ["operation", "targetId"]
            : [
                "operation", "targetId", "givenName", "familyName", "organization",
                "emailAddresses", "phoneNumbers",
            ]
        guard Set(args.keys).isSubset(of: allowed) else { throw ContactReadFailure.unavailable }
        let (container, item) = try await resolve(token, kind == .create)
        try await access()
        let change: ContactMutation
        if kind == .create {
            guard item == nil, args["givenName"] != nil, args["familyName"] != nil else {
                throw ContactReadFailure.unavailable
            }
            change = .create(in: container, fields: try Self.patch(args))
        } else {
            guard let item, item.container == container else {
                throw ContactReadFailure.unavailable
            }
            if kind == .update {
                change = .update(item, changes: try Self.patch(args), precondition: .unknown)
            } else {
                change = .delete(item, precondition: .unknown)
            }
        }
        let review = try await engine.prepare(change)
        do { try await access() } catch {
            await engine.reject(review)
            throw error
        }
        let id = UUID().uuidString
        entries[id] = Entry(review: review, expires: uptime() + 120)
        return try await reply(
            .object(["actionId": .string(id), "status": .string("pendingLocalApproval")]))
    }
    /// Trusted native surface only. Intentionally absent from the tool registry and all decoded inputs.
    func reviewForLocalDisplay(_ id: String) async throws -> ContactReviewDisplay {
        try await access()
        guard let entry = entries[id], entry.expires > uptime() else {
            throw ContactReadFailure.unavailable
        }
        return entry.review.display
    }
    func confirmLocally(
        _ id: String, acknowledgeDeletion: Bool = false, deletionPhrase: String = ""
    ) async throws {
        try await access()
        guard let entry = entries[id], entry.expires > uptime(), entry.confirmation == nil
        else { throw ContactReadFailure.unavailable }
        let confirmation = try await engine.confirm(
            entry.review, acknowledgeDeletion: acknowledgeDeletion, deletionPhrase: deletionPhrase)
        guard entries[id] != nil else { throw ContactReadFailure.unavailable }
        entries[id]?.confirmation = confirmation
    }
    func commit(_ args: [String: MCPJSON]) async throws -> MCPToolResult {
        try await access()
        guard Set(args.keys) == ["actionId"], let id = args["actionId"]?.string,
            let entry = entries[id], entry.expires > uptime(), let confirmation = entry.confirmation
        else { return try await reply(.object(["status": .string("notApproved")])) }
        entries.removeValue(forKey: id)
        let outcome = await engine.commit(confirmation)
        return try await reply(.object(["status": .string(outcome.rawValue)]))
    }
    static func patch(_ args: [String: MCPJSON]) throws -> ContactChanges {
        let name: ValueChange<ContactName>
        if args["givenName"] != nil || args["familyName"] != nil {
            guard let given = args["givenName"]?.string, let family = args["familyName"]?.string
            else { throw ContactReadFailure.unavailable }
            name = .set(ContactName(given: given, family: family))
        } else {
            name = .unchanged
        }
        func array(_ key: String) throws -> ValueChange<[LabeledValue<String>]> {
            guard let value = args[key] else { return .unchanged }
            guard let items = value.array, items.count <= 32 else {
                throw ContactReadFailure.unavailable
            }
            return .set(
                try items.map { item in
                    guard let string = item.string, string.utf8.count <= 256 else {
                        throw ContactReadFailure.unavailable
                    }
                    return LabeledValue(label: nil, value: string)
                })
        }
        let organization: ValueChange<String?>
        if let raw = args["organization"] {
            guard let value = raw.string else { throw ContactReadFailure.unavailable }
            organization = .set(value.isEmpty ? nil : value)
        } else {
            organization = .unchanged
        }
        return try ContactChanges(
            name: name, emailAddresses: array("emailAddresses"),
            phoneNumbers: array("phoneNumbers"), organization: organization)
    }
}

import Foundation

package enum GoogleDurableKind: Sendable { case insert, update, delete }
package struct GoogleDurableCommand: Sendable {
    package let kind: GoogleDurableKind
    package let operationID: UUID
    package let creationID: UUID
    package let eventID: String
    package let expectedETag: String?
    package let previousContent: GoogleEventContent?
    package let content: GoogleEventContent?
    package init(
        kind: GoogleDurableKind, operationID: UUID, creationID: UUID, eventID: String,
        expectedETag: String?, previousContent: GoogleEventContent?, content: GoogleEventContent?
    ) {
        self.kind = kind
        self.operationID = operationID
        self.creationID = creationID
        self.eventID = eventID
        self.expectedETag = expectedETag
        self.previousContent = previousContent
        self.content = content
    }
    func validate() throws {
        guard GoogleCalendarRequest.validEventID(eventID),
            kind == .insert
                ? (expectedETag == nil && creationID == operationID && previousContent == nil)
                : (expectedETag.map(GoogleCalendarRequest.validETag) == true),
            (kind == .delete) == (content == nil)
        else { throw GoogleDestinationFailure.invalidInput }
        try content?.validate()
        try previousContent?.validate()
    }
}
/// No public or package initializer. Only GoogleDestinationClient's owned-session factory issues this.
package struct GoogleDurableDestination: Sendable {
    package let calendarID: String
    package let marker: String
    private let dispatch:
        @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void) async throws
            -> Void
    private let verify:
        @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void) async throws
            -> String?
    private let transfer:
        @Sendable (UUID, @escaping @Sendable () async throws -> Void) async throws -> Void
    private let inventory:
        @Sendable (@escaping @Sendable () async throws -> Void) async throws -> Set<String>
    private let baseline:
        @Sendable (GoogleRecoveryBaseline, @escaping @Sendable () async throws -> Void) async throws
            -> Void
    init(
        calendarID: String, marker: String,
        dispatch:
            @escaping @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void)
            async throws -> Void,
        verify:
            @escaping @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void)
            async throws -> String?,
        baseline:
            @escaping @Sendable (
                GoogleRecoveryBaseline, @escaping @Sendable () async throws -> Void
            ) async throws -> Void,
        inventory:
            @escaping @Sendable (@escaping @Sendable () async throws -> Void) async throws -> Set<
                String
            >,
        transfer:
            @escaping @Sendable (UUID, @escaping @Sendable () async throws -> Void) async throws ->
            Void
    ) {
        self.calendarID = calendarID
        self.marker = marker
        self.dispatch = dispatch
        self.verify = verify
        self.baseline = baseline
        self.inventory = inventory
        self.transfer = transfer
    }
    package func transferWriter(
        to recipient: UUID, beforeSend: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await transfer(recipient, beforeSend)
    }
    package func inventoryIDs(beforeSend: @escaping @Sendable () async throws -> Void) async throws
        -> Set<String>
    {
        try await inventory(beforeSend)
    }
    package func verifyBaseline(
        _ value: GoogleRecoveryBaseline, beforeSend: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await baseline(value, beforeSend)
    }
    package func send(
        _ command: GoogleDurableCommand, beforeSend: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await dispatch(command, beforeSend)
    }
    package func confirm(
        _ command: GoogleDurableCommand, beforeSend: @escaping @Sendable () async throws -> Void
    ) async throws -> String? {
        try await verify(command, beforeSend)
    }
}

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
    init(
        calendarID: String, marker: String,
        dispatch:
            @escaping @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void)
            async throws -> Void,
        verify:
            @escaping @Sendable (GoogleDurableCommand, @escaping @Sendable () async throws -> Void)
            async throws -> String?
    ) {
        self.calendarID = calendarID
        self.marker = marker
        self.dispatch = dispatch
        self.verify = verify
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

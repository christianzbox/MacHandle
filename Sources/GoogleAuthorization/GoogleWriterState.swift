import Foundation

/// Non-expiring cooperative writer assignment. Not a credential or a privacy proof.
struct GoogleWriterState: Codable, Equatable, Sendable {
    let version: Int
    let owner: String
    let writer: UUID
    let generation: UUID

    init(owner: String, writer: UUID) {
        version = 1
        self.owner = owner
        self.writer = writer
        generation = UUID()
    }
    func encoded() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
    static func parse(_ text: String?, owner: String) throws -> Self {
        guard let text, text.utf8.count <= 1024,
            let value = try? JSONDecoder().decode(Self.self, from: Data(text.utf8)),
            value.version == 1, value.owner == owner
        else { throw GoogleDestinationFailure.ownership }
        return value
    }
}

package struct GoogleRecoveryBaseline: Sendable {
    package let eventID: String
    package let creationID: UUID
    package let etag: String?
    package let content: GoogleEventContent?
    package init(eventID: String, creationID: UUID, etag: String?, content: GoogleEventContent?) {
        self.eventID = eventID
        self.creationID = creationID
        self.etag = etag
        self.content = content
    }
}

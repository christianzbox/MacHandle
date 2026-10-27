import Foundation

// Deliberately internal until signed activation, durable identity and privacy gates are met.
// UI/caller input cannot construct these capabilities through the exported module API.
struct GoogleDestination: Sendable, Hashable { let nonce: UUID }
struct GoogleEventInsert: Sendable, Hashable { let nonce: UUID }
struct GoogleObservedEvent: Sendable, Hashable { let nonce: UUID }

package struct GoogleEventTime: Codable, Equatable, Sendable {
    package let date: String?
    package let dateTime: String?
    package init(day: String) throws {
        guard Self.dayValue(day) != nil else { throw GoogleDestinationFailure.invalidInput }
        date = day
        dateTime = nil
    }
    package init(instant: Date) throws {
        guard instant.timeIntervalSince1970.isFinite else {
            throw GoogleDestinationFailure.invalidInput
        }
        date = nil
        dateTime = ISO8601DateFormatter().string(from: instant)
    }
    package var value: Date? {
        if let date, dateTime == nil { return Self.dayValue(date) }
        if let dateTime, date == nil {
            let parser = ISO8601DateFormatter()
            if let value = parser.date(from: dateTime) { return value }
            parser.formatOptions.insert(.withFractionalSeconds)
            return parser.date(from: dateTime)
        }
        return nil
    }
    package static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.date != nil || rhs.date != nil {
            return lhs.date == rhs.date && lhs.dateTime == nil && rhs.dateTime == nil
        }
        guard let first = lhs.value, let second = rhs.value else { return false }
        return first == second
    }
    private static func dayValue(_ day: String) -> Date? {
        guard day.utf8.count == 10 else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        parser.isLenient = false
        guard let value = parser.date(from: day), parser.string(from: value) == day else {
            return nil
        }
        return value
    }
}

package struct GoogleEventContent: Codable, Equatable, Sendable {
    package let summary: String
    package let description: String
    package let location: String
    package let start: GoogleEventTime
    package let end: GoogleEventTime
    package let transparency: String

    package init(
        start: GoogleEventTime, end: GoogleEventTime, summary: String = "Busy",
        description: String = "", location: String = "", isFree: Bool = false
    ) throws {
        self.summary = summary
        self.description = description
        self.location = location
        self.start = start
        self.end = end
        transparency = isFree ? "transparent" : "opaque"
        try validate()
    }
    func validate() throws {
        guard let first = start.value, let last = end.value, first < last,
            (start.date == nil) == (end.date == nil),
            [summary, description, location].allSatisfy({ $0.utf8.count <= 8192 }),
            ["opaque", "transparent"].contains(transparency)
        else { throw GoogleDestinationFailure.invalidInput }
    }
}

struct GoogleEventWire: Codable, Sendable {
    struct Properties: Codable, Sendable {
        var `private`: [String: String]
    }
    struct Reminders: Codable, Sendable { var useDefault: Bool }
    struct Guest: Codable, Sendable { var email: String? }
    let id: String
    var etag: String?
    var status: String?
    var summary: String?
    var description: String?
    var location: String?
    var start: GoogleEventTime?
    var end: GoogleEventTime?
    var transparency: String?
    var visibility: String?
    var extendedProperties: Properties?
    var reminders: Reminders?
    var attendees: [Guest]?
    var recurrence: [String]?
    var recurringEventId: String?

    init(id: String, owner: String, operation: String, content: GoogleEventContent) {
        self.id = id
        summary = content.summary
        description = content.description
        location = content.location
        start = content.start
        end = content.end
        transparency = content.transparency
        visibility = "private"
        extendedProperties = Properties(private: [
            "macHandleOwner": owner, "macHandleOperation": operation,
        ])
        reminders = Reminders(useDefault: false)
    }
    func content() throws -> GoogleEventContent {
        guard status == "confirmed", attendees?.isEmpty != false,
            recurrence?.isEmpty != false, recurringEventId == nil,
            let start, let end, let summary, let transparency,
            ["opaque", "transparent"].contains(transparency)
        else { throw GoogleDestinationFailure.invalidResponse }
        return try GoogleEventContent(
            start: start, end: end, summary: summary,
            description: description ?? "", location: location ?? "",
            isFree: transparency == "transparent")
    }
}

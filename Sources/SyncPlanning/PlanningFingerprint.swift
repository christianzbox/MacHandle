import CoreDomain
import CryptoKit
import Foundation

/// Versioned deterministic digest, not Swift Hasher, encryption, identity proof or a capability.
public struct PlanningFingerprint: Hashable, Sendable {
    public let value: String
    public init(_ value: String) throws {
        guard value.utf8.count == 64,
            value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { throw PlanningIssue.invalidInput }
        self.value = value
    }
    public static func content(_ content: PlannedEventContent) throws -> Self {
        guard
            [content.title, content.location, content.notes].allSatisfy({ $0.utf8.count <= 8192 })
        else {
            throw PlanningIssue.invalidInput
        }
        return digest(
            ["content-v1"] + time(content.time) + [
                content.isFree ? "free" : "busy", content.title, content.location, content.notes,
            ])
    }
    public static func calendar(_ source: CalendarReference) -> Self {
        digest(["calendar-v1"] + resource(source))
    }
    public static func occurrence(_ source: OccurrenceReference) throws -> Self {
        let anchor: [String]
        switch source.originalAnchor {
        case .unknown: throw PlanningIssue.ambiguousIdentity
        case .notRecurring: anchor = ["single"]
        case .timed(let instant): anchor = ["timed", instantKey(instant)]
        case .allDay(let date): anchor = ["day"] + day(date)
        }
        return digest(
            ["occurrence-v1"] + resource(source.calendar) + [source.item.rawValue] + anchor)
    }
    static func digest(_ fields: [String]) -> Self {
        var data = Data()
        // Byte-length prefixes prevent delimiter ambiguity; no locale, clock or random input.
        for field in fields {
            data.append(contentsOf: String(field.utf8.count).utf8)
            data.append(58)
            data.append(contentsOf: field.utf8)
        }
        return try! Self(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
    static func resource(_ value: CalendarReference) -> [String] {
        [
            value.account.provider.rawValue, value.account.store.rawValue,
            value.account.account.rawValue, value.localID.rawValue,
        ]
    }
    static func time(_ value: EventTime) -> [String] {
        switch value {
        case .timed(let interval, let zone):
            ["timed", instantKey(interval.start), instantKey(interval.end), zone.rawValue]
        case .allDay(let dates, let zone):
            ["allDay"] + day(dates.start) + day(dates.end) + [zone.rawValue]
        }
    }
    private static func day(_ date: LocalDate) -> [String] {
        [String(date.year), String(date.month), String(date.day)]
    }
    private static func instantKey(_ instant: Instant) -> String {
        let value = instant.date.timeIntervalSince1970
        return String((value == 0 ? 0.0 : value).bitPattern, radix: 16)
    }
}

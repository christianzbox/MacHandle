import CoreDomain
import Foundation
import MCPServer
import PermissionEngine

enum ReminderReadFailure: Error { case unavailable }
enum ReminderJSON {
    static func field<T>(_ value: FieldValue<T>, _ encode: (T) throws -> MCPJSON) throws -> MCPJSON
    {
        switch value {
        case .notFetched: .object(["state": .string("notFetched")])
        case .notAuthorized: .object(["state": .string("notAuthorized")])
        case .value(let value): .object(["state": .string("value"), "value": try encode(value)])
        }
    }
    static func text(_ value: String) throws -> MCPJSON {
        guard value.utf8.count <= 8192 else { throw ReminderReadFailure.unavailable }
        return .string(value)
    }
    static func due(_ value: ReminderDue?) -> MCPJSON {
        guard let value else { return .null }
        func date(_ d: LocalDate) -> String {
            String(format: "%04d-%02d-%02d", d.year, d.month, d.day)
        }
        switch value {
        case .date(let d):
            return .object([
                "kind": .string("date"), "date": .string(date(d)), "time": .null, "timeZone": .null,
            ])
        case .localDateTime(let d, let t, let zone):
            return .object([
                "kind": .string("localDateTime"), "date": .string(date(d)),
                "time": .string(String(format: "%02d:%02d:%02d", t.hour, t.minute, t.second)),
                "timeZone": zone.map { .string($0.rawValue) } ?? .null,
            ])
        }
    }
    static func reminder(_ value: Reminder, token: String, list: String, fields: Set<ReminderField>)
        throws -> MCPJSON
    {
        var content: [String: MCPJSON] = [:]
        if fields.contains(.title) { content["title"] = try field(value.title, text) }
        if fields.contains(.notes) {
            content["notes"] = try field(value.notes) { try $0.map(text) ?? .null }
        }
        if fields.contains(.due) { content["due"] = try field(value.due, due) }
        if fields.contains(.completion) {
            content["completion"] = try field(value.completion) {
                switch $0 {
                case .incomplete:
                    .object(["completed": .bool(false), "completedAtEpochSeconds": .null])
                case .completed(let at):
                    .object([
                        "completed": .bool(true),
                        "completedAtEpochSeconds": at.map { .number($0.date.timeIntervalSince1970) }
                            ?? .null,
                    ])
                }
            }
        }
        if fields.contains(.recurrence) {
            content["recurrence"] = try field(value.recurrence) {
                .string($0 == .recurring ? "recurring" : "notRecurring")
            }
        }
        return .object([
            "reminderId": .string(token), "listId": .string(list), "fields": .object(content),
        ])
    }
    static func observation(_ value: ObservationState, truncated: Bool = false) -> MCPJSON {
        let state: String
        switch value.completeness {
        case .complete: state = truncated ? "partial" : "complete"
        case .partial: state = "partial"
        case .unknown: state = "unknown"
        }
        // A successful local enumeration is never advertised as remote completeness/freshness.
        return .object([
            "completeness": .string(state),
            "observedAtEpochSeconds": .number(value.observedAt.date.timeIntervalSince1970),
            "freshness": .string(value.freshness == .localCache ? "localCache" : "unknown"),
        ])
    }
}

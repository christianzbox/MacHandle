import CoreDomain
import Foundation
import MCPServer

/// Explicit projection, never Codable/reflection over provider identities or revisions.
enum ReadJSON {
    static func interval(_ value: InstantInterval) -> MCPJSON {
        .object([
            "startEpochSeconds": .number(value.start.date.timeIntervalSince1970),
            "endEpochSeconds": .number(value.end.date.timeIntervalSince1970),
        ])
    }
    static func time(_ value: EventTime) -> MCPJSON {
        switch value {
        case .timed(let span, let zone):
            .object([
                "kind": .string("timed"), "interval": interval(span),
                "timeZone": .string(zone.rawValue),
            ])
        case .allDay(let span, let zone):
            .object([
                "kind": .string("allDay"), "startDate": .string(date(span.start)),
                "endDate": .string(date(span.end)), "timeZone": .string(zone.rawValue),
            ])
        }
    }
    private static func date(_ value: LocalDate) -> String {
        String(format: "%04d-%02d-%02d", value.year, value.month, value.day)
    }
    static func occupancy(_ value: Occupancy) -> MCPJSON {
        switch value {
        case .free: .string("free")
        case .busy: .string("busy")
        case .tentative: .string("tentative")
        case .unknown: .string("unknown")
        }
    }
    static func status(_ value: EventStatus) -> MCPJSON {
        switch value {
        case .active: .string("active")
        case .cancelled: .string("cancelled")
        case .unknown: .string("unknown")
        }
    }
    static func field(_ value: FieldValue<String?>) throws -> MCPJSON {
        switch value {
        case .notFetched: return .object(["state": .string("notFetched")])
        case .notAuthorized: return .object(["state": .string("notAuthorized")])
        case .value(let text):
            guard text == nil || text!.utf8.count <= 8192 else { throw ReadFailure.unavailable }
            return .object(["state": .string("value"), "value": text.map(MCPJSON.string) ?? .null])
        }
    }
    static func observation(_ value: ObservationState, truncated: Bool = false) -> MCPJSON {
        let completeness: String
        var reason: MCPJSON = .null
        switch value.completeness {
        case .complete:
            completeness = truncated ? "partial" : "complete"
            if truncated { reason = .string("outputLimit") }
        case .unknown: completeness = "unknown"
        case .partial(let partial):
            completeness = "partial"
            switch partial {
            case .morePages: reason = .string("morePages")
            case .providerLimit: reason = .string("providerLimit")
            case .interrupted: reason = .string("interrupted")
            }
        }
        let freshness: String
        var through: MCPJSON = .null
        switch value.freshness {
        case .unknown: freshness = "unknown"
        case .localCache: freshness = "localCache"
        case .verifiedThrough(let instant):
            freshness = "verifiedThrough"
            through = .number(instant.date.timeIntervalSince1970)
        }
        return .object([
            "observedAtEpochSeconds": .number(value.observedAt.date.timeIntervalSince1970),
            "completeness": .string(completeness), "partialReason": reason,
            "freshness": .string(freshness), "verifiedThroughEpochSeconds": through,
        ])
    }

    static func object(_ properties: [String: MCPJSON], required: [String]? = nil) -> MCPJSON {
        .object([
            "type": .string("object"), "properties": .object(properties),
            "required": .array((required ?? properties.keys.sorted()).map(MCPJSON.string)),
            "additionalProperties": .bool(false),
        ])
    }
    static func array(_ item: MCPJSON, max: Int) -> MCPJSON {
        .object(["type": .string("array"), "items": item, "maxItems": .number(Double(max))])
    }
    static func choices(_ values: [String]) -> MCPJSON {
        .object(["type": .string("string"), "enum": .array(values.map(MCPJSON.string))])
    }
    static func nullable(_ value: MCPJSON) -> MCPJSON {
        .object(["anyOf": .array([value, .object(["type": .string("null")])])])
    }
    static let string = MCPJSON.object(["type": .string("string")])
    static let number = MCPJSON.object(["type": .string("number")])
    static let boolean = MCPJSON.object(["type": .string("boolean")])
    static let intervalSchema = object(["startEpochSeconds": number, "endEpochSeconds": number])
    static let observationSchema = object([
        "observedAtEpochSeconds": number,
        "completeness": choices(["complete", "partial", "unknown"]),
        "partialReason": nullable(
            choices(["outputLimit", "morePages", "providerLimit", "interrupted"])),
        "freshness": choices(["unknown", "localCache", "verifiedThrough"]),
        "verifiedThroughEpochSeconds": nullable(number),
    ])
    static let fieldSchema = MCPJSON.object([
        "oneOf": .array([
            object(["state": choices(["notFetched", "notAuthorized"])]),
            object(["state": choices(["value"]), "value": nullable(string)]),
        ])
    ])
    static let eventSchema = object([
        "eventId": string, "calendarId": string,
        "time": .object([
            "oneOf": .array([
                object(["kind": choices(["timed"]), "interval": intervalSchema, "timeZone": string]
                ),
                object([
                    "kind": choices(["allDay"]), "startDate": string, "endDate": string,
                    "timeZone": string,
                ]),
            ])
        ]),
        "occupancy": choices(["free", "busy", "tentative", "unknown"]),
        "status": choices(["active", "cancelled", "unknown"]),
        "fields": object(
            ["title": fieldSchema, "location": fieldSchema, "notes": fieldSchema], required: []),
    ])
    static let discoverySchema = object([
        "calendars": array(object(["calendarId": string, "name": string]), max: 32),
        "observation": observationSchema,
    ])
    static let availabilitySchema = object([
        "window": intervalSchema,
        "blocks": array(
            object([
                "interval": intervalSchema, "occupancy": choices(["busy", "tentative", "unknown"]),
            ]), max: 1000),
        "observation": observationSchema, "absenceProvesFree": .object(["const": .bool(false)]),
    ])
    static let searchSchema = object([
        "events": array(eventSchema, max: 100), "window": intervalSchema,
        "truncated": boolean, "observation": observationSchema,
    ])
    static let detailSchema = object([
        "event": nullable(eventSchema),
        "status": choices(["found", "notFoundInWindow", "unknown"]),
        "window": intervalSchema, "observation": observationSchema,
    ])
}

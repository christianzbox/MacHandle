import MCPServer

package enum ReminderReadSchema {
    package static func object(_ properties: [String: MCPJSON], required: [String]? = nil)
        -> MCPJSON
    {
        .object([
            "type": .string("object"), "properties": .object(properties),
            "required": .array((required ?? properties.keys.sorted()).map(MCPJSON.string)),
            "additionalProperties": .bool(false),
        ])
    }
    package static func array(_ value: MCPJSON, max: Int) -> MCPJSON {
        .object(["type": .string("array"), "items": value, "maxItems": .number(Double(max))])
    }
    package static func nullable(_ value: MCPJSON) -> MCPJSON {
        .object(["anyOf": .array([value, .object(["type": .string("null")])])])
    }
    package static func choice(_ values: [String]) -> MCPJSON {
        .object(["type": .string("string"), "enum": .array(values.map(MCPJSON.string))])
    }
    package static let string = MCPJSON.object(["type": .string("string")])
    package static let number = MCPJSON.object(["type": .string("number")])
    package static let boolean = MCPJSON.object(["type": .string("boolean")])
    package static func fieldSchema(_ value: MCPJSON) -> MCPJSON {
        .object([
            "oneOf": .array([
                object(["state": choice(["notFetched", "notAuthorized"])]),
                object(["state": choice(["value"]), "value": value]),
            ])
        ])
    }
    package static let observationSchema = object([
        "completeness": choice(["complete", "partial", "unknown"]),
        "freshness": choice(["unknown", "localCache"]), "observedAtEpochSeconds": number,
    ])
    package static let reminderSchema = object([
        "reminderId": string, "listId": string,
        "fields": object(
            [
                "title": fieldSchema(string), "notes": fieldSchema(nullable(string)),
                "due": fieldSchema(
                    nullable(
                        object([
                            "kind": choice(["date", "localDateTime"]), "date": string,
                            "time": nullable(string), "timeZone": nullable(string),
                        ]))),
                "completion": fieldSchema(
                    object(["completed": boolean, "completedAtEpochSeconds": nullable(number)])),
                "recurrence": fieldSchema(choice(["recurring", "notRecurring"])),
            ], required: []),
    ])
    package static let listsSchema = object([
        "lists": array(object(["listId": string, "name": string]), max: 32),
        "observation": observationSchema,
    ])
    package static let searchSchema = object([
        "reminders": array(reminderSchema, max: 100), "truncated": boolean,
        "observation": observationSchema,
    ])
    package static let detailSchema = object([
        "reminder": nullable(reminderSchema), "status": choice(["found", "notObserved"]),
        "absenceProvesDeletion": .object(["const": .bool(false)]), "observation": observationSchema,
    ])
}

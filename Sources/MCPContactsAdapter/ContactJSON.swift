import CoreDomain
import Foundation
import MCPServer
import PermissionEngine

enum ContactReadFailure: Error { case unavailable }
enum ContactJSON {
    static func field<T>(_ value: FieldValue<T>, _ encode: (T) throws -> MCPJSON) throws -> MCPJSON
    {
        switch value {
        case .notFetched: .object(["state": .string("notFetched")])
        case .notAuthorized: .object(["state": .string("notAuthorized")])
        case .value(let value): .object(["state": .string("value"), "value": try encode(value)])
        }
    }
    static func text(_ value: String) throws -> MCPJSON {
        guard value.utf8.count <= 8192 else { throw ContactReadFailure.unavailable }
        return .string(value)
    }
    static func contact(
        _ value: Contact, token: String, container: String, fields: Set<ContactField>
    ) throws -> MCPJSON {
        var content: [String: MCPJSON] = [:]
        func labeled(_ items: [LabeledValue<String>]) throws -> MCPJSON {
            guard items.count <= 32 else { throw ContactReadFailure.unavailable }
            return .array(
                try items.map {
                    .object(["label": try $0.label.map(text) ?? .null, "value": try text($0.value)])
                })
        }
        if fields.contains(.name) {
            content["name"] = try field(value.name) {
                .object(["given": try text($0.given), "family": try text($0.family)])
            }
        }
        if fields.contains(.emailAddresses) {
            content["emailAddresses"] = try field(value.emailAddresses, labeled)
        }
        if fields.contains(.phoneNumbers) {
            content["phoneNumbers"] = try field(value.phoneNumbers, labeled)
        }
        if fields.contains(.organization) {
            content["organization"] = try field(value.organization) { try $0.map(text) ?? .null }
        }
        if fields.contains(.postalAddresses) {
            content["postalAddresses"] = try field(value.postalAddresses) { items in
                guard items.count <= 32 else { throw ContactReadFailure.unavailable }
                return .array(
                    try items.map { item in
                        .object([
                            "label": try item.label.map(text) ?? .null,
                            "value": .object([
                                "street": try text(item.value.street),
                                "city": try text(item.value.city),
                                "region": try text(item.value.region),
                                "postalCode": try text(item.value.postalCode),
                                "country": try text(item.value.country),
                            ]),
                        ])
                    })
            }
        }
        return .object([
            "contactId": .string(token), "containerId": .string(container),
            "fields": .object(content),
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
    static func object(_ properties: [String: MCPJSON], required: [String]? = nil) -> MCPJSON {
        .object([
            "type": .string("object"), "properties": .object(properties),
            "required": .array((required ?? properties.keys.sorted()).map(MCPJSON.string)),
            "additionalProperties": .bool(false),
        ])
    }
    static func array(_ value: MCPJSON, max: Int) -> MCPJSON {
        .object(["type": .string("array"), "items": value, "maxItems": .number(Double(max))])
    }
    static func nullable(_ value: MCPJSON) -> MCPJSON {
        .object(["anyOf": .array([value, .object(["type": .string("null")])])])
    }
    static func choice(_ values: [String]) -> MCPJSON {
        .object(["type": .string("string"), "enum": .array(values.map(MCPJSON.string))])
    }
    static let string = MCPJSON.object(["type": .string("string")])
    static let number = MCPJSON.object(["type": .string("number")])
    static let boolean = MCPJSON.object(["type": .string("boolean")])
    static func fieldSchema(_ value: MCPJSON) -> MCPJSON {
        .object([
            "oneOf": .array([
                object(["state": choice(["notFetched", "notAuthorized"])]),
                object(["state": choice(["value"]), "value": value]),
            ])
        ])
    }
    static let observationSchema = object([
        "completeness": choice(["complete", "partial", "unknown"]),
        "freshness": choice(["unknown", "localCache"]), "observedAtEpochSeconds": number,
    ])
    static let labeledSchema = array(object(["label": nullable(string), "value": string]), max: 32)
    static let contactSchema = object([
        "contactId": string, "containerId": string,
        "fields": object(
            [
                "name": fieldSchema(object(["given": string, "family": string])),
                "emailAddresses": fieldSchema(labeledSchema),
                "phoneNumbers": fieldSchema(labeledSchema),
                "organization": fieldSchema(nullable(string)),
                "postalAddresses": fieldSchema(
                    array(
                        object([
                            "label": nullable(string),
                            "value": object([
                                "street": string, "city": string, "region": string,
                                "postalCode": string, "country": string,
                            ]),
                        ]), max: 32)),
            ], required: []),
    ])
    static let containersSchema = object([
        "containers": array(object(["containerId": string, "name": string]), max: 32),
        "observation": observationSchema,
    ])
    static let searchSchema = object([
        "contacts": array(contactSchema, max: 100), "truncated": boolean,
        "observation": observationSchema,
    ])
    static let detailSchema = object([
        "contact": nullable(contactSchema), "status": choice(["found", "notObserved"]),
        "absenceProvesDeletion": .object(["const": .bool(false)]), "observation": observationSchema,
    ])
}

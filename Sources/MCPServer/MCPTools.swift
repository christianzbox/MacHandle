import Foundation

/// Fixed synthetic values only. A future broker adapter must be independently authorized.
package struct MCPTool: Sendable {
    struct IntegerField: Sendable {
        let name: String
        let range: ClosedRange<Int>
    }
    let name: String
    let description: String
    let parameters: [MCPInputField]
    let outputSchema: MCPJSON
    let execute: @Sendable ([String: MCPJSON]) async throws -> MCPToolResult

    init(
        name: String, description: String, fields: [IntegerField], outputSchema: MCPJSON,
        execute: @escaping @Sendable ([String: Int]) async throws -> MCPJSON
    ) {
        self.init(
            name: name, description: description,
            parameters: fields.map { .init($0.name, kind: .integer($0.range)) },
            outputSchema: outputSchema,
            execute: { values in
                MCPToolResult(value: try await execute(values.mapValues { $0.integer! }))
            })
    }
    package init(
        name: String, description: String, parameters: [MCPInputField],
        outputSchema: MCPJSON,
        execute: @escaping @Sendable ([String: MCPJSON]) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.outputSchema = outputSchema
        self.execute = execute
    }
    var validRegistration: Bool {
        func validName(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 64
                && value.utf8.allSatisfy {
                    (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                        || [45, 46, 95].contains($0)
                }
        }
        return validName(name) && description.utf8.count <= 1024 && parameters.count <= 16
            && Set(parameters.map(\.name)).count == parameters.count
            && parameters.allSatisfy { validName($0.name) && $0.valid }
            && outputSchema.object != nil
    }
    var definition: MCPJSON {
        .object([
            "name": .string(name), "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(
                    Dictionary(uniqueKeysWithValues: parameters.map { ($0.name, $0.schema) })),
                "required": .array(parameters.filter(\.required).map { .string($0.name) }),
                "additionalProperties": .bool(false),
            ]),
            "outputSchema": outputSchema,
            "annotations": .object([
                "readOnlyHint": .bool(true), "destructiveHint": .bool(false),
                "idempotentHint": .bool(true), "openWorldHint": .bool(false),
            ]),
        ])
    }
    func arguments(_ value: MCPJSON) throws -> [String: MCPJSON] {
        guard let object = value.object,
            Set(object.keys).isSubset(of: Set(parameters.map(\.name)))
        else {
            throw MCPToolFailure.arguments
        }
        for field in parameters {
            if let value = object[field.name] {
                guard field.accepts(value) else { throw MCPToolFailure.arguments }
            } else if field.required {
                throw MCPToolFailure.arguments
            }
        }
        return object
    }
    package static let synthetic: [Self] = [
        Self(
            name: "mock_add", description: "Add two bounded synthetic integers. No personal data.",
            fields: [
                .init(name: "a", range: -1_000_000...1_000_000),
                .init(name: "b", range: -1_000_000...1_000_000),
            ],
            outputSchema: schema("sum", type: "integer"),
            execute: { args in
                .object(["sum": .number(Double(args["a"]! + args["b"]!))])
            }),
        Self(
            name: "mock_fail", description: "Return a fixed synthetic execution error.", fields: [],
            outputSchema: schema("synthetic", type: "boolean"),
            execute: { _ in throw MCPToolFailure.execution }),
        Self(
            name: "mock_status",
            description: "Report synthetic readiness. This does not connect to MacHandle services.",
            fields: [], outputSchema: schema("synthetic", type: "boolean"),
            execute: { _ in
                .object(["synthetic": .bool(true)])
            }),
        Self(
            name: "mock_wait",
            description: "Wait up to one second to exercise cancellation; no external work.",
            fields: [.init(name: "milliseconds", range: 0...1000)],
            outputSchema: schema("completed", type: "boolean"),
            execute: { args in
                try await Task.sleep(for: .milliseconds(args["milliseconds"]!))
                return .object(["completed": .bool(true)])
            }),
    ]
    private static func schema(_ key: String, type: String) -> MCPJSON {
        .object([
            "type": .string("object"),
            "properties": .object([key: .object(["type": .string(type)])]),
            "required": .array([.string(key)]), "additionalProperties": .bool(false),
        ])
    }
}
enum MCPToolFailure: Error { case arguments, execution }

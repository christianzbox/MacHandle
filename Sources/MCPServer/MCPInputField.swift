import Foundation

/// Deliberately small schema vocabulary; validators and advertised bounds share one definition.
package struct MCPInputField: Sendable {
    package enum Kind: Sendable {
        case integer(ClosedRange<Int>)
        case string(maximum: Int)
        case strings(maximum: Int, itemMaximum: Int, choices: Set<String>?)
    }
    let name: String
    let kind: Kind
    let required: Bool
    package init(_ name: String, kind: Kind, required: Bool = true) {
        self.name = name
        self.kind = kind
        self.required = required
    }
    var valid: Bool {
        switch kind {
        case .integer(let range):
            range.lowerBound >= -9_007_199_254_740_991 && range.upperBound <= 9_007_199_254_740_991
        case .string(let max): (1...4096).contains(max)
        case .strings(let max, let itemMax, let choices):
            (1...64).contains(max) && (1...256).contains(itemMax)
                && (choices == nil
                    || ((1...64).contains(choices!.count)
                        && choices!.allSatisfy { $0.unicodeScalars.count <= itemMax }))
        }
    }
    var schema: MCPJSON {
        switch kind {
        case .integer(let range):
            .object([
                "type": .string("integer"), "minimum": .number(Double(range.lowerBound)),
                "maximum": .number(Double(range.upperBound)),
            ])
        case .string(let max):
            .object(["type": .string("string"), "maxLength": .number(Double(max))])
        case .strings(let max, let itemMax, let choices):
            .object([
                "type": .string("array"), "maxItems": .number(Double(max)),
                "uniqueItems": .bool(true),
                "items": .object(
                    ["type": .string("string"), "maxLength": .number(Double(itemMax))]
                        .merging(
                            choices.map { ["enum": MCPJSON.array($0.sorted().map(MCPJSON.string))] }
                                ?? [:]
                        ) { _, new in new }),
            ])
        }
    }
    func accepts(_ value: MCPJSON) -> Bool {
        switch kind {
        case .integer(let range): return value.integer.map(range.contains) == true
        case .string(let max): return value.string.map { $0.unicodeScalars.count <= max } == true
        case .strings(let max, let itemMax, let choices):
            if let array = value.array, array.count <= max {
                let strings = array.compactMap(\.string)
                return strings.count == array.count && Set(strings).count == strings.count
                    && strings.allSatisfy {
                        $0.unicodeScalars.count <= itemMax && (choices?.contains($0) ?? true)
                    }
            }
            return false
        }
    }
}

/// The adapter revalidates after suspended work and again immediately before protocol delivery.
package struct MCPToolResult: Sendable {
    package let value: MCPJSON
    package let validate: @Sendable () async throws -> Void
    package init(value: MCPJSON, validate: @escaping @Sendable () async throws -> Void = {}) {
        self.value = value
        self.validate = validate
    }
}

import Foundation

indirect enum MCPJSON: Codable, Equatable, Sendable {
    case object([String: MCPJSON])
    case array([MCPJSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self), n.isFinite {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([MCPJSON].self) {
            self = .array(a)
        } else {
            self = .object(try c.decode([String: MCPJSON].self))
        }
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var object: [String: MCPJSON]? { if case .object(let v) = self { v } else { nil } }
    var string: String? { if case .string(let v) = self { v } else { nil } }
    var integer: Int? {
        guard case .number(let v) = self, v.isFinite, abs(v) <= 9_007_199_254_740_991,
            v.rounded() == v
        else { return nil }
        return Int(v)
    }
    subscript(_ key: String) -> MCPJSON? { object?[key] }
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

enum MCPWireFailure: Error { case malformed, limit, closed, io }

/// Bound structure before Foundation decoding, and reject duplicate object keys even when escaped.
struct MCPJSONParser {
    private let bytes: [UInt8]
    private var offset = 0
    private var nodes = 0
    init(_ data: Data) throws {
        guard data.count <= 65_536, String(data: data, encoding: .utf8) != nil else {
            throw MCPWireFailure.malformed
        }
        bytes = Array(data)
    }
    mutating func parse() throws -> MCPJSON {
        let value = try value(depth: 0)
        whitespace()
        guard offset == bytes.count else { throw MCPWireFailure.malformed }
        return value
    }
    private mutating func value(depth: Int) throws -> MCPJSON {
        nodes += 1
        guard depth <= 32, nodes <= 4096 else { throw MCPWireFailure.limit }
        whitespace()
        guard offset < bytes.count else { throw MCPWireFailure.malformed }
        if bytes[offset] == 123 {
            offset += 1
            var object: [String: MCPJSON] = [:]
            whitespace()
            if take(125) { return .object(object) }
            repeat {
                whitespace()
                let key = try string()
                guard object[key] == nil else { throw MCPWireFailure.malformed }
                whitespace()
                guard take(58) else { throw MCPWireFailure.malformed }
                object[key] = try value(depth: depth + 1)
                whitespace()
                if take(125) { return .object(object) }
                guard take(44) else { throw MCPWireFailure.malformed }
            } while true
        }
        if bytes[offset] == 91 {
            offset += 1
            var array: [MCPJSON] = []
            whitespace()
            if take(93) { return .array(array) }
            repeat {
                array.append(try value(depth: depth + 1))
                whitespace()
                if take(93) { return .array(array) }
                guard take(44) else { throw MCPWireFailure.malformed }
            } while true
        }
        if bytes[offset] == 34 { return .string(try string()) }
        let start = offset
        while offset < bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) {
            offset += 1
        }
        guard start < offset else { throw MCPWireFailure.malformed }
        let data = Data(bytes[start..<offset])
        guard let scalar = try? JSONDecoder().decode(MCPJSON.self, from: data),
            scalar.object == nil
        else { throw MCPWireFailure.malformed }
        return scalar
    }
    private mutating func string() throws -> String {
        let start = offset
        guard take(34) else { throw MCPWireFailure.malformed }
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            if byte == 34 {
                guard
                    let value = try? JSONDecoder().decode(
                        String.self, from: Data(bytes[start..<offset]))
                else { throw MCPWireFailure.malformed }
                return value
            }
            if byte == 92 {
                guard offset < bytes.count else { throw MCPWireFailure.malformed }
                offset += 1
            }
        }
        throw MCPWireFailure.malformed
    }
    private mutating func whitespace() {
        while offset < bytes.count, [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 }
    }
    private mutating func take(_ byte: UInt8) -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1
        return true
    }
}

struct MCPLineFramer {
    private var pending = Data()
    mutating func append(_ chunk: Data) throws -> [Data] {
        guard chunk.count <= 4096 else { throw MCPWireFailure.limit }
        var frames: [Data] = []
        for byte in chunk {
            if byte == 10 {
                if pending.last == 13 { pending.removeLast() }
                frames.append(pending)
                pending = Data()
            } else {
                guard pending.count < 65_536 else { throw MCPWireFailure.limit }
                pending.append(byte)
            }
        }
        return frames
    }
    var hasPartialFrame: Bool { !pending.isEmpty }
}

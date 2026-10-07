import Foundation

/// Compatibility metadata carried by its owning value, never merged with an old document.
/// Integers remain exact; Decimal preserves supported decimal values, not their JSON spelling.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case decimal(Decimal)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let decoded = try? value.decode(Bool.self) { self = .bool(decoded) }
        else if let decoded = try? value.decode(String.self) { self = .string(decoded) }
        else if let decoded = try? value.decode(Int64.self) { self = .integer(decoded) }
        else if let decoded = try? value.decode(UInt64.self) { self = .unsignedInteger(decoded) }
        else if let decoded = try? value.decode(Decimal.self), !decoded.isNaN { self = .decimal(decoded) }
        else if var array = try? decoder.unkeyedContainer() {
            var values: [JSONValue] = []
            while !array.isAtEnd { values.append(try array.decode(JSONValue.self)) }
            self = .array(values)
        } else if let object = try? decoder.container(keyedBy: JSONFieldKey.self) {
            var values: [String: JSONValue] = [:]
            for key in object.allKeys { values[key.stringValue] = try object.decode(JSONValue.self, forKey: key) }
            self = .object(values)
        } else {
            throw UnknownJSONFieldError.unsupportedValue(codingPath: decoder.codingPath.map(\.stringValue))
        }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let decoded): try value.encode(decoded)
        case .string(let decoded): try value.encode(decoded)
        case .integer(let decoded): try value.encode(decoded)
        case .unsignedInteger(let decoded): try value.encode(decoded)
        case .decimal(let decoded):
            guard !decoded.isNaN else {
                throw UnknownJSONFieldError.unsupportedValue(codingPath: encoder.codingPath.map(\.stringValue))
            }
            try value.encode(decoded)
        case .array(let decoded): try value.encode(decoded)
        case .object(let decoded): try value.encode(decoded)
        }
    }
}

/// Distinct from legacy known-field decoding errors: fallback must never discard metadata.
enum UnknownJSONFieldError: Error {
    case unsupportedValue(codingPath: [String])
}

private struct JSONFieldKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

enum UnknownJSONFields {
    static func decode<Key: CodingKey & CaseIterable>(from decoder: Decoder, excluding: Key.Type, retired: Set<String> = []) throws -> [String: JSONValue] {
        let known = Set(Key.allCases.map(\.stringValue)).union(retired)
        let container = try decoder.container(keyedBy: JSONFieldKey.self)
        var fields: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            fields[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        return fields
    }

    static func encode<Key: CodingKey & CaseIterable>(_ fields: [String: JSONValue], to encoder: Encoder, excluding: Key.Type, retired: Set<String> = []) throws {
        let known = Set(Key.allCases.map(\.stringValue)).union(retired)
        var container = encoder.container(keyedBy: JSONFieldKey.self)
        // Exclude all known keys, including optionals intentionally omitted by the current value.
        for (key, value) in fields where !known.contains(key) {
            try container.encode(value, forKey: JSONFieldKey(key))
        }
    }

    static func preservingMetadataErrors<Value>(_ decode: () throws -> Value, fallback: () -> Value) throws -> Value {
        do { return try decode() }
        catch let error as UnknownJSONFieldError { throw error }
        catch { return fallback() }
    }
}

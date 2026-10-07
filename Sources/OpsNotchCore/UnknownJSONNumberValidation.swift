import Foundation

/// JSONDecoder does not expose numeric tokens and Decimal can silently round them.
/// The persistence boundary checks unknown numbers against their encoded Decimal value
/// before Codable normalization. Known fields retain their existing decoding behavior.
enum UnknownJSONNumberValidation {
    static func validate(_ data: Data) throws {
        var scanner = Scanner(bytes: Array(data))
        try scanner.value(context: .store, depth: 0)
        scanner.whitespace()
        guard scanner.index == scanner.bytes.count else { throw ShelfStoreError.invalidStore }
    }

    private enum Context {
        case store, settings, items, item, paths, path, hotkey, unknown, known

        func field(_ key: String) -> Context {
            switch self {
            case .store:
                if key == "items" { return .items }
                if key == "settings" { return .settings }
                return ShelfStore.CodingKeys.allCases.contains { $0.stringValue == key } ? .known : .unknown
            case .settings:
                if key == "finder_quick_paths" { return .paths }
                if key == "hotkey" || key == "finder_reveal_hotkey" { return .hotkey }
                let known = ShelfSettings.CodingKeys.allCases.contains { $0.stringValue == key }
                    || ShelfSettings.retiredJSONKeys.contains(key)
                return known ? .known : .unknown
            case .item:
                return ShelfItem.CodingKeys.allCases.contains { $0.stringValue == key } ? .known : .unknown
            case .path:
                return FinderQuickPath.CodingKeys.allCases.contains { $0.stringValue == key } ? .known : .unknown
            case .hotkey:
                return HotkeyShortcut.CodingKeys.allCases.contains { $0.stringValue == key } ? .known : .unknown
            case .unknown: return .unknown
            default: return .known
            }
        }

        var element: Context {
            switch self {
            case .store, .items: return .item // Legacy root array.
            case .paths: return .path
            case .unknown: return .unknown
            default: return .known
            }
        }
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0

        mutating func whitespace() {
            while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
        }

        mutating func consume(_ byte: UInt8) -> Bool {
            whitespace()
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        mutating func string(decodeKey: Bool = true) throws -> String {
            whitespace()
            let start = index
            guard consume(34) else { throw ShelfStoreError.invalidStore }
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == 34 {
                    return decodeKey ? try JSONDecoder().decode(String.self, from: Data(bytes[start..<index])) : ""
                }
                if byte == 92 { index += 1 } // Escaped quotes cannot terminate the token.
            }
            throw ShelfStoreError.invalidStore
        }

        mutating func value(context: Context, depth: Int) throws {
            guard depth <= 512 else { throw ShelfStoreError.invalidStore }
            whitespace()
            guard index < bytes.count else { throw ShelfStoreError.invalidStore }
            if consume(123) {
                if consume(125) { return }
                repeat {
                    let key = try string()
                    guard consume(58) else { throw ShelfStoreError.invalidStore }
                    try value(context: context.field(key), depth: depth + 1)
                    if consume(125) { return }
                } while consume(44)
                throw ShelfStoreError.invalidStore
            }
            if consume(91) {
                if consume(93) { return }
                repeat {
                    try value(context: context.element, depth: depth + 1)
                    if consume(93) { return }
                } while consume(44)
                throw ShelfStoreError.invalidStore
            }
            if bytes[index] == 34 { _ = try string(decodeKey: false); return }
            let start = index
            while index < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
            guard index > start else { throw ShelfStoreError.invalidStore }
            if case .unknown = context, bytes[start] == 45 || (48...57).contains(bytes[start]) {
                let token = Data(bytes[start..<index])
                guard let decimal = try? JSONDecoder().decode(Decimal.self, from: token),
                      !decimal.isNaN,
                      let encoded = try? JSONEncoder().encode(decimal),
                      let original = CanonicalNumber(String(decoding: token, as: UTF8.self)),
                      let roundTripped = CanonicalNumber(String(decoding: encoded, as: UTF8.self)),
                      original == roundTripped else {
                    throw UnknownJSONFieldError.unsupportedValue(codingPath: ["unknown number at byte \(start)"])
                }
            }
        }
    }

    /// Compare decimal values using digits and a base-10 exponent, never Double.
    private struct CanonicalNumber: Equatable {
        let negative: Bool
        let digits: String
        let exponent: Int

        init?(_ token: String) {
            let parts = token.lowercased().split(separator: "e", omittingEmptySubsequences: false)
            guard parts.count <= 2, let mantissa = parts.first else { return nil }
            let rawExponent: Int
            if parts.count == 2 {
                guard let value = Int(parts[1]) else { return nil }
                rawExponent = value
            } else { rawExponent = 0 }
            var coefficient = String(mantissa)
            let isNegative = coefficient.hasPrefix("-")
            if isNegative { coefficient.removeFirst() }
            let fractionCount = coefficient.firstIndex(of: ".").map {
                coefficient.distance(from: coefficient.index(after: $0), to: coefficient.endIndex)
            } ?? 0
            coefficient.removeAll { $0 == "." }
            guard !coefficient.isEmpty, coefficient.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
            let (initialExponent, underflow) = rawExponent.subtractingReportingOverflow(fractionCount)
            guard !underflow else { return nil }
            var adjustedExponent = initialExponent
            coefficient = String(coefficient.drop(while: { $0 == "0" }))
            if coefficient.isEmpty {
                negative = false; digits = "0"; exponent = 0
                return
            }
            while coefficient.last == "0" {
                coefficient.removeLast()
                let (next, overflow) = adjustedExponent.addingReportingOverflow(1)
                guard !overflow else { return nil }
                adjustedExponent = next
            }
            negative = isNegative
            digits = coefficient
            exponent = adjustedExponent
        }
    }
}

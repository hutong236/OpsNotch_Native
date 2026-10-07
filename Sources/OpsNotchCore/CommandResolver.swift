import Foundation

/// Safe query intents only. Resolving an intent never performs a system action.
public enum CommandIntent: Equatable, Sendable {
    case desktopList
    case desktopSwitch(index: Int)
    case finderPath(String)
    case typeFilter(kind: ShelfKind, query: String)
    case favorites(query: String)
}

public enum CommandResolver {
    public static func resolve(_ query: String) -> CommandIntent? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Preserve paths verbatim; path expansion and safe-action validation belong
        // to the action boundary, not this pure parser.
        if trimmed.hasPrefix("~/") || trimmed.hasPrefix("/") {
            return .finderPath(trimmed)
        }

        let tokenEnd = trimmed.firstIndex(where: { $0.isWhitespace }) ?? trimmed.endIndex
        let token = trimmed[..<tokenEnd].lowercased()
        let residual = String(trimmed[tokenEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if token == "@fav" {
            return .favorites(query: residual)
        }
        if token.hasPrefix("type:"), let kind = ShelfKind(rawValue: String(token.dropFirst(5))) {
            return .typeFilter(kind: kind, query: residual)
        }

        if token == "d" {
            return residual.isEmpty ? .desktopList : desktopSwitch(residual)
        }
        if token.hasPrefix("d"), residual.isEmpty {
            return desktopSwitch(String(token.dropFirst()))
        }
        return nil
    }

    private static func desktopSwitch(_ indexText: String) -> CommandIntent? {
        guard !indexText.isEmpty,
              indexText.first != "0",
              indexText.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let index = Int(indexText), index > 0 else { return nil }
        return .desktopSwitch(index: index)
    }
}

import Foundation

public enum DesktopCommand: Equatable, Sendable {
    case list
    case switchTo(index: Int)
}

public enum DesktopCommandParser {
    public static func parse(_ input: String) -> DesktopCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let command = trimmed.lowercased()
        if command == "d" || command == "desktop" || command == "桌面" {
            return .list
        }

        for prefix in ["desktop", "桌面", "d"] {
            guard command.hasPrefix(prefix) else { continue }
            let suffix = String(command.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let first = suffix.first,
                  first != "0",
                  suffix.allSatisfy(\.isNumber),
                  let index = Int(suffix),
                  index > 0 else {
                continue
            }
            return .switchTo(index: index)
        }

        return nil
    }
}

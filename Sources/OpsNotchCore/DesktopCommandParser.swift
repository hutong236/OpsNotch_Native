import Foundation

public enum DesktopCommand: Equatable, Sendable {
    case list
    case switchTo(index: Int)
}

public enum DesktopCommandParser {
    public static func parse(_ input: String) -> DesktopCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.lowercased().split(whereSeparator: { $0.isWhitespace })
        guard let prefix = parts.first.map(String.init),
              ["d", "desktop", "桌面"].contains(prefix) else {
            return nil
        }

        if parts.count == 1 {
            return .list
        }

        guard parts.count == 2 else { return nil }
        let indexText = String(parts[1])
        guard indexText.first != "0",
              indexText.allSatisfy(\.isNumber),
              let index = Int(indexText),
              index > 0 else {
            return nil
        }

        return .switchTo(index: index)
    }
}

public enum DesktopTargetSelectionAction: Equatable, Sendable {
    case switchDesktop
    case moveWindow
    case moveWindowAndFollow
}

public enum DesktopTargetSelectionResolver {
    public static func resolve(optionPressed: Bool, shiftPressed: Bool) -> DesktopTargetSelectionAction {
        guard optionPressed else { return .switchDesktop }
        return shiftPressed ? .moveWindowAndFollow : .moveWindow
    }
}

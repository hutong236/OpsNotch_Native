#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
enum AppContextResolver {
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "dev.warp.warp-stable",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm"
    ]

    private static let browserBundleIDs: Set<String> = [
        "com.apple.safari",
        "com.google.chrome",
        "com.google.chrome.canary",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.browser"
    ]

    static func current() -> AppContextKind {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .generic }
        return kind(bundleIdentifier: app.bundleIdentifier, localizedName: app.localizedName)
    }

    static func kind(bundleIdentifier: String?, localizedName: String?) -> AppContextKind {
        let bundle = (bundleIdentifier ?? "").lowercased()
        let name = (localizedName ?? "").lowercased()

        if bundle == "com.apple.finder" || name == "finder" { return .finder }
        if terminalBundleIDs.contains(bundle)
            || ["terminal", "iterm", "warp", "alacritty", "kitty", "wezterm"].contains(where: name.contains) {
            return .terminal
        }
        if browserBundleIDs.contains(bundle)
            || ["safari", "chrome", "edge", "firefox", "arc"].contains(where: name.contains) {
            return .browser
        }
        return .generic
    }
}
#endif

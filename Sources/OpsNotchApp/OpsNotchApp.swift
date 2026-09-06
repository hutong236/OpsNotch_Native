#if os(macOS)
import AppKit
import SwiftUI

@main
struct OpsNotchNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("隐藏 Ops Notch") {
                    NSApplication.shared.hide(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
#else
@main
struct LinuxPlaceholder { static func main() {} }
#endif

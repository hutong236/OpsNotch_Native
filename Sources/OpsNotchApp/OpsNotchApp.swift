#if os(macOS)
import SwiftUI

@main
struct OpsNotchNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
#else
@main
struct LinuxPlaceholder { static func main() {} }
#endif

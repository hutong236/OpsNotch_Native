#if os(macOS)
import SwiftUI

enum OpsTypography {
    static let display = Font.system(size: 20, weight: .semibold)
    static let title = Font.system(size: 16, weight: .semibold)
    static let settingsTitle = Font.system(size: 22, weight: .semibold)
    static let heading = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 12)
    static let bodyStrong = Font.system(size: 12, weight: .semibold)
    static let secondary = Font.system(size: 10)
    static let secondaryStrong = Font.system(size: 10, weight: .medium)
    static let metadata = Font.system(size: 9)
    static let prominentIcon = Font.system(size: 24, weight: .semibold)
    static let monospacedBody = Font.system(size: 11, design: .monospaced)
    // Preserve existing shelf text metrics during the behavior-neutral migration.
    static let shelfSubtitle = Font.system(size: 9.5)
    static let rowTitle = Font.system(size: 11.5, weight: .semibold)
    static let micro = Font.system(size: 8)
}
#endif

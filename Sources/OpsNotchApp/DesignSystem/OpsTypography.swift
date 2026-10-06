#if os(macOS)
import SwiftUI

enum OpsTypography {
    static let display = Font.system(size: 20, weight: .semibold)
    static let title = Font.system(size: 16, weight: .semibold)
    static let heading = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 12)
    static let bodyStrong = Font.system(size: 12, weight: .semibold)
    static let secondary = Font.system(size: 10)
    static let metadata = Font.system(size: 9)
    static let micro = Font.system(size: 8)
}
#endif

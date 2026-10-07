#if os(macOS)
import SwiftUI

enum OpsRadius {
    static let small: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 12
    // Existing row geometry remains stable until the component migration.
    static let compactRow: CGFloat = 9
    static let shelfRow: CGFloat = 11
    static let panel: CGFloat = 18
}
#endif

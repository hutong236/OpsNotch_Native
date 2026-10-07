#if os(macOS)
import SwiftUI

enum OpsSurface {
    static var panelStroke: Color { Color.white.opacity(0.12) }
    static var card: Color { Color.primary.opacity(0.028) }
    static var hover: Color { Color.primary.opacity(0.055) }
    static var hoverStrong: Color { Color.primary.opacity(0.075) }
    static var focused: Color { Color.primary.opacity(0.10) }
    static var focusStroke: Color { Color.white.opacity(0.55) }
    static var selected: Color { Color.accentColor.opacity(0.13) }
}
#endif

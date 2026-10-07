#if os(macOS)
import SwiftUI

enum OpsSurface {
    static func panelStrokeOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.30 : 0.14
    }

    static func focusStrokeOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.92 : 0.62
    }

    static func selectedOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.22 : 0.13
    }

    static func selectionSubtleOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.14 : 0.08
    }

    static func dividerOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.22 : 0.10
    }

    static func dropTargetStrokeOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.58 : 0.30
    }

    static func settingsCardOpacity(increasedContrast: Bool) -> Double {
        increasedContrast ? 0.075 : 0.035
    }

    static func panelStroke(increasedContrast: Bool) -> Color {
        Color.primary.opacity(panelStrokeOpacity(increasedContrast: increasedContrast))
    }

    static func focusStroke(increasedContrast: Bool) -> Color {
        Color.accentColor.opacity(focusStrokeOpacity(increasedContrast: increasedContrast))
    }

    static func selected(increasedContrast: Bool) -> Color {
        Color.accentColor.opacity(selectedOpacity(increasedContrast: increasedContrast))
    }

    static func selectionSubtle(increasedContrast: Bool) -> Color {
        Color.accentColor.opacity(selectionSubtleOpacity(increasedContrast: increasedContrast))
    }

    static func divider(increasedContrast: Bool) -> Color {
        Color.primary.opacity(dividerOpacity(increasedContrast: increasedContrast))
    }

    static func dropTargetStroke(increasedContrast: Bool) -> Color {
        Color.accentColor.opacity(dropTargetStrokeOpacity(increasedContrast: increasedContrast))
    }

    static func settingsCard(increasedContrast: Bool) -> Color {
        Color.primary.opacity(settingsCardOpacity(increasedContrast: increasedContrast))
    }

    // Compatibility defaults for surfaces that do not yet need an environment-aware override.
    static var panelStroke: Color { panelStroke(increasedContrast: false) }
    static var card: Color { Color.primary.opacity(0.028) }
    static var hover: Color { Color.primary.opacity(0.055) }
    static var hoverStrong: Color { Color.primary.opacity(0.075) }
    static var focused: Color { Color.primary.opacity(0.10) }
    static var focusStroke: Color { focusStroke(increasedContrast: false) }
    static var selected: Color { selected(increasedContrast: false) }
    static var selectionSubtle: Color { selectionSubtle(increasedContrast: false) }
    static var divider: Color { divider(increasedContrast: false) }
    static var dropTargetStroke: Color { dropTargetStroke(increasedContrast: false) }
    static var settingsCard: Color { settingsCard(increasedContrast: false) }
}
#endif

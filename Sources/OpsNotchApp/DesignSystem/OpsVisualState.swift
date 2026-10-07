#if os(macOS)

enum OpsVisualState: Equatable {
    case `default`
    case hovered
    case pressed
    case focused
    case selected
    case disabled
    case dragging
}

/// Row interaction is composable: selection and keyboard focus may coexist.
/// backgroundState chooses the fill, while showsFocusRing preserves focus independently.
struct OpsRowVisualState: Equatable {
    let selected: Bool
    let focused: Bool
    let hovered: Bool
    let disabled: Bool
    let dragging: Bool

    var showsAccessories: Bool {
        hovered || focused || selected
    }

    var showsFocusRing: Bool {
        focused || dragging
    }

    var backgroundState: OpsVisualState {
        if disabled { return .disabled }
        if dragging { return .dragging }
        if selected { return .selected }
        if hovered { return .hovered }
        if focused { return .focused }
        return .default
    }
}
#endif

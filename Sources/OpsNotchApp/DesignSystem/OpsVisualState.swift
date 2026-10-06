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
#endif

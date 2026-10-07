#if os(macOS)
import SwiftUI

struct OpsIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var selected = false
    var destructive = false
    var helpText: String? = nil
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: OpsControlMetrics.iconSize, weight: .medium))
                .frame(
                    minWidth: OpsControlMetrics.minimumHitTarget,
                    minHeight: OpsControlMetrics.minimumHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(OpsIconButtonStyle(hovered: hovered))
        .foregroundStyle(foregroundColor)
        .accessibilityLabel(Text(accessibilityLabel))
        .help(helpText ?? accessibilityLabel)
        .onHover { hovered = $0 }
    }

    private var foregroundColor: Color {
        if destructive { return .red }
        if selected { return .accentColor }
        return .secondary
    }
}

private struct OpsIconButtonStyle: ButtonStyle {
    let hovered: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                background(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: OpsRadius.control, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func background(isPressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        if isPressed { return OpsSurface.hoverStrong }
        return hovered ? OpsSurface.hover : .clear
    }
}
#endif

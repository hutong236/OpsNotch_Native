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
                .background(
                    hovered ? OpsSurface.hover : Color.clear,
                    in: RoundedRectangle(cornerRadius: OpsRadius.control, style: .continuous)
                )
        }
        .buttonStyle(.plain)
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
#endif

#if os(macOS)
import SwiftUI
import OpsNotchCore

struct ShelfCommandBar: View {
    @Binding var query: String
    let language: AppLanguage
    let focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: OpsSpacing.small) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L10n.text("searchUnified", language), text: $query)
                .textFieldStyle(.plain)
                .font(OpsTypography.body)
                .focused(focused)
                .accessibilityLabel(Text(L10n.text("searchUnified", language)))
                .help(L10n.text("searchCommandHelp", language))
            if !query.isEmpty {
                OpsIconButton(systemName: "xmark.circle.fill", accessibilityLabel: L10n.text("shelfClearSearch", language)) { query = "" }
            }
        }
        .padding(.horizontal, OpsSpacing.small)
        .frame(height: OpsControlMetrics.searchHeight)
        .background(OpsSurface.hoverStrong, in: RoundedRectangle(cornerRadius: OpsRadius.control))
        .overlay(RoundedRectangle(cornerRadius: OpsRadius.control)
            .strokeBorder(focused.wrappedValue ? Color.accentColor : Color.clear, lineWidth: 1))
    }
}
#endif

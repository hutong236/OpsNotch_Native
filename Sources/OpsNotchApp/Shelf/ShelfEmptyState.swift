#if os(macOS)
import SwiftUI
import OpsNotchCore

struct ShelfEmptyState: View {
    let filtered: Bool
    let language: AppLanguage

    var body: some View {
        VStack(spacing: OpsSpacing.small) {
            Image(systemName: filtered ? "line.3.horizontal.decrease.circle" : "tray")
                .font(OpsTypography.display).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.text(filtered ? "noMatch" : "empty", language)).font(OpsTypography.bodyStrong)
            if !filtered {
                Text(L10n.text("emptyHint", language)).font(OpsTypography.secondary)
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(OpsSpacing.xxLarge)
    }
}
#endif

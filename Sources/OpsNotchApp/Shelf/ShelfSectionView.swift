#if os(macOS)
import SwiftUI

/// Section heading shared by all source groups; grouping changes belong to the snapshot layer.
struct ShelfSectionView: View {
    let title: String
    let count: Int
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: OpsSpacing.small) {
            Text(title).font(OpsTypography.metadata).foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Text("\(count)").font(OpsTypography.micro).foregroundStyle(.secondary)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction).buttonStyle(.borderless).font(OpsTypography.metadata)
            }
        }
        .padding(.horizontal, OpsSpacing.small)
        .padding(.top, OpsSpacing.small)
        .padding(.bottom, OpsSpacing.micro)
    }
}
#endif

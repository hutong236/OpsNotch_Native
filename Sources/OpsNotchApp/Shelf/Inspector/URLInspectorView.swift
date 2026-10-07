#if os(macOS)
import SwiftUI

struct URLInspectorView: View {
    let url: String
    var body: some View {
        VStack(alignment: .leading, spacing: OpsSpacing.medium) {
            Image(systemName: "globe").font(OpsTypography.title).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(url).font(OpsTypography.shelfSubtitle).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
#endif

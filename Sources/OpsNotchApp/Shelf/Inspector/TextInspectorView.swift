#if os(macOS)
import SwiftUI

struct TextInspectorView: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text).font(OpsTypography.shelfSubtitle).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
#endif

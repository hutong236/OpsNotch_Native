#if os(macOS)
import SwiftUI

struct TextInspectorView: View {
    let text: String
    var body: some View {
        // Reuse the AppKit-backed selectable full-text preview rather than
        // putting arbitrary clipboard contents in a SwiftUI display list.
        SelectableTextView(text: text, fontSize: 9.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}
#endif

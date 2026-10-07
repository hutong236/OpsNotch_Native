#if os(macOS)
import AppKit
import SwiftUI

struct ImageInspectorView: View {
    let image: NSImage?
    let title: String
    let unavailable: String
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: OpsRadius.control))
                    .accessibilityLabel(Text(title))
            } else {
                Label(unavailable, systemImage: "photo").foregroundStyle(.secondary)
            }
        }
    }
}
#endif

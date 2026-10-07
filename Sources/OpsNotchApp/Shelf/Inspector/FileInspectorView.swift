#if os(macOS)
import AppKit
import SwiftUI

/// Also renders application and command descriptors without probing the filesystem.
struct FileInspectorView: View {
    let path: String
    let image: NSImage?
    let symbol: String
    var body: some View {
        ScrollView {
            VStack(spacing: OpsSpacing.medium) {
                Group {
                    if let image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
                    else { Image(systemName: symbol).font(OpsTypography.title).foregroundStyle(.secondary) }
                }
                .frame(width: 64, height: 64).accessibilityHidden(true)
                Text(path).font(OpsTypography.shelfSubtitle).foregroundStyle(.secondary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
#endif

#if os(macOS)
import AppKit
import QuickLookUI
import OpsNotchCore

@MainActor
final class QuickLookService: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookService()
    private var previewURL: URL?

    func preview(_ item: ShelfItem) {
        guard [.file, .folder].contains(item.kind) else { return }
        let url = URL(fileURLWithPath: item.content)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        previewURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        (previewURL ?? URL(fileURLWithPath: "/")) as NSURL
    }
}
#endif

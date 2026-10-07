#if os(macOS)
import AppKit
import OpsNotchCore

/// Resolves presentation intents through the existing application and system services.
@MainActor
struct ShelfItemActionDispatcher {
    let model: AppModel
    let clipboard: ClipboardManager

    func perform(_ intent: ShelfPresentationItem.ActionIntent) {
        switch intent {
        case .desktop(let command): model.requestDesktopCommand?(command)
        case .openFinder(let path, let quickPathID): model.requestOpenFinderPath?(path, quickPathID)
        case .openLocal(let path, let isDirectory):
            model.openLocalEntry(.local(id: QuickShelfEntry.localID(path: path), title: "", path: path, isDirectory: isDirectory), using: clipboard)
        case .useShelfItem(let id):
            guard let item = item(id) else { return }
            ItemActionService.performDefault(item, clipboard: clipboard, model: model)
        case .copyShelfItem(let id):
            guard let item = item(id) else { return }
            if item.clipboardImage {
                guard clipboard.copyImageFile(item.content) else { return }
            } else { clipboard.copyFromApp(item.content) }
            model.recordUse(id)
            model.showToast(L10n.text("copied", model.language))
        case .copyPath(let path):
            clipboard.copyFromApp(path)
            model.showToast(L10n.text("pathCopied", model.language))
        case .revealPath(let path): NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        case .quickLook(let path):
            QuickLookService.shared.preview(ShelfItem(kind: .file, title: URL(fileURLWithPath: path).lastPathComponent, content: path, storageMode: .reference))
        case .floatingPreview(let id):
            guard let item = item(id) else { return }
            FloatingPreviewController.shared.show(item: item, language: model.language)
        case .setWorkingSet(let id, let included):
            guard let item = item(id), model.isInWorkingSet(item) != included else { return }
            model.toggleWorkingSet(item)
        case .setPinned(let id, let pinned):
            guard let item = item(id), item.pinned != pinned else { return }
            model.togglePin(item)
        case .editShelfItem(let id):
            guard let item = item(id) else { return }
            model.beginEdit(item)
        case .removeShelfItem(let id): model.remove(Set([id]))
        }
    }
    private func item(_ id: UUID) -> ShelfItem? { model.items.first { $0.id == id } }
}
#endif

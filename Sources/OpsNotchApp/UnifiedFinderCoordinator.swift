#if os(macOS)
import Foundation
import OpsNotchCore

/// 统一 Quick Shelf 的 Finder 动作协调器。
/// 复用既有 FinderWindowService，不把 Finder 系统交互塞进 SwiftUI。
@MainActor
final class UnifiedFinderCoordinator {
    private unowned let model: AppModel
    private unowned let shelf: ShelfWindowController
    private let finder = FinderWindowService()

    init(model: AppModel, shelf: ShelfWindowController) {
        self.model = model
        self.shelf = shelf
    }

    func open(path: String, quickPathID: UUID?) {
        shelf.hide()
        let mode = FinderOpenModePreference.current

        Task { [weak self] in
            guard let self else { return }
            let result = await finder.openDirectory(path, mode: mode)

            if case .invalidPath = result {
                model.showToast(model.language == .zhCN
                    ? "目录不存在：\(path)"
                    : "Folder does not exist: \(path)")
                return
            }

            if let quickPathID {
                recordUsage(for: quickPathID)
            }

            if case .openedDirectoryAfterTabFallback = result {
                model.showToast(model.language == .zhCN
                    ? "Finder 标签页创建失败或超时，已安全回退到系统默认打开方式。"
                    : "Finder tab creation failed or timed out; safely fell back to the system default.")
            }
        }
    }

    private func recordUsage(for id: UUID) {
        let now = ShelfClock.now()
        model.updateSettings { settings in
            guard let index = settings.finderQuickPaths.firstIndex(where: { $0.id == id }) else { return }
            settings.finderQuickPaths[index].useCount &+= 1
            settings.finderQuickPaths[index].lastUsedAt = now
        }
    }
}
#endif

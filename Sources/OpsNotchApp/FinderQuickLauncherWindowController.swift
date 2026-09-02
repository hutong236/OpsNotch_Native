#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

@MainActor
final class FinderQuickLauncherWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let finder = FinderWindowService()
    private var panel: FinderQuickPanel?
    /// 当前视觉列表中的位置，不等同于数字槽位。
    private var selectedPosition = 0

    init(model: AppModel) {
        self.model = model
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        selectedPosition = 0
        let panel = ensurePanel()
        refresh(panel)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func ensurePanel() -> FinderQuickPanel {
        if let panel { return panel }
        let panel = FinderQuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onKey = { [weak self] event in self?.handle(event) ?? false }
        self.panel = panel
        return panel
    }

    private func refresh(_ panel: NSPanel) {
        let rows = launcherRows
        selectedPosition = min(selectedPosition, max(rows.count - 1, 0))
        panel.contentView = NSHostingView(rootView: FinderQuickLauncherView(
            rows: rows,
            selectedPosition: selectedPosition,
            language: model.language
        ))
    }

    /// 默认路径始终保持第一行；收藏路径按最近使用、累计使用次数动态排序。
    /// 每个收藏路径的数字键仍由它在 settings.finderQuickPaths 中的固定槽位决定。
    private var launcherRows: [FinderLauncherRow] {
        var rows: [FinderLauncherRow] = [
            FinderLauncherRow(
                id: "default",
                position: 0,
                slot: nil,
                quickPathID: nil,
                shortcut: "↩",
                label: model.language == .zhCN ? "默认路径" : "Default",
                path: model.settings.finderDefaultPath,
                useCount: 0
            )
        ]

        for ranked in FinderQuickPathRanking.ranked(model.settings.finderQuickPaths) {
            rows.append(FinderLauncherRow(
                id: ranked.item.id.uuidString,
                position: rows.count,
                slot: ranked.slot,
                quickPathID: ranked.item.id,
                shortcut: "\(ranked.slot)",
                label: ranked.item.label,
                path: ranked.item.path,
                useCount: ranked.item.useCount
            ))
        }
        return rows
    }

    private func handle(_ event: NSEvent) -> Bool {
        let rows = launcherRows
        guard !rows.isEmpty else { return false }

        switch event.keyCode {
        case 53: // Esc
            panel?.orderOut(nil)
            return true
        case 125: // Down
            selectedPosition = min(selectedPosition + 1, rows.count - 1)
            if let panel { refresh(panel) }
            return true
        case 126: // Up
            selectedPosition = max(selectedPosition - 1, 0)
            if let panel { refresh(panel) }
            return true
        case 36, 76: // Return / keypad Enter
            open(rows[selectedPosition])
            return true
        default:
            if let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), digit >= 1, digit <= 9,
               let row = rows.first(where: { $0.slot == digit }) {
                open(row)
                return true
            }
            return false
        }
    }

    private func open(_ row: FinderLauncherRow) {
        // 立即收起启动器；Finder 自动化在异步子进程中执行，绝不阻塞键盘/UI 主线程。
        panel?.orderOut(nil)
        let mode = FinderOpenModePreference.current

        Task { [weak self] in
            guard let self else { return }
            let result = await finder.openDirectory(row.path, mode: mode)

            if case .invalidPath = result {
                model.showToast(model.language == .zhCN ? "目录不存在：\(row.path)" : "Folder does not exist: \(row.path)")
                return
            }

            if let id = row.quickPathID {
                recordUsage(for: id)
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

private final class FinderQuickPanel: NSPanel {
    var onKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        super.keyDown(with: event)
    }
}

private struct FinderLauncherRow: Identifiable {
    let id: String
    let position: Int
    /// nil 为默认路径；1...9 是固定数字绑定。
    let slot: Int?
    let quickPathID: UUID?
    let shortcut: String
    let label: String
    let path: String
    let useCount: UInt64
}

private struct FinderQuickLauncherView: View {
    let rows: [FinderLauncherRow]
    let selectedPosition: Int
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(language == .zhCN ? "快速打开目录" : "Quick Open Folder")
                    .font(.title2.bold())
                Text(language == .zhCN
                     ? "常用目录自动靠前；数字键绑定保持不变"
                     : "Frequently used folders move up; number bindings stay fixed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Text(row.shortcut)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(width: 30, height: 26)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(row.label).font(.system(size: 13, weight: .medium))
                                if row.useCount > 0 {
                                    Text("×\(row.useCount)")
                                        .font(.system(size: 9, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(NSString(string: row.path).expandingTildeInPath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        row.position == selectedPosition ? Color.accentColor.opacity(0.16) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
        }
        .padding(20)
        .frame(width: 520, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}
#endif

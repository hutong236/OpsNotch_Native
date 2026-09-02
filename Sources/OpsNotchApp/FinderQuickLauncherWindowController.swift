#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

@MainActor
final class FinderQuickLauncherWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let finder = FinderWindowService()
    private var panel: FinderQuickPanel?
    private var selectedIndex = 0

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
        selectedIndex = 0
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
        selectedIndex = min(selectedIndex, max(rows.count - 1, 0))
        panel.contentView = NSHostingView(rootView: FinderQuickLauncherView(
            rows: rows,
            selectedIndex: selectedIndex,
            language: model.language
        ))
    }

    private var launcherRows: [FinderLauncherRow] {
        var rows: [FinderLauncherRow] = [
            FinderLauncherRow(index: 0, shortcut: "↩", label: model.language == .zhCN ? "默认路径" : "Default", path: model.settings.finderDefaultPath)
        ]
        for (index, item) in model.settings.finderQuickPaths.prefix(9).enumerated() {
            rows.append(FinderLauncherRow(index: index + 1, shortcut: "\(index + 1)", label: item.label, path: item.path))
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
            selectedIndex = min(selectedIndex + 1, rows.count - 1)
            if let panel { refresh(panel) }
            return true
        case 126: // Up
            selectedIndex = max(selectedIndex - 1, 0)
            if let panel { refresh(panel) }
            return true
        case 36, 76: // Return / keypad Enter
            open(rows[selectedIndex])
            return true
        default:
            if let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), digit >= 1, digit <= 9,
               let row = rows.first(where: { $0.index == digit }) {
                open(row)
                return true
            }
            return false
        }
    }

    private func open(_ row: FinderLauncherRow) {
        let result = finder.openDirectory(row.path)
        if case .invalidPath = result {
            model.showToast(model.language == .zhCN ? "目录不存在：\(row.path)" : "Folder does not exist: \(row.path)")
            return
        }
        panel?.orderOut(nil)
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
    var id: Int { index }
    let index: Int
    let shortcut: String
    let label: String
    let path: String
}

private struct FinderQuickLauncherView: View {
    let rows: [FinderLauncherRow]
    let selectedIndex: Int
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(language == .zhCN ? "快速打开目录" : "Quick Open Folder")
                    .font(.title2.bold())
                Text(language == .zhCN ? "数字键直接打开，↑↓选择，回车确认" : "Press a number, use ↑↓, or press Return")
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
                            Text(row.label).font(.system(size: 13, weight: .medium))
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
                        row.index == selectedIndex ? Color.accentColor.opacity(0.16) : Color.clear,
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

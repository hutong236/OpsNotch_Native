from pathlib import Path

app = Path("Sources/OpsNotchApp/AppModel.swift")
s = app.read_text()
old = """    var requestOpenFinderPath: ((String, UUID?) -> Void)?
    var hotkeyApply: ((HotkeyShortcut?) -> HotkeyError?)?
"""
new = """    var requestOpenFinderPath: ((String, UUID?) -> Void)?
    var requestDesktopCommand: ((DesktopCommand) -> Void)?
    var hotkeyApply: ((HotkeyShortcut?) -> HotkeyError?)?
"""
assert old in s, "AppModel request hook anchor not found"
s = s.replace(old, new, 1)

old = """    var visibleQuickEntries: [QuickShelfEntry] {
        visibleFinderEntries
            + visibleItems.map(QuickShelfEntry.shelf)
            + visibleLocalEntries
    }
"""
new = """    var visibleDesktopEntries: [QuickShelfEntry] {
        guard kindFilter == .all,
              let command = DesktopCommandParser.parse(query) else { return [] }

        switch command {
        case .list:
            let subtitle = language == .zhCN
                ? "按 Enter 查看所有桌面"
                : "Press Enter to view desktops"
            return [.desktop(
                id: QuickShelfEntry.desktopListID,
                title: L10n.text("desktopList", language),
                subtitle: subtitle,
                command: command
            )]
        case .switchTo(let index):
            let title = language == .zhCN
                ? "切换到桌面 \\(index)"
                : "Switch to Desktop \\(index)"
            let subtitle = language == .zhCN
                ? "按 Enter 执行 · d \\(index)"
                : "Press Enter · d \\(index)"
            return [.desktop(
                id: QuickShelfEntry.desktopSwitchID(index),
                title: title,
                subtitle: subtitle,
                command: command
            )]
        }
    }

    var visibleQuickEntries: [QuickShelfEntry] {
        visibleDesktopEntries
            + visibleFinderEntries
            + visibleItems.map(QuickShelfEntry.shelf)
            + visibleLocalEntries
    }
"""
assert old in s, "AppModel visibleQuickEntries anchor not found"
s = s.replace(old, new, 1)

old = """        switch entry {
        case .finder(_, _, let path, let quickPathID):
"""
new = """        switch entry {
        case .desktop(_, _, _, let command):
            requestDesktopCommand?(command)
        case .finder(_, _, let path, let quickPathID):
"""
assert old in s, "AppModel confirmHighlight anchor not found"
s = s.replace(old, new, 1)

old = """        switch entry {
        case .shelf(let item):
            guard ItemPreviewKind.isPreviewable(item) else { return }
"""
new = """        switch entry {
        case .desktop:
            return
        case .shelf(let item):
            guard ItemPreviewKind.isPreviewable(item) else { return }
"""
assert old in s, "AppModel quickLook anchor not found"
s = s.replace(old, new, 1)
app.write_text(s)

view = Path("Sources/OpsNotchApp/ShelfView.swift")
s = view.read_text()
old = """        let groups = model.grouped
        let working = model.workingSetItems
"""
new = """        let groups = model.grouped
        let desktopEntries = model.visibleDesktopEntries
        let working = model.workingSetItems
"""
assert old in s, "ShelfView content anchor not found"
s = s.replace(old, new, 1)

old = """        let isEmpty = finderEntries.isEmpty
            && working.isEmpty
"""
new = """        let isEmpty = desktopEntries.isEmpty
            && finderEntries.isEmpty
            && working.isEmpty
"""
assert old in s, "ShelfView empty anchor not found"
s = s.replace(old, new, 1)

old = """                    LazyVStack(spacing: 3) {
                        if !finderEntries.isEmpty {
"""
new = """                    LazyVStack(spacing: 3) {
                        if !desktopEntries.isEmpty {
                            SectionHeader(title: L10n.text("desktop", model.language), count: desktopEntries.count)
                            ForEach(desktopEntries) { entry in
                                DesktopQuickShelfRowView(model: model, entry: entry)
                                    .id(entry.id)
                            }
                        }

                        if !finderEntries.isEmpty {
"""
assert old in s, "ShelfView list anchor not found"
s = s.replace(old, new, 1)

old = """private struct FinderQuickShelfRowView: View {
"""
new = """private struct DesktopQuickShelfRowView: View {
    @ObservedObject var model: AppModel
    let entry: QuickShelfEntry
    @State private var hovered = false

    private var highlighted: Bool { model.highlightedQuickEntryID == entry.id }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if let subtitle = entry.desktopSubtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "return")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .contentShape(Rectangle())
        .background(hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 1)
            }
        }
        .onHover { hovered = $0 }
        .onTapGesture {
            guard let command = entry.desktopCommand else { return }
            model.requestDesktopCommand?(command)
        }
    }
}

private struct FinderQuickShelfRowView: View {
"""
assert old in s, "ShelfView row insertion anchor not found"
s = s.replace(old, new, 1)
view.write_text(s)

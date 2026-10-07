#if os(macOS)
import Foundation
import OpsNotchCore

struct ShelfSnapshot {
    let itemSnapshot: QuickShelfItemSnapshot
    let finderEntries: [QuickShelfEntry]
    let desktopEntries: [QuickShelfEntry]
    let localEntries: [QuickShelfEntry]
    let visibleEntries: [QuickShelfEntry]
    let presentationItems: [ShelfPresentationItem]
    let presentationByID: [String: ShelfPresentationItem]
    let entryByID: [String: QuickShelfEntry]
}

/// One source/presentation derivation per revision. Interaction state never invalidates ranking.
@MainActor
final class ShelfSnapshotProvider {
    private(set) var revision: UInt64 = 0
    private let cache = QuickShelfSnapshotCache<ShelfSnapshot>()

    func invalidate() { revision &+= 1 }

    func snapshot(items: [ShelfItem], settings: ShelfSettings, experience: ShelfExperienceModel) -> ShelfSnapshot {
        cache.value(for: revision) {
            buildQuickShelfSnapshot(items: items, settings: settings, query: experience.query,
                kindFilter: experience.kindFilter, appContext: experience.appContext)
        }
    }

    private func buildQuickShelfSnapshot(items: [ShelfItem], settings: ShelfSettings, query: String, kindFilter: ShelfKindFilter, appContext: AppContextKind) -> ShelfSnapshot {
        let itemSnapshot = QuickShelfItemSnapshotBuilder.build(
            items: items,
            workingSetItemIDs: settings.workingSetItemIDs,
            query: query,
            kindFilter: kindFilter,
            appContext: appContext
        )
        let desktopEntries = buildVisibleDesktopEntries(settings: settings, query: query, kindFilter: kindFilter)
        let finderEntries = buildVisibleFinderEntries(settings: settings, query: query, kindFilter: kindFilter)
        let localEntries: [QuickShelfEntry] = []
        let visibleEntries = desktopEntries
            + finderEntries
            + itemSnapshot.visibleItems.map(QuickShelfEntry.shelf)
        let entryByID = Dictionary(uniqueKeysWithValues: visibleEntries.map { ($0.id, $0) })

        let presentationItems = ShelfPresentationAdapter.adapt(visibleEntries,
            language: settings.language, workingSetItemIDs: Set(settings.workingSetItemIDs))
        return ShelfSnapshot(
            itemSnapshot: itemSnapshot,
            finderEntries: finderEntries,
            desktopEntries: desktopEntries,
            localEntries: localEntries,
            visibleEntries: visibleEntries,
            presentationItems: presentationItems,
            presentationByID: Dictionary(uniqueKeysWithValues: presentationItems.map { ($0.id, $0) }),
            entryByID: entryByID
        )
    }

    private func buildVisibleFinderEntries(settings: ShelfSettings, query: String, kindFilter: ShelfKindFilter) -> [QuickShelfEntry] {
        guard kindFilter == .all || kindFilter == .file else { return [] }

        var entries: [QuickShelfEntry] = []
        let defaultPath = expandedFinderPath(settings.finderDefaultPath)
        let defaultTitle = L10n.text("finderDefaultPath", settings.language)
        if finderMatches(title: defaultTitle, path: defaultPath, query: query) {
            entries.append(.finder(
                id: QuickShelfEntry.finderDefaultID,
                title: defaultTitle,
                path: defaultPath,
                quickPathID: nil
            ))
        }

        for ranked in FinderQuickPathRanking.ranked(settings.finderQuickPaths) {
            let path = expandedFinderPath(ranked.item.path)
            guard finderMatches(title: ranked.item.label, path: path, query: query) else { continue }
            entries.append(.finder(
                id: QuickShelfEntry.finderID(ranked.item.id),
                title: ranked.item.label,
                path: path,
                quickPathID: ranked.item.id
            ))
        }
        return entries
    }

    private func buildVisibleDesktopEntries(settings: ShelfSettings, query: String, kindFilter: ShelfKindFilter) -> [QuickShelfEntry] {
        guard kindFilter == .all,
              let command = DesktopCommandParser.parse(query) else { return [] }

        switch command {
        case .list:
            let subtitle = settings.language == .zhCN
                ? "按 Enter 查看所有桌面"
                : "Press Enter to view desktops"
            return [.desktop(
                id: QuickShelfEntry.desktopListID,
                title: L10n.text("desktopList", settings.language),
                subtitle: subtitle,
                command: command
            )]
        case .switchTo(let index):
            let title = settings.language == .zhCN
                ? "切换到桌面 \(index)"
                : "Switch to Desktop \(index)"
            let subtitle = settings.language == .zhCN
                ? "按 Enter 执行 · d \(index)"
                : "Press Enter · d \(index)"
            return [.desktop(
                id: QuickShelfEntry.desktopSwitchID(index),
                title: title,
                subtitle: subtitle,
                command: command
            )]
        }
    }

    private func finderMatches(title: String, path: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(trimmed)
            || path.localizedCaseInsensitiveContains(trimmed)
    }

    private func expandedFinderPath(_ rawPath: String) -> String {
        NSString(string: rawPath).expandingTildeInPath
    }
}
#endif

#if os(macOS)
import Foundation
import OpsNotchCore

struct ShelfSectionSnapshot: Identifiable {
    let kind: ShelfSectionKind
    let entries: [QuickShelfEntry]
    var id: ShelfSectionKind { kind }
}

struct ShelfSnapshot {
    let sections: [ShelfSectionSnapshot]
    let itemSnapshot: QuickShelfItemSnapshot
    let finderEntries: [QuickShelfEntry]
    let desktopEntries: [QuickShelfEntry]
    let localEntries: [QuickShelfEntry]
    let visibleEntries: [QuickShelfEntry]
    let visibleShelfItems: [ShelfItem]
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
            buildQuickShelfSnapshot(items: items, settings: settings, scope: experience.commandSearchScope, appContext: experience.appContext)
        }
    }

    private func buildQuickShelfSnapshot(items: [ShelfItem], settings: ShelfSettings, scope: CommandSearchScope, appContext: AppContextKind) -> ShelfSnapshot {
        let now = ShelfClock.now()
        let itemSnapshot = QuickShelfItemSnapshotBuilder.build(
            items: items,
            workingSetItemIDs: settings.workingSetItemIDs,
            query: scope.query,
            kindFilter: scope.kindFilter,
            appContext: appContext,
            now: now,
            searchScope: scope
        )
        let desktopEntries = buildVisibleDesktopEntries(settings: settings, intent: scope.intent)
        let finderEntries: [QuickShelfEntry]
        if case .finderPath(let path) = scope.intent {
            let expanded = expandedFinderPath(path)
            finderEntries = [.finder(id: "finder:path:\(expanded)", title: path, path: expanded, quickPathID: nil)]
        } else if scope.includesFinderQuickPaths {
            // Finder quick paths are a first-class Shelf source, not a context-only source.
            // Keep them visible in the default Smart Shelf so an empty Shelf still exposes
            // the configured default directory and saved shortcuts.
            finderEntries = buildVisibleFinderEntries(settings: settings, query: scope.query, kindFilter: scope.kindFilter)
        } else {
            finderEntries = []
        }
        let localEntries: [QuickShelfEntry] = []
        let sections = buildSections(items: items, itemSnapshot: itemSnapshot, finderEntries: finderEntries,
            desktopEntries: desktopEntries, scope: scope, appContext: appContext, now: now)
        // Rendering, keyboard traversal and presentation consume the same section order.
        let visibleEntries = sections.flatMap(\.entries)
        let entryByID = Dictionary(uniqueKeysWithValues: visibleEntries.map { ($0.id, $0) })

        let presentationItems = ShelfPresentationAdapter.adapt(visibleEntries,
            language: settings.language, workingSetItemIDs: Set(settings.workingSetItemIDs))
        return ShelfSnapshot(
            sections: sections,
            itemSnapshot: itemSnapshot,
            finderEntries: finderEntries,
            desktopEntries: desktopEntries,
            localEntries: localEntries,
            visibleEntries: visibleEntries,
            visibleShelfItems: visibleEntries.compactMap(\.shelfItem),
            presentationItems: presentationItems,
            presentationByID: Dictionary(uniqueKeysWithValues: presentationItems.map { ($0.id, $0) }),
            entryByID: entryByID
        )
    }

    private func buildSections(items: [ShelfItem], itemSnapshot: QuickShelfItemSnapshot, finderEntries: [QuickShelfEntry],
                               desktopEntries: [QuickShelfEntry], scope: CommandSearchScope,
                               appContext: AppContextKind, now: UInt64) -> [ShelfSectionSnapshot] {
        let visibleIDs = Set(itemSnapshot.visibleItems.map(\.id))
        // Preserve store insertion order for SmartShelfRanking's same-second newest tie.
        let visibleItems = items.filter { visibleIDs.contains($0.id) }
        var entriesByKind: [ShelfSectionKind: [QuickShelfEntry]] = [:]
        switch scope.intent {
        case .desktopList, .desktopSwitch, .finderPath:
            entriesByKind[.context] = desktopEntries + finderEntries
        case .favorites:
            // Include pinned working-set members once, rather than splitting a favorites request.
            entriesByKind[.favorites] = SmartShelfRanking.ordered(visibleItems,
                query: scope.query, kindFilter: scope.kindFilter, appContext: appContext, now: now).map(QuickShelfEntry.shelf)
        default:
            let hasQuery = !scope.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasQuery || scope.intent != nil || scope.kindFilter != .all {
                // Rank across partitions so membership never puts a weaker query match ahead
                // of a stronger match. SmartShelfRanking retains its newest-item reservation.
                entriesByKind[.results] = SmartShelfRanking.ordered(visibleItems,
                    query: scope.query, kindFilter: scope.kindFilter, appContext: appContext, now: now).map(QuickShelfEntry.shelf)
                    + finderEntries
            } else {
                entriesByKind[.context] = finderEntries
                entriesByKind[.now] = itemSnapshot.working.map(QuickShelfEntry.shelf)
                entriesByKind[.favorites] = itemSnapshot.pinned.map(QuickShelfEntry.shelf)
                entriesByKind[.recent] = itemSnapshot.recent.map(QuickShelfEntry.shelf)
            }
        }
        // Stable entry IDs remain the identity boundary across all source adapters.
        var seen = Set<String>()
        let counts = entriesByKind.mapValues(\.count)
        return ShelfSectionModel.visibleSections(itemCounts: counts).compactMap { kind in
            let entries = (entriesByKind[kind] ?? []).filter { seen.insert($0.id).inserted }
            guard !entries.isEmpty else { return nil }
            return ShelfSectionSnapshot(kind: kind, entries: entries)
        }
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

    private func buildVisibleDesktopEntries(settings: ShelfSettings, intent: CommandIntent?) -> [QuickShelfEntry] {
        let command: DesktopCommand
        switch intent {
        case .desktopList: command = .list
        case .desktopSwitch(let index): command = .switchTo(index: index)
        default: return []
        }

        switch command {
        case .list:
            let subtitle = L10n.text("desktopCommandListHint", settings.language)
            return [.desktop(
                id: QuickShelfEntry.desktopListID,
                title: L10n.text("desktopList", settings.language),
                subtitle: subtitle,
                command: command
            )]
        case .switchTo(let index):
            let title = String(
                format: L10n.text("desktopCommandSwitchTitle", settings.language),
                index
            )
            let subtitle = String(
                format: L10n.text("desktopCommandSwitchHint", settings.language),
                index
            )
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

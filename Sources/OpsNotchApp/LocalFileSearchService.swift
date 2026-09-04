#if os(macOS)
import AppKit
import Foundation

struct LocalFileCandidate: Identifiable, Equatable, Sendable {
    let path: String
    let title: String
    let isDirectory: Bool

    var id: String { path }
}

@MainActor
enum LocalFileSearchService {
    static func recentDocumentPaths(limit: Int = 20) -> [String] {
        Array(NSDocumentController.shared.recentDocumentURLs.prefix(limit)).map(\.path)
    }

    static func search(
        query: String,
        recentDocumentPaths: [String],
        shelfPaths: [String],
        finderPaths: [String],
        limit: Int = 20
    ) async -> [LocalFileCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        return await Task.detached(priority: .userInitiated) {
            searchSync(
                query: trimmed,
                recentDocumentPaths: recentDocumentPaths,
                shelfPaths: shelfPaths,
                finderPaths: finderPaths,
                limit: limit
            )
        }.value
    }

    nonisolated private static func searchSync(
        query: String,
        recentDocumentPaths: [String],
        shelfPaths: [String],
        finderPaths: [String],
        limit: Int
    ) -> [LocalFileCandidate] {
        let fm = FileManager.default
        let q = query.lowercased()
        var candidates: [LocalFileCandidate] = []
        var seenPaths = Set<String>()

        func addPath(_ path: String) {
            guard candidates.count < max(limit * 4, limit) else { return }
            let standardized = NSString(string: path).standardizingPath
            guard !standardized.isEmpty, !seenPaths.contains(standardized) else { return }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: standardized, isDirectory: &isDirectory) else { return }
            let title = URL(fileURLWithPath: standardized).lastPathComponent
            let searchable = "\(title) \(standardized)".lowercased()
            guard searchable.contains(q) else { return }
            seenPaths.insert(standardized)
            candidates.append(LocalFileCandidate(path: standardized, title: title, isDirectory: isDirectory.boolValue))
        }

        for path in recentDocumentPaths { addPath(path) }

        var roots: [String] = []
        var seenRoots = Set<String>()
        func appendRoot(_ raw: String) {
            let expanded = NSString(string: raw).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: expanded, isDirectory: &isDirectory) else { return }
            let root = isDirectory.boolValue
                ? expanded
                : URL(fileURLWithPath: expanded).deletingLastPathComponent().path
            let standardized = NSString(string: root).standardizingPath
            guard !seenRoots.contains(standardized) else { return }
            seenRoots.insert(standardized)
            roots.append(standardized)
        }

        shelfPaths.forEach(appendRoot)
        finderPaths.forEach(appendRoot)

        for root in roots.prefix(16) {
            guard candidates.count < max(limit * 4, limit) else { break }
            guard let urls = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: root, isDirectory: true),
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls.prefix(64) {
                addPath(url.path)
                if candidates.count >= max(limit * 4, limit) { break }
            }
        }

        func matchScore(_ candidate: LocalFileCandidate) -> Int {
            let title = candidate.title.lowercased()
            let path = candidate.path.lowercased()
            if title == q { return 400 }
            if title.hasPrefix(q) { return 300 }
            if title.contains(q) { return 220 }
            if path.hasPrefix(q) { return 180 }
            if path.contains(q) { return 120 }
            return 0
        }

        return Array(candidates.sorted {
            let l = matchScore($0)
            let r = matchScore($1)
            if l != r { return l > r }
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
            return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }.prefix(limit))
    }
}
#endif

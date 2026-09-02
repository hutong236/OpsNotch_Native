#if os(macOS)
import AppKit
import Foundation

/// 使用 macOS 原生 Spotlight 元数据索引查找应用，并在 Finder 中定位选中。
/// 不启动目标应用，不依赖 shell/mdfind。
@MainActor
final class SpotlightRevealService {
    enum Result {
        case revealed(URL)
        case notFound(String)
    }

    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?

    func revealApplication(named rawName: String, completion: @escaping (Result) -> Void) {
        stopCurrentQuery()

        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.notFound(rawName))
            return
        }
        let appName = trimmed.lowercased().hasSuffix(".app") ? trimmed : "\(trimmed).app"

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.predicate = NSPredicate(format: "%K ==[c] %@", NSMetadataItemFSNameKey, appName)
        query.valueListAttributes = [NSMetadataItemPathKey]

        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self, weak query] _ in
            guard let self, let query else { return }
            MainActor.assumeIsolated {
                query.disableUpdates()

                let candidates: [URL] = query.results.compactMap { result in
                    guard let item = result as? NSMetadataItem,
                          let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                        return nil
                    }
                    return URL(fileURLWithPath: path)
                }
                .filter { $0.pathExtension.caseInsensitiveCompare("app") == .orderedSame }
                .sorted { lhs, rhs in
                    // /Applications 优先，其次 ~/Applications，再按路径稳定排序。
                    let lp = Self.priority(for: lhs)
                    let rp = Self.priority(for: rhs)
                    if lp != rp { return lp < rp }
                    return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
                }

                self.stopCurrentQuery()

                guard let url = candidates.first else {
                    completion(.notFound(appName))
                    return
                }
                NSWorkspace.shared.activateFileViewerSelecting([url])
                completion(.revealed(url))
            }
        }

        self.query = query
        query.start()
    }

    private func stopCurrentQuery() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        query?.stop()
        query = nil
    }

    private static func priority(for url: URL) -> Int {
        let path = url.standardizedFileURL.path
        if path.hasPrefix("/Applications/") { return 0 }
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path + "/"
        if path.hasPrefix(userApps) { return 1 }
        return 2
    }
}
#endif

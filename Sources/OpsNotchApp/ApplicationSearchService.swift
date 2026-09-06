#if os(macOS)
import Foundation

struct ApplicationCandidate: Identifiable, Equatable, Sendable {
    let path: String
    let title: String

    var id: String { path }
}

enum ApplicationSearchService {
    static let fixedDirectories = [
        "/Applications",
        "/System/Applications",
        "~/Applications",
    ]

    private static let indexedApplications: [ApplicationCandidate] = scanFixedDirectories()

    static func search(query: String, limit: Int = 20) -> [ApplicationCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        let normalizedQuery = trimmed.lowercased()
        let matches = indexedApplications.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
        }

        func score(_ candidate: ApplicationCandidate) -> Int {
            let title = candidate.title.lowercased()
            if title == normalizedQuery { return 300 }
            if title.hasPrefix(normalizedQuery) { return 200 }
            return 100
        }

        return Array(matches.sorted {
            let leftScore = score($0)
            let rightScore = score($1)
            if leftScore != rightScore { return leftScore > rightScore }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }.prefix(limit))
    }

    private static func scanFixedDirectories() -> [ApplicationCandidate] {
        let fileManager = FileManager.default
        var seenPaths = Set<String>()
        var results: [ApplicationCandidate] = []

        for rawRoot in fixedDirectories {
            let expandedRoot = NSString(string: rawRoot).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: expandedRoot, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let rootURL = URL(fileURLWithPath: expandedRoot, isDirectory: true)
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { continue }
                let path = NSString(string: url.path).standardizingPath
                guard seenPaths.insert(path).inserted else { continue }

                results.append(ApplicationCandidate(
                    path: path,
                    title: url.deletingPathExtension().lastPathComponent
                ))
            }
        }

        return results.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}
#endif

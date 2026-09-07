#if os(macOS)
import AppKit

/// 读取拖拽/剪贴板中的真实文件 URL。
///
/// 文件 pasteboard 可能同时提供 fileURL、文件内容等多种 flavor。直接使用
/// `readObjects(forClasses: [NSURL.self])` 时，AppKit 可以从文件内容 flavor 物化出
/// `/tmp/...` 临时文件。对于暂存工具这会把临时路径误当成原文件路径持久化。
///
/// 因此固定优先级：
/// 1. 每个 NSPasteboardItem 明确声明的 `.fileURL`
/// 2. legacy `NSFilenamesPboardType` 绝对路径
/// 3. 最后才使用 AppKit NSURL object reader 兼容少数来源
@MainActor
enum PasteboardFileURLReader {
    private static let legacyFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    static func read(from pasteboard: NSPasteboard) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            guard url.isFileURL else { return }
            let normalized = url.standardizedFileURL
            let key = normalized.path
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            result.append(normalized)
        }

        // 首选 pasteboard item 自己声明的 fileURL，避免泛型 reader 从文件内容生成临时 URL。
        if let items = pasteboard.pasteboardItems {
            for item in items {
                guard let raw = item.string(forType: .fileURL),
                      let url = URL(string: raw) else { continue }
                append(url)
            }
        }
        if !result.isEmpty { return result }

        // Finder/旧 AppKit 来源仍可能只给 NSFilenamesPboardType。
        if let paths = pasteboard.propertyList(forType: legacyFilenamesType) as? [String] {
            for path in paths where !path.isEmpty {
                append(URL(fileURLWithPath: path))
            }
        }
        if !result.isEmpty { return result }

        // 兼容兜底；只有没有明确 fileURL/path flavor 时才允许 AppKit object conversion。
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL] {
            for object in objects {
                append(object as URL)
            }
        }
        return result
    }
}
#endif

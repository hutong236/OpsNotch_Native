import Foundation

public extension ShelfStoreService {
    /// 剪贴板/拖入自动捕获专用入口:单趟 mutate 内完成"相同内容判定与上浮(或新增)",
    /// 查重不再额外做一次全文件读写。内容相同则刷新已有条目的最近使用时间,
    /// 不新增条目;手动 addText/addURL 仍保持原语义,允许用户主动创建内容相同但标题不同的多个条目。
    @discardableResult
    func captureText(_ content: String, title: String? = nil, sourceAppName: String? = nil) throws -> ShelfStore {
        let normalized = Self.normalizedClipboardText(content)
        guard !normalized.isEmpty else { return try load() }
        return try mutate { store in
            if let index = Self.newestCaptureIndex(in: store.items, kind: .text, matches: { Self.normalizedClipboardText($0) == normalized }) {
                store.items[index].updatedAt = ShelfClock.now()
                if let sourceAppName, !sourceAppName.isEmpty { store.items[index].sourceAppName = sourceAppName }
                return
            }
            let displayTitle: String
            if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                displayTitle = title
            } else {
                let firstLine = normalized.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "Text"
                displayTitle = String(firstLine.prefix(48))
            }
            store.items.append(ShelfItem(kind: .text, title: displayTitle, content: normalized, sourceAppName: sourceAppName))
        }
    }

    /// 拖入 http/https URL 的捕获入口:与 captureText 对称,相同 URL 上浮已有条目而非新增。
    @discardableResult
    func captureURL(_ value: String, title: String? = nil, sourceAppName: String? = nil) throws -> ShelfStore {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SafeActionValidator.isHTTPURL(trimmed) else { throw ShelfStoreError.invalidURL }
        return try mutate { store in
            if let index = Self.newestCaptureIndex(in: store.items, kind: .url, matches: { $0 == trimmed }) {
                store.items[index].updatedAt = ShelfClock.now()
                if let sourceAppName, !sourceAppName.isEmpty { store.items[index].sourceAppName = sourceAppName }
                return
            }
            let fallback = URL(string: trimmed)?.host ?? trimmed
            let displayTitle = title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ?? fallback
            store.items.append(ShelfItem(kind: .url, title: displayTitle, content: trimmed, sourceAppName: sourceAppName))
        }
    }

    /// 图片剪贴板捕获入口：将 PNG 数据落入 Shelf 管理目录，并标记为 clipboardImage，
    /// 这样条目既能显示缩略图/预览，也能再次以图片而不是文件路径写回系统剪贴板。
    @discardableResult
    func captureImageData(_ data: Data, sourceAppName: String? = nil) throws -> ShelfStore {
        guard !data.isEmpty else { return try load() }
        return try mutate { store in
            // The 1-second live pasteboard suppression cannot deduplicate images
            // recopied later. Reuse a recently captured managed image instead of
            // persisting multiple identical PNGs. Limit filesystem lookups to
            // recent entries; comparisons use memory-mapped data where possible.
            let recentImageIndices = store.items.indices
                .filter { store.items[$0].clipboardImage && store.items[$0].storageMode == .copy }
                .sorted { lhs, rhs in
                    let a = store.items[lhs]
                    let b = store.items[rhs]
                    return (a.updatedAt, a.createdAt, lhs) > (b.updatedAt, b.createdAt, rhs)
                }
                .prefix(16)
            for index in recentImageIndices {
                let existing = store.items[index]
                let expectedParent = managedFilesURL
                    .appendingPathComponent(existing.id.uuidString, isDirectory: true)
                    .standardizedFileURL
                let imageURL = URL(fileURLWithPath: existing.content).standardizedFileURL
                // Never read an arbitrary referenced file as part of clipboard dedup.
                guard imageURL.deletingLastPathComponent() == expectedParent,
                      let values = try? imageURL.resourceValues(
                          forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
                      ),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      values.fileSize == data.count,
                      let previousData = try? Data(contentsOf: imageURL, options: .mappedIfSafe),
                      previousData == data else { continue }
                store.items[index].updatedAt = ShelfClock.now()
                if let sourceAppName, !sourceAppName.isEmpty {
                    store.items[index].sourceAppName = sourceAppName
                }
                return
            }

            let id = UUID()
            let parent = managedFilesURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let fileName = "clipboard-image-\(id.uuidString.prefix(8)).png"
            let destination = parent.appendingPathComponent(fileName)
            try data.write(to: destination, options: .atomic)
            store.items.append(ShelfItem(
                id: id,
                kind: .file,
                title: "Clipboard Image",
                content: destination.path,
                storageMode: .copy,
                fileExtension: "png",
                sourceAppName: sourceAppName,
                clipboardImage: true
            ))
        }
    }

    /// 命中"同类型且 matches 内容"的最新条目(按 updatedAt,再按 createdAt 取最大),用于捕获去重。
    private static func newestCaptureIndex(
        in items: [ShelfItem],
        kind: ShelfKind,
        matches: (String) -> Bool
    ) -> Int? {
        var best: (index: Int, updatedAt: UInt64, createdAt: UInt64)?
        for (index, item) in items.enumerated() where item.kind == kind && matches(item.content) {
            if best == nil || (item.updatedAt, item.createdAt) > (best!.updatedAt, best!.createdAt) {
                best = (index, item.updatedAt, item.createdAt)
            }
        }
        return best?.index
    }

    private static func normalizedClipboardText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

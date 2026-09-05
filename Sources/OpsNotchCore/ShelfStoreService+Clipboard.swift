import Foundation

public extension ShelfStoreService {
    /// 剪贴板/拖入自动捕获专用入口:单趟 mutate 内完成"相同内容判定与上浮(或新增)",
    /// 查重不再额外做一次全文件读写。内容相同则刷新已有条目的最近使用时间,
    /// 不新增条目;手动 addText/addURL 仍保持原语义,允许用户主动创建内容相同但标题不同的多个条目。
    @discardableResult
    func captureText(_ content: String, title: String? = nil) throws -> ShelfStore {
        let normalized = Self.normalizedClipboardText(content)
        guard !normalized.isEmpty else { return try load() }
        return try mutate { store in
            if let index = Self.newestCaptureIndex(in: store.items, kind: .text, matches: { Self.normalizedClipboardText($0) == normalized }) {
                store.items[index].updatedAt = ShelfClock.now()
                return
            }
            let displayTitle: String
            if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                displayTitle = title
            } else {
                let firstLine = normalized.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "Text"
                displayTitle = String(firstLine.prefix(48))
            }
            store.items.append(ShelfItem(kind: .text, title: displayTitle, content: normalized))
        }
    }

    /// 拖入 http/https URL 的捕获入口:与 captureText 对称,相同 URL 上浮已有条目而非新增。
    @discardableResult
    func captureURL(_ value: String, title: String? = nil) throws -> ShelfStore {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SafeActionValidator.isHTTPURL(trimmed) else { throw ShelfStoreError.invalidURL }
        return try mutate { store in
            if let index = Self.newestCaptureIndex(in: store.items, kind: .url, matches: { $0 == trimmed }) {
                store.items[index].updatedAt = ShelfClock.now()
                return
            }
            let fallback = URL(string: trimmed)?.host ?? trimmed
            let displayTitle = title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ?? fallback
            store.items.append(ShelfItem(kind: .url, title: displayTitle, content: trimmed))
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

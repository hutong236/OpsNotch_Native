import Foundation

public extension ShelfStoreService {
    /// 剪贴板自动捕获专用入口：相同文本不新增第二条，而是刷新已有条目的最近使用时间。
    /// 手动 addText 仍保持原语义，允许用户主动创建内容相同但标题不同的多个条目。
    @discardableResult
    func captureText(_ content: String, title: String? = nil) throws -> ShelfStore {
        let normalized = Self.normalizedClipboardText(content)
        guard !normalized.isEmpty else { return try load() }

        let current = try load()
        if let existing = current.items
            .filter({ $0.kind == .text && Self.normalizedClipboardText($0.content) == normalized })
            .max(by: {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.createdAt < $1.createdAt
            }) {
            return try touch(id: existing.id)
        }

        return try addText(normalized, title: title)
    }

    private static func normalizedClipboardText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

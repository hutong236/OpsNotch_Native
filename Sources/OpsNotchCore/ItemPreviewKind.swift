import Foundation

/// 悬浮放大预览的条目资格判定:文字条目与图片文件条目可预览,其余类型不可。
public enum ItemPreviewKind {
    public static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif",
        "tiff", "tif", "bmp", "svg", "avif", "ico"
    ]

    public static func isImagePath(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return !ext.isEmpty && imageExtensions.contains(ext)
    }

    public static func isPreviewable(_ item: ShelfItem) -> Bool {
        switch item.kind {
        case .text:
            return !item.content.isEmpty
        case .file:
            if isImagePath(item.content) { return true }
            if let ext = item.fileExtension?.lowercased(), imageExtensions.contains(ext) { return true }
            return false
        case .folder, .url, .application, .action:
            return false
        }
    }
}

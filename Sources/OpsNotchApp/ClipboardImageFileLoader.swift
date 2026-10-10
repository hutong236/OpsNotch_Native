#if os(macOS)
import Foundation

/// Read a managed PNG on a background worker without decoding/re-encoding it.
/// Mapping avoids eagerly allocating another heap-sized copy for large images.
enum ClipboardImageFileLoader {
    nonisolated static func readPNG(at path: String) -> Data? {
        autoreleasepool {
            guard let data = try? Data(
                contentsOf: URL(fileURLWithPath: path),
                options: .mappedIfSafe
            ), !data.isEmpty else { return nil }
            return data
        }
    }
}
#endif

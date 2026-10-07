#if os(macOS)
import Foundation
import ImageIO

struct DecodedImageResource: @unchecked Sendable {
    let cgImage: CGImage
    let originalPixelSize: CGSize
}

enum BackgroundImageDecoder {
    /// ImageIO decode is intentionally detached from MainActor and bounded to the requested
    /// pixel size. The original dimensions are returned separately for layout calculations.
    static func thumbnail(at url: URL, maximumPixelSize: Int) async -> DecodedImageResource? {
        await Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return nil }
            return autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(
                    url as CFURL,
                    [kCGImageSourceShouldCache: false] as CFDictionary
                ) else { return nil }

                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                let originalWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue
                let originalHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue

                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true,
                    ] as CFDictionary
                ) else { return nil }

                let originalSize = CGSize(
                    width: originalWidth ?? Double(cgImage.width),
                    height: originalHeight ?? Double(cgImage.height)
                )
                return DecodedImageResource(cgImage: cgImage, originalPixelSize: originalSize)
            }
        }.value
    }
}
#endif

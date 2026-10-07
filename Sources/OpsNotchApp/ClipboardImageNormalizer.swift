#if os(macOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ClipboardImageNormalizer {
    enum Source: Sendable {
        case png
        case tiff
    }

    /// PNG pasteboard data is already in the managed format; TIFF is transcoded with
    /// ImageIO off the main actor so large screenshots do not stall AppKit event handling.
    nonisolated static func pngData(from data: Data, source: Source) -> Data? {
        guard !data.isEmpty else { return nil }
        if source == .png { return data }

        return autoreleasepool {
            guard let imageSource = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
            ) else { return nil }

            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else { return nil }

            CGImageDestinationAddImageFromSource(destination, imageSource, 0, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return output as Data
        }
    }
}
#endif

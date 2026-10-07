#if os(macOS)
import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import OpsNotchApp

final class ClipboardImageNormalizerTests: XCTestCase {
    func testPNGPassthroughDoesNotReencode() throws {
        let png = try makeImageData(type: .png)
        let normalized = try XCTUnwrap(
            ClipboardImageNormalizer.pngData(from: png, source: .png)
        )
        XCTAssertEqual(normalized, png)
    }

    func testTIFFConvertsToPNG() throws {
        let tiff = try makeImageData(type: .tiff)
        let normalized = try XCTUnwrap(
            ClipboardImageNormalizer.pngData(from: tiff, source: .tiff)
        )
        let source = try XCTUnwrap(CGImageSourceCreateWithData(normalized as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.png.identifier)
    }

    private func makeImageData(type: NSBitmapImageRep.FileType) throws -> Data {
        let rep = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 4,
                pixelsHigh: 4,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        return try XCTUnwrap(rep.representation(using: type, properties: [:]))
    }
}
#endif

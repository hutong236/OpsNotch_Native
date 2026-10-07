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

    func testBackgroundDecoderBoundsPixelDimensions() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-image-decode-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let rep = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 1024,
                pixelsHigh: 512,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: url)

        let decoded = try XCTUnwrap(
            await BackgroundImageDecoder.thumbnail(at: url, maximumPixelSize: 128)
        )

        XCTAssertLessThanOrEqual(decoded.cgImage.width, 128)
        XCTAssertLessThanOrEqual(decoded.cgImage.height, 128)
        XCTAssertEqual(decoded.originalPixelSize.width, 1024, accuracy: 1)
        XCTAssertEqual(decoded.originalPixelSize.height, 512, accuracy: 1)
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

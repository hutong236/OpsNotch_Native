#if os(macOS)
import AppKit
import XCTest

final class PasteboardSemanticsTests: XCTestCase {
    func testWritingNSURLKeepsFileURLPasteboardFlavor() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-pasteboard-\(UUID().uuidString).txt")
        try Data("fixture".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("opsnotch-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        XCTAssertTrue(pasteboard.writeObjects([fileURL as NSURL]))
        XCTAssertNotNil(pasteboard.availableType(from: [.fileURL]))

        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = try XCTUnwrap(
            pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL]
        )
        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual((objects[0] as URL).standardizedFileURL, fileURL.standardizedFileURL)
    }

    func testWritingStringKeepsStringPasteboardFlavor() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("opsnotch-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        XCTAssertTrue(pasteboard.setString("clipboard text", forType: .string))
        XCTAssertNotNil(pasteboard.availableType(from: [.string]))
        XCTAssertEqual(pasteboard.string(forType: .string), "clipboard text")

        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let fileObjects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL]
        XCTAssertTrue(fileObjects == nil || fileObjects?.isEmpty == true)
    }
}
#endif

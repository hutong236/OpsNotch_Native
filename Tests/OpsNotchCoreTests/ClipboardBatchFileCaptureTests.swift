import Foundation
import XCTest
@testable import OpsNotchCore

final class ClipboardBatchFileCaptureTests: XCTestCase {
    func testBatchReferenceCaptureKeepsOrderKindsAndSourceApplication() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inputs = root.appendingPathComponent("inputs", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let text = inputs.appendingPathComponent("alpha.txt")
        let folder = inputs.appendingPathComponent("reports", isDirectory: true)
        let app = inputs.appendingPathComponent("Demo.app", isDirectory: true)
        try Data("alpha".utf8).write(to: text)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let captured = try service.addClipboardPaths(
            [text, folder, app], mode: .reference, sourceAppName: "Finder"
        )

        XCTAssertEqual(captured.items.count, 3)
        XCTAssertEqual(captured.items.map(\.kind), [.file, .folder, .application])
        XCTAssertEqual(captured.items.map(\.content), [text.path, folder.path, app.path])
        XCTAssertEqual(captured.items.map(\.sourceAppName), ["Finder", "Finder", "Finder"])
        XCTAssertTrue(captured.items.allSatisfy { $0.storageMode == .reference })
        XCTAssertEqual(try service.load().items.map(\.id), captured.items.map(\.id))
    }

    func testBatchCopyCopiesFileAndFolderButReferencesApplications() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inputs = root.appendingPathComponent("inputs", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let text = inputs.appendingPathComponent("alpha.txt")
        let folder = inputs.appendingPathComponent("reports", isDirectory: true)
        let app = inputs.appendingPathComponent("Demo.app", isDirectory: true)
        try Data("alpha".utf8).write(to: text)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("report".utf8).write(to: folder.appendingPathComponent("one.txt"))
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let captured = try service.addClipboardPaths([text, folder, app], mode: .copy)

        XCTAssertEqual(captured.items.map(\.kind), [.file, .folder, .application])
        XCTAssertEqual(captured.items.map(\.storageMode), [.copy, .copy, .reference])
        XCTAssertEqual(captured.items[2].content, app.path)
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: captured.items[0].content)),
            Data("alpha".utf8)
        )
        let copiedFolder = URL(fileURLWithPath: captured.items[1].content, isDirectory: true)
        XCTAssertEqual(
            try Data(contentsOf: copiedFolder.appendingPathComponent("one.txt")),
            Data("report".utf8)
        )
        let directories = try FileManager.default.contentsOfDirectory(
            at: service.managedFilesURL, includingPropertiesForKeys: nil
        )
        XCTAssertEqual(directories.count, 2, "Applications must never create copied bundles")
    }

    func testBatchFailureRollsBackUncommittedManagedCopiesAndShelf() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let valid = root.appendingPathComponent("valid.txt")
        try Data("available".utf8).write(to: valid)
        let absent = root.appendingPathComponent("missing.txt")

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let first = try service.addText("keep existing item")
        XCTAssertThrowsError(try service.addClipboardPaths([valid, absent], mode: .copy))

        let after = try service.load()
        XCTAssertEqual(after.items.map(\.id), first.items.map(\.id))
        XCTAssertEqual(after.items.map(\.content), first.items.map(\.content))
        let managed = try FileManager.default.contentsOfDirectory(
            at: service.managedFilesURL, includingPropertiesForKeys: nil
        )
        XCTAssertTrue(managed.isEmpty, "Failed batch must delete partially copied files")
    }

    func testEmptyBatchDoesNotChangeExistingShelf() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let original = try service.addText("unchanged")
        let result = try service.addClipboardPaths([], mode: .copy)
        XCTAssertEqual(result.items.map(\.id), original.items.map(\.id))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-batch-file-test-\(UUID().uuidString)", isDirectory: true)
    }
}

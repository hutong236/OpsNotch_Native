#if os(macOS)
import AppKit
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class ClipboardCaptureReconciliationTests: XCTestCase {
    @MainActor
    func testLateTextCaptureDoesNotUndoPinOrSettingsChange() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let model = AppModel(store: service)
        model.addText("keep me")
        let item = try XCTUnwrap(model.items.first)
        let originalRevision = model.publishedStoreRevision

        // Simulate a captured snapshot committed to disk before the MainActor
        // continuation had a chance to publish it to the view.
        let staleCapture = try service.captureText("background text", sourceAppName: "Notes")
        model.togglePin(item)
        model.updateSettings { $0.addMode = .copy }

        try await model.reconcileClipboardCapture(staleCapture, startedAt: originalRevision)

        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.items.first(where: { $0.id == item.id })?.pinned, true)
        XCTAssertEqual(model.items.first(where: { $0.content == "background text" })?.sourceAppName, "Notes")
        XCTAssertEqual(model.settings.addMode, .copy)
        XCTAssertEqual(model.items.map(\.id), try service.load().items.map(\.id))
    }

    @MainActor
    func testLateImageCaptureDoesNotResurrectDeletedItem() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let model = AppModel(store: service)
        model.addText("delete me")
        let deletedID = try XCTUnwrap(model.items.first?.id)
        let capturedAt = model.publishedStoreRevision
        let staleCapture = try service.captureImageData(Data([1, 2, 3, 4]))

        model.remove(Set([deletedID]))
        try await model.reconcileClipboardCapture(staleCapture, startedAt: capturedAt)

        XCTAssertFalse(model.items.contains { $0.id == deletedID })
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.clipboardImage, true)
        XCTAssertEqual(model.items.map(\.id), try service.load().items.map(\.id))
    }

    @MainActor
    func testLateFileCaptureDoesNotUndoWorkingSetOrLatestUse() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let model = AppModel(store: service)
        model.addText("important")
        let important = try XCTUnwrap(model.items.first)
        let capturedAt = model.publishedStoreRevision

        let externalFile = root.appendingPathComponent("sample.txt")
        try Data("payload".utf8).write(to: externalFile)
        let staleCapture = try service.addClipboardPaths(
            [externalFile], mode: .reference, sourceAppName: "Finder"
        )

        model.toggleWorkingSet(important)
        model.recordUse(important.id)
        let expectedCount = try XCTUnwrap(model.items.first(where: { $0.id == important.id })?.useCount)

        try await model.reconcileClipboardCapture(staleCapture, startedAt: capturedAt)

        XCTAssertTrue(model.settings.workingSetItemIDs.contains(important.id))
        XCTAssertEqual(model.items.first(where: { $0.id == important.id })?.useCount, expectedCount)
        XCTAssertTrue(model.items.contains { $0.content == externalFile.path })
        XCTAssertEqual(model.settings.workingSetItemIDs, try service.load().settings.workingSetItemIDs)
    }

    @MainActor
    func testUncontendedCapturePublishesSnapshotNormally() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let model = AppModel(store: service)
        let capturedAt = model.publishedStoreRevision
        let committed = try service.captureText("fresh")

        try await model.reconcileClipboardCapture(committed, startedAt: capturedAt)

        XCTAssertEqual(model.items.map(\.content), ["fresh"])
        XCTAssertGreaterThan(model.publishedStoreRevision, capturedAt)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-async-capture-test-\(UUID().uuidString)", isDirectory: true)
    }
}
#endif

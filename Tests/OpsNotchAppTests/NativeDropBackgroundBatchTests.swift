#if os(macOS)
import Foundation
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class NativeDropBackgroundBatchTests: XCTestCase {
    @MainActor
    func testNativeMultiFileDropPublishesBatchInOriginalOrder() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inputs = root.appendingPathComponent("inputs", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let first = inputs.appendingPathComponent("first.txt")
        let second = inputs.appendingPathComponent("second.txt")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let model = AppModel(store: service)
        await model.addPathsAsync([first, second], sourceAppName: "Finder")

        XCTAssertEqual(model.items.map(\.content), [first.path, second.path])
        XCTAssertEqual(model.items.map(\.sourceAppName), ["Finder", "Finder"])
        XCTAssertEqual(try service.load().items.map(\.id), model.items.map(\.id))
    }

    @MainActor
    func testNativeCopyModeKeepsDraggedApplicationAsCopiedFolder() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let inputs = root.appendingPathComponent("inputs", isDirectory: true)
        let bundle = inputs.appendingPathComponent("Demo.app", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data("bundle".utf8).write(to: bundle.appendingPathComponent("metadata.txt"))
        let source = inputs.appendingPathComponent("notes.txt")
        try Data("notes".utf8).write(to: source)

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let model = AppModel(store: service)
        model.updateSettings { $0.addMode = .copy }
        await model.addPathsAsync([source, bundle])

        XCTAssertEqual(model.items.map(\.kind), [.file, .folder])
        XCTAssertEqual(model.items.map(\.storageMode), [.copy, .copy])
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: model.items[0].content)),
            Data("notes".utf8)
        )
        XCTAssertEqual(
            try Data(contentsOf: URL(fileURLWithPath: model.items[1].content)
                .appendingPathComponent("metadata.txt")),
            Data("bundle".utf8)
        )
        XCTAssertEqual(try service.load().items.map(\.content), model.items.map(\.content))
    }

    @MainActor
    func testFailedBatchDoesNotPublishPartialShelfOrLeaveManagedCopies() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("available.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("available".utf8).write(to: source)
        let missing = root.appendingPathComponent("missing.txt")

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let model = AppModel(store: service)
        model.addText("existing")
        let original = try XCTUnwrap(model.items.first?.id)
        model.updateSettings { $0.addMode = .copy }

        await model.addPathsAsync([source, missing])

        XCTAssertEqual(model.items.map(\.id), [original])
        XCTAssertEqual(try service.load().items.map(\.id), [original])
        let directories = try FileManager.default.contentsOfDirectory(
            at: service.managedFilesURL, includingPropertiesForKeys: nil
        )
        XCTAssertTrue(directories.isEmpty)
    }

    @MainActor
    func testNativeDropCompletionKeepsNewerPinAndWorkingSetState() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("incoming.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("incoming".utf8).write(to: input)

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let model = AppModel(store: service)
        model.addText("keep")
        let original = try XCTUnwrap(model.items.first)
        let dropTask = Task { await model.addPathsAsync([input]) }
        model.togglePin(original)
        model.toggleWorkingSet(original)
        await dropTask.value

        XCTAssertEqual(model.items.first(where: { $0.id == original.id })?.pinned, true)
        XCTAssertTrue(model.settings.workingSetItemIDs.contains(original.id))
        XCTAssertTrue(model.items.contains { $0.content == input.path })
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-native-drop-batch-\(UUID().uuidString)", isDirectory: true)
    }
}
#endif

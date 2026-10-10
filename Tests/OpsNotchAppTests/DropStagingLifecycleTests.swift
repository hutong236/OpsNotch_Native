#if os(macOS)
import AppKit
import XCTest
@testable import OpsNotchApp

final class DropStagingLifecycleTests: XCTestCase {
    @MainActor
    func testImageDropKeepsStagingUntilConsumerAcknowledges() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let board = isolatedPasteboard()
        let imageData = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x01])
        XCTAssertTrue(board.setData(imageData, forType: .init("public.png")))
        let resolver = DropPayloadResolver(stagingRoot: root)
        var finish: ((Bool) -> Void)?
        var fileURL: URL?
        let received = expectation(description: "staged image available")

        let accepted = resolver.performDrop(
            from: board,
            onPromiseStarted: {},
            handleImmediate: { _ in XCTFail("Expected image staging"); return false },
            handlePromised: { urls, acknowledge in
                XCTAssertEqual(urls.count, 1)
                fileURL = urls.first
                finish = acknowledge
                XCTAssertEqual(
                    try? Data(contentsOf: urls[0]), imageData,
                    "Temporary file must remain readable until managed copy succeeds"
                )
                received.fulfill()
            }
        )
        XCTAssertTrue(accepted, "Drag event should return without blocking on disk I/O")
        await fulfillment(of: [received], timeout: 10)

        let source = try XCTUnwrap(fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        // The consumer has received the staging file but has not finished the
        // managed copy yet. A normal callback return must not remove it.
        await Task.yield()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        try XCTUnwrap(finish)(true)
        let cleaned = await waitUntilMissing(source, timeout: 5)
        XCTAssertTrue(cleaned)
    }

    @MainActor
    func testFailedImageMaterializationCompletesWithNoSourceURLs() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("occupied".utf8).write(to: root) // A file where a directory is needed.
        let board = isolatedPasteboard()
        XCTAssertTrue(board.setData(Data([1, 2, 3]), forType: .init("public.png")))
        let resolver = DropPayloadResolver(stagingRoot: root)
        let finished = expectation(description: "failure delivers an acknowledgement")
        XCTAssertTrue(resolver.performDrop(
            from: board,
            onPromiseStarted: {},
            handleImmediate: { _ in XCTFail("Image should be staged"); return false },
            handlePromised: { urls, acknowledge in
                XCTAssertTrue(urls.isEmpty, "No invalid staged path can be reported as successful")
                acknowledge(false)
                finished.fulfill()
            }
        ))
        await fulfillment(of: [finished], timeout: 10)
        XCTAssertEqual(try Data(contentsOf: root), Data("occupied".utf8))
    }

    func testPromiseAccumulatorCompletesOnlyAtExpectedCallbacks() {
        let accumulator = PromiseAccumulator()
        let a = URL(fileURLWithPath: "/tmp/promised-a")
        let b = URL(fileURLWithPath: "/tmp/promised-b")
        XCTAssertNil(accumulator.record(fileURL: a, error: nil))
        XCTAssertNil(accumulator.setExpectedCallbacks(2))
        let snapshot = accumulator.record(fileURL: b, error: nil)
        XCTAssertEqual(snapshot?.urls, [a, b])
        XCTAssertEqual(snapshot?.failures, 0)
        XCTAssertNil(accumulator.record(fileURL: a, error: nil),
            "A finished session must never signal duplicate completions")
    }

    func testPromiseAccumulatorRecordsPartialFailure() {
        let accumulator = PromiseAccumulator()
        XCTAssertNil(accumulator.setExpectedCallbacks(2))
        XCTAssertNil(accumulator.record(fileURL: URL(fileURLWithPath: "/tmp/failed"),
                                         error: CocoaError(.fileReadNoSuchFile)))
        let valid = URL(fileURLWithPath: "/tmp/success")
        let snapshot = accumulator.record(fileURL: valid, error: nil)
        XCTAssertEqual(snapshot?.urls, [valid])
        XCTAssertEqual(snapshot?.failures, 1)
    }

    @MainActor
    private func waitUntilMissing(_ url: URL, timeout: TimeInterval) async -> Bool {
        for _ in 0..<100 {
            if !FileManager.default.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-drop-staging-test-\(UUID().uuidString)",
                                    isDirectory: true)
    }

    private func isolatedPasteboard() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name(
            "lab.hutong.opsnotch.drop.staging.test.\(UUID().uuidString)"
        ))
        board.clearContents()
        return board
    }
}
#endif

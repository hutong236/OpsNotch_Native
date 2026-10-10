#if os(macOS)
import Foundation
import XCTest
@testable import OpsNotchApp

final class StaleDropStagingCleanupTests: XCTestCase {
    @MainActor
    func testStartupQuarantinesOldStagingWithoutDeletingNewSession() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent("drop-staging", isDirectory: true)
        let abandoned = staging.appendingPathComponent("old-drop", isDirectory: true)
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: 1024 * 1024)
            .write(to: abandoned.appendingPathComponent("image.png"))

        let resolver = DropPayloadResolver(stagingRoot: staging)
        resolver.cleanupStaleStaging(rootURL: root)

        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path),
            "The slow recursive delete should not run on the main thread")
        let fresh = staging.appendingPathComponent("new-drop", isDirectory: true)
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
        let newFile = fresh.appendingPathComponent("current.txt")
        try Data("keep".utf8).write(to: newFile)

        let cleaned = await waitForQuarantinesToDisappear(rootURL: root)
        XCTAssertTrue(cleaned)
        XCTAssertEqual(try Data(contentsOf: newFile), Data("keep".utf8),
            "Cleanup of an abandoned session must never affect new drag sessions")
    }

    @MainActor
    func testNextLaunchRecoversInterruptedQuarantineDeletion() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let orphan = root.appendingPathComponent(
            "drop-staging-trash-from-crashed-run", isDirectory: true
        )
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: orphan.appendingPathComponent("data"))

        let resolver = DropPayloadResolver(stagingRoot: root.appendingPathComponent("drop-staging"))
        resolver.cleanupStaleStaging(rootURL: root)
        // A repeated startup check must not launch overlapping deletes.
        resolver.cleanupStaleStaging(rootURL: root)

        let cleaned = await waitForQuarantinesToDisappear(rootURL: root)
        XCTAssertTrue(cleaned)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    @MainActor
    private func waitForQuarantinesToDisappear(rootURL: URL) async -> Bool {
        for _ in 0..<100 {
            let current = (try? FileManager.default.contentsOfDirectory(
                at: rootURL, includingPropertiesForKeys: nil
            )) ?? []
            if !current.contains(where: { $0.lastPathComponent.hasPrefix("drop-staging-trash-") }) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-startup-staging-\(UUID().uuidString)",
                                    isDirectory: true)
    }
}
#endif

#if os(macOS)
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class ShelfFinderShortcutVisibilityTests: XCTestCase {
    func testGenericShelfShowsDefaultAndSavedFinderQuickPaths() async {
        await MainActor.run {
            let quickID = UUID()
            let settings = ShelfSettings(
                finderDefaultPath: "~/Downloads",
                finderQuickPaths: [
                    FinderQuickPath(id: quickID, label: "Work", path: "~/Documents")
                ]
            )
            let experience = ShelfExperienceModel()
            let snapshot = ShelfSnapshotProvider().snapshot(
                items: [],
                settings: settings,
                experience: experience
            )

            XCTAssertEqual(
                snapshot.finderEntries.map(\.id),
                [QuickShelfEntry.finderDefaultID, QuickShelfEntry.finderID(quickID)]
            )
            XCTAssertEqual(snapshot.sections.first?.kind, .context)
            XCTAssertEqual(snapshot.visibleEntries.map(\.id), snapshot.finderEntries.map(\.id))
        }
    }

    func testDefaultFinderEntryIsPreviewableWhenHighlighted() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-finder-preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        await MainActor.run {
            let storeRoot = root.appendingPathComponent("store", isDirectory: true)
            let model = AppModel(store: ShelfStoreService(rootURL: storeRoot))
            model.updateSettings { $0.finderDefaultPath = root.path }
            model.resetQuickHighlight()

            XCTAssertEqual(model.highlightedQuickEntryID, QuickShelfEntry.finderDefaultID)
            XCTAssertTrue(model.canPreviewHighlighted)
        }
    }
}
#endif

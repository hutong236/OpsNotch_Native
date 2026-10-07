#if os(macOS)
import AppKit
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class SmartShelfSelectionTests: XCTestCase {
    func testResultsRangeAndRetrievalFollowRenderedCrossPartitionOrder() async {
        await MainActor.run {
            verifySelection(query: "prod", favoriteRecent: false)
        }
    }

    func testFavoritesRangeAndRetrievalIncludeWorkingPinsInRenderedOrder() async {
        await MainActor.run {
            verifySelection(query: "@fav prod", favoriteRecent: true)
        }
    }

    @MainActor
    private func verifySelection(query: String, favoriteRecent: Bool) {
        // In-memory only: no AppModel, services, windows, pasteboard or user store.
        let working = ShelfItem(kind: .text, title: "prod", content: "runbook", pinned: true,
            createdAt: 100, updatedAt: 100)
        let pinned = ShelfItem(kind: .text, title: "Pinned", content: "reference prod", pinned: true,
            createdAt: 200, updatedAt: 200)
        let recent = ShelfItem(kind: .text, title: "Recent", content: "reference prod",
            pinned: favoriteRecent, createdAt: 300, updatedAt: 300)
        let experience = ShelfExperienceModel()
        experience.query = query
        let provider = ShelfSnapshotProvider()
        let settings = ShelfSettings(workingSetItemIDs: [working.id])
        let snapshot = provider.snapshot(items: [working, pinned, recent], settings: settings,
            experience: experience)
        experience.snapshot = { snapshot }

        let renderedIDs = snapshot.visibleEntries.compactMap(\.shelfItem).map(\.id)
        XCTAssertEqual(renderedIDs, [recent.id, working.id, pinned.id])
        experience.toggleSelection(recent, flags: .command)
        experience.toggleSelection(working, flags: .shift)
        XCTAssertEqual(experience.selection, Set([recent.id, working.id]))
        XCTAssertEqual(experience.selectedItems(including: recent).map(\.id),
            [recent.id, working.id])

        // Drag retrieval follows screen order even when selection was made in reverse.
        experience.selection = Set([working.id, pinned.id, recent.id])
        XCTAssertEqual(experience.selectedItems(including: pinned).map(\.id), renderedIDs)
    }
}
#endif

#if os(macOS)
import Foundation
import OpsNotchCore

extension AppModel {
    /// Promised URLs are owned by a temporary drag staging session. They must be
    /// copied to shelf-managed storage before the resolver removes that session.
    /// Unlike ordinary native paths, this mode is always .copy.
    func addPromisedPathsAsync(_ urls: [URL]) async -> Bool {
        guard !urls.isEmpty else { return false }
        let store = self.store
        let startedAt = publishedStoreRevision
        do {
            let snapshot = try await Task.detached(priority: .userInitiated) {
                try store.addClipboardPaths(
                    urls, mode: .copy, applicationsAsReferences: false
                )
            }.value
            try await reconcileClipboardCapture(snapshot, startedAt: startedAt)
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }
}
#endif

#if os(macOS)
import Foundation
import OpsNotchCore

@MainActor
extension AppModel {
    /// Apply an asynchronous storage mutation without rolling back newer UI
    /// operations. Store locking makes disk commits serial, but does not ensure
    /// that their asynchronous MainActor continuations resume in commit order.
    ///
    /// If another action published during the await, re-read the latest
    /// committed store off MainActor. Repeat if another UI action publishes
    /// while that read is in flight; the final check and apply are synchronous
    /// on MainActor, so the candidate cannot become stale between them.
    func reconcileClipboardCapture(_ snapshot: ShelfStore, startedAt revision: UInt64) async throws {
        let store = self.store
        var candidate = snapshot
        var observedRevision = revision
        while observedRevision != publishedStoreRevision {
            observedRevision = publishedStoreRevision
            candidate = try await Task.detached(priority: .utility) {
                try store.load()
            }.value
        }
        apply(candidate)
    }

    /// Automatic clipboard capture persists off the main actor. The store is internally
    /// serialized with its lock, so UI event handling stays responsive while JSON/file I/O runs.
    func captureClipboardTextAsync(_ text: String, sourceAppName: String? = nil) async {
        let store = self.store
        let startingRevision = publishedStoreRevision
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.captureText(text, sourceAppName: sourceAppName)
            }.value
            try await reconcileClipboardCapture(value, startedAt: startingRevision)
            showToast(L10n.text("clipboardCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// Sensor drop remains a direct user action; its existing synchronous semantics are preserved.
    func captureDroppedText(_ text: String) {
        do { apply(try store.captureText(text)) }
        catch { showToast(error.localizedDescription) }
    }

    func captureDroppedURL(_ text: String) {
        do { apply(try store.captureURL(text)) }
        catch { showToast(error.localizedDescription) }
    }

    /// Clipboard file copies can include large files/directories. Move copy/reference resolution
    /// and shelf.json updates off the main actor, then apply only the final snapshot on MainActor.
    func captureClipboardFilesAsync(_ urls: [URL], sourceAppName: String? = nil) async {
        guard !urls.isEmpty else { return }

        let store = self.store
        let mode = settings.addMode
        let startingRevision = publishedStoreRevision
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.addClipboardPaths(
                    urls, mode: mode, sourceAppName: sourceAppName
                )
            }.value
            try await reconcileClipboardCapture(value, startedAt: startingRevision)
            showToast(L10n.text("clipboardCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// PNG data has already been normalized off the main actor by ClipboardManager.
    /// Managed-file write + shelf.json mutation also stay off MainActor.
    func captureClipboardImageDataAsync(_ data: Data, sourceAppName: String? = nil) async {
        let store = self.store
        let startingRevision = publishedStoreRevision
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.captureImageData(data, sourceAppName: sourceAppName)
            }.value
            try await reconcileClipboardCapture(value, startedAt: startingRevision)
            showToast(L10n.text("clipboardImageCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
#endif

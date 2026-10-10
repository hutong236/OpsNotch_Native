#if os(macOS)
import Foundation
import OpsNotchCore

@MainActor
extension AppModel {
    /// Automatic clipboard capture persists off the main actor. The store is internally
    /// serialized with its lock, so UI event handling stays responsive while JSON/file I/O runs.
    func captureClipboardTextAsync(_ text: String, sourceAppName: String? = nil) async {
        let store = self.store
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.captureText(text, sourceAppName: sourceAppName)
            }.value
            apply(value)
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
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.addClipboardPaths(
                    urls, mode: mode, sourceAppName: sourceAppName
                )
            }.value
            apply(value)
            showToast(L10n.text("clipboardCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// PNG data has already been normalized off the main actor by ClipboardManager.
    /// Managed-file write + shelf.json mutation also stay off MainActor.
    func captureClipboardImageDataAsync(_ data: Data, sourceAppName: String? = nil) async {
        let store = self.store
        do {
            let value = try await Task.detached(priority: .utility) {
                try store.captureImageData(data, sourceAppName: sourceAppName)
            }.value
            apply(value)
            showToast(L10n.text("clipboardImageCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
#endif

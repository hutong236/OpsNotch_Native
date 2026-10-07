#if os(macOS)
import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsPage(
            title: L10n.text("settingsShortcuts", model.language),
            subtitle: L10n.text("hotkeyHint", model.language)
        ) {
            SettingsCard {
                SettingsRow(L10n.text("hotkeyRow", model.language)) {
                    HotkeyRecorderView(model: model)
                }
            }
        }
    }
}
#endif

#if os(macOS)
import SwiftUI
import OpsNotchCore

struct AdvancedSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsPage(title: L10n.text("settingsAdvanced", model.language)) {
            SettingsCard {
                SettingsRow(L10n.text("settingsVersion", model.language)) {
                    Text("Ops Notch v\(AppVersionService.current)")
                        .foregroundStyle(.secondary)
                }

                Divider()

                SettingsRow(
                    L10n.text("settingsDataPath", model.language),
                    detail: ShelfStoreService.defaultRootURL().path
                ) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
#endif

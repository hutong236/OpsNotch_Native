#if os(macOS)
import SwiftUI

struct FinderSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: FinderRevealController

    var body: some View {
        SettingsPage(
            title: L10n.text("settingsFinder", model.language),
            subtitle: L10n.text("settingsFinderHint", model.language)
        ) {
            SettingsCard {
                FinderRevealSettingsView(model: model, controller: controller)
            }
        }
    }
}
#endif

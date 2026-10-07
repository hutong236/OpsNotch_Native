#if os(macOS)
import SwiftUI
import OpsNotchCore

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var loginItem: LoginItemService

    var body: some View {
        SettingsPage(title: L10n.text("settingsGeneral", model.language)) {
            SettingsCard {
                SettingsRow(L10n.text("language", model.language)) {
                    Picker("", selection: languageBinding) {
                        Text("简体中文").tag(AppLanguage.zhCN)
                        Text("English").tag(AppLanguage.enUS)
                    }
                    .labelsHidden()
                    .frame(width: OpsControlMetrics.settingsCompactPickerWidth)
                }

                Divider()

                SettingsRow(L10n.text("launchAtLogin", model.language)) {
                    Toggle("", isOn: Binding(get: { loginItem.enabled }, set: loginItem.setEnabled))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if let error = loginItem.lastError {
                    Text(error)
                        .font(OpsTypography.metadata)
                        .foregroundStyle(.red)
                }

                Divider()

                SettingsRow(L10n.text("displayTarget", model.language)) {
                    Picker("", selection: displayBinding) {
                        Text(L10n.text("allDisplays", model.language)).tag(DisplayTarget.all)
                        Text(L10n.text("mouseDisplay", model.language)).tag(DisplayTarget.mouse)
                        Text(L10n.text("primaryDisplay", model.language)).tag(DisplayTarget.primary)
                        Text(L10n.text("currentDisplay", model.language)).tag(DisplayTarget.current)
                    }
                    .labelsHidden()
                    .frame(width: OpsControlMetrics.settingsPickerWidth)
                }
            }
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.settings.language },
            set: { value in model.updateSettings { $0.language = value } }
        )
    }

    private var displayBinding: Binding<DisplayTarget> {
        Binding(
            get: { model.settings.displayTarget },
            set: { value in model.updateSettings { $0.displayTarget = value } }
        )
    }
}
#endif

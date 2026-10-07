#if os(macOS)
import SwiftUI
import OpsNotchCore

struct ShelfSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsPage(
            title: L10n.text("settingsShelf", model.language),
            subtitle: L10n.text("settingsShelfHint", model.language)
        ) {
            SettingsCard {
                SettingsRow(
                    L10n.text("dragAssist", model.language),
                    detail: L10n.text("dragAssistHint", model.language)
                ) {
                    Picker("", selection: dragAssistBinding) {
                        Text(L10n.text("dragAssistNearby", model.language)).tag(DragAssistMode.nearby)
                        Text(L10n.text("dragAssistSensorOnly", model.language)).tag(DragAssistMode.sensorOnly)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: OpsControlMetrics.settingsPickerWidth)
                }

                Divider()

                SettingsRow(
                    L10n.text("keepShelfOpen", model.language),
                    detail: L10n.text("keepShelfOpenHint", model.language)
                ) {
                    Toggle("", isOn: keepOpenBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()

                SettingsRow(
                    L10n.text("fileDropMode", model.language),
                    detail: L10n.text("fileDropModeHint", model.language)
                ) {
                    Picker("", selection: addModeBinding) {
                        Text(L10n.text("reference", model.language)).tag(StorageMode.reference)
                        Text(L10n.text("copyIn", model.language)).tag(StorageMode.copy)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: OpsControlMetrics.settingsPickerWidth)
                }
            }
        }
    }

    private var dragAssistBinding: Binding<DragAssistMode> {
        Binding(
            get: { model.settings.dragAssistMode },
            set: { value in model.updateSettings { $0.dragAssistMode = value } }
        )
    }

    private var keepOpenBinding: Binding<Bool> {
        Binding(
            get: { model.settings.shelfKeepOpen },
            set: { value in
                model.updateSettings { $0.shelfKeepOpen = value }
                if !value { model.requestDelayedHide?() }
            }
        )
    }

    private var addModeBinding: Binding<StorageMode> {
        Binding(
            get: { model.settings.addMode },
            set: { value in model.updateSettings { $0.addMode = value } }
        )
    }
}
#endif

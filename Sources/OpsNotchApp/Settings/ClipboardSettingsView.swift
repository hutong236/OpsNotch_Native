#if os(macOS)
import SwiftUI
import OpsNotchCore

struct ClipboardSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsPage(
            title: L10n.text("settingsClipboard", model.language),
            subtitle: L10n.text("clipboardAutomaticHint", model.language)
        ) {
            SettingsCard {
                SettingsRow(
                    L10n.text("clipboardAutomatic", model.language),
                    detail: L10n.text("clipboardAutomaticDetail", model.language)
                ) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(L10n.text("enabled", model.language))
                }

                Divider()

                SettingsRow(
                    L10n.text("recentCleanup", model.language),
                    detail: L10n.text("recentCleanupHint", model.language)
                ) {
                    Picker("", selection: ttlBinding) {
                        Text(L10n.text("oneHour", model.language)).tag(UInt64(1))
                        Text(L10n.text("oneDay", model.language)).tag(UInt64(24))
                        Text(L10n.text("threeDays", model.language)).tag(UInt64(72))
                        Text(L10n.text("sevenDays", model.language)).tag(UInt64(168))
                        Text(L10n.text("never", model.language)).tag(UInt64(0))
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
            }
        }
    }

    private var ttlBinding: Binding<UInt64> {
        Binding(
            get: { model.settings.tempTTLHours },
            set: { value in model.updateSettings { $0.tempTTLHours = value } }
        )
    }
}
#endif

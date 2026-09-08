#if os(macOS)
import SwiftUI
import OpsNotchCore

struct MenuBarSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var manager: MenuBarManager

    var body: some View {
        VStack(spacing: 11) {
            settingRow(L10n.text("menuBarEnable", model.language)) {
                Toggle("", isOn: boolBinding(\.menuBarManagementEnabled))
                    .toggleStyle(.switch).labelsHidden()
            }

            Divider()
            settingRow(L10n.text("menuBarStartCollapsed", model.language)) {
                Toggle("", isOn: boolBinding(\.menuBarStartCollapsed))
                    .toggleStyle(.switch).labelsHidden()
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Divider()
            settingRow(L10n.text("menuBarAutoHide", model.language)) {
                Picker("", selection: autoHideBinding) {
                    Text(L10n.text("never", model.language)).tag(UInt64(0))
                    Text("5 \(L10n.text("seconds", model.language))").tag(UInt64(5))
                    Text("10 \(L10n.text("seconds", model.language))").tag(UInt64(10))
                    Text("30 \(L10n.text("seconds", model.language))").tag(UInt64(30))
                    Text("60 \(L10n.text("seconds", model.language))").tag(UInt64(60))
                }
                .frame(width: 150)
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Divider()
            settingRow(L10n.text("menuBarAlwaysHidden", model.language)) {
                Toggle("", isOn: boolBinding(\.menuBarAlwaysHiddenEnabled))
                    .toggleStyle(.switch).labelsHidden()
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Divider()
            settingRow(L10n.text("menuBarAnimation", model.language)) {
                Toggle("", isOn: boolBinding(\.menuBarAnimationEnabled))
                    .toggleStyle(.switch).labelsHidden()
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Divider()
            settingRow(L10n.text("menuBarHiddenPanel", model.language)) {
                Toggle("", isOn: boolBinding(\.menuBarPanelEnabled))
                    .toggleStyle(.switch).labelsHidden()
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Text(L10n.text("menuBarPanelPermissionHint", model.language))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.text("menuBarNotchOverflowHint", model.language))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            settingRow(L10n.text("menuBarHotkey", model.language)) {
                HotkeyRecorderControl(
                    language: model.language,
                    shortcut: model.settings.menuBarHotkey,
                    conflict: manager.hotkeyConflict,
                    onPrepare: { manager.clearHotkeyConflict() },
                    onSet: { manager.setHotkey($0) }
                )
            }
            .disabled(!model.settings.menuBarManagementEnabled)

            Divider()
            HStack(spacing: 8) {
                Button(L10n.text("menuBarCollapse", model.language)) { manager.collapse() }
                Button(L10n.text("menuBarShowHidden", model.language)) { manager.showHiddenArea() }
                if model.settings.menuBarAlwaysHiddenEnabled {
                    Button(L10n.text("menuBarShowAll", model.language)) { manager.showAll() }
                }
                if model.settings.menuBarPanelEnabled {
                    Button(L10n.text("menuBarHiddenPanel", model.language)) { manager.showHiddenItemsPanel() }
                }
                Spacer()
            }
            .controlSize(.small)
            .disabled(!model.settings.menuBarManagementEnabled)

            Text(L10n.text("menuBarArrangeHint", model.language))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.text("menuBarGestureHint", model.language))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); trailing() }
    }

    private func boolBinding(_ path: WritableKeyPath<ShelfSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: path] },
            set: { value in model.updateSettings { $0[keyPath: path] = value } }
        )
    }

    private var autoHideBinding: Binding<UInt64> {
        Binding(
            get: { model.settings.menuBarAutoHideSeconds },
            set: { value in model.updateSettings { $0.menuBarAutoHideSeconds = value } }
        )
    }
}
#endif

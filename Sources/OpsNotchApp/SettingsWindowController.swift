#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private let finderReveal: FinderRevealController
    private let inputMethodManager: InputMethodManager
    private let loginItem = LoginItemService()
    private var window: NSWindow?

    init(model: AppModel, finderReveal: FinderRevealController, inputMethodManager: InputMethodManager) {
        self.model = model
        self.finderReveal = finderReveal
        self.inputMethodManager = inputMethodManager
    }

    func show() {
        if let window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(
            model: model,
            loginItem: loginItem,
            finderReveal: finderReveal,
            inputMethodManager: inputMethodManager
        )
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("settingsTitle", model.language)
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var loginItem: LoginItemService
    @ObservedObject var finderReveal: FinderRevealController
    @ObservedObject var inputMethodManager: InputMethodManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                title
                group(L10n.text("general", model.language)) {
                    settingRow(L10n.text("language", model.language)) {
                        Picker("", selection: languageBinding) {
                            Text("简体中文").tag(AppLanguage.zhCN)
                            Text("English").tag(AppLanguage.enUS)
                        }.frame(width: 150)
                    }
                    Divider()
                    settingRow(L10n.text("launchAtLogin", model.language)) {
                        Toggle("", isOn: Binding(get: { loginItem.enabled }, set: loginItem.setEnabled))
                            .toggleStyle(.switch).labelsHidden()
                    }
                    if let error = loginItem.lastError { Text(error).font(.caption).foregroundStyle(.red) }
                    Divider()
                    settingRow(L10n.text("displayTarget", model.language)) {
                        Picker("", selection: displayBinding) {
                            Text(L10n.text("allDisplays", model.language)).tag(DisplayTarget.all)
                            Text(L10n.text("mouseDisplay", model.language)).tag(DisplayTarget.mouse)
                            Text(L10n.text("primaryDisplay", model.language)).tag(DisplayTarget.primary)
                            Text(L10n.text("currentDisplay", model.language)).tag(DisplayTarget.current)
                        }.frame(width: 190)
                    }
                    Divider()
                    settingRow(L10n.text("hotkeyRow", model.language)) { HotkeyRecorderView(model: model) }
                    Text(L10n.text("hotkeyHint", model.language))
                        .font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 2)
                }

                group(model.language == .zhCN ? "输入法管理" : "Input Method Manager") {
                    InputMethodSettingsView(model: model, manager: inputMethodManager)
                }

                group(model.language == .zhCN ? "Finder 快捷路径" : "Finder Quick Paths") {
                    FinderRevealSettingsView(model: model, controller: finderReveal)
                }

                group(L10n.text("storage", model.language)) {
                    settingRow(L10n.text("fileDropMode", model.language)) {
                        Picker("", selection: addModeBinding) {
                            Text(L10n.text("reference", model.language)).tag(StorageMode.reference)
                            Text(L10n.text("copyIn", model.language)).tag(StorageMode.copy)
                        }.pickerStyle(.segmented).frame(width: 190)
                    }
                    Divider()
                    settingRow(L10n.text("recentCleanup", model.language)) {
                        Picker("", selection: ttlBinding) {
                            Text(L10n.text("oneHour", model.language)).tag(UInt64(1))
                            Text(L10n.text("oneDay", model.language)).tag(UInt64(24))
                            Text(L10n.text("threeDays", model.language)).tag(UInt64(72))
                            Text(L10n.text("sevenDays", model.language)).tag(UInt64(168))
                            Text(L10n.text("never", model.language)).tag(UInt64(0))
                        }.frame(width: 150)
                    }
                }

                Text(L10n.text("clipboardHint", model.language)).font(.system(size: 10)).foregroundStyle(.secondary)
                Divider()
                Text("Ops Notch v\(AppVersionService.current)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 620)
    }

    private var title: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full.fill").font(.system(size: 26)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ops Notch").font(.title2.bold())
                Text("Native macOS · AppKit + SwiftUI").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(spacing: 11) { content() }
                .padding(14)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); trailing() }
    }

    private var languageBinding: Binding<AppLanguage> { Binding(get: { model.settings.language }, set: { value in model.updateSettings { $0.language = value } }) }
    private var displayBinding: Binding<DisplayTarget> { Binding(get: { model.settings.displayTarget }, set: { value in model.updateSettings { $0.displayTarget = value } }) }
    private var addModeBinding: Binding<StorageMode> { Binding(get: { model.settings.addMode }, set: { value in model.updateSettings { $0.addMode = value } }) }
    private var ttlBinding: Binding<UInt64> { Binding(get: { model.settings.tempTTLHours }, set: { value in model.updateSettings { $0.tempTTLHours = value } }) }
}
#endif

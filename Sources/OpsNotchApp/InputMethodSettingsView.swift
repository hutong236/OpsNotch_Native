#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct InputMethodSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var manager: InputMethodManager

    private var isChinese: Bool { model.language == .zhCN }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "按 App 自动切换输入法" : "Switch input method per app")
                        .font(.system(size: 12, weight: .medium))
                    Text(isChinese ? "切换到不同应用时自动使用对应输入法。" : "Automatically select an input method when the active app changes.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $manager.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            if manager.rules.isEmpty {
                Text(isChinese ? "尚未添加应用规则。未配置的 App 会保持当前输入法。" : "No app rules yet. Unconfigured apps keep the current input method.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(manager.rules) { rule in
                        ruleRow(rule)
                        if rule.id != manager.rules.last?.id { Divider() }
                    }
                }
            }

            HStack {
                Button {
                    chooseApplication()
                } label: {
                    Label(isChinese ? "添加应用" : "Add App", systemImage: "plus")
                }
                Spacer()
                Button(isChinese ? "刷新输入法" : "Refresh Input Methods") {
                    manager.refreshInputSources()
                }
                .buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    private func ruleRow(_ rule: InputMethodRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rule.appName).font(.system(size: 12, weight: .medium))
                    Text(rule.bundleID).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    manager.removeRule(id: rule.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Picker("", selection: modeBinding(rule)) {
                    Text(isChinese ? "固定输入法" : "Fixed").tag(InputMethodRuleMode.fixed)
                    Text(isChinese ? "记忆输入法" : "Remember").tag(InputMethodRuleMode.remember)
                    Text(isChinese ? "保持当前" : "Keep Current").tag(InputMethodRuleMode.keep)
                }
                .labelsHidden()
                .frame(width: 130)

                if rule.mode == .fixed {
                    Picker("", selection: sourceBinding(rule)) {
                        Text(isChinese ? "选择输入法" : "Choose Input Method").tag(String?.none)
                        ForEach(manager.inputSources) { source in
                            Text(source.name).tag(Optional(source.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                } else if rule.mode == .remember {
                    Text(isChinese ? "切回此 App 时恢复本次会话中最后使用的输入法" : "Restores the last input method used by this app in the current session")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text(isChinese ? "不主动改变输入法" : "Does not change the input method")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func modeBinding(_ rule: InputMethodRule) -> Binding<InputMethodRuleMode> {
        Binding(
            get: { manager.rules.first(where: { $0.id == rule.id })?.mode ?? rule.mode },
            set: { manager.updateRule(id: rule.id, mode: $0) }
        )
    }

    private func sourceBinding(_ rule: InputMethodRule) -> Binding<String?> {
        Binding(
            get: { manager.rules.first(where: { $0.id == rule.id })?.inputSourceID },
            set: { manager.updateRule(id: rule.id, inputSourceID: $0, setInputSource: true) }
        )
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = isChinese ? "选择应用" : "Choose Application"
        panel.prompt = isChinese ? "添加" : "Add"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            manager.addApplication(url: url)
        }
    }
}
#endif

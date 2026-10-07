#if os(macOS)
import SwiftUI

struct WorkspaceSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsPage(
            title: L10n.text("settingsWorkspace", model.language),
            subtitle: L10n.text("settingsWorkspaceHint", model.language)
        ) {
            SettingsCard {
                SettingsRow(
                    L10n.text("workspaceDesktopCommands", model.language),
                    detail: L10n.text("workspaceDesktopCommandsHint", model.language)
                ) {
                    Text("d · d2")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Divider()

                SettingsRow(
                    L10n.text("workspaceWindowMove", model.language),
                    detail: L10n.text("workspaceWindowMoveHint", model.language)
                ) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
#endif

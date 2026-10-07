#if os(macOS)
import SwiftUI
import OpsNotchCore

enum OpsSettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case shelf
    case clipboard
    case finder
    case workspace
    case inputMethod
    case shortcuts
    case advanced

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .general: return "settingsGeneral"
        case .shelf: return "settingsShelf"
        case .clipboard: return "settingsClipboard"
        case .finder: return "settingsFinder"
        case .workspace: return "settingsWorkspace"
        case .inputMethod: return "settingsInputMethod"
        case .shortcuts: return "settingsShortcuts"
        case .advanced: return "settingsAdvanced"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .shelf: return "tray.full"
        case .clipboard: return "doc.on.clipboard"
        case .finder: return "folder"
        case .workspace: return "rectangle.3.group"
        case .inputMethod: return "keyboard"
        case .shortcuts: return "command"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var loginItem: LoginItemService
    @ObservedObject var finderReveal: FinderRevealController
    @ObservedObject var inputMethodManager: InputMethodManager

    @State private var selection: OpsSettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(OpsSettingsSection.allCases, selection: $selection) { section in
                Label(L10n.text(section.localizationKey, model.language), systemImage: section.symbolName)
                    .tag(Optional(section))
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsView(model: model, loginItem: loginItem)
        case .shelf:
            ShelfSettingsView(model: model)
        case .clipboard:
            ClipboardSettingsView(model: model)
        case .finder:
            FinderSettingsView(model: model, controller: finderReveal)
        case .workspace:
            WorkspaceSettingsPane(model: model)
        case .inputMethod:
            SettingsPage(title: L10n.text("settingsInputMethod", model.language)) {
                SettingsCard {
                    InputMethodSettingsView(model: model, manager: inputMethodManager)
                }
            }
        case .shortcuts:
            ShortcutSettingsView(model: model)
        case .advanced:
            AdvancedSettingsView(model: model)
        }
    }
}
#endif

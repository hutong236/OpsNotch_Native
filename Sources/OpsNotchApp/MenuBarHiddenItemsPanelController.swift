#if os(macOS)
import AppKit
import ApplicationServices
import Combine
import SwiftUI
import OpsNotchCore

enum MenuBarHiddenSection: String {
    case hidden
    case alwaysHidden
}

struct MenuBarHiddenItemPresentation: Identifiable {
    let id: String
    let title: String
    let owner: String
    let section: MenuBarHiddenSection
}

/// 可选隐藏项目面板。扫描与点击仅在用户启用此功能后使用辅助功能 API；
/// 基础的菜单栏隐藏/展开完全不需要该权限。
@MainActor
final class MenuBarHiddenItemsPanelController: ObservableObject {
    enum Phase {
        case loading
        case permissionRequired
        case unavailable(String)
        case ready
    }

    @Published var language: AppLanguage
    @Published private(set) var items: [MenuBarHiddenItemPresentation] = []
    @Published private(set) var phase: Phase = .loading

    var onRefresh: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onActivate: ((String) -> Void)?

    private let popover = NSPopover()

    init(language: AppLanguage) {
        self.language = language
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 340)
        popover.contentViewController = NSHostingController(rootView: MenuBarHiddenItemsPanelView(controller: self))
    }

    var isVisible: Bool { popover.isShown }

    func show(relativeTo button: NSStatusBarButton) {
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func close() {
        popover.performClose(nil)
    }

    func setLoading() {
        phase = .loading
    }

    func setPermissionRequired() {
        items = []
        phase = .permissionRequired
    }

    func setUnavailable(_ message: String) {
        items = []
        phase = .unavailable(message)
    }

    func setItems(_ items: [MenuBarHiddenItemPresentation]) {
        self.items = items
        phase = .ready
    }
}

private struct MenuBarHiddenItemsPanelView: View {
    @ObservedObject var controller: MenuBarHiddenItemsPanelController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("menuBarHiddenPanel", controller.language)).font(.headline)
                    Text(L10n.text("menuBarPanelHint", controller.language))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    controller.onRefresh?()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            Divider()

            switch controller.phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.text("menuBarPanelLoading", controller.language))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .permissionRequired:
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("menuBarPanelPermission", controller.language))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button(L10n.text("menuBarPanelGrantPermission", controller.language)) {
                        controller.onRequestPermission?()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .unavailable(let message):
                Text(message)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .ready:
                if controller.items.isEmpty {
                    Text(L10n.text("menuBarPanelEmpty", controller.language))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(controller.items) { item in
                                Button {
                                    controller.onActivate?(item.id)
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: item.section == .alwaysHidden ? "eye.slash.fill" : "eye.slash")
                                            .frame(width: 16)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                            Text(item.owner).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Text(L10n.text(
                                            item.section == .alwaysHidden ? "menuBarAlwaysHiddenSection" : "menuBarHiddenSection",
                                            controller.language
                                        ))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 360, height: 340)
    }
}

enum MenuBarAXScanner {
    struct Item {
        let id: String
        let element: AXUIElement
        let title: String
        let owner: String
        let section: MenuBarHiddenSection

        var presentation: MenuBarHiddenItemPresentation {
            .init(id: id, title: title, owner: owner, section: section)
        }
    }

    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func scan(hiddenSeparatorX: CGFloat, alwaysHiddenSeparatorX: CGFloat?, rtl: Bool) -> [Item] {
        var result: [Item] = []
        var seen = Set<String>()
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            guard pid > 0, pid != ownPID else { continue }
            let owner = app.localizedName ?? app.bundleIdentifier ?? "App"
            let appElement = AXUIElementCreateApplication(pid)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                appElement,
                kAXExtrasMenuBarAttribute as CFString,
                &value
            ) == .success, let raw = value else { continue }

            let menuBar = raw as! AXUIElement
            for element in menuItems(in: menuBar, maxDepth: 3) {
                guard let frame = frame(of: element), !frame.isEmpty else { continue }
                let centerX = frame.midX
                let section: MenuBarHiddenSection?
                if rtl {
                    if let alwaysHiddenSeparatorX, centerX > alwaysHiddenSeparatorX {
                        section = .alwaysHidden
                    } else if centerX > hiddenSeparatorX {
                        section = .hidden
                    } else {
                        section = nil
                    }
                } else {
                    if let alwaysHiddenSeparatorX, centerX < alwaysHiddenSeparatorX {
                        section = .alwaysHidden
                    } else if centerX < hiddenSeparatorX {
                        section = .hidden
                    } else {
                        section = nil
                    }
                }
                guard let section else { continue }

                let key = "\(pid):\(Int(frame.minX.rounded())):\(Int(frame.width.rounded()))"
                guard seen.insert(key).inserted else { continue }
                let title = bestTitle(for: element, fallback: owner)
                result.append(Item(id: key, element: element, title: title, owner: owner, section: section))
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.section != rhs.section { return lhs.section == .hidden }
            if lhs.owner != rhs.owner { return lhs.owner.localizedCaseInsensitiveCompare(rhs.owner) == .orderedAscending }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func activate(_ item: Item) -> Bool {
        var rawActions: CFArray?
        let actions: [String]
        if AXUIElementCopyActionNames(item.element, &rawActions) == .success,
           let rawActions {
            actions = rawActions as? [String] ?? []
        } else {
            actions = []
        }

        if actions.contains(kAXShowMenuAction as String),
           AXUIElementPerformAction(item.element, kAXShowMenuAction as CFString) == .success {
            return true
        }
        return AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success
    }

    private static func menuItems(in element: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        guard maxDepth >= 0 else { return [] }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return [] }

        var result: [AXUIElement] = []
        for child in children {
            let role = stringValue(kAXRoleAttribute, from: child)
            let subrole = stringValue(kAXSubroleAttribute, from: child)
            if role == kAXMenuBarItemRole as String || subrole == "AXMenuExtra" {
                result.append(child)
            } else if maxDepth > 0 {
                result.append(contentsOf: menuItems(in: child, maxDepth: maxDepth - 1))
            }
        }
        return result
    }

    private static func bestTitle(for element: AXUIElement, fallback: String) -> String {
        for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            if let value = stringValue(attribute, from: element)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return fallback
    }

    private static func stringValue(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        let position = positionValue as! AXValue
        let dimensions = sizeValue as! AXValue
        guard AXValueGetType(position) == .cgPoint,
              AXValueGetType(dimensions) == .cgSize,
              AXValueGetValue(position, .cgPoint, &point),
              AXValueGetValue(dimensions, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
}
#endif

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

enum MenuBarPanelInteraction {
    case primary
    case secondary
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
    @Published private(set) var isRefreshing = false

    var onRefresh: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onInteract: ((String, MenuBarPanelInteraction) -> Void)?

    private let popover = NSPopover()

    init(language: AppLanguage) {
        self.language = language
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 340)
        popover.contentViewController = NSHostingController(rootView: MenuBarHiddenItemsPanelView(controller: self))
    }

    var isVisible: Bool { popover.isShown }
    var isLoading: Bool { isRefreshing }

    func show(relativeTo button: NSStatusBarButton) {
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func close() {
        popover.performClose(nil)
    }

    func beginRefresh(preserveItems: Bool) {
        isRefreshing = true
        if !preserveItems || items.isEmpty {
            phase = .loading
        }
    }

    func finishRefresh() {
        isRefreshing = false
        if case .loading = phase {
            phase = .ready
        }
    }

    func setLoading() {
        beginRefresh(preserveItems: false)
    }

    func setPermissionRequired() {
        items = []
        isRefreshing = false
        phase = .permissionRequired
    }

    func setUnavailable(_ message: String) {
        items = []
        isRefreshing = false
        phase = .unavailable(message)
    }

    func setItems(_ items: [MenuBarHiddenItemPresentation], refreshing: Bool = false) {
        self.items = items
        isRefreshing = refreshing
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
                    if controller.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(controller.isRefreshing)
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
                                MenuBarHiddenItemRow(
                                    item: item,
                                    language: controller.language,
                                    onPrimary: {
                                        controller.onInteract?(item.id, .primary)
                                    },
                                    onSecondary: {
                                        controller.onInteract?(item.id, .secondary)
                                    }
                                )
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

private struct MenuBarHiddenItemRow: View {
    let item: MenuBarHiddenItemPresentation
    let language: AppLanguage
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
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
                language
            ))
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .overlay {
            MenuBarHiddenItemMouseBridge(onPrimary: onPrimary, onSecondary: onSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// SwiftUI 的 Button/点击手势无法可靠地区分菜单栏面板中的普通点击与右键。
/// 用最小 AppKit bridge 保留原生鼠标语义：左键执行主操作，右键直接请求原项目菜单。
private struct MenuBarHiddenItemMouseBridge: NSViewRepresentable {
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    func makeNSView(context: Context) -> MenuBarHiddenItemMouseView {
        let view = MenuBarHiddenItemMouseView()
        view.onPrimary = onPrimary
        view.onSecondary = onSecondary
        return view
    }

    func updateNSView(_ nsView: MenuBarHiddenItemMouseView, context: Context) {
        nsView.onPrimary = onPrimary
        nsView.onSecondary = onSecondary
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: MenuBarHiddenItemMouseView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
}

private final class MenuBarHiddenItemMouseView: NSView {
    var onPrimary: (() -> Void)?
    var onSecondary: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installClickRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installClickRecognizers()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func installClickRecognizers() {
        let primary = NSClickGestureRecognizer(target: self, action: #selector(handlePrimaryClick(_:)))
        primary.buttonMask = 1 << 0
        addGestureRecognizer(primary)

        let secondary = NSClickGestureRecognizer(target: self, action: #selector(handleSecondaryClick(_:)))
        secondary.buttonMask = 1 << 1
        addGestureRecognizer(secondary)
    }

    @objc private func handlePrimaryClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onPrimary?()
    }

    @objc private func handleSecondaryClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onSecondary?()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

enum MenuBarAXScanner {
    struct Item: @unchecked Sendable {
        let id: String
        let element: AXUIElement
        let title: String
        let owner: String
        let section: MenuBarHiddenSection
        let frame: CGRect

        var presentation: MenuBarHiddenItemPresentation {
            .init(id: id, title: title, owner: owner, section: section)
        }
    }

    private struct RunningApplication: Sendable {
        let pid: pid_t
        let owner: String
        let priority: Int
    }

    // Each application is scanned independently. A wedged third-party AX endpoint can therefore
    // consume one worker but can no longer block every later refresh behind a serial queue.
    private static let applicationScanQueue = DispatchQueue(
        label: "lab.hutong.opsnotch.menu-bar-ax-app-scan",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private static let applicationMessagingTimeout: Float = 0.18
    private static let scanBudget: TimeInterval = 1.8
    private static let perApplicationBudget: TimeInterval = 0.70

    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Synchronous scan retained for the notch-overflow probe. It is globally budgeted so this
    /// legacy path also cannot spend unbounded time walking menu extras.
    static func scan(hiddenSeparatorX: CGFloat, alwaysHiddenSeparatorX: CGFloat?, rtl: Bool) -> [Item] {
        let applications = runningApplicationsSnapshot()
        let deadline = Date().addingTimeInterval(scanBudget)
        var result: [Item] = []

        for app in applications {
            guard Date() < deadline else { break }
            let appDeadline = min(deadline, Date().addingTimeInterval(perApplicationBudget))
            result.append(contentsOf: scan(
                application: app,
                hiddenSeparatorX: hiddenSeparatorX,
                alwaysHiddenSeparatorX: alwaysHiddenSeparatorX,
                rtl: rtl,
                deadline: appDeadline
            ))
        }
        return sortedItems(result)
    }

    /// Progressive scan used by the hidden-items panel. Each app gets its own concurrent task and
    /// successful batches are delivered immediately on the main queue instead of waiting for the
    /// slowest process. The manager owns the overall UI timeout and generation invalidation.
    static func scanProgressively(
        hiddenSeparatorX: CGFloat,
        alwaysHiddenSeparatorX: CGFloat?,
        rtl: Bool,
        onBatch: @escaping ([Item]) -> Void,
        completion: @escaping () -> Void
    ) {
        let applications = runningApplicationsSnapshot()
        guard !applications.isEmpty else {
            DispatchQueue.main.async(execute: completion)
            return
        }

        let group = DispatchGroup()
        for app in applications {
            group.enter()
            applicationScanQueue.async {
                let deadline = Date().addingTimeInterval(perApplicationBudget)
                let items = scan(
                    application: app,
                    hiddenSeparatorX: hiddenSeparatorX,
                    alwaysHiddenSeparatorX: alwaysHiddenSeparatorX,
                    rtl: rtl,
                    deadline: deadline
                )
                if !items.isEmpty {
                    let batch = sortedItems(items)
                    DispatchQueue.main.async {
                        onBatch(batch)
                    }
                }
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    static func sortedItems(_ items: [Item]) -> [Item] {
        items.sorted { lhs, rhs in
            if lhs.section != rhs.section { return lhs.section == .hidden }
            if lhs.owner != rhs.owner {
                return lhs.owner.localizedCaseInsensitiveCompare(rhs.owner) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func runningApplicationsSnapshot() -> [RunningApplication] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications.compactMap { app -> RunningApplication? in
            let pid = app.processIdentifier
            guard pid > 0, pid != ownPID else { return nil }

            let priority: Int
            switch app.activationPolicy {
            case .accessory:
                priority = 0
            case .regular:
                priority = 1
            default:
                // Prohibited/background-only processes cannot own an interactive status item and
                // were a major source of unnecessary AX calls in the previous scanner.
                return nil
            }

            return RunningApplication(
                pid: pid,
                owner: app.localizedName ?? app.bundleIdentifier ?? "App",
                priority: priority
            )
        }

        return applications.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.owner.localizedCaseInsensitiveCompare(rhs.owner) == .orderedAscending
        }
    }

    private static func scan(
        application app: RunningApplication,
        hiddenSeparatorX: CGFloat,
        alwaysHiddenSeparatorX: CGFloat?,
        rtl: Bool,
        deadline: Date
    ) -> [Item] {
        guard Date() < deadline else { return [] }
        let appElement = AXUIElementCreateApplication(app.pid)
        configureTimeout(on: appElement)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXExtrasMenuBarAttribute as CFString,
            &value
        ) == .success, let raw = value else { return [] }

        let menuBar = raw as! AXUIElement
        configureTimeout(on: menuBar)
        var result: [Item] = []
        var seen = Set<String>()

        for element in menuItems(in: menuBar, maxDepth: 3, deadline: deadline) {
            guard Date() < deadline else { break }
            configureTimeout(on: element)
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

            let key = "\(app.pid):\(Int(frame.minX.rounded())):\(Int(frame.width.rounded()))"
            guard seen.insert(key).inserted else { continue }
            result.append(Item(
                id: key,
                element: element,
                title: bestTitle(for: element, fallback: app.owner),
                owner: app.owner,
                section: section,
                frame: frame
            ))
        }
        return result
    }

    static func perform(_ interaction: MenuBarPanelInteraction, on item: Item) -> Bool {
        configureTimeout(on: item.element)
        var rawActions: CFArray?
        let actions: [String]
        if AXUIElementCopyActionNames(item.element, &rawActions) == .success,
           let rawActions {
            actions = rawActions as? [String] ?? []
        } else {
            actions = []
        }

        let orderedActions: [String]
        switch interaction {
        case .primary:
            orderedActions = [kAXPressAction as String, kAXShowMenuAction as String]
        case .secondary:
            orderedActions = [kAXShowMenuAction as String, kAXPressAction as String]
        }

        for action in orderedActions where actions.isEmpty || actions.contains(action) {
            if AXUIElementPerformAction(item.element, action as CFString) == .success {
                return true
            }
        }
        return false
    }

    private static func configureTimeout(on element: AXUIElement) {
        _ = AXUIElementSetMessagingTimeout(element, applicationMessagingTimeout)
    }

    private static func menuItems(
        in element: AXUIElement,
        maxDepth: Int,
        deadline: Date
    ) -> [AXUIElement] {
        guard maxDepth >= 0, Date() < deadline else { return [] }
        configureTimeout(on: element)
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return [] }

        var result: [AXUIElement] = []
        for child in children {
            guard Date() < deadline else { break }
            configureTimeout(on: child)
            let role = stringValue(kAXRoleAttribute, from: child)
            let subrole = stringValue(kAXSubroleAttribute, from: child)
            if role == kAXMenuBarItemRole as String || subrole == "AXMenuExtra" {
                result.append(child)
            } else if maxDepth > 0 {
                result.append(contentsOf: menuItems(
                    in: child,
                    maxDepth: maxDepth - 1,
                    deadline: deadline
                ))
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
        configureTimeout(on: element)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        configureTimeout(on: element)
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

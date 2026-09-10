from pathlib import Path
import re

manager_path = Path('Sources/OpsNotchApp/MenuBarManager.swift')
manager = manager_path.read_text()

old = '''    private var rawPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var panelController: MenuBarHiddenItemsPanelController!
    private var panelOpenedForNotchOverflow = false
    private var notchProbeGeneration = 0
    private var lastPanelScanAt: Date?
    private var panelScanGeneration = 0
'''
new = '''    private var rawPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var stagedPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var panelController: MenuBarHiddenItemsPanelController!
    private var panelOpenedForNotchOverflow = false
    private var notchProbeGeneration = 0
    private var lastPanelScanAt: Date?
    private var panelScanGeneration = 0
'''
assert old in manager, 'manager property anchor not found'
manager = manager.replace(old, new, 1)
manager = manager.replace('    private let panelCacheLifetime: TimeInterval = 5\n', '    private let panelCacheLifetime: TimeInterval = 30\n', 1)

pattern = re.compile(r'    private func refreshPanelItems\(promptForPermission: Bool\) \{.*?\n    \}\n\n    private func interactWithPanelItem', re.S)
replacement = r'''    private func refreshPanelItems(promptForPermission: Bool) {
        panelScanGeneration += 1
        let generation = panelScanGeneration
        panelController.language = model.language
        guard MenuBarAXScanner.ensureTrusted(prompt: promptForPermission) else {
            stagedPanelItems.removeAll()
            rawPanelItems.removeAll()
            lastPanelScanAt = nil
            panelController.setPermissionRequired()
            return
        }
        guard positionsAreValid() else {
            stagedPanelItems.removeAll()
            rawPanelItems.removeAll()
            lastPanelScanAt = nil
            panelController.setUnavailable(L10n.text("menuBarOrderInvalid", model.language))
            return
        }

        stagedPanelItems.removeAll(keepingCapacity: true)
        let hadCachedItems = !rawPanelItems.isEmpty
        panelController.beginRefresh(preserveItems: hadCachedItems)
        let previous = state
        applyState(.allExpanded, animated: false, scheduleAutoHide: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, generation == self.panelScanGeneration else { return }
            let hiddenX = self.itemX(self.hiddenSeparatorItem)
            let alwaysX = self.model.settings.menuBarAlwaysHiddenEnabled ? self.itemX(self.alwaysHiddenSeparatorItem) : nil
            guard let hiddenX else {
                self.panelScanGeneration += 1
                self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                self.applyState(previous, animated: false, scheduleAutoHide: true)
                return
            }

            MenuBarAXScanner.scanProgressively(
                hiddenSeparatorX: hiddenX,
                alwaysHiddenSeparatorX: alwaysX,
                rtl: NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft,
                onBatch: { [weak self] batch in
                    guard let self, generation == self.panelScanGeneration else { return }
                    for item in batch {
                        self.stagedPanelItems[item.id] = item
                        self.rawPanelItems[item.id] = item
                    }
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.lastPanelScanAt = Date()
                    self.panelController.setItems(visible.map(\.presentation), refreshing: true)
                },
                completion: { [weak self] in
                    guard let self, generation == self.panelScanGeneration else { return }
                    let fresh = MenuBarAXScanner.sortedItems(Array(self.stagedPanelItems.values))
                    if !fresh.isEmpty || !hadCachedItems {
                        self.rawPanelItems = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })
                    }
                    self.lastPanelScanAt = Date()
                    self.panelScanGeneration += 1
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.panelController.setItems(visible.map(\.presentation), refreshing: false)
                    self.applyState(previous, animated: false, scheduleAutoHide: true)
                }
            )

            // AX calls cannot be cancelled reliably. The UI therefore owns the overall deadline:
            // after two seconds we stop waiting, preserve any partial/cached items, and invalidate
            // this generation so late results cannot overwrite a newer refresh.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, generation == self.panelScanGeneration else { return }
                self.panelScanGeneration += 1
                let partial = MenuBarAXScanner.sortedItems(Array(self.stagedPanelItems.values))
                if !partial.isEmpty {
                    for item in partial {
                        self.rawPanelItems[item.id] = item
                    }
                    self.lastPanelScanAt = Date()
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.panelController.setItems(visible.map(\.presentation), refreshing: false)
                } else if !self.rawPanelItems.isEmpty {
                    self.panelController.finishRefresh()
                } else {
                    self.lastPanelScanAt = nil
                    self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                }
                self.applyState(previous, animated: false, scheduleAutoHide: true)
            }
        }
    }

    private func interactWithPanelItem'''
manager, count = pattern.subn(replacement, manager, count=1)
assert count == 1, f'refreshPanelItems replacement count={count}'
manager_path.write_text(manager)

panel_path = Path('Sources/OpsNotchApp/MenuBarHiddenItemsPanelController.swift')
panel = panel_path.read_text()

old = '''    @Published var language: AppLanguage
    @Published private(set) var items: [MenuBarHiddenItemPresentation] = []
    @Published private(set) var phase: Phase = .loading
'''
new = '''    @Published var language: AppLanguage
    @Published private(set) var items: [MenuBarHiddenItemPresentation] = []
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var isRefreshing = false
'''
assert old in panel, 'panel published state anchor not found'
panel = panel.replace(old, new, 1)

pattern = re.compile(r'    var isVisible: Bool \{ popover\.isShown \}.*?\n    func setItems\(_ items: \[MenuBarHiddenItemPresentation\]\) \{\n        self\.items = items\n        phase = \.ready\n    \}', re.S)
replacement = r'''    var isVisible: Bool { popover.isShown }
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
    }'''
panel, count = pattern.subn(replacement, panel, count=1)
assert count == 1, f'panel controller methods replacement count={count}'

old = '''                Button {
                    controller.onRefresh?()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(controller.isLoading)
'''
new = '''                Button {
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
'''
assert old in panel, 'refresh button anchor not found'
panel = panel.replace(old, new, 1)

scanner_start = panel.index('enum MenuBarAXScanner {')
scanner_end = panel.rindex('\n#endif')
scanner = r'''enum MenuBarAXScanner {
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
}'''
panel = panel[:scanner_start] + scanner + panel[scanner_end:]
panel_path.write_text(panel)

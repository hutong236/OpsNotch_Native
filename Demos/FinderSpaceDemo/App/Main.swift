import AppKit
import ApplicationServices

@main
enum FinderSpaceDemoMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let log = DemoLog()
        if CommandLine.arguments.contains("--probe") {
            app.setActivationPolicy(.accessory)
            Task { @MainActor in
                do {
                    let runtime = try DemoRuntime(log: log)
                    let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 180),
                        styleMask: [.titled], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.title = "FinderSpaceDemo CI probe"
                    window.orderFront(nil)
                    defer { window.orderOut(nil) }
                    try await Task.sleep(nanoseconds: 300_000_000)
                    let id = CGWindowID(window.windowNumber)
                    let before = try runtime.membership(id)
                    guard before.count == 1, let current = before.first else {
                        throw DemoFailure("PROBE_WINDOW_HAS_NO_UNIQUE_SPACE \(before.sorted())")
                    }
                    log.write("PROBE_OWN_WINDOW id=\(id) space=\(current)")
                    for method in [DemoRuntime.Method.objectiveC, .swift] {
                        // Exercise both actual calling conventions on our own window.
                        // This SAME-Space call is never a cross-Space movement test.
                        try runtime.requestMove(windowID: id, spaceID: current, method: method)
                        try await Task.sleep(nanoseconds: 250_000_000)
                        guard try runtime.membership(id) == before else {
                            throw DemoFailure("PROBE_UNEXPECTED_MEMBERSHIP_CHANGE")
                        }
                        log.write("PROBE_PASS method=\(method) same-space invocation returned")
                    }
                    log.write("CROSS_SPACE_NOT_TESTED; FINDER_NOT_TESTED; run the GUI on the target Mac")
                    exit(0)
                } catch {
                    log.write("PROBE_FAILED \(error.localizedDescription)")
                    exit(1)
                }
            }
            app.run()
        } else {
            app.setActivationPolicy(.regular)
            let delegate = DemoAppDelegate(log: log)
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}

@MainActor
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private let log: DemoLog
    private var runtime: DemoRuntime?
    private var window: NSWindow!
    private let source = NSPopUpButton()
    private let target = NSPopUpButton()
    private let method = NSPopUpButton()
    private let activateFinder = NSButton(checkboxWithTitle: tr("移动前激活 Finder", "Activate Finder before moving"), target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let output = NSTextView()
    private var inputs: [NSControl] = []
    private var finderWindows: [FinderWindow] = []
    private var targets: [DemoSpace] = []
    private var busy = false

    init(log: DemoLog) { self.log = log }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let root = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: tr("退出 FinderSpaceDemo", "Quit FinderSpaceDemo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = submenu
        menu.addItem(root)
        NSApp.mainMenu = menu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = tr("Finder 桌面移动 Demo", "Finder Desktop Move Demo")
        window.minSize = NSSize(width: 700, height: 580)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -18)
        ])
        let help = NSTextField(wrappingLabelWithString: tr(
            "打开一个普通 Finder 文件夹窗口，刷新后选择窗口和目标桌面。先测“移动”，再手动切换桌面目视确认。",
            "Open a normal Finder folder window, refresh, then choose that window and a destination. Move first, then switch desktops manually to inspect it."))
        stack.addArrangedSubview(help)
        let permission = button(tr("辅助功能权限", "Accessibility"), #selector(permissionAction))
        let open = button(tr("打开 Finder", "Open Finder"), #selector(openFinder))
        let refresh = button(tr("刷新窗口与桌面", "Refresh"), #selector(refreshAction))
        stack.addArrangedSubview(row([permission, open, refresh]))
        for (label, popup) in [(tr("Finder 窗口", "Finder window"), source), (tr("目标桌面", "Destination"), target), (tr("调用方式", "Call method"), method)] {
            stack.addArrangedSubview(NSTextField(labelWithString: label))
            stack.addArrangedSubview(popup)
            popup.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        source.target = self
        source.action = #selector(sourceChanged)
        method.addItems(withTitles: [tr("Objective-C 直接调用", "Direct Objective-C call"), tr("Swift 调用（对照 v2.7.19）", "Swift call (v2.7.19 comparison)")])
        activateFinder.state = .on
        let move = button(tr("移动所选 Finder 窗口", "Move selected Finder window"), #selector(moveAction))
        move.keyEquivalent = "\r"
        stack.addArrangedSubview(row([activateFinder, move]))
        inputs = [permission, open, refresh, source, target, method, activateFinder, move]
        stack.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        output.isEditable = false
        output.isSelectable = true
        output.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        output.textContainerInset = NSSize(width: 6, height: 6)
        output.isVerticallyResizable = true
        output.autoresizingMask = [.width]
        output.textContainer?.widthTracksTextView = true
        scroll.documentView = output
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        stack.addArrangedSubview(row([
            button(tr("复制诊断日志", "Copy log"), #selector(copyLog)),
            button(tr("保存诊断日志…", "Save log…"), #selector(saveLog))
        ]))
        output.string = log.text
        log.onChange = { [weak self] text in
            self?.output.string = text
            self?.output.scrollToEndOfDocument(nil)
        }
        do { runtime = try DemoRuntime(log: log) }
        catch { showError(error) }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshAction()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.spacing = 10
        return row
    }
    private func showError(_ error: Error) {
        status.stringValue = error.localizedDescription
        log.write("ERROR \(error.localizedDescription)")
    }

    @objc private func permissionAction() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        log.write("AX_PERMISSION_CHECK \(trusted)")
        status.stringValue = tr("在辅助功能列表中允许 FinderSpaceDemo，然后返回刷新。", "Allow FinderSpaceDemo under Accessibility, then Refresh.")
    }

    @objc private func openFinder() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        status.stringValue = tr("Finder 窗口打开后，点击刷新。", "Click Refresh after the Finder window opens.")
    }

    @objc private func refreshAction() {
        guard !busy, let runtime else { return }
        source.removeAllItems()
        target.removeAllItems()
        finderWindows = []
        targets = []
        do {
            targets = try runtime.spaces().filter { $0.type == 0 }
            target.addItems(withTitles: targets.map(\.label))
            for space in targets { log.write("DESKTOP number=\(space.number) id=\(space.id) display=\(space.display) current=\(space.current)") }
            finderWindows = try runtime.finderWindows()
            source.addItems(withTitles: finderWindows.map { "\($0.title) · Window \($0.id)" })
            status.stringValue = finderWindows.isEmpty
                ? tr("没有普通 Finder 窗口，请打开文件夹后刷新。", "No normal Finder window. Open a folder and refresh.")
                : tr("请选择另一个普通桌面，然后点击移动。", "Select a different normal desktop, then Move.")
            sourceChanged()
        } catch { showError(error) }
    }

    @objc private func sourceChanged() {
        guard let runtime, finderWindows.indices.contains(source.indexOfSelectedItem) else { return }
        let selected = finderWindows[source.indexOfSelectedItem]
        if let before = try? runtime.membership(selected.id),
           let sourceSpace = targets.first(where: { before.contains($0.id) }),
           let candidate = targets.firstIndex(where: { $0.display == sourceSpace.display && !before.contains($0.id) }) {
            target.selectItem(at: candidate)
        }
    }

    @objc private func moveAction() {
        guard !busy, let runtime,
              finderWindows.indices.contains(source.indexOfSelectedItem),
              targets.indices.contains(target.indexOfSelectedItem) else { return }
        // Window selection is explicit and fixed, independent of whoever owns keyboard focus.
        let selected = finderWindows[source.indexOfSelectedItem]
        let destination = targets[target.indexOfSelectedItem]
        let callMethod = DemoRuntime.Method(rawValue: method.indexOfSelectedItem) ?? .objectiveC
        let shouldActivate = activateFinder.state == .on
        busy = true
        inputs.forEach { $0.isEnabled = false }
        Task { @MainActor in
            defer { busy = false; inputs.forEach { $0.isEnabled = true } }
            do {
                guard AXIsProcessTrusted(), !selected.app.isTerminated else { throw DemoFailure("Finder / Accessibility unavailable") }
                guard try runtime.identifier(selected.element) == selected.id else { throw DemoFailure("Selected Finder window changed; refresh") }
                guard runtime.attribute(selected.element, kAXMinimizedAttribute) as? Bool != true,
                      runtime.attribute(selected.element, "AXFullScreen") as? Bool != true else {
                    throw DemoFailure(tr("请使用非最小化、非全屏的 Finder 窗口。", "Use a non-minimized, non-full-screen Finder window."))
                }
                let topology = try runtime.spaces()
                let before = try runtime.membership(selected.id)
                log.write("BEFORE window=\(selected.id) pid=\(selected.app.processIdentifier) spaces=\(before.sorted()) target=\(destination.id) activate=\(shouldActivate)")
                guard before.count == 1, let sourceSpace = topology.first(where: { before.contains($0.id) }), sourceSpace.type == 0 else {
                    throw DemoFailure(tr("窗口不属于单一普通桌面；请检查“分配到所有桌面”和全屏设置。", "Window must belong to one normal desktop. Check All Desktops / full screen."))
                }
                guard topology.contains(where: { $0.id == destination.id && $0.type == 0 }), sourceSpace.display == destination.display else {
                    throw DemoFailure(tr("请在同一显示器的两个普通桌面之间测试。", "Choose two normal desktops on the same display."))
                }
                guard !before.contains(destination.id) else {
                    throw DemoFailure(tr("窗口已在该桌面，请选择其他桌面；这不算移动成功。", "Already on that desktop. Choose another; this is not a movement test."))
                }
                if shouldActivate {
                    let activated = selected.app.activate(options: [.activateIgnoringOtherApps])
                    let raised = AXUIElementPerformAction(selected.element, kAXRaiseAction as CFString)
                    log.write("ACTIVATE requested=\(activated) raise_error=\(raised.rawValue)")
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                // Do not replace the selected AXWindow after activation.
                guard try runtime.identifier(selected.element) == selected.id,
                      try runtime.membership(selected.id) == before else { throw DemoFailure("Source changed before call; refresh and retry") }
                status.stringValue = tr("已请求移动，正在检查窗口归属…", "Move requested; checking window membership…")
                try runtime.requestMove(windowID: selected.id, spaceID: destination.id, method: callMethod)
                let verified = try await runtime.verify(windowID: selected.id, target: destination.id, original: before)
                status.stringValue = verified
                    ? tr("系统已确认窗口进入目标桌面。请手动切换过去目视确认。", "WindowServer confirmed the destination. Switch there manually to inspect it.")
                    : tr("5 秒内未确认移动。请复制日志，以便定位失败步骤。", "Movement not confirmed within 5 seconds. Copy the log to diagnose.")
            } catch { showError(error) }
        }
    }

    @objc private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log.text, forType: .string)
        status.stringValue = tr("诊断日志已复制。", "Diagnostic log copied.")
    }

    @objc private func saveLog() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FinderSpaceDemo.log"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do { try self.log.text.write(to: url, atomically: true, encoding: .utf8) }
            catch { self.showError(error) }
        }
    }
}

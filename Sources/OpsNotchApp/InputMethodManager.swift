#if os(macOS)
import AppKit
import Carbon
import Combine
import Foundation
import OpsNotchCore

struct InputSourceOption: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
final class InputMethodManager: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Self.enabledKey)
            if enabled { start() } else { stop() }
        }
    }
    @Published private(set) var rules: [InputMethodRule]
    @Published private(set) var inputSources: [InputSourceOption] = []

    private static let enabledKey = "input_method_manager_enabled"
    private static let rulesKey = "input_method_manager_rules"

    private let defaults: UserDefaults
    private var activationObserver: NSObjectProtocol?
    private var pendingSwitch: DispatchWorkItem?
    private var lastActiveBundleID: String?
    private var rememberedSources: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: Self.enabledKey)
        if let data = defaults.data(forKey: Self.rulesKey),
           let decoded = try? JSONDecoder().decode([InputMethodRule].self, from: data) {
            rules = decoded
        } else {
            rules = []
        }
        refreshInputSources()
        if enabled { start() }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func refreshInputSources() {
        let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
        var values: [InputSourceOption] = []
        for case let source as TISInputSource in list {
            guard isSelectableKeyboardSource(source),
                  let id = stringProperty(source, key: kTISPropertyInputSourceID) else { continue }
            let name = stringProperty(source, key: kTISPropertyLocalizedName) ?? id
            values.append(InputSourceOption(id: id, name: name))
        }
        inputSources = values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addApplication(url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        guard !rules.contains(where: { $0.bundleID == bundleID }) else { return }
        rules.append(InputMethodRule(bundleID: bundleID, appName: name, mode: .keep))
        persistRules()
    }

    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        persistRules()
    }

    func updateRule(id: UUID, mode: InputMethodRuleMode? = nil, inputSourceID: String? = nil, setInputSource: Bool = false) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        if let mode { rules[index].mode = mode }
        if setInputSource { rules[index].inputSourceID = inputSourceID }
        persistRules()
    }

    func sourceName(for id: String?) -> String {
        guard let id else { return "—" }
        return inputSources.first(where: { $0.id == id })?.name ?? id
    }

    private func start() {
        guard activationObserver == nil else { return }
        lastActiveBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in self?.handleActivated(app) }
        }
    }

    private func stop() {
        pendingSwitch?.cancel()
        pendingSwitch = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    private func handleActivated(_ app: NSRunningApplication) {
        guard enabled, let bundleID = app.bundleIdentifier else { return }

        if let previous = lastActiveBundleID,
           previous != bundleID,
           rules.first(where: { $0.bundleID == previous })?.mode == .remember,
           let current = currentInputSourceID() {
            rememberedSources[previous] = current
        }
        lastActiveBundleID = bundleID

        guard let rule = rules.first(where: { $0.bundleID == bundleID }) else { return }
        let targetID: String?
        switch rule.mode {
        case .fixed:
            targetID = rule.inputSourceID
        case .remember:
            targetID = rememberedSources[bundleID]
        case .keep:
            targetID = nil
        }
        guard let targetID, targetID != currentInputSourceID() else { return }

        pendingSwitch?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.enabled,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID else { return }
            self.selectInputSource(id: targetID)
        }
        pendingSwitch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func currentInputSourceID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return stringProperty(source, key: kTISPropertyInputSourceID)
    }

    @discardableResult
    private func selectInputSource(id: String) -> Bool {
        let list = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
        for case let source as TISInputSource in list {
            guard stringProperty(source, key: kTISPropertyInputSourceID) == id else { continue }
            return TISSelectInputSource(source) == noErr
        }
        return false
    }

    private func isSelectableKeyboardSource(_ source: TISInputSource) -> Bool {
        guard let type = stringProperty(source, key: kTISPropertyInputSourceType) else { return false }
        return type == (kTISTypeKeyboardLayout as String) || type == (kTISTypeKeyboardInputMode as String)
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func persistRules() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: Self.rulesKey)
        }
    }
}
#endif

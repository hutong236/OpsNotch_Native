from pathlib import Path

path = Path("Sources/OpsNotchApp/DesktopSpaceController.swift")
text = path.read_text()

old = """        guard ensureAccessibilityPermission() else {
            return .failure(.accessibilityRequired)
        }
"""
new = """        guard await ensureAccessibilityPermission() else {
            return .failure(.accessibilityRequired)
        }
"""
assert old in text, "switchToDesktop accessibility guard not found"
text = text.replace(old, new, 1)

old = """            let flags: CGEventFlags = [.maskControl, .maskSecondaryFn]
            down.flags = flags
            up.flags = flags
"""
new = """            // Mission Control's native Space shortcut is Control + Left/Right.
            // Adding the Fn modifier can change the semantic key event on macOS
            // and makes the HID fallback unreliable.
            let flags: CGEventFlags = .maskControl
            down.flags = flags
            up.flags = flags
"""
assert old in text, "HID fallback modifier block not found"
text = text.replace(old, new, 1)

old = """    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return AXIsProcessTrusted()
    }
"""
new = """    private func ensureAccessibilityPermission() async -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // The system permission sheet/settings flow is asynchronous. Previously
        // we checked again immediately and returned failure, so the first desktop
        // command could only show the permission prompt and never continue.
        // Keep the same command alive for a short window and resume as soon as
        // macOS reports that Accessibility has been granted.
        for _ in 0..<180 {
            if AXIsProcessTrusted() { return true }
            if Task.isCancelled { return false }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        return AXIsProcessTrusted()
    }
"""
assert old in text, "ensureAccessibilityPermission implementation not found"
text = text.replace(old, new, 1)

path.write_text(text)

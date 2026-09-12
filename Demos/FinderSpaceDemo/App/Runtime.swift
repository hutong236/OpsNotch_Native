import AppKit
import ApplicationServices
import Darwin
import FinderSpaceDemoBridge

func tr(_ chinese: String, _ english: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? chinese : english
}

struct DemoFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

struct DemoSpace {
    let number: Int
    let id: UInt64
    let display: String
    let displayName: String
    let type: Int
    let current: Bool

    var label: String {
        "\(displayName) · \(tr("桌面", "Desktop")) \(number) · Space \(id)\(current ? " ✓" : "")"
    }
}

struct FinderWindow {
    let app: NSRunningApplication
    let element: AXUIElement
    let id: CGWindowID
    let title: String
    let minimized: Bool
    let fullscreen: Bool
}

@MainActor
final class DemoLog {
    private(set) var text = ""
    private(set) var url: URL?
    var onChange: ((String) -> Void)?
    private var handle: FileHandle?

    init() {
        do {
            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/lab.hutong.opsnotch.finder-space-demo")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = "FinderSpaceDemo-\(UUID().uuidString).log"
            let destination = folder.appendingPathComponent(name)
            guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
                throw DemoFailure("Cannot create log file")
            }
            handle = try FileHandle(forWritingTo: destination)
            url = destination
        } catch {
            write("LOG_FILE_UNAVAILABLE \(error.localizedDescription)")
        }
        write("OS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        #if arch(arm64)
        write("ARCH arm64")
        #else
        write("ARCH x86_64")
        #endif
        write("BUILD \(Bundle.main.object(forInfoDictionaryKey: "DemoSourceCommit") as? String ?? "unbundled")")
        write("AX_TRUSTED \(AXIsProcessTrusted())")
        write("BRIDGE \(String(cString: FinderDemoBridgeStatus()))")
    }

    func write(_ line: String) {
        let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        text += entry
        print(line)
        fflush(stdout)
        if let handle {
            do { try handle.write(contentsOf: Data(entry.utf8)) }
            catch { self.handle = nil; text += "LOG_WRITE_FAILED\n" }
        }
        onChange?(text)
    }
}

@MainActor
final class DemoRuntime {
    enum Method: Int { case objectiveC, swift }
    private typealias Connection = @convention(c) () -> Int32
    private typealias ReadDisplays = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias ReadWindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias WindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private let image: UnsafeMutableRawPointer
    private let process: UnsafeMutableRawPointer
    private let connection: Connection
    private let readDisplays: ReadDisplays
    private let readWindowSpaces: ReadWindowSpaces
    private let axID: WindowID
    let log: DemoLog

    init(log: DemoLog) throws {
        self.log = log
        guard let loaded = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let currentProcess = dlopen(nil, RTLD_LAZY) else {
            throw DemoFailure("Unable to load SkyLight / process image")
        }
        image = loaded
        process = currentProcess
        func symbol(_ name: String, in handle: UnsafeMutableRawPointer) throws -> UnsafeMutableRawPointer {
            guard let pointer = dlsym(handle, name) else { throw DemoFailure("Missing symbol: \(name)") }
            return pointer
        }
        connection = unsafeBitCast(try symbol("SLSMainConnectionID", in: loaded), to: Connection.self)
        readDisplays = unsafeBitCast(try symbol("SLSCopyManagedDisplaySpaces", in: loaded), to: ReadDisplays.self)
        readWindowSpaces = unsafeBitCast(try symbol("SLSCopySpacesForWindows", in: loaded), to: ReadWindowSpaces.self)
        axID = unsafeBitCast(try symbol("_AXUIElementGetWindow", in: currentProcess), to: WindowID.self)
        log.write("CONNECTION \(connection())")
    }

    func spaces() throws -> [DemoSpace] {
        guard let array = readDisplays(connection())?.takeRetainedValue(),
              let displays = array as? [[String: Any]] else { throw DemoFailure("Cannot read desktop topology") }
        let screens: [(String, String)] = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return (CFUUIDCreateString(nil, uuid) as String, screen.localizedName)
        }
        let ordered = displays.enumerated().sorted { lhs, rhs in
            func rank(_ pair: (offset: Int, element: [String: Any])) -> Int {
                screens.firstIndex { $0.0 == pair.element["Display Identifier"] as? String } ?? screens.count + pair.offset
            }
            return rank(lhs) < rank(rhs)
        }
        var result: [DemoSpace] = []
        for (offset, display) in ordered {
            guard let identifier = display["Display Identifier"] as? String else { continue }
            let active = display["Current Space"] as? [String: Any] ?? [:]
            let currentID = Self.spaceID(active)
            for raw in display["Spaces"] as? [[String: Any]] ?? [] {
                guard let id = Self.spaceID(raw), let type = (raw["type"] as? NSNumber)?.intValue,
                      type == 0 || type == 4 else { continue }
                result.append(DemoSpace(number: result.count + 1, id: id, display: identifier,
                    displayName: screens.first { $0.0 == identifier }?.1 ?? "Display \(offset + 1)",
                    type: type, current: id == currentID))
            }
        }
        return result
    }

    private static func spaceID(_ raw: [String: Any]) -> UInt64? {
        ((raw["ManagedSpaceID"] ?? raw["id64"]) as? NSNumber)?.uint64Value
    }

    func membership(_ id: CGWindowID) throws -> Set<UInt64> {
        let ids = [NSNumber(value: Int32(bitPattern: id))] as CFArray
        guard let array = readWindowSpaces(connection(), 7, ids)?.takeRetainedValue() else {
            throw DemoFailure("SLSCopySpacesForWindows returned nil for window=\(id)")
        }
        return Set((array as NSArray).compactMap { ($0 as? NSNumber)?.uint64Value })
    }

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return result == .success ? value : nil
    }

    func identifier(_ element: AXUIElement) throws -> CGWindowID {
        var id: CGWindowID = 0
        let error = axID(element, &id)
        guard error == .success, id != 0 else {
            throw DemoFailure("AX_WINDOW_ID_FAILED error=\(error.rawValue) window=\(id)")
        }
        return id
    }

    func finderWindows() throws -> [FinderWindow] {
        guard AXIsProcessTrusted() else {
            throw DemoFailure(tr("请先为 FinderSpaceDemo 开启辅助功能权限，再点击刷新。", "Enable Accessibility for FinderSpaceDemo, then Refresh."))
        }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            throw DemoFailure(tr("Finder 未运行，请先打开 Finder。", "Open Finder first."))
        }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 2)
        log.write("FINDER pid=\(finder.processIdentifier) frontmost=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
        for name in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(app, name as CFString, &value)
            let id: CGWindowID?
            if let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                id = try? identifier(unsafeBitCast(value, to: AXUIElement.self))
            } else {
                id = nil
            }
            log.write("FINDER_\(name) error=\(error.rawValue) window=\(id.map(String.init) ?? "none")")
        }
        var raw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
        guard error == .success, let elements = raw as? [AXUIElement] else {
            throw DemoFailure("FINDER_AX_WINDOWS_FAILED error=\(error.rawValue)")
        }
        var windows: [FinderWindow] = []
        for element in elements {
            guard attribute(element, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole else { continue }
            do {
                let id = try identifier(element)
                let minimized = attribute(element, kAXMinimizedAttribute) as? Bool ?? false
                let fullscreen = attribute(element, "AXFullScreen") as? Bool ?? false
                windows.append(FinderWindow(app: finder, element: element, id: id,
                    title: attribute(element, kAXTitleAttribute) as? String ?? "Finder", minimized: minimized, fullscreen: fullscreen))
                log.write("FINDER_WINDOW id=\(id) spaces=\(try membership(id).sorted()) minimized=\(minimized) fullscreen=\(fullscreen)")
            } catch { log.write("WINDOW_SKIPPED \(error.localizedDescription)") }
        }
        return windows
    }

    func requestMove(windowID: CGWindowID, spaceID: UInt64, method: Method) throws {
        log.write("CALL method=\(method) window=\(windowID) target=\(spaceID) frontmost=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
        var result: Int64 = 0
        if method == .objectiveC {
            let status = FinderDemoRequestMove(windowID, spaceID, &result)
            guard status == 0 else { throw DemoFailure("OBJC_REQUEST_FAILED code=\(status)") }
        } else {
            // Match v2.7.19's raw Swift objc_msgSend bridge for a controlled comparison.
            typealias GetClass = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
            typealias GetSelector = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
            typealias Alloc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
            typealias InitMove = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, CFArray, UInt64) -> UnsafeMutableRawPointer?
            typealias Release = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void
            typealias Perform = @convention(c) (UnsafeMutableRawPointer) -> Int64
            guard let address = FinderDemoMoveAddress(),
                  let clsSymbol = dlsym(process, "objc_getClass"),
                  let selectorSymbol = dlsym(process, "sel_registerName"),
                  let sendSymbol = dlsym(process, "objc_msgSend") else { throw DemoFailure("SWIFT_BRIDGE_UNAVAILABLE") }
            let getClass = unsafeBitCast(clsSymbol, to: GetClass.self)
            let selector = unsafeBitCast(selectorSymbol, to: GetSelector.self)
            guard let cls = getClass("SLSBridgedMoveWindowsToManagedSpaceOperation"),
                  let alloc = selector("alloc"), let initializer = selector("initWithWindows:spaceID:"),
                  let release = selector("release"),
                  let allocated = unsafeBitCast(sendSymbol, to: Alloc.self)(cls, alloc),
                  let operation = unsafeBitCast(sendSymbol, to: InitMove.self)(allocated, initializer,
                    [NSNumber(value: Int32(bitPattern: windowID))] as CFArray, spaceID) else { throw DemoFailure("SWIFT_INITIALIZER_FAILED") }
            result = unsafeBitCast(address, to: Perform.self)(operation)
            unsafeBitCast(sendSymbol, to: Release.self)(operation, release)
        }
        log.write("SUBMITTED raw_result=\(result) (not yet verified)")
    }

    func verify(windowID: CGWindowID, target: UInt64, original: Set<UInt64>) async throws -> Bool {
        var previous = original
        var stableCount = 0
        for tick in 0..<100 {
            try await Task.sleep(nanoseconds: 50_000_000)
            let after = try membership(windowID)
            if after != previous { log.write("MEMBERSHIP elapsed_ms=\((tick + 1) * 50) window=\(windowID) spaces=\(after.sorted())") }
            previous = after
            stableCount = after == [target] ? stableCount + 1 : 0
            if stableCount >= 3 {
                log.write("VERIFIED window=\(windowID) before=\(original.sorted()) after=\(after.sorted())")
                return true
            }
        }
        log.write("TIMEOUT window=\(windowID) before=\(original.sorted()) after=\(previous.sorted()) target=\(target)")
        return false
    }
}

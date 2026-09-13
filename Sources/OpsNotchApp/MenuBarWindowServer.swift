#if os(macOS)
import AppKit
import Darwin

/// Read-only access to the WindowServer's menu-extra inventory. The public CG window list
/// can omit hidden menu extras even while their AX elements still have valid offscreen frames.
enum MenuBarWindowServer {
    struct Inventory {
        let windows: [MenuBarItemClickForwarder.Window]
        let diagnostic: String
    }

    private typealias MainConnection = @convention(c) () -> Int32
    private typealias WindowCount = @convention(c) (Int32, Int32, UnsafeMutablePointer<Int32>) -> CGError
    private typealias WindowList = @convention(c) (Int32, Int32, Int32, UnsafeMutablePointer<CGWindowID>, UnsafeMutablePointer<Int32>) -> CGError
    private typealias WindowOwner = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<Int32>) -> CGError
    private typealias ConnectionPID = @convention(c) (Int32, UnsafeMutablePointer<pid_t>) -> CGError
    private typealias WindowFrame = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<CGRect>) -> CGError
    private typealias WindowLevel = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<Int32>) -> CGError

    private struct API {
        let mainConnection: MainConnection
        let windowCount: WindowCount
        let menuBarWindows: WindowList
        let windowOwner: WindowOwner
        let connectionPID: ConnectionPID
        let windowFrame: WindowFrame
        let windowLevel: WindowLevel

        init?() {
            // Retain the image for the lifetime of these C function pointers. Resolve exported
            // CGS/SLS names dynamically so missing private APIs never prevent app launch.
            guard let image = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return nil }
            func function<T>(_ suffix: String, as type: T.Type) -> T? {
                for prefix in ["SLS", "CGS"] {
                    if let symbol = dlsym(image, prefix + suffix) {
                        return unsafeBitCast(symbol, to: type)
                    }
                }
                return nil
            }
            guard let mainConnection = function("MainConnectionID", as: MainConnection.self),
                  let windowCount = function("GetWindowCount", as: WindowCount.self),
                  let menuBarWindows = function("GetProcessMenuBarWindowList", as: WindowList.self),
                  let windowOwner = function("GetWindowOwner", as: WindowOwner.self),
                  let connectionPID = function("ConnectionGetPID", as: ConnectionPID.self),
                  let windowFrame = function("GetScreenRectForWindow", as: WindowFrame.self),
                  let windowLevel = function("GetWindowLevel", as: WindowLevel.self) else {
                dlclose(image)
                return nil
            }
            self.mainConnection = mainConnection
            self.windowCount = windowCount
            self.menuBarWindows = menuBarWindows
            self.windowOwner = windowOwner
            self.connectionPID = connectionPID
            self.windowFrame = windowFrame
            self.windowLevel = windowLevel
        }
    }

    private static let api = API()

    static func menuBarWindows() -> Inventory {
        guard let api else { return Inventory(windows: [], diagnostic: "server-api=unavailable") }
        let connection = api.mainConnection()
        var count: Int32 = 0
        let countResult = api.windowCount(connection, 0, &count)
        guard countResult == .success, count >= 0, count < 16_352 else {
            return Inventory(windows: [], diagnostic: "server-count-error=\(countResult.rawValue) count=\(count)")
        }
        // Allow for windows created between the count and list calls; reject a truncated list
        // instead of accidentally treating one member of an ambiguous pair as a unique match.
        let capacity = Int(count) + 32
        var identifiers = [CGWindowID](repeating: 0, count: capacity)
        var actual: Int32 = 0
        let listResult = identifiers.withUnsafeMutableBufferPointer {
            api.menuBarWindows(connection, 0, Int32(capacity), $0.baseAddress!, &actual)
        }
        guard listResult == .success, actual >= 0, Int(actual) < capacity else {
            return Inventory(windows: [], diagnostic: "server-list-error=\(listResult.rawValue) count=\(actual) capacity=\(capacity)")
        }
        let ids = Set(identifiers.prefix(Int(actual))).sorted()
        var windows = [MenuBarItemClickForwarder.Window]()
        var errors = [String]()
        for id in ids {
            let result = readWindow(id, api: api, connection: connection, isMenuBarItem: true)
            if let window = result.window { windows.append(window) }
            else { errors.append("\(id):\(result.diagnostic)") }
        }
        return Inventory(windows: windows,
            diagnostic: "server-menu-count=\(ids.count) readable=\(windows.count) errors=[\(errors.prefix(6).joined(separator: ";"))]")
    }

    /// Query owner and current geometry directly, including when public descriptions omit the
    /// window. This is also used immediately before posting a previously resolved click.
    static func readWindow(_ identifier: CGWindowID) -> MenuBarItemClickForwarder.Window? {
        guard let api else { return nil }
        return readWindow(identifier, api: api, connection: api.mainConnection(), isMenuBarItem: false).window
    }

    private static func readWindow(_ identifier: CGWindowID, api: API, connection: Int32,
                                   isMenuBarItem: Bool) -> (window: MenuBarItemClickForwarder.Window?, diagnostic: String) {
        guard identifier != kCGNullWindowID else { return (nil, "null-id") }
        var owner: Int32 = 0
        let ownerResult = api.windowOwner(connection, identifier, &owner)
        guard ownerResult == .success else { return (nil, "owner=\(ownerResult.rawValue)") }
        var pid: pid_t = 0
        let pidResult = api.connectionPID(owner, &pid)
        guard pidResult == .success, pid > 0 else { return (nil, "pid=\(pidResult.rawValue)") }
        var frame = CGRect.zero
        let frameResult = api.windowFrame(connection, identifier, &frame)
        guard frameResult == .success,
              [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
              frame.width > 0, frame.height > 0 else { return (nil, "frame=\(frameResult.rawValue)") }
        var layer: Int32 = 0
        let layerResult = api.windowLevel(connection, identifier, &layer)
        guard layerResult == .success else { return (nil, "layer=\(layerResult.rawValue)") }
        return (MenuBarItemClickForwarder.Window(pid: pid, id: identifier, frame: frame,
            layer: Int(layer), source: .windowServer, isMenuBarItem: isMenuBarItem), "ok")
    }
}
#endif

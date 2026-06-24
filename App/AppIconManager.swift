import Cocoa
import AppKit

// MARK: - Debug helper (internal so other files can use it)
func debugLog(_ text: String) {
    let text = text + "\n"
    let path = "/tmp/externaldock_debug.txt"
    if FileManager.default.fileExists(atPath: path) {
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            handle.write(text.data(using: .utf8)!)
            handle.closeFile()
        }
    } else {
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - AppIconManager
class AppIconManager {

    static let shared = AppIconManager()

    private let defaultsKey = "appPaths"
    private var iconCache: [String: NSImage] = [:]

    /// Default app paths on a typical macOS system
    static var defaultAppPaths: [String] {
        return [
            "/System/Applications/Launchpad.app",
            "/Applications/Safari.app",
            "/Applications/Google Chrome.app",
            "/System/Applications/System Settings.app",
            "/System/Applications/Utilities/Terminal.app"
        ]
    }

    private init() {}

    // MARK: - Load/Save App List
    func loadAppPaths() -> [String] {
        guard let paths = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return Self.defaultAppPaths
        }
        return paths.filter { FileManager.default.fileExists(atPath: $0) }
    }

    func saveAppPaths(_ paths: [String]) {
        UserDefaults.standard.set(paths, forKey: defaultsKey)
    }

    func addApp(path: String) {
        var paths = loadAppPaths()
        if !paths.contains(path) {
            paths.append(path)
            saveAppPaths(paths)
        }
    }

    func removeApp(at path: String) {
        var paths = loadAppPaths()
        paths.removeAll { $0 == path }
        saveAppPaths(paths)
    }

    // MARK: - Icon
    func icon(for appPath: String) -> NSImage {
        if let cached = iconCache[appPath] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 42, height: 42)
        iconCache[appPath] = icon
        return icon
    }

    // MARK: - App Name
    func appName(for appPath: String) -> String {
        let filename = (appPath as NSString).lastPathComponent
        return (filename as NSString).deletingPathExtension
    }

    // MARK: - Launch with External Screen Detection
    func launchApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        let appName = self.appName(for: path)

        debugLog("=== launchApp called ===")
        debugLog("path: \(path)")
        debugLog("appName: \(appName)")

        // List all running apps for debugging
        for app in NSWorkspace.shared.runningApplications {
            debugLog("  running: \(app.localizedName ?? "?") bundle=\(app.bundleURL?.lastPathComponent ?? "?") pid=\(app.processIdentifier)")
        }

        // First, check if app is already running
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == appName || $0.bundleURL?.lastPathComponent == "\(appName).app"
        }) {
            debugLog("Found matching running app: \(runningApp.localizedName ?? "?") pid=\(runningApp.processIdentifier)")
            // App is running — move its windows to external screen, then activate
            moveWindowsToExternalScreen(for: runningApp)
            debugLog("After moveWindowsToExternalScreen")
            runningApp.activate(options: .activateIgnoringOtherApps)
            debugLog("After activate")
            return
        }

        debugLog("App not running, launching new instance")

        // App not running — launch it normally
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    // MARK: - Move Windows to External Screen (direct AX API - no AppleScript)
    private func moveWindowsToExternalScreen(for app: NSRunningApplication) {
        guard let externalScreen = externalTargetScreen() else {
            debugLog("moveWindows: no external screen found")
            return
        }

        let screenFrame = externalScreen.frame
        debugLog("External screen frame: \(screenFrame)")

        // Coordinate conversion: NSScreen (bottom-left origin) → AX (top-left origin)
        // AX (0,0) = top-left of primary display
        // Formula: axY = mainScreenHeight - nsY
        let mainScreenHeight = NSScreen.screens[0].frame.height
        debugLog("Main screen height: \(mainScreenHeight)")

        let targetX = screenFrame.minX + 50
        let targetY = (mainScreenHeight - screenFrame.maxY) + 60
        let targetW: CGFloat = 1200
        let targetH: CGFloat = 800
        debugLog("Target AX pos: (\(Int(targetX)), \(Int(targetY))) size: \(Int(targetW))x\(Int(targetH))")

        // Get app accessibility element
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get windows
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first else {
            debugLog("AX: Could not get windows (error: \(result.rawValue))")
            return
        }

        debugLog("AX: Got \(windows.count) windows, using first one")

        // Set position
        var position = CGPoint(x: targetX, y: targetY)
        let posVal = AXValueCreate(.cgPoint, &position)!
        let posResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            posVal
        )
        debugLog("AX: Set position result = \(posResult.rawValue) (0=success)")

        // Set size
        var size = CGSize(width: targetW, height: targetH)
        let sizeVal = AXValueCreate(.cgSize, &size)!
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeVal
        )
        debugLog("AX: Set size result = \(sizeResult.rawValue) (0=success)")
        debugLog("=== moveWindows end ===")
    }

    // MARK: - Find External Screen (as NSScreen object)
    private func externalTargetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        return screens.last
    }

    // MARK: - Clear Cache
    func clearCache() {
        iconCache.removeAll()
    }

    /// Check if Accessibility permission is granted
    static func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
}
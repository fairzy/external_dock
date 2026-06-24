import Cocoa
import AppKit

// MARK: - DockEdge Enum (shared)
enum DockEdge: String, CaseIterable {
    case bottom
    case top
    case left
    case right

    var displayName: String {
        switch self {
        case .bottom: return "底部"
        case .top: return "顶部"
        case .left: return "左侧"
        case .right: return "右侧"
        }
    }

    var isHorizontal: Bool {
        return self == .bottom || self == .top
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {

    private var dockWindowManager: DockWindowManager!
    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set accessory policy EARLY - hides Dock icon but allows windows to work
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register defaults
        registerDefaultSettings()

        // Initialize managers
        dockWindowManager = DockWindowManager()
        settingsWindowController = SettingsWindowController(dockManager: dockWindowManager)

        // Setup menu bar icon
        setupMenuBar()

        // Show dock
        dockWindowManager.showOnExternalScreen()

        // Activate to ensure windows appear
        NSApp.activate(ignoringOtherApps: true)

        // Check Accessibility permission for window-moving feature
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.checkAccessibilityPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dockWindowManager.cleanup()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⚡"
        statusItem.button?.font = NSFont.systemFont(ofSize: 16)

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "设置 External Dock...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let edgeMenu = NSMenuItem(title: "切换边缘", action: nil, keyEquivalent: "")
        let edgeSubmenu = NSMenu()

        for edge in DockEdge.allCases {
            let item = NSMenuItem(
                title: edge.displayName,
                action: #selector(switchEdge(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = edge.rawValue
            if edge == dockWindowManager.currentEdge {
                item.state = .on
            }
            edgeSubmenu.addItem(item)
        }
        edgeMenu.submenu = edgeSubmenu
        menu.addItem(edgeMenu)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func switchEdge(_ sender: NSMenuItem) {
        guard let edgeRaw = sender.representedObject as? String,
              let edge = DockEdge(rawValue: edgeRaw) else { return }
        dockWindowManager.setEdge(edge)

        if let menu = statusItem.menu,
           let edgeMenu = menu.item(withTitle: "切换边缘")?.submenu {
            for item in edgeMenu.items {
                item.state = (item.representedObject as? String == edge.rawValue) ? .on : .off
            }
        }
    }

    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            "dockEdge": DockEdge.bottom.rawValue,
            "appPaths": AppIconManager.defaultAppPaths
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    private func checkAccessibilityPermission() {
        // Debug: write permission status to file
        let trusted = AppIconManager.hasAccessibilityPermission()
        debugLog("checkAccessibilityPermission: AXIsProcessTrusted = \(trusted)")
        debugLog("Bundle path: \(Bundle.main.bundlePath)")

        // Check if we already prompted the user this session
        let hasPrompted = UserDefaults.standard.bool(forKey: "accessibilityAlertShown")
        if hasPrompted {
            debugLog("Already prompted before, skipping")
            return
        }

        // Check if permission is actually granted
        if trusted {
            debugLog("Permission already granted, no need to prompt")
            return
        }

        // Mark as shown so we don't keep nagging
        UserDefaults.standard.set(true, forKey: "accessibilityAlertShown")
        debugLog("Showing permission alert")

        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "为了在点击图标时自动将应用窗口移到外接屏，需要授权辅助功能。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能 → 勾选 ExternalDock\n\n⚠️ 授权后请完全退出 App 再重新打开才能生效"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "不再提醒")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
import Cocoa
import AppKit

// MARK: - Floating Dock Panel (never steals focus)
class DockPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Dock Window Manager
class DockWindowManager: NSObject {

    private var dockPanel: DockPanel!
    private var dockViewController: DockViewController!
    private(set) var currentEdge: DockEdge = .bottom

    private let dockWidth: CGFloat = 60
    private let dockHeight: CGFloat = 60  // 56px icon + small padding
    private let padding: CGFloat = 12

    override init() {
        super.init()

        // Load saved edge
        let savedEdge = UserDefaults.standard.string(forKey: "dockEdge") ?? DockEdge.bottom.rawValue
        currentEdge = DockEdge(rawValue: savedEdge) ?? .bottom

        // Create VC and set initial layout direction
        dockViewController = DockViewController()
        _ = dockViewController.view  // Force view load
        
        // FIX: Don't call repositionWindow from onAppListChanged - prevents screen jumping
        dockViewController.onAppListChanged = { [weak self] in
            // Only resize, don't reload icons (avoids infinite loop)
            DispatchQueue.main.async {
                self?.repositionWindow(forceReload: false)
            }
        }
        
        dockViewController.updateLayout(for: currentEdge)

        // Create panel
        createPanel()

        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Panel Creation
    private func createPanel() {
        let rect = NSRect(x: 0, y: 0, width: 300, height: dockHeight)
        dockPanel = DockPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        dockPanel.isFloatingPanel = true
        dockPanel.level = .floating
        dockPanel.isOpaque = false
        dockPanel.backgroundColor = NSColor.clear
        dockPanel.hasShadow = true
        dockPanel.hidesOnDeactivate = false
        dockPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        dockPanel.contentViewController = dockViewController
    }

    // MARK: - Screen Detection - ALWAYS prefer external screen if ANY exists
    private func targetScreenFrame() -> CGRect {
        let screens = NSScreen.screens
        
        // If more than 1 screen, pick the first external one
        // Simple rule: if multiple screens, pick the one that's NOT the first (main)
        if screens.count > 1 {
            // First screen is built-in, second is external
            let external = screens[screens.count - 1]
            print("DEBUG: Using external screen")
            return external.visibleFrame
        }
        
        // Fallback to main screen
        print("DEBUG: Using main screen (no external detected)")
        return NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    // MARK: - Window Positioning - 4 EDGES
    func repositionWindow(forceReload: Bool = true) {
        // FIX Screen Jumping: Only reload icons when explicitly requested
        // This prevents reload → onAppListChanged → reposition → reload loop
        if forceReload {
            dockViewController.reloadIcons()
        }
        
        let screenFrame = targetScreenFrame()
        let viewSize = dockViewController.calculateContentSize(for: currentEdge)

        var panelRect: CGRect

        switch currentEdge {
        case .bottom:
            let barWidth = max(viewSize.width + padding * 2, 300)
            panelRect = CGRect(
                x: screenFrame.midX - barWidth / 2,
                y: screenFrame.minY,
                width: barWidth,
                height: dockHeight
            )
        case .top:
            let barWidth = max(viewSize.width + padding * 2, 300)
            panelRect = CGRect(
                x: screenFrame.midX - barWidth / 2,
                y: screenFrame.maxY - dockHeight,
                width: barWidth,
                height: dockHeight
            )
        case .left:
            let barHeight = max(viewSize.height + padding * 2, dockHeight)
            panelRect = CGRect(
                x: screenFrame.minX,
                y: screenFrame.midY - barHeight / 2,
                width: dockWidth,
                height: barHeight
            )
        case .right:
            let barHeight = max(viewSize.height + padding * 2, dockHeight)
            panelRect = CGRect(
                x: screenFrame.maxX - dockWidth,
                y: screenFrame.midY - barHeight / 2,
                width: dockWidth,
                height: barHeight
            )
        }

        dockPanel.setFrame(panelRect, display: true)
        dockPanel.orderFrontRegardless()
    }

    func showOnExternalScreen() {
        repositionWindow()
    }

    func hide() {
        dockPanel.orderOut(nil)
    }

    func cleanup() {
        hide()
        NotificationCenter.default.removeObserver(self)
    }

    func setEdge(_ edge: DockEdge) {
        currentEdge = edge
        UserDefaults.standard.set(edge.rawValue, forKey: "dockEdge")
        dockViewController.updateLayout(for: edge)
        repositionWindow()
    }

    // MARK: - Screen change handler
    @objc private func screenParametersDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.repositionWindow()
        }
    }
}
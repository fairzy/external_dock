import Cocoa
import AppKit

// MARK: - App Icon Button with Directional Animation
class AppIconButton: NSView {
    private let imageView = NSImageView()
    private let indicatorView = NSView()  // Running indicator dot
    
    var appPath: String = ""
    var onClick: (() -> Void)?
    var onRemove: (() -> Void)?
    
    // Animation direction based on dock edge
    enum ExpandDirection {
        case up, down, left, right
    }
    var expandDirection: ExpandDirection = .up {  // Default for bottom edge
        didSet {
            // Update indicator position when direction changes
            indicatorView.frame = indicatorFrame
        }
    }
    
    private var normalFrame: NSRect {
        NSRect(x: 7, y: 7, width: 42, height: 42)
    }
    
    private var expandedFrame: NSRect {
        let size: CGFloat = 50  // Expanded size
        switch expandDirection {
        case .up:      return NSRect(x: 3, y: 12, width: size, height: size)  // Bottom edge → expand up
        case .down:    return NSRect(x: 3, y: 2, width: size, height: size)   // Top edge → expand down
        case .left:    return NSRect(x: 12, y: 3, width: size, height: size)  // Left edge → expand right
        case .right:   return NSRect(x: 2, y: 3, width: size, height: size)   // Right edge → expand left
        }
    }
    
    // Indicator position based on dock edge (close to screen edge)
    private var indicatorFrame: NSRect {
        let dotSize: CGFloat = 4
        switch expandDirection {
        case .up:      return NSRect(x: 26, y: 2, width: dotSize, height: dotSize)  // Bottom → dot at BOTTOM center
        case .down:    return NSRect(x: 26, y: 50, width: dotSize, height: dotSize)  // Top → dot at TOP center
        case .left:    return NSRect(x: 2, y: 26, width: dotSize, height: dotSize)   // Left → dot at LEFT middle
        case .right:   return NSRect(x: 50, y: 26, width: dotSize, height: dotSize)  // Right → dot at RIGHT middle
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        // Icon - start at normal position
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = normalFrame
        addSubview(imageView)
        
        // Running indicator dot
        indicatorView.wantsLayer = true
        indicatorView.layer?.cornerRadius = 2  // 4px diameter → 2px radius (perfect circle)
        indicatorView.layer?.backgroundColor = NSColor.black.cgColor
        indicatorView.alphaValue = 0  // Hidden by default
        addSubview(indicatorView)
        
        // Fixed size for button
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),
            heightAnchor.constraint(equalToConstant: 56)
        ])
        
        // Hover tracking
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }
    
    func configure(with path: String) {
        appPath = path
        imageView.image = AppIconManager.shared.icon(for: path)
        
        updateRunningState()
    }
    
    /// Update running indicator based on current app state
    func updateRunningState() {
        let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == appName || $0.bundleURL?.lastPathComponent == "\(appName).app"
        }
        indicatorView.alphaValue = isRunning ? 1 : 0
        indicatorView.frame = indicatorFrame
    }
    
    /// Called by timer to refresh indicator without reconfiguring everything
    func updateIndicator(isRunning: Bool) {
        indicatorView.alphaValue = isRunning ? 1 : 0
    }
    
    // MARK: - Mouse
    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alphaValue = 1.0
            self?.onClick?()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "移除此应用", action: #selector(removeTapped), keyEquivalent: "")
        remove.target = self
        menu.addItem(remove)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func removeTapped() {
        onRemove?()
    }
    
    // MARK: - Directional Hover Animation
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = expandedFrame
        })
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().frame = normalFrame
        })
    }
}

// MARK: - Simple Visual Effect View
class EffectView: NSVisualEffectView {
    override var wantsUpdateLayer: Bool { true }
}

// MARK: - Dock View Controller
class DockViewController: NSViewController {
    private let stackView = NSStackView()
    private let backgroundView = EffectView()
    
    var onAppListChanged: (() -> Void)?
    private var currentEdge: DockEdge = .bottom
    
    override func loadView() {
        self.view = NSView(frame: .zero)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupStack()
        reloadIcons()
        
        // Periodically refresh running indicator dots (every 2 seconds)
        Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(refreshIndicators), userInfo: nil, repeats: true)
    }
    
    @objc private func refreshIndicators() {
        for case let btn as AppIconButton in stackView.arrangedSubviews {
            let path = btn.appPath
            guard !path.isEmpty else { continue }
            let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.localizedName == name || $0.bundleURL?.lastPathComponent == "\(name).app"
            }
            btn.updateIndicator(isRunning: isRunning)
        }
    }
    
    private func setupBackground() {
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupStack() {
        stackView.orientation = .horizontal
        stackView.spacing = 2
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor)
        ])
    }
    
    private func expandDirection(for edge: DockEdge) -> AppIconButton.ExpandDirection {
        switch edge {
        case .bottom: return .up    // Bottom edge → icons expand up
        case .top: return .down     // Top edge → icons expand down
        case .left: return .left    // Left edge → icons expand to the right
        case .right: return .right  // Right edge → icons expand to the left
        }
    }
    
    func reloadIcons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let paths = AppIconManager.shared.loadAppPaths()
        let direction = expandDirection(for: currentEdge)
        
        for path in paths {
            let btn = AppIconButton(frame: .zero)
            btn.configure(with: path)
            btn.expandDirection = direction
            btn.onClick = {
                AppIconManager.shared.launchApp(at: path)
            }
            btn.onRemove = { [weak self] in
                AppIconManager.shared.removeApp(at: path)
                self?.reloadIcons()
                self?.onAppListChanged?()
            }
            stackView.addArrangedSubview(btn)
        }
        
        if paths.isEmpty {
            let label = NSTextField(labelWithString: "右键设置添加应用")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            stackView.addArrangedSubview(label)
        }
        
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }
    
    func updateLayout(for edge: DockEdge) {
        currentEdge = edge
        stackView.orientation = edge.isHorizontal ? .horizontal : .vertical
        stackView.alignment = edge.isHorizontal ? .centerY : .centerX
        reloadIcons()  // Reload with correct animation direction
    }
    
    func calculateContentSize(for edge: DockEdge) -> CGSize {
        let paths = AppIconManager.shared.loadAppPaths()
        let count = max(paths.count, 1)
        
        let itemW: CGFloat = 56
        let itemH: CGFloat = 56
        let spacing: CGFloat = 2
        let padding: CGFloat = 16
        
        if edge.isHorizontal {
            let w = CGFloat(count) * itemW + CGFloat(count - 1) * spacing + padding
            return CGSize(width: w, height: itemH + 4)
        } else {
            let h = CGFloat(count) * itemH + CGFloat(count - 1) * spacing + padding
            return CGSize(width: itemW + 4, height: h)
        }
    }
}
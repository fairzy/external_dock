import Cocoa
import AppKit

// MARK: - SettingsWindowController
class SettingsWindowController: NSWindowController {

    private weak var dockManager: DockWindowManager?

    // UI Components
    private let screenPopUp = NSPopUpButton()
    private let edgePopUp = NSPopUpButton()
    private let appTableView = NSTableView()
    private let appListScrollView = NSScrollView()
    private let addButton = NSButton(title: "➕ 添加应用", target: nil, action: nil)
    private let removeButton = NSButton(title: "➖ 移除选中", target: nil, action: nil)

    private var appPaths: [String] = []

    // MARK: - Init
    init(dockManager: DockWindowManager) {
        self.dockManager = dockManager
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "External Dock 设置"
        window.level = .floating
        super.init(window: window)
        window.contentViewController = SettingsViewController(settingsController: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override showWindow to reload data
    override func showWindow(_ sender: Any?) {
        appPaths = AppIconManager.shared.loadAppPaths()
        appTableView.reloadData()
        refreshScreenList()
        refreshEdgeSelection()
        super.showWindow(sender)
    }

    // MARK: - UI Setup (called from content vc)
    func setupViews(in view: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Screen Selection
        let screenRow = createLabeledRow(
            label: "目标屏幕:",
            control: screenPopUp,
            action: #selector(screenChanged)
        )
        stack.addArrangedSubview(screenRow)

        // Edge Selection
        let edgeRow = createLabeledRow(
            label: "停靠边缘:",
            control: edgePopUp,
            action: #selector(edgeChanged)
        )
        stack.addArrangedSubview(edgeRow)

        // App List Label
        let appLabel = NSTextField(labelWithString: "快捷应用列表:")
        appLabel.font = NSFont.boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(appLabel)

        // Table + Buttons
        setupAppTable()
        stack.addArrangedSubview(appListScrollView)

        let buttonRow = NSStackView(views: [addButton, removeButton])
        buttonRow.spacing = 8
        buttonRow.alignment = .leading
        stack.addArrangedSubview(buttonRow)

        addButton.target = self
        addButton.action = #selector(addApp)
        removeButton.target = self
        removeButton.action = #selector(removeSelectedApp)

        // Fill initial data
        refreshScreenList()
        refreshEdgeSelection()
    }

    private func createLabeledRow(label: String, control: NSControl, action: Selector) -> NSView {
        let row = NSStackView(views: [
            {
                let l = NSTextField(labelWithString: label)
                l.font = NSFont.systemFont(ofSize: 13)
                l.setContentHuggingPriority(.required, for: .horizontal)
                return l
            }(),
            control
        ])
        row.spacing = 8
        row.alignment = .centerY

        if let button = control as? NSPopUpButton {
            button.target = self
            button.action = action
        }

        return row
    }

    // MARK: - Screen List
    private func refreshScreenList() {
        screenPopUp.removeAllItems()
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let name = index == 0 ? "主屏 (\(Int(frame.width))×\(Int(frame.height)))" :
                                    "外接屏 \(index) (\(Int(frame.width))×\(Int(frame.height)))"
            screenPopUp.addItem(withTitle: name)
        }
        if screens.count > 1 {
            screenPopUp.selectItem(at: 1) // default to first external
        }
    }

    // MARK: - Edge Selection
    private func refreshEdgeSelection() {
        edgePopUp.removeAllItems()
        for edge in DockEdge.allCases {
            edgePopUp.addItem(withTitle: edge.displayName)
            let lastItem = edgePopUp.lastItem!
            lastItem.representedObject = edge.rawValue
        }

        let currentEdge = dockManager?.currentEdge ?? .bottom
        for item in edgePopUp.itemArray {
            if (item.representedObject as? String) == currentEdge.rawValue {
                edgePopUp.select(item)
                break
            }
        }
    }

    // MARK: - App Table
    private func setupAppTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appPath"))
        column.title = "应用路径"
        column.width = 360
        appTableView.addTableColumn(column)
        appTableView.headerView = nil
        appTableView.dataSource = self
        appTableView.delegate = self
        appTableView.rowHeight = 28
        appTableView.target = self
        appTableView.doubleAction = #selector(doubleClickRow)

        appListScrollView.documentView = appTableView
        appListScrollView.hasVerticalScroller = true
        appListScrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
    }

    // MARK: - Actions
    @objc private func screenChanged() {
        // Will be handled in reposition - force reload to pick up new apps
        dockManager?.repositionWindow(forceReload: true)
    }

    @objc private func edgeChanged() {
        guard let selectedItem = edgePopUp.selectedItem,
              let edgeRaw = selectedItem.representedObject as? String,
              let edge = DockEdge(rawValue: edgeRaw) else { return }
        dockManager?.setEdge(edge)
    }

    @objc private func addApp() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.applicationBundle]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.message = "选择一个或多个应用添加到 External Dock"
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")

        openPanel.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self, response == .OK else { return }

            for url in openPanel.urls {
                AppIconManager.shared.addApp(path: url.path)
            }

            self.appPaths = AppIconManager.shared.loadAppPaths()
            self.appTableView.reloadData()
            self.dockManager?.repositionWindow(forceReload: true)
        }
    }

    @objc private func removeSelectedApp() {
        let selectedRow = appTableView.selectedRow
        guard selectedRow >= 0, selectedRow < appPaths.count else { return }

        AppIconManager.shared.removeApp(at: appPaths[selectedRow])
        appPaths = AppIconManager.shared.loadAppPaths()
        appTableView.reloadData()
        dockManager?.repositionWindow(forceReload: true)
    }

    @objc private func doubleClickRow() {
        let row = appTableView.clickedRow
        guard row >= 0, row < appPaths.count else { return }
        NSWorkspace.shared.selectFile(appPaths[row], inFileViewerRootedAtPath: "")
    }
}

// MARK: - NSTableViewDataSource / Delegate
extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return appPaths.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < appPaths.count else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("appCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView(frame: .zero)
            cell?.identifier = identifier

            let iconView = NSImageView(frame: NSRect(x: 4, y: 2, width: 24, height: 24))
            iconView.tag = 1001
            cell?.addSubview(iconView)

            let textField = NSTextField(frame: NSRect(x: 32, y: 4, width: 350, height: 20))
            textField.tag = 1002
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.font = NSFont.systemFont(ofSize: 12)
            cell?.addSubview(textField)
        }

        let path = appPaths[row]
        if let iconView = cell?.viewWithTag(1001) as? NSImageView {
            iconView.image = AppIconManager.shared.icon(for: path)
        }
        if let textField = cell?.viewWithTag(1002) as? NSTextField {
            let name = AppIconManager.shared.appName(for: path)
            textField.stringValue = "\(name)  (\(path))"
        }

        return cell
    }
}

// MARK: - Settings View Controller (Wrapper)
extension SettingsWindowController {
    class SettingsViewController: NSViewController {
        weak var settingsController: SettingsWindowController?

        init(settingsController: SettingsWindowController) {
            self.settingsController = settingsController
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            self.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 440))
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            settingsController?.setupViews(in: view)
        }
    }
}
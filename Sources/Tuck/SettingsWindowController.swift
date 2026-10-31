import AppKit
import ServiceManagement

/// Settings: lists menu bar items under Shown / Hidden and moves them on drag and drop.
/// Built in code (no nib). Created on demand and released on close.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private enum Section: CaseIterable {
        case shown, hidden

        var title: String {
            switch self {
            case .shown: "Shown"
            case .hidden: "Hidden (revealed by the arrow)"
            }
        }
    }

    private enum Row {
        case header(Section)
        case item(MenuBarItem, Section)
        case note(String, Section?)

        var section: Section? {
            switch self {
            case .header(let section), .item(_, let section): section
            case .note(_, let section): section
            }
        }
    }

    private static let dragType = NSPasteboard.PasteboardType("com.jasonxu.tuck.item")
    private static let rehideChoices: [(String, TimeInterval)] = [
        ("5 seconds", 5), ("10 seconds", 10), ("30 seconds", 30), ("1 minute", 60), ("Never", 0),
    ]

    private let menuBar: MenuBarController
    private let onClose: () -> Void

    private let table = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let rehidePopup = NSPopUpButton()
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch Tuck at login", target: nil, action: nil)
    private let accessibilityStatus = NSTextField(labelWithString: "")
    private let accessibilityButton = NSButton(title: "Grant…", target: nil, action: nil)
    private let screenRecordingStatus = NSTextField(labelWithString: "")
    private let screenRecordingButton = NSButton(title: "Grant…", target: nil, action: nil)

    private var items: [MenuBarItem] = []
    private var rows: [Row] = []
    private var images: [String: NSImage] = [:]
    private var isBusy = false
    private var isHolding = false

    init(menuBar: MenuBarController, onClose: @escaping () -> Void) {
        self.menuBar = menuBar
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Tuck Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        if !isHolding {
            isHolding = true
            menuBar.beginHold()
            window?.center()
        }
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        // Activation is cooperative on macOS 26; make sure the window is visible even if it's denied.
        window?.orderFrontRegardless()
        refreshPermissions()
        reload()
    }

    // MARK: NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        // Picks up permissions granted in System Settings while the window was in the background.
        let hadAccess = !items.isEmpty
        refreshPermissions()
        if !hadAccess && Permissions.hasAccessibility { reload() }
    }

    func windowWillClose(_ notification: Notification) {
        if isHolding {
            isHolding = false
            menuBar.endHold()
        }
        onClose()
    }

    // MARK: UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let title = Self.boldLabel("Menu bar items")
        let hint = NSTextField(wrappingLabelWithString: "Listed left to right. Drag an item between Shown and Hidden and Tuck moves the real icon. You can also ⌘-drag icons past the │ divider in the menu bar.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .inset
        table.usesAutomaticRowHeights = false
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([Self.dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.draggingDestinationFeedbackStyle = .gap

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        refreshButton.controlSize = .small
        let statusRow = NSStackView(views: [statusLabel, NSView(), refreshButton])

        for (label, _) in Self.rehideChoices { rehidePopup.addItem(withTitle: label) }
        let currentDelay = Settings.autoRehideDelay
        let selected = Self.rehideChoices.firstIndex { $0.1 == currentDelay } ?? 1
        rehidePopup.selectItem(at: selected)
        rehidePopup.target = self
        rehidePopup.action = #selector(rehideChanged)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginToggled)
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let general = NSGridView(views: [
            [NSTextField(labelWithString: "Hide revealed items after:"), rehidePopup],
            [NSGridCell.emptyContentView, loginCheckbox],
        ])
        general.rowSpacing = 8
        general.column(at: 0).xPlacement = .trailing

        accessibilityButton.target = self
        accessibilityButton.action = #selector(grantAccessibility)
        screenRecordingButton.target = self
        screenRecordingButton.action = #selector(grantScreenRecording)
        let permissions = NSGridView(views: [
            [Self.permissionLabel("Accessibility", detail: "required to list and move items"), accessibilityStatus, accessibilityButton],
            [Self.permissionLabel("Screen Recording", detail: "optional, shows real icons here"), screenRecordingStatus, screenRecordingButton],
        ])
        permissions.rowSpacing = 8
        permissions.column(at: 1).xPlacement = .trailing

        let stack = NSStackView(views: [
            title, hint, scroll, statusRow,
            Self.separator(),
            Self.boldLabel("General"), general,
            Self.separator(),
            Self.boldLabel("Permissions"), permissions,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.setCustomSpacing(4, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            contentView.widthAnchor.constraint(equalToConstant: 460),
        ])
    }

    private static func boldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private static func permissionLabel(_ name: String, detail: String) -> NSTextField {
        let text = NSMutableAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
        text.append(NSAttributedString(string: "\n\(detail)", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return NSTextField(labelWithAttributedString: text)
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func refreshPermissions() {
        let ax = Permissions.hasAccessibility
        accessibilityStatus.stringValue = ax ? "Granted" : "Not granted"
        accessibilityStatus.textColor = ax ? .systemGreen : .systemOrange
        accessibilityButton.isHidden = ax

        let sr = Permissions.hasScreenRecording
        screenRecordingStatus.stringValue = sr ? "Granted" : "Not granted"
        screenRecordingStatus.textColor = sr ? .systemGreen : .secondaryLabelColor
        screenRecordingButton.isHidden = sr
    }

    // MARK: Data

    private func reload() {
        guard Permissions.hasAccessibility else {
            items = []
            images = [:]
            rebuildRows()
            return
        }
        statusLabel.stringValue = "Reading menu bar…"
        Task {
            // Give the menu bar a moment to lay out after expanding.
            try? await Task.sleep(for: .milliseconds(200))
            await rescan()
            statusLabel.stringValue = "\(items.count) items"
        }
    }

    private func rescan() async {
        items = await MenuBarItemScanner.scan().filter { !$0.isFixed }
        rebuildRows()
        let captured = await ItemImageCapture.images(for: items)
        if !captured.isEmpty {
            images = captured
            table.reloadData()
        }
    }

    private func section(of item: MenuBarItem) -> Section {
        guard let divider = menuBar.dividerFrame else { return .shown }
        return item.frame.midX < divider.midX ? .hidden : .shown
    }

    private func items(in section: Section) -> [MenuBarItem] {
        items.filter { self.section(of: $0) == section }
    }

    private func rebuildRows() {
        if !Permissions.hasAccessibility {
            rows = [.note("Grant Accessibility access below to list and move menu bar items.", nil)]
        } else {
            rows = []
            for section in Section.allCases {
                rows.append(.header(section))
                let sectionItems = items(in: section)
                if sectionItems.isEmpty {
                    rows.append(.note(section == .hidden ? "Drop items here to hide them" : "Drop items here to show them", section))
                }
                rows += sectionItems.map { .item($0, section) }
            }
        }
        table.reloadData()
    }

    // MARK: Moving

    /// A drop between `rows[row - 1]` and `rows[row]` targets the section of the row above, at the
    /// number of that section's items that precede the drop point.
    private func destination(forRow row: Int) -> (section: Section, index: Int)? {
        guard row > 0, row <= rows.count, let section = rows[row - 1].section else { return nil }
        let index = rows[..<row].reduce(0) { count, candidate in
            if case .item(_, let s) = candidate, s == section { return count + 1 }
            return count
        }
        return (section, index)
    }

    private func placement(for item: MenuBarItem, in section: Section, at index: Int) -> ItemMover.Placement? {
        var siblings = items(in: section)
        var index = index
        if let current = siblings.firstIndex(where: { $0.id == item.id }) {
            if current < index { index -= 1 }
            siblings.remove(at: current)
        }
        if index < siblings.count { return .leftOf(siblings[index].frame) }
        if let last = siblings.last { return .rightOf(last.frame) }
        switch section {
        case .hidden: return menuBar.dividerFrame.map { .leftOf($0) }
        case .shown: return menuBar.arrowFrame.map { .rightOf($0) }
        }
    }

    private func move(_ item: MenuBarItem, to section: Section, index: Int) {
        let sameSpot = self.section(of: item) == section
            && items(in: section).firstIndex(where: { $0.id == item.id }).map { $0 == index || $0 + 1 == index } == true
        guard !sameSpot else { return }

        isBusy = true
        refreshButton.isEnabled = false
        statusLabel.stringValue = "Moving \(item.title)…"
        Task {
            var current = item
            var landed = false
            for _ in 0..<2 {
                menuBar.expand(autoRehide: false)
                guard let placement = placement(for: current, in: section, at: index) else { break }
                await ItemMover.move(current, to: placement)
                try? await Task.sleep(for: .milliseconds(350))
                await rescan()
                guard let fresh = items.first(where: { $0.id == item.id }) else { break }
                current = fresh
                if self.section(of: fresh) == section {
                    landed = true
                    break
                }
            }
            statusLabel.stringValue = landed
                ? "Moved \(item.title)"
                : "Couldn't move \(item.title). Try ⌘-dragging it in the menu bar."
            isBusy = false
            refreshButton.isEnabled = true
        }
    }

    // MARK: Actions

    @objc private func refreshClicked() { reload() }

    @objc private func rehideChanged() {
        Settings.autoRehideDelay = Self.rehideChoices[rehidePopup.indexOfSelectedItem].1
    }

    @objc private func loginToggled() {
        do {
            if loginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
            NSAlert(error: error).runModal()
        }
    }

    @objc private func grantAccessibility() { Permissions.requestAccessibility() }
    @objc private func grantScreenRecording() { Permissions.requestScreenRecording() }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard !isBusy, case .item(let item, _) = rows[row] else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.id, forType: Self.dragType)
        return pasteboardItem
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard !isBusy, (info.draggingSource as? NSTableView) === table, destination(forRow: row) != nil else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let id = info.draggingPasteboard.string(forType: Self.dragType),
              let item = items.first(where: { $0.id == id }),
              let destination = destination(forRow: row) else { return false }
        move(item, to: destination.section, index: destination.index)
        return true
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .header = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .item = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .item = rows[row] { return 30 }
        return 24
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .header(let section):
            let cell = textCell(in: tableView, identifier: "header")
            cell.textField?.stringValue = section.title
            cell.textField?.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
            return cell
        case .note(let text, _):
            let cell = textCell(in: tableView, identifier: "note")
            cell.textField?.stringValue = text
            cell.textField?.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            cell.textField?.textColor = .tertiaryLabelColor
            return cell
        case .item(let item, _):
            let cell = itemCell(in: tableView)
            cell.textField?.stringValue = item.displayName
            cell.imageView?.image = images[item.id] ?? NSRunningApplication(processIdentifier: item.pid)?.icon
            return cell
        }
    }

    private func textCell(in tableView: NSTableView, identifier: String) -> NSTableCellView {
        let id = NSUserInterfaceItemIdentifier(identifier)
        if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView { return cell }
        let cell = NSTableCellView()
        cell.identifier = id
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private func itemCell(in tableView: NSTableView) -> NSTableCellView {
        let id = NSUserInterfaceItemIdentifier("item")
        if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView { return cell }
        let cell = NSTableCellView()
        cell.identifier = id
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(imageView)
        cell.addSubview(label)
        cell.imageView = imageView
        cell.textField = label
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

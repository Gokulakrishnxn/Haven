import AppKit
import HavenCore

/// Task Center: task list on the left; header, context and live output on the right.
final class OutputWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: TaskStore
    private let table = NSTableView()
    private let textView = NSTextView()
    private let titleLabel = Theme.label(font: Theme.titleFont)
    private let metaLabel = Theme.label(font: Theme.captionFont, color: .secondaryLabelColor)
    private let contextLabel = Theme.label(font: Theme.captionFont, color: .secondaryLabelColor)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let rerunButton = NSButton(title: "Run Again", target: nil, action: nil)
    private var selectedID: UUID?
    private var ticker: Timer?

    init(store: TaskStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 500),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.title = "Tasks"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Layout

    private func buildUI(in window: NSWindow) {
        // Sidebar
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("task")))
        table.headerView = nil
        table.rowHeight = 48
        table.style = .sourceList
        table.dataSource = self
        table.delegate = self
        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false

        let clear = NSButton(title: "Clear Finished", target: self, action: #selector(clearFinished))
        clear.bezelStyle = .inline
        clear.controlSize = .small
        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        let sidebarStack = NSStackView(views: [listScroll, clear])
        sidebarStack.orientation = .vertical
        sidebarStack.edgeInsets = NSEdgeInsets(top: 38, left: 0, bottom: 10, right: 0)
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarStack)
        NSLayoutConstraint.activate([
            sidebarStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sidebarStack.topAnchor.constraint(equalTo: sidebar.topAnchor),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
            listScroll.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor),
            sidebar.widthAnchor.constraint(greaterThanOrEqualToConstant: 230),
        ])

        // Detail
        titleLabel.lineBreakMode = .byTruncatingTail
        cancelButton.target = self; cancelButton.action = #selector(cancelSelected)
        rerunButton.target = self; rerunButton.action = #selector(rerunSelected)
        for b in [cancelButton, rerunButton] { b.bezelStyle = .rounded; b.controlSize = .small }
        contextLabel.maximumNumberOfLines = 3
        contextLabel.lineBreakMode = .byTruncatingTail

        let titleRow = NSStackView(views: [titleLabel, NSView(), cancelButton, rerunButton])
        let header = NSStackView(views: [titleRow, metaLabel, contextLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 6
        header.edgeInsets = NSEdgeInsets(top: 38, left: 20, bottom: 12, right: 20)

        textView.isEditable = false
        textView.font = Theme.monoFont
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        let outputScroll = NSScrollView()
        outputScroll.documentView = textView
        outputScroll.hasVerticalScroller = true
        outputScroll.drawsBackground = false

        let detail = NSStackView(views: [header, NSBox.separator(), outputScroll])
        detail.orientation = .vertical
        detail.spacing = 0
        header.widthAnchor.constraint(equalTo: detail.widthAnchor).isActive = true
        outputScroll.widthAnchor.constraint(equalTo: detail.widthAnchor).isActive = true

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(sidebar)
        split.addArrangedSubview(detail)
        window.contentView = split
    }

    // MARK: Actions

    func show() {
        reload()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.window?.isVisible == true, self.store.runningCount > 0 else { return }
            self.reload()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    private var selectedTask: HavenTask? {
        store.tasks.first { $0.id == selectedID }
    }

    @objc private func cancelSelected() { selectedTask.map(store.cancel) }
    @objc private func rerunSelected() { selectedTask.map(store.rerun) }
    @objc private func clearFinished() { store.clearFinished() }

    /// Re-reads the store; keeps the current selection when it still exists.
    func reload() {
        table.reloadData()
        if let selectedID, let row = store.tasks.firstIndex(where: { $0.id == selectedID }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        } else if !store.tasks.isEmpty {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
        showDetail()
    }

    private func showDetail() {
        let row = table.selectedRow
        guard store.tasks.indices.contains(row) else {
            selectedID = nil
            titleLabel.stringValue = "No tasks yet"
            metaLabel.stringValue = "Press ⌥Space to start one."
            contextLabel.stringValue = ""
            cancelButton.isHidden = true
            rerunButton.isHidden = true
            textView.string = ""
            return
        }
        let task = store.tasks[row]
        selectedID = task.id
        titleLabel.stringValue = task.instruction
        metaLabel.stringValue = "\(task.agent.rawValue) · \(task.status.rawValue) · \(Self.format(task.elapsed))"
        contextLabel.stringValue = Self.contextSummary(task.context)
        cancelButton.isHidden = task.status != .working
        rerunButton.isHidden = task.status == .working

        let text = task.output.isEmpty ? (task.status == .working ? "Working…" : "No output.") : task.output
        if textView.string != text {
            let atBottom = textView.enclosingScrollView.map { $0.contentView.bounds.maxY >= textView.frame.maxY - 20 } ?? true
            textView.string = text
            if atBottom { textView.scrollToEndOfDocument(nil) }
        }
    }

    static func contextSummary(_ c: TaskContext) -> String {
        var parts: [String] = []
        if let app = c.appName { parts.append("From \(app)") }
        if let t = c.selectedText { parts.append("“\(t.prefix(120))”") }
        if c.brief != nil { parts.append("With annotations") }
        return parts.joined(separator: " · ")
    }

    static func format(_ t: TimeInterval) -> String {
        t < 60 ? "\(Int(t))s" : "\(Int(t) / 60)m \(Int(t) % 60)s"
    }

    // MARK: NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { store.tasks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = store.tasks[row]
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = Theme.color(for: task.status).cgColor
        dot.layer?.cornerRadius = 4
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let title = Theme.label(String(task.instruction.prefix(60)), font: .systemFont(ofSize: 13, weight: .medium))
        title.lineBreakMode = .byTruncatingTail
        let sub = Theme.label("\(task.agent.rawValue) · \(Self.format(task.elapsed))", font: Theme.captionFont, color: .secondaryLabelColor)
        let text = NSStackView(views: [title, sub])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let row = NSStackView(views: [dot, text])
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
        return row
    }

    func tableViewSelectionDidChange(_ notification: Notification) { showDetail() }
}

private extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

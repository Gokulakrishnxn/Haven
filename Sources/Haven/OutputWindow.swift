import AppKit

/// Task list on the left, selected task's output on the right.
final class OutputWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: TaskStore
    private let table = NSTableView()
    private let textView = NSTextView()
    private var selectedID: UUID?

    init(store: TaskStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: true)
        window.title = "Haven Tasks"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildUI(in window: NSWindow) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("task"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 40
        table.dataSource = self
        table.delegate = self
        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true
        listScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        let outputScroll = NSScrollView()
        outputScroll.documentView = textView
        outputScroll.hasVerticalScroller = true

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(listScroll)
        split.addArrangedSubview(outputScroll)
        window.contentView = split
    }

    func show() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    /// Re-reads the store; keeps the current selection when it still exists.
    func reload() {
        table.reloadData()
        if let selectedID, let row = store.tasks.firstIndex(where: { $0.id == selectedID }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        } else if !store.tasks.isEmpty {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
        showOutput()
    }

    private func showOutput() {
        let row = table.selectedRow
        guard store.tasks.indices.contains(row) else {
            textView.string = "No tasks yet. Press ⌥Space to start one."
            return
        }
        let task = store.tasks[row]
        selectedID = task.id
        textView.string = task.status == .working && task.output.isEmpty
            ? "Working…" : task.output
    }

    // MARK: NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { store.tasks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = store.tasks[row]
        let title = NSTextField(labelWithString: String(task.instruction.prefix(50)))
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        let sub = NSTextField(labelWithString: "\(task.agent.rawValue) · \(task.status.rawValue)")
        sub.font = .systemFont(ofSize: 11)
        sub.textColor = StatusPill.color(for: task.status)

        let stack = NSStackView(views: [title, sub])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    func tableViewSelectionDidChange(_ notification: Notification) { showOutput() }
}

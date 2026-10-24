import AppKit
import SwiftUI
import HavenUI

/// Task Center window hosting the SwiftUI split view.
final class OutputWindow: NSWindowController {
    private let store: TaskStore
    private let model = TaskCenterModel()

    init(store: TaskStore) {
        self.store = store
        let window = NSWindow(contentViewController: NSHostingController(rootView: TaskCenterView(model: model)))
        window.title = "Tasks"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 820, height: 500))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        model.onCancel = { [weak self] id in self?.task(id).map { self?.store.cancel($0) } }
        model.onRerun = { [weak self] id in self?.task(id).map { self?.store.rerun($0) } }
        model.onClearFinished = { [weak self] in self?.store.clearFinished() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func task(_ id: UUID) -> HavenTask? { store.tasks.first { $0.id == id } }

    func show() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    /// Pushes the current tasks to the view; keeps the selection while that task exists.
    func reload() {
        model.items = store.tasks.map(\.item)
        if model.selection == nil || !model.items.contains(where: { $0.id == model.selection }) {
            model.selection = model.items.first?.id
        }
    }
}

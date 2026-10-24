import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Triple-click selected text anywhere to get a small menu: Chat, Explain, and saved Quick Actions.
final class SelectionPopup {
    private let model = SelectionPopupModel()
    private let panel: NSPanel
    private var clickMonitor: Any?
    private var dismissMonitor: Any?
    private var captured = TaskContext()

    var quickActions: () -> [QuickAction] = { [] }
    var onChat: ((TaskContext) -> Void)?
    var onRun: ((QuickAction?, TaskContext) -> Void)?  // nil action means Explain

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 232, height: 140),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingController(rootView: SelectionPopupView(model: model))
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host

        model.onChat = { [weak self] in self?.finish { $0.onChat?($1) } }
        model.onExplain = { [weak self] in self?.finish { $0.onRun?(nil, $1) } }
        model.onRun = { [weak self] action in self?.finish { $0.onRun?(action, $1) } }
    }

    func start() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard event.clickCount == 3 else { return }
            let location = NSEvent.mouseLocation
            // Let the app finish updating its selection before reading it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.show(near: location) }
        }
    }

    /// Development aid: shows the popup with sample text, without needing a triple-click.
    func debugShow() {
        captured = TaskContext(appName: "Demo", selectedText: "The quick brown fox jumps over the lazy dog")
        model.preview = "The quick brown fox jumps over the…"
        model.actions = Array(quickActions().prefix(5))
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        panel.setContentSize(panel.contentViewController?.view.fittingSize ?? panel.frame.size)
        panel.setFrameTopLeftPoint(NSPoint(x: 300, y: 600))
        panel.orderFrontRegardless()
    }

    private func show(near point: NSPoint) {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        ElementProbe.prepare(pid: app.processIdentifier)
        guard let text = ContextCapture.selectedText(in: app), !text.isEmpty else { return }

        captured = TaskContext(appName: app.localizedName, selectedText: text,
                               tab: ContextCapture.browserTab(of: app))
        model.preview = String(text.prefix(40))
        model.actions = Array(quickActions().prefix(5))

        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = panel.contentViewController?.view.fittingSize ?? panel.frame.size
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(NSPoint(x: point.x - 16, y: point.y - 14))
        panel.orderFrontRegardless()

        dismissMonitor.map(NSEvent.removeMonitor)
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func hide() {
        panel.orderOut(nil)
        dismissMonitor.map(NSEvent.removeMonitor)
        dismissMonitor = nil
    }

    private func finish(_ body: (SelectionPopup, TaskContext) -> Void) {
        let context = captured
        hide()
        body(self, context)
    }
}

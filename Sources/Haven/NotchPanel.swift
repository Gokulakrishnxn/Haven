import AppKit
import SwiftUI
import HavenUI

/// Black bar flush with the top of the screen, wrapped around the notch when there is one.
/// Click it to open actions and the live output of the latest task.
final class NotchPanel: NSPanel {
    private let model = NotchModel()
    private var resizeObserver: NSObjectProtocol?

    override var canBecomeKey: Bool { false }

    init(onAsk: @escaping () -> Void, onAnnotate: @escaping () -> Void, onShowTasks: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 32),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false

        model.onAsk = onAsk
        model.onAnnotate = onAnnotate
        model.onShowTasks = onShowTasks
        applyScreenGeometry()

        let host = NSHostingController(rootView: NotchView(model: model))
        host.sizingOptions = [.preferredContentSize]  // grows when expanded
        contentViewController = host

        // Keep the top edge glued to the top of the screen as the bar resizes.
        resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            self?.anchorToTop()
        }
    }

    deinit { resizeObserver.map(NotificationCenter.default.removeObserver) }

    /// Width of the physical notch, or nil on a screen without one.
    static func notchWidth(of screen: NSScreen?) -> CGFloat? {
        guard let screen, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        return max(100, screen.frame.width - left.width - right.width)
    }

    private func applyScreenGeometry() {
        let width = Self.notchWidth(of: NSScreen.main)
        model.hasNotch = width != nil
        if let width { model.notchWidth = width }
    }

    func update(items: [TaskItem]) {
        guard Preferences.showStatusPill else { orderOut(nil); return }
        model.items = items
        // Development aid: HAVEN_NOTCH_EXPANDED=1 opens the notch at launch.
        if ProcessInfo.processInfo.environment["HAVEN_NOTCH_EXPANDED"] != nil { model.expanded = true }
        applyScreenGeometry()
        anchorToTop()
        orderFrontRegardless()
    }

    private func anchorToTop() {
        guard let screen = NSScreen.main else { return }
        setFrameTopLeftPoint(NSPoint(x: screen.frame.midX - frame.width / 2, y: screen.frame.maxY))
    }
}

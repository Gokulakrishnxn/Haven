import AppKit
import SwiftUI
import HavenUI

/// Always-on-top pill hosting the SwiftUI pill view. Click opens the Task Center.
final class StatusPill: NSPanel {
    private let onClick: () -> Void

    override var canBecomeKey: Bool { false }

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(contentRect: NSRect(x: 0, y: 0, width: 170, height: 32),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
    }

    /// Hidden when there are no tasks or the user turned the pill off.
    func update(tasks: [HavenTask]) {
        guard Preferences.showStatusPill, let pill = PillState.from(tasks.map(\.item)) else {
            orderOut(nil)
            return
        }
        let host = NSHostingView(rootView: StatusPillView(pill: pill, onTap: onClick))
        let size = host.fittingSize
        contentView = host
        setContentSize(size)
        if let screen = NSScreen.main {
            let f = screen.frame
            setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.maxY - size.height - 40))
        }
        orderFrontRegardless()
    }
}

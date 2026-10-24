import AppKit

/// Small always-on-top pill that shows running task count. Click opens the output window.
final class StatusPill: NSPanel {
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")
    private let onClick: () -> Void

    override var canBecomeKey: Bool { false }

    static func color(for status: HavenTask.Status) -> NSColor { Theme.color(for: status) }

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(contentRect: NSRect(x: 0, y: 0, width: 150, height: 30),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        buildUI()
    }

    private func buildUI() {
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 15
        blur.layer?.masksToBounds = true
        contentView = blur

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        label.font = .systemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [dot, label])
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
        ])
        blur.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clicked)))
    }

    @objc private func clicked() { onClick() }

    /// Hidden when there are no tasks; otherwise shows running count or the last result.
    func update(tasks: [HavenTask]) {
        guard let latest = tasks.first, Preferences.showStatusPill else { orderOut(nil); return }
        let running = tasks.filter { $0.status == .working }.count
        if running > 0 {
            label.stringValue = running == 1 ? "1 task working" : "\(running) tasks working"
            dot.layer?.backgroundColor = Self.color(for: .working).cgColor
        } else {
            label.stringValue = latest.status.rawValue
            dot.layer?.backgroundColor = Self.color(for: latest.status).cgColor
        }
        position()
        orderFrontRegardless()
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        setFrameOrigin(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - frame.height - 40))
    }
}

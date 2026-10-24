import AppKit

/// Borderless floating panel with a text field, agent picker and context chip.
/// Plain AppKit so the project builds with just the Command Line Tools.
final class ComposerPanel: NSPanel, NSTextFieldDelegate {
    private let field = NSTextField()
    private let picker = NSPopUpButton()
    private let contextLabel = NSTextField(labelWithString: "")
    private var onSubmit: ((Agent, String) -> Void)?

    override var canBecomeKey: Bool { true }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 120),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        buildUI()
    }

    private func buildUI() {
        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 120))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = Theme.radiusPanel
        blur.layer?.masksToBounds = true
        contentView = blur

        contextLabel.font = Theme.captionFont
        contextLabel.textColor = .secondaryLabelColor
        contextLabel.lineBreakMode = .byTruncatingTail
        contextLabel.maximumNumberOfLines = 2

        field.placeholderString = "What should Haven do?"
        field.font = Theme.inputFont
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self

        picker.addItems(withTitles: Agent.allCases.map(\.rawValue))
        picker.controlSize = .small

        let hint = Theme.label("↩ Run   ⌘↩ Run another   ⎋ Close", font: Theme.captionFont, color: .secondaryLabelColor)

        let bottom = NSStackView(views: [picker, NSView(), hint])
        let stack = NSStackView(views: [contextLabel, field, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: blur.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -12),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottom.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func present(context: TaskContext, onSubmit: @escaping (Agent, String) -> Void) {
        self.onSubmit = onSubmit
        field.stringValue = ""
        picker.selectItem(withTitle: Preferences.defaultAgent.rawValue)

        var lines: [String] = []
        if let app = context.appName { lines.append("From \(app)") }
        if let text = context.selectedText { lines.append("“\(text)”") }
        contextLabel.stringValue = lines.joined(separator: "\n")
        contextLabel.isHidden = lines.isEmpty

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameOrigin(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - f.height * 0.25 - frame.height))
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(field)
    }

    // Return submits, Escape closes.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            let agent = Agent.allCases[picker.indexOfSelectedItem]
            Preferences.defaultAgent = agent
            onSubmit?(agent, text)
            // ⌘↩ keeps the composer open so another task can be started right away.
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                field.stringValue = ""
            } else {
                orderOut(nil)
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            orderOut(nil)
            return true
        default:
            return false
        }
    }
}

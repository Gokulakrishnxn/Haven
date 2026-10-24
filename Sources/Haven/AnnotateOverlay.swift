import AppKit

/// Annotate mode (docs/design.md §13): dim the screen, hover to highlight, click or drag to
/// place numbered pins, add a note per pin, then send everything as one brief.
final class AnnotateController {
    private var windows: [OverlayWindow] = []
    private(set) var pins: [Pin] = []
    private let onSend: (Agent, String, [Pin]) -> Void

    init(onSend: @escaping (Agent, String, [Pin]) -> Void) { self.onSend = onSend }

    var isActive: Bool { !windows.isEmpty }

    func begin() {
        guard !isActive else { return }
        pins = []
        let primary = NSScreen.main ?? NSScreen.screens[0]
        windows = NSScreen.screens.map { screen in
            OverlayWindow(screen: screen, controller: self, hostsBar: screen == primary)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        (windows.first { $0.hostsBar })?.focusInstruction()
    }

    func end() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        pins = []
    }

    func add(_ pin: Pin) {
        pins.append(pin)
        redraw()
    }

    func removeLast() {
        guard !pins.isEmpty else { return }
        pins.removeLast()
        redraw()
    }

    func setNote(_ note: String, forPin n: Int) {
        if let i = pins.firstIndex(where: { $0.n == n }) { pins[i].note = note }
        redraw()
    }

    func send(agent: Agent, instruction: String) {
        guard !pins.isEmpty || !instruction.isEmpty else { return }
        let text = instruction.isEmpty ? "Address the annotated items." : instruction
        let snapshot = pins
        end()
        onSend(agent, text, snapshot)
    }

    private func redraw() { windows.forEach { $0.contentView?.needsDisplay = true } }
}

private final class OverlayWindow: NSWindow {
    let hostsBar: Bool
    private let bar = NSTextField()
    private let picker = NSPopUpButton()

    override var canBecomeKey: Bool { true }

    init(screen: NSScreen, controller: AnnotateController, hostsBar: Bool) {
        self.hostsBar = hostsBar
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        let view = AnnotateView(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, controller: controller)
        contentView = view
        if hostsBar { buildBar(in: view, controller: controller) }
        setFrame(screen.frame, display: true)
    }

    private func buildBar(in view: NSView, controller: AnnotateController) {
        let blur = Theme.vibrancy(radius: 16)
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blur)

        bar.placeholderString = "Tell Haven what to do with these…"
        bar.font = .systemFont(ofSize: 15)
        bar.isBordered = false
        bar.drawsBackground = false
        bar.focusRingType = .none
        bar.delegate = view as? NSTextFieldDelegate
        (view as? AnnotateView)?.instructionField = bar
        (view as? AnnotateView)?.agentPicker = picker

        picker.addItems(withTitles: Agent.allCases.map(\.rawValue))
        picker.selectItem(withTitle: Preferences.defaultAgent.rawValue)
        picker.controlSize = .small
        let hint = Theme.label("Click or drag to pin · ↩ Send · ⌫ Undo · ⎋ Exit", font: Theme.captionFont, color: .secondaryLabelColor)

        let bottom = NSStackView(views: [picker, NSView(), hint])
        let stack = NSStackView(views: [bar, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            blur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -48),
            blur.widthAnchor.constraint(equalToConstant: 620),
            stack.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: blur.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -10),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottom.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func focusInstruction() { makeFirstResponder(bar) }
}

/// Flipped view (top-left origin) so view coordinates map to global screen coordinates by a constant offset.
private final class AnnotateView: NSView, NSTextFieldDelegate {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    let screen: NSScreen
    unowned let controller: AnnotateController
    var instructionField: NSTextField?
    var agentPicker: NSPopUpButton?

    private var hover: CGRect?
    private var dragStart: CGPoint?
    private var dragRect: CGRect?
    private var noteField: NSTextField?
    private var notePin: Int?

    init(frame: CGRect, screen: NSScreen, controller: AnnotateController) {
        self.screen = screen
        self.controller = controller
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Coordinates

    private var offset: CGPoint {
        let primaryHeight = NSScreen.screens[0].frame.height
        return CGPoint(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY)
    }
    private func toGlobal(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + offset.x, y: p.y + offset.y) }
    private func toLocal(_ r: CGRect) -> CGRect { r.offsetBy(dx: -offset.x, dy: -offset.y) }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()

        if let hover, dragStart == nil {
            outline(toLocal(hover), color: .controlAccentColor)
        }
        if let dragRect { outline(dragRect, color: .controlAccentColor) }

        for pin in controller.pins {
            let rect = toLocal(CGRect(x: pin.x, y: pin.y, width: pin.w, height: pin.h))
            guard bounds.intersects(rect) else { continue }
            outline(rect, color: .systemOrange)
            drawBadge(pin.n, at: CGPoint(x: rect.minX, y: rect.minY))
        }
    }

    private func outline(_ rect: CGRect, color: NSColor) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        color.withAlphaComponent(0.12).setFill(); path.fill()
        color.setStroke(); path.lineWidth = 2; path.stroke()
    }

    private func drawBadge(_ n: Int, at p: CGPoint) {
        let r = CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: r).fill()
        let s = NSAttributedString(string: "\(n)", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.white])
        let size = s.size()
        s.draw(at: CGPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2))
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        let global = toGlobal(convert(event.locationInWindow, from: nil))
        hover = ElementProbe.element(at: global)?.frame
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragStart = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let s = dragStart else { return }
        let p = convert(event.locationInWindow, from: nil)
        dragRect = CGRect(x: min(s.x, p.x), y: min(s.y, p.y), width: abs(p.x - s.x), height: abs(p.y - s.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil; dragRect = nil; needsDisplay = true }
        guard let start = dragStart else { return }
        let n = controller.pins.count + 1

        if let rect = dragRect, rect.width > 6, rect.height > 6 {
            let g = CGRect(origin: toGlobal(rect.origin), size: rect.size)
            let info = ElementProbe.element(at: CGPoint(x: g.midX, y: g.midY))
            controller.add(Pin(n: n, kind: .region, x: g.minX, y: g.minY, w: g.width, h: g.height, app: info?.app))
            askNote(for: n, near: rect.origin)
        } else {
            let g = toGlobal(start)
            let info = ElementProbe.element(at: g)
            let f = info?.frame ?? CGRect(x: g.x - 12, y: g.y - 12, width: 24, height: 24)
            controller.add(Pin(n: n, kind: .element, x: f.minX, y: f.minY, w: f.width, h: f.height,
                               app: info?.app, role: info?.role, title: info?.title, value: info?.value))
            askNote(for: n, near: toLocal(f).origin)
        }
    }

    // MARK: Notes

    private func askNote(for n: Int, near p: CGPoint) {
        noteField?.removeFromSuperview()
        let f = NSTextField(frame: CGRect(x: min(max(p.x + 14, 8), bounds.width - 268), y: min(p.y + 14, bounds.height - 40), width: 260, height: 28))
        f.placeholderString = "Note for pin \(n)…"
        f.bezelStyle = .roundedBezel
        f.delegate = self
        addSubview(f)
        noteField = f
        notePin = n
        window?.makeFirstResponder(f)
    }

    private func finishNote(commit: Bool) {
        if commit, let n = notePin, let f = noteField { controller.setNote(f.stringValue, forPin: n) }
        noteField?.removeFromSuperview()
        noteField = nil
        notePin = nil
        window?.makeFirstResponder(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        let isNote = control === noteField
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if isNote { finishNote(commit: true) } else { sendBrief() }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if isNote { finishNote(commit: false) } else { controller.end() }
            return true
        default:
            return false
        }
    }

    private func sendBrief() {
        let text = instructionField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let agent = Agent.allCases[agentPicker?.indexOfSelectedItem ?? 0]
        controller.send(agent: agent, instruction: text)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: controller.end()                                  // esc
        case 51: controller.removeLast()                           // delete
        case 36, 76: sendBrief()                                   // return
        default: super.keyDown(with: event)
        }
    }
}

import AppKit
import HavenCore

/// Three skippable steps (docs/design.md §19): shortcut, agents, permissions.
final class OnboardingWindow: NSWindowController {
    private var step = 0
    private let content = NSStackView()
    private let next = NSButton(title: "Continue", target: nil, action: nil)
    private let skip = NSButton(title: "Skip", target: nil, action: nil)
    private var detected: [Agent: String]?
    var onFinish: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 12
        next.bezelStyle = .rounded
        next.keyEquivalent = "\r"
        next.target = self; next.action = #selector(advance)
        skip.bezelStyle = .inline
        skip.target = self; skip.action = #selector(finish)

        let footer = NSStackView(views: [skip, NSView(), next])
        let root = NSStackView(views: [content, NSView(), footer])
        root.orientation = .vertical
        root.edgeInsets = NSEdgeInsets(top: 48, left: 40, bottom: 28, right: 40)
        root.translatesAutoresizingMaskIntoConstraints = false
        footer.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -80).isActive = true

        let bg = NSVisualEffectView()
        bg.material = .windowBackground
        bg.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: bg.leadingAnchor), root.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            root.topAnchor.constraint(equalTo: bg.topAnchor), root.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
        ])
        window.contentView = bg
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        step = 0
        render()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    @objc private func advance() {
        if step == 1, detected == nil { return }
        if step >= 2 { finish() } else { step += 1; render() }
    }

    @objc private func finish() {
        Preferences.onboarded = true
        window?.orderOut(nil)
        onFinish?()
    }

    @objc private func grantAccessibility() { ContextCapture.requestAccessibility() }

    private func render() {
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        skip.isHidden = step == 2
        next.title = step == 2 ? "Done" : "Continue"

        switch step {
        case 0:
            add("Welcome to Haven", font: .systemFont(ofSize: 28, weight: .bold))
            add("Point at anything. Haven does the rest.", color: .secondaryLabelColor)
            add("Press ⌥Space in any app to ask. Press ⌥⇧Space to point at what you mean. Tasks keep running in the background; a small pill at the top of the screen shows progress.")
        case 1:
            add("Connect your agents", font: .systemFont(ofSize: 24, weight: .bold))
            add("Haven uses the agent CLIs already installed on your Mac.", color: .secondaryLabelColor)
            if let detected {
                for agent in Agent.allCases {
                    let ok = detected[agent] != nil
                    add("\(ok ? "●" : "○")  \(agent.rawValue)  \(ok ? "found" : "not installed")",
                        color: ok ? .labelColor : .secondaryLabelColor)
                }
                if detected.isEmpty { add("Install an agent CLI, then reopen this from the menu.", color: .secondaryLabelColor) }
            } else {
                add("Looking…", color: .secondaryLabelColor)
                AgentDetector.detect { [weak self] result in
                    self?.detected = result
                    if self?.step == 1 { self?.render() }
                }
            }
        default:
            add("Optional permissions", font: .systemFont(ofSize: 24, weight: .bold))
            add("Haven asks only for what a feature needs, when you use it. Accessibility lets it read your selected text and identify elements when you annotate.", color: .secondaryLabelColor)
            let grant = NSButton(title: AXIsProcessTrusted() ? "Accessibility enabled" : "Enable Accessibility…", target: self, action: #selector(grantAccessibility))
            grant.bezelStyle = .rounded
            grant.isEnabled = !AXIsProcessTrusted()
            content.addArrangedSubview(grant)
            add("You can skip this and change it later. Haven still works without it.", font: Theme.captionFont, color: .secondaryLabelColor)
        }
    }

    private func add(_ text: String, font: NSFont = Theme.bodyFont, color: NSColor = .labelColor) {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = font
        l.textColor = color
        l.preferredMaxLayoutWidth = 400
        content.addArrangedSubview(l)
    }
}

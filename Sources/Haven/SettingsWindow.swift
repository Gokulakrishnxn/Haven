import AppKit
import HavenCore

/// Minimal preferences: default agent, status pill, and shortcut reference.
final class SettingsWindow: NSWindowController {
    private let picker = NSPopUpButton()
    private let pillToggle = NSButton(checkboxWithTitle: "Show status pill", target: nil, action: nil)
    var onChange: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "Haven Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        picker.addItems(withTitles: Agent.allCases.map(\.rawValue))
        picker.target = self; picker.action = #selector(changed)
        pillToggle.target = self; pillToggle.action = #selector(changed)

        let grid = NSGridView(views: [
            [Theme.label("Default agent"), picker],
            [Theme.label("Status"), pillToggle],
            [Theme.label("New task"), Theme.label("⌥Space", color: .secondaryLabelColor)],
            [Theme.label("Annotate"), Theme.label("⌥⇧Space", color: .secondaryLabelColor)],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        let bg = NSView()
        bg.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
        ])
        window.contentView = bg
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        picker.selectItem(withTitle: Preferences.defaultAgent.rawValue)
        pillToggle.state = Preferences.showStatusPill ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    @objc private func changed() {
        Preferences.defaultAgent = Agent.allCases[picker.indexOfSelectedItem]
        Preferences.showStatusPill = pillToggle.state == .on
        onChange?()
    }
}

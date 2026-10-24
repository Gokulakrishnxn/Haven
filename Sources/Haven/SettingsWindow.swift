import AppKit
import SwiftUI
import HavenUI

/// Settings window hosting the SwiftUI form.
final class SettingsWindow: NSWindowController {
    private let model = SettingsModel(agent: Preferences.defaultAgent, showPill: Preferences.showStatusPill)
    var onChange: (() -> Void)?

    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Haven Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        model.onChange = { [weak self] in
            guard let self else { return }
            Preferences.defaultAgent = self.model.agent
            Preferences.showStatusPill = self.model.showPill
            self.onChange?()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }
}

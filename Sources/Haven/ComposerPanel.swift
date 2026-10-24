import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Borderless floating panel hosting the SwiftUI composer.
final class ComposerPanel: NSPanel {
    private let model = ComposerModel()
    private var onSubmit: ((Agent, String) -> Void)?

    override var canBecomeKey: Bool { true }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 120),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false

        let host = NSHostingController(rootView: ComposerView(model: model))
        host.sizingOptions = [.preferredContentSize]  // panel grows with the text field
        contentViewController = host

        model.onClose = { [weak self] in self?.orderOut(nil) }
        model.onSubmit = { [weak self] agent, text, keepOpen in
            Preferences.defaultAgent = agent
            self?.onSubmit?(agent, text)
            if !keepOpen { self?.orderOut(nil) }
        }
    }

    func present(context: TaskContext, onSubmit: @escaping (Agent, String) -> Void) {
        self.onSubmit = onSubmit
        model.text = ""
        model.agent = Preferences.defaultAgent
        model.appName = context.appName
        model.selection = context.selectedText

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameTopLeftPoint(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - f.height * 0.22))
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}

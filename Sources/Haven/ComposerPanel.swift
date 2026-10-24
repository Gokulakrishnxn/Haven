import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Borderless floating panel hosting the SwiftUI composer.
final class ComposerPanel: NSPanel {
    private let model = ComposerModel()
    private var onSubmit: ((Agent, String?, String, [URL]) -> Void)?
    /// Called when the user taps the annotate button.
    var onAnnotate: (() -> Void)?

    override var canBecomeKey: Bool { true }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 620, height: 120),
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
        model.onSubmit = { [weak self] submission, keepOpen in
            Preferences.defaultAgent = submission.agent
            Preferences.defaultModel = submission.model
            self?.onSubmit?(submission.agent, submission.model, submission.text, submission.files)
            if !keepOpen { self?.orderOut(nil) }
        }
        model.onAnnotate = { [weak self] in
            self?.orderOut(nil)
            self?.onAnnotate?()
        }
        model.onAttach = { [weak self] in self?.chooseFiles() }
    }

    func present(context: TaskContext, onSubmit: @escaping (Agent, String?, String, [URL]) -> Void) {
        self.onSubmit = onSubmit
        model.text = ""
        model.files = []
        model.agent = Preferences.defaultAgent
        model.model = Preferences.defaultModel
        model.appName = context.appName
        model.selection = context.selectedText

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameTopLeftPoint(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - f.height * 0.22))
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func chooseFiles() {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = true
        open.canChooseDirectories = true
        open.prompt = "Attach"
        // The composer is a floating panel; keep the picker above it.
        open.level = .floating
        if open.runModal() == .OK { model.add(files: open.urls) }
        makeKeyAndOrderFront(nil)
    }
}

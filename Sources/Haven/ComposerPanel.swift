import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Borderless floating panel hosting the SwiftUI composer.
final class ComposerPanel: NSPanel {
    private let model = ComposerModel()
    /// Starts the task and returns its id so the status card can follow it.
    private var onSubmit: ((ComposerSubmission) -> UUID?)?
    private var trackedTask: UUID?
    var onStop: ((UUID) -> Void)?
    var onOpenTasks: (() -> Void)?
    /// Called when the user taps the annotate button.
    var onAnnotate: (() -> Void)?

    override var canBecomeKey: Bool { true }

    private let quickActions: QuickActionStore

    init(quickActions: QuickActionStore) {
        self.quickActions = quickActions
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
            if let id = self?.onSubmit?(submission) { self?.trackedTask = id }
            if !keepOpen { self?.orderOut(nil) }
        }
        model.onAnnotate = { [weak self] in
            self?.orderOut(nil)
            self?.onAnnotate?()
        }
        model.onAttach = { [weak self] in self?.chooseFiles() }
        model.onStop = { [weak self] id in self?.onStop?(id) }
        model.onOpenTasks = { [weak self] in self?.onOpenTasks?() }
        model.onSaveAction = { [weak self] text, agent, modelID in
            guard let self else { return }
            self.quickActions.saveWithPrompt(prompt: text, agent: agent, model: modelID,
                                             suggestedName: QuickActionStore.suggestedName(for: text))
            self.model.quickActions = self.quickActions.actions
            self.makeKeyAndOrderFront(nil)
        }
    }

    func present(context: TaskContext, onSubmit: @escaping (ComposerSubmission) -> UUID?) {
        self.onSubmit = onSubmit
        model.text = ""
        model.files = []
        trackedTask = nil
        model.activeTask = nil
        model.quickActions = quickActions.actions
        model.agent = Preferences.defaultAgent
        model.model = Preferences.defaultModel
        model.appName = context.appName
        model.selection = context.selectedText
        model.tab = context.tab

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameTopLeftPoint(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - f.height * 0.22))
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    /// Development aid: submits through the real composer path.
    func debugSubmit(_ text: String) {
        model.text = text
        model.submit(keepOpen: true)
    }

    /// Keeps the status card in step with the task started from this panel.
    func sync(items: [TaskItem]) {
        guard let id = trackedTask else { return }
        model.activeTask = items.first { $0.id == id }
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

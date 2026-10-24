import AppKit
import Carbon.HIToolbox
import HavenCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = TaskStore()
    private let panel = ComposerPanel()
    private var statusItem: NSStatusItem!
    private var composeKey: HotKey?
    private var annotateKey: HotKey?
    private lazy var outputWindow = OutputWindow(store: store)
    private lazy var pill = StatusPill { [weak self] in self?.outputWindow.show() }
    private lazy var annotate = AnnotateController { [weak self] agent, text, pins in
        self?.startAnnotated(agent: agent, instruction: text, pins: pins)
    }
    private lazy var onboarding: OnboardingWindow = {
        let w = OnboardingWindow()
        return w
    }()
    private lazy var settings: SettingsWindow = {
        let w = SettingsWindow()
        w.onChange = { [weak self] in
            guard let self else { return }
            self.pill.update(tasks: self.store.tasks)
        }
        return w
    }()
    private var annotateAppName: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "house.circle", accessibilityDescription: "Haven")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        store.onChange = { [weak self] in
            guard let self else { return }
            self.pill.update(tasks: self.store.tasks)
            if self.outputWindow.window?.isVisible == true { self.outputWindow.reload() }
        }

        composeKey = HotKey(id: 1, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.showComposer()
        }
        annotateKey = HotKey(id: 2, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey)) { [weak self] in
            self?.toggleAnnotate()
        }

        if !Preferences.onboarded { onboarding.show() }
    }

    // MARK: Actions

    @objc private func showComposer() {
        guard !annotate.isActive else { return }
        let context = ContextCapture.capture()
        panel.present(context: context) { [store] agent, text in
            store.start(agent: agent, instruction: text, context: context)
        }
    }

    @objc private func toggleAnnotate() {
        if annotate.isActive { annotate.end(); return }
        panel.orderOut(nil)
        annotateAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        annotate.begin()
    }

    private func startAnnotated(agent: Agent, instruction: String, pins: [Pin]) {
        var context = TaskContext()
        context.appName = pins.first?.app ?? annotateAppName
        context.brief = BriefBuilder.markdown(pins: pins)
        store.start(agent: agent, instruction: instruction, context: context)
    }

    @objc private func showTasks() { outputWindow.show() }
    @objc private func showWelcome() { onboarding.show() }
    @objc private func showSettings() { settings.show() }
    @objc private func enableContext() { ContextCapture.requestAccessibility() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Menu (rebuilt on open so status is current)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func item(_ title: String, _ action: Selector, key: String = "") {
            menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
        }
        item("New Task…      ⌥Space", #selector(showComposer))
        item("Annotate…      ⌥⇧Space", #selector(toggleAnnotate))
        item("Show Tasks…", #selector(showTasks))

        if !store.tasks.isEmpty {
            menu.addItem(.separator())
            for task in store.tasks.prefix(6) {
                menu.addItem(withTitle: "\(task.status.rawValue)  \(task.instruction.prefix(40))", action: nil, keyEquivalent: "")
            }
        }
        menu.addItem(.separator())
        if !AXIsProcessTrusted() { item("Enable Accessibility…", #selector(enableContext)) }
        item("Welcome…", #selector(showWelcome))
        item("Settings…", #selector(showSettings), key: ",")
        item("Quit Haven", #selector(quit), key: "q")
    }
}

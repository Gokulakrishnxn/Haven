import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = TaskStore()
    private let panel = ComposerPanel()
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private lazy var outputWindow = OutputWindow(store: store)
    private lazy var pill = StatusPill { [weak self] in self?.outputWindow.show() }

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

        // ⌥Space
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.showComposer()
        }
    }

    @objc private func showComposer() {
        let context = ContextCapture.capture()
        panel.present(context: context) { [store] agent, text in
            store.start(agent: agent, instruction: text, context: context)
        }
    }

    @objc private func showTasks() { outputWindow.show() }
    @objc private func enableContext() { ContextCapture.requestAccessibility() }
    @objc private func quit() { NSApp.terminate(nil) }

    // Rebuilt on open so task status is current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "New Task…  (⌥Space)", action: #selector(showComposer), keyEquivalent: "").target = self

        menu.addItem(withTitle: "Show Tasks…", action: #selector(showTasks), keyEquivalent: "").target = self

        if !store.tasks.isEmpty {
            menu.addItem(.separator())
            for task in store.tasks.prefix(8) {
                let title = "\(task.status.rawValue)  \(task.instruction.prefix(40))"
                menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
            }
        }
        menu.addItem(.separator())
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Enable Selected-Text Context…", action: #selector(enableContext), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "Quit Haven", action: #selector(quit), keyEquivalent: "q").target = self
    }
}

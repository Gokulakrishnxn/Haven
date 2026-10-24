import AppKit
import SwiftUI
import Carbon.HIToolbox
import HavenCore
import HavenUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TaskStore()
    private let quickActions = QuickActionStore()
    private lazy var vaultController = VaultController(store: store)
    private lazy var panel = ComposerPanel(quickActions: quickActions)
    private var statusItem: NSStatusItem!
    private var composeKey: HotKey?
    private var annotateKey: HotKey?
    private lazy var outputWindow = OutputWindow(store: store, quickActions: quickActions)
    private lazy var notch = NotchPanel(
        onAsk: { [weak self] in self?.showComposer() },
        onAnnotate: { [weak self] in self?.toggleAnnotate() },
        onShowTasks: { [weak self] in self?.showTasks() })
    private lazy var annotate = AnnotateController { [weak self] agent, model, text, pins in
        self?.startAnnotated(agent: agent, model: model, instruction: text, pins: pins)
    }
    private lazy var onboarding: OnboardingWindow = {
        let w = OnboardingWindow()
        return w
    }()
    private lazy var settings: SettingsWindow = {
        let w = SettingsWindow(store: store, quickActions: quickActions, vault: vaultController)
        w.onChange = { [weak self] in
            guard let self else { return }
            self.notch.update(items: self.store.tasks.map(\.item))
            self.menuModel.name = Preferences.displayName
        }
        return w
    }()
    private let menuModel = MenuPanelModel()
    private let popover = NSPopover()
    private var annotateAppName: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.module.url(forResource: "HavenAppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = HavenBrand.menuBarImage
        statusItem.button?.setAccessibilityLabel("Haven")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        configureMenuPanel()

        store.onChange = { [weak self] in
            guard let self else { return }
            self.notch.update(items: self.store.tasks.map(\.item))
            self.menuModel.items = self.store.tasks.map(\.item)
            if self.outputWindow.window?.isVisible == true { self.outputWindow.reload() }
        }

        composeKey = HotKey(id: 1, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.showComposer()
        }
        annotateKey = HotKey(id: 2, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey)) { [weak self] in
            self?.toggleAnnotate()
        }

        panel.onAnnotate = { [weak self] in self?.toggleAnnotate() }
        store.loginNote = { [weak self] in
            (self?.vaultController.hasLogins ?? false) ? VaultController.agentNote : nil
        }
        store.helperDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path
        vaultController.start()
        notch.update(items: [])
        if !Preferences.onboarded { onboarding.show() }

        // Development aid: HAVEN_SHOW=composer|tasks|onboarding|settings opens that window at launch.
        // HAVEN_RUN="prompt" also starts a task with the default agent.
        if let prompt = ProcessInfo.processInfo.environment["HAVEN_RUN"] {
            store.start(agent: Preferences.defaultAgent, instruction: prompt, context: TaskContext())
        }
        // HAVEN_SNAP=dir writes a PNG of each visible Haven window after two seconds, then quits.
        if let dir = ProcessInfo.processInfo.environment["HAVEN_SNAP"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(ProcessInfo.processInfo.environment["HAVEN_SNAP_DELAY"] ?? "") ?? 2.5)) {
                for (i, w) in NSApp.windows.enumerated() where w.isVisible {
                    guard let view = w.contentView?.superview ?? w.contentView,
                          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: URL(fileURLWithPath: dir).appendingPathComponent("window-\(i).png"))
                }
                NSApp.terminate(nil)
            }
        }
        switch ProcessInfo.processInfo.environment["HAVEN_SHOW"] {
        case "composer": showComposer()
        case "tasks": outputWindow.show()
        case "onboarding": onboarding.show()
        case "settings": settings.show()
        case "panel": statusItemClicked()
        case "annotate": toggleAnnotate()
        default: break
        }
    }

    // MARK: Actions

    @objc private func showComposer() {
        guard !annotate.isActive else { return }
        let context = ContextCapture.capture()
        panel.present(context: context) { [store] submission in
            var ctx = context
            ctx.selectedText = submission.selection
            ctx.tab = submission.tab
            ctx.files = submission.files.map(\.path)
            store.start(agent: submission.agent, model: submission.model, instruction: submission.text, context: ctx)
        }
    }

    @objc private func toggleAnnotate() {
        if annotate.isActive { annotate.end(); return }
        panel.orderOut(nil)
        annotateAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        annotate.begin()
    }

    private func startAnnotated(agent: Agent, model: String?, instruction: String, pins: [Pin]) {
        var context = TaskContext()
        context.appName = pins.first?.app ?? annotateAppName
        context.brief = BriefBuilder.markdown(pins: pins)
        Preferences.defaultAgent = agent
        Preferences.defaultModel = model
        store.start(agent: agent, model: model, instruction: instruction, context: context)
    }

    @objc private func showTasks() { outputWindow.show() }
    @objc private func showWelcome() { onboarding.show() }
    @objc private func showSettings() { settings.show() }
    func applicationWillTerminate(_ notification: Notification) { vaultController.stop() }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Menu-bar panel

    private func configureMenuPanel() {
        menuModel.name = Preferences.displayName
        menuModel.onNewTask = { [weak self] in self?.closePanel(); self?.showComposer() }
        menuModel.onAnnotate = { [weak self] in self?.closePanel(); self?.toggleAnnotate() }
        menuModel.onShowTasks = { [weak self] in self?.closePanel(); self?.showTasks() }
        menuModel.onSelectTask = { [weak self] _ in self?.closePanel(); self?.showTasks() }
        menuModel.onSettings = { [weak self] in self?.closePanel(); self?.showSettings() }
        menuModel.onQuit = { NSApp.terminate(nil) }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuPanelView(model: menuModel))
    }

    private func closePanel() { popover.performClose(nil) }

    /// Left click opens the panel; right click shows a minimal Quit menu.
    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Haven", action: #selector(quit), keyEquivalent: "q").target = self
            statusItem.menu = menu
            button.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            closePanel()
        } else {
            menuModel.items = store.tasks.map(\.item)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

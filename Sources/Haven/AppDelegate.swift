import AppKit
import SwiftUI
import Carbon.HIToolbox
import HavenCore
import HavenUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TaskStore()
    private let quickActions = QuickActionStore()
    private lazy var vaultController = VaultController(store: store)
    private let mcpStore = MCPStore()
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
        let w = SettingsWindow(store: store, quickActions: quickActions, vault: vaultController, mcp: mcpStore)
        w.onChange = { [weak self] in
            guard let self else { return }
            self.notch.update(items: self.store.tasks.map(\.item))
            self.menuModel.name = Preferences.displayName
            self.registerHotKeys()
        }
        return w
    }()
    private let selectionPopup = SelectionPopup()
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
            let items = self.store.tasks.map(\.item)
            // The notch and composer reflect this session only; the Task Center and menu show history too.
            let live = self.store.tasks.filter { !$0.restored }.map(\.item)
            self.notch.update(items: live)
            self.panel.sync(items: live)
            self.menuModel.items = items
            if self.outputWindow.window?.isVisible == true { self.outputWindow.reload() }
        }

        registerHotKeys()

        panel.onAnnotate = { [weak self] in self?.toggleAnnotate() }
        panel.onStop = { [weak self] id in
            if let task = self?.store.tasks.first(where: { $0.id == id }) { self?.store.cancel(task) }
        }
        panel.onOpenTasks = { [weak self] in self?.showTasks() }
        selectionPopup.quickActions = { [weak self] in self?.quickActions.actions ?? [] }
        selectionPopup.onChat = { [weak self] context in self?.showComposer(with: context) }
        selectionPopup.onRun = { [weak self] action, context in
            guard let self else { return }
            let agent = action?.agent ?? Preferences.defaultAgent
            let model = action.map { $0.agent == nil ? Preferences.defaultModel : $0.model } ?? Preferences.defaultModel
            self.store.start(agent: agent, model: agent == Preferences.defaultAgent ? model : nil,
                             instruction: action?.prompt ?? "Explain this clearly and concisely.", context: context)
        }
        selectionPopup.start()
        store.loginNote = { [weak self] in VaultController.agentNote(hasLogins: self?.vaultController.hasLogins ?? false) }
        store.mcpConfigPath = { [weak self] id in self?.mcpStore.configPath(for: id) }
        store.helperDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path
        vaultController.start()
        notch.update(items: [])
        if !Preferences.onboarded { onboarding.show() }

        // Development aid: HAVEN_SHOW=composer|tasks|onboarding|settings opens that window at launch.
        // HAVEN_RUN="prompt" also starts a task with the default agent.
        if let prompt = ProcessInfo.processInfo.environment["HAVEN_RUN"] {
            if ProcessInfo.processInfo.environment["HAVEN_SHOW"] == "composer" {
                showComposer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.panel.debugSubmit(prompt) }
            } else {
                store.start(agent: Preferences.defaultAgent, instruction: prompt, context: TaskContext())
            }
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
        // HAVEN_PROBE="x,y" prints what Annotate would see at that screen point (twice, 1.5 s apart), then quits.
        if let probe = ProcessInfo.processInfo.environment["HAVEN_PROBE"]?.split(separator: ",").compactMap({ Double($0) }), probe.count == 2 {
            let point = CGPoint(x: probe[0], y: probe[1])
            ElementProbe.prepareVisibleApps()
            for delay in [0.2, 1.7] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let e = ElementProbe.element(at: point)
                    print("probe@\(delay)s app=\(e?.app ?? "-") role=\(e?.role ?? "-") title=\(e?.title ?? "-") frame=\(e?.frame.map { "\($0)" } ?? "none")")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { NSApp.terminate(nil) }
        }
        if let script = ProcessInfo.processInfo.environment["HAVEN_BROWSER_SCRIPT"] { vaultController.runBrowserScript(script) }
        switch ProcessInfo.processInfo.environment["HAVEN_SHOW"] {
        case "composer": if ProcessInfo.processInfo.environment["HAVEN_RUN"] == nil { showComposer() }
        case "tasks": outputWindow.show()
        case "onboarding": onboarding.show()
        case "settings": settings.show()
        case "panel": statusItemClicked()
        case "annotate": toggleAnnotate()
        case "selection": selectionPopup.debugShow()
        default: break
        }
    }

    /// (Re)registers the global shortcuts from preferences. Replacing an instance unregisters the old key.
    private func registerHotKeys() {
        let c = Preferences.composeShortcut, a = Preferences.annotateShortcut
        composeKey = nil
        annotateKey = nil
        composeKey = HotKey(id: 1, keyCode: c.keyCode, modifiers: c.modifiers) { [weak self] in self?.showComposer() }
        if a != c {
            annotateKey = HotKey(id: 2, keyCode: a.keyCode, modifiers: a.modifiers) { [weak self] in self?.toggleAnnotate() }
        }
    }

    // MARK: Actions

    @objc private func showComposer() { showComposer(with: nil) }

    private func showComposer(with preset: TaskContext?) {
        guard !annotate.isActive else { return }
        let context = preset ?? ContextCapture.capture()
        panel.present(context: context) { [store] submission in
            var ctx = context
            ctx.selectedText = submission.selection
            ctx.tab = submission.tab
            ctx.files = submission.files.map(\.path)
            return store.start(agent: submission.agent, model: submission.model, instruction: submission.text, context: ctx).id
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
    func applicationWillTerminate(_ notification: Notification) {
        store.persist()
        vaultController.stop()
    }

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

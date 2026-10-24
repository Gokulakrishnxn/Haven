import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Settings window hosting the SwiftUI preferences (profile, general, agents, shortcuts, privacy, about).
final class SettingsWindow: NSWindowController {
    private let store: TaskStore
    private let model = SettingsModel(displayName: Preferences.displayName, email: Preferences.email,
                                      agent: Preferences.defaultAgent, showPill: Preferences.showStatusPill,
                                      workingFolder: Preferences.workingFolder)
    private var poll: Timer?
    private var loading = false
    var onChange: (() -> Void)?

    init(store: TaskStore) {
        self.store = store
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Haven Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        // Development aid: HAVEN_SECTION=general|agents|... opens that pane first.
        if let name = ProcessInfo.processInfo.environment["HAVEN_SECTION"],
           let section = SettingsSection.allCases.first(where: { $0.rawValue.lowercased() == name }) {
            model.section = section
        }
        model.version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
        model.onChange = { [weak self] in self?.persist() }
        model.onChooseFolder = { [weak self] in self?.chooseFolder() }
        model.onRecheckAgents = { [weak self] in self?.detectAgents() }
        model.onOpenAccessibility = { ContextCapture.requestAccessibility() }
        model.onOpenScreenRecording = {
            CGRequestScreenCaptureAccess()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        model.onClearHistory = { [weak self] in self?.store.clearFinished() }
        model.onOpenRepo = {
            if let url = URL(string: "https://github.com/Gokulakrishnxn/Haven") { NSWorkspace.shared.open(url) }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        refresh()
        detectAgents()
        // Permissions are granted in System Settings; reflect them without reopening.
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    private func refresh() {
        model.accessibilityGranted = AXIsProcessTrusted()
        model.screenRecordingGranted = CGPreflightScreenCaptureAccess()
        model.taskCount = store.startedCount
    }

    private func detectAgents() {
        model.agentStatus = nil
        AgentDetector.detect { [weak self] found in
            self?.model.agentStatus = Dictionary(uniqueKeysWithValues: Agent.allCases.map { ($0, AgentStatus(path: found[$0])) })
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { model.workingFolder = url.path }
    }

    private func persist() {
        Preferences.displayName = model.displayName
        Preferences.email = model.email
        Preferences.defaultAgent = model.agent
        Preferences.showStatusPill = model.showPill
        Preferences.workingFolder = model.workingFolder
        onChange?()
    }
}

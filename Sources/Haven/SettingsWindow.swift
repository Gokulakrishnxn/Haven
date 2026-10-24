import AppKit
import SwiftUI
import HavenCore
import HavenUI
import HavenSecurity

/// Settings window hosting the SwiftUI preferences (profile, general, agents, shortcuts, privacy, about).
final class SettingsWindow: NSWindowController {
    private let store: TaskStore
    private let quickActions: QuickActionStore
    private let vault: VaultController
    private let mcp: MCPStore
    private let model = SettingsModel(displayName: Preferences.displayName, email: Preferences.email,
                                      agent: Preferences.defaultAgent, showPill: Preferences.showStatusPill,
                                      workingFolder: Preferences.workingFolder,
                                      composeShortcut: Preferences.composeShortcut, annotateShortcut: Preferences.annotateShortcut)
    private var poll: Timer?
    private var loading = false
    var onChange: (() -> Void)?

    init(store: TaskStore, quickActions: QuickActionStore, vault: VaultController, mcp: MCPStore) {
        self.mcp = mcp
        self.store = store
        self.quickActions = quickActions
        self.vault = vault
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
        model.quickActions = quickActions.actions
        model.onUpdateAction = { [weak self] action in self?.quickActions.update(action) }
        model.onDeleteAction = { [weak self] id in
            self?.quickActions.delete(id)
            self?.model.quickActions = self?.quickActions.actions ?? []
        }
        model.onAddAction = { [weak self] in
            self?.quickActions.add(QuickAction(name: "New action", prompt: ""))
            self?.model.quickActions = self?.quickActions.actions ?? []
        }
        model.onAddCredential = { [weak self] label, site, username, password in
            do { try self?.vault.vault.add(label: label, site: site, username: username, password: password) }
            catch { NSLog("Could not save login: \(error)") }
            self?.reloadVault()
        }
        model.onDeleteCredential = { [weak self] id in
            self?.vault.vault.remove(id)
            self?.reloadVault()
        }
        model.mcpServers = mcp.servers
        model.onAddMCP = { [weak self] name, kind, commandLine, url in
            guard let self else { return }
            let server: MCPServerConfig
            if kind == .command {
                let parsed = MCPServerConfig.parse(commandLine: commandLine)
                server = MCPServerConfig(name: name, kind: .command, command: parsed.command, args: parsed.args)
            } else {
                server = MCPServerConfig(name: name, kind: .url, url: url)
            }
            self.mcp.add(server)
            self.model.mcpServers = self.mcp.servers
        }
        model.onSetMCPEnabled = { [weak self] id, enabled in
            self?.mcp.setEnabled(id, enabled)
            self?.model.mcpServers = self?.mcp.servers ?? []
        }
        model.onDeleteMCP = { [weak self] id in
            self?.mcp.delete(id)
            self?.model.mcpServers = self?.mcp.servers ?? []
        }
        model.onRefreshAudit = { [weak self] in self?.reloadVault() }
        model.onClearHistory = { [weak self] in self?.store.clearFinished() }
        model.onOpenRepo = {
            if let url = URL(string: "https://github.com/Gokulakrishnxn/Haven") { NSWorkspace.shared.open(url) }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func reloadVault() {
        model.credentials = vault.vault.all().map { CredentialRow(id: $0.id, label: $0.label, site: $0.site, username: $0.username) }
        model.auditRows = vault.audit.entries().reversed().map {
            AuditRow(id: $0.id, time: $0.time, credential: $0.credential, site: $0.site, task: $0.task,
                     outcome: $0.outcome.rawValue, detail: $0.detail)
        }
        model.auditIntact = vault.audit.firstBrokenIndex() == nil
    }

    func show() {
        reloadVault()
        refresh()
        detectAgents()
        // Permissions are granted in System Settings; reflect them without reopening.
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }

    private func refresh() {
        if model.quickActions != quickActions.actions { model.quickActions = quickActions.actions }
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
        Preferences.composeShortcut = model.composeShortcut
        Preferences.annotateShortcut = model.annotateShortcut
        onChange?()
    }
}

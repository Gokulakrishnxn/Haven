import SwiftUI
import HavenCore

public enum SettingsSection: String, CaseIterable, Identifiable {
    case profile = "Profile", general = "General", agents = "Agents", quickActions = "Quick Actions"
    case logins = "Logins", audit = "Audit Log", tools = "Tools", browser = "Browser"
    case shortcuts = "Shortcuts", privacy = "Privacy", about = "About"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .general: return "gearshape"
        case .agents: return "sparkles"
        case .quickActions: return "bolt"
        case .logins: return "key"
        case .tools: return "puzzlepiece.extension"
        case .browser: return "globe"
        case .audit: return "list.bullet.rectangle"
        case .shortcuts: return "command"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
}

/// A saved login as the UI sees it. The password is never part of this.
public struct CredentialRow: Identifiable, Equatable {
    public let id: UUID
    public var label: String
    public var site: String
    public var username: String
    public init(id: UUID, label: String, site: String, username: String) {
        self.id = id; self.label = label; self.site = site; self.username = username
    }
}

public struct AuditRow: Identifiable, Equatable {
    public let id: String
    public var time: Date
    public var credential: String
    public var site: String
    public var task: String
    public var outcome: String
    public var detail: String
    public init(id: String, time: Date, credential: String, site: String, task: String, outcome: String, detail: String) {
        self.id = id; self.time = time; self.credential = credential; self.site = site
        self.task = task; self.outcome = outcome; self.detail = detail
    }
}

public struct AgentStatus: Equatable {
    public var path: String?
    public init(path: String?) { self.path = path }
    public var installed: Bool { path != nil }
}

public final class SettingsModel: ObservableObject {
    @Published public var section: SettingsSection = .profile
    @Published public var displayName: String { didSet { onChange() } }
    @Published public var email: String { didSet { onChange() } }
    @Published public var agent: Agent { didSet { onChange() } }
    @Published public var showPill: Bool { didSet { onChange() } }
    @Published public var workingFolder: String { didSet { onChange() } }
    @Published public var composeShortcut: Shortcut { didSet { onChange() } }
    @Published public var annotateShortcut: Shortcut { didSet { onChange() } }
    /// nil while detection is running.
    @Published public var agentStatus: [Agent: AgentStatus]?
    @Published public var accessibilityGranted = false
    @Published public var screenRecordingGranted = false
    @Published public var taskCount = 0
    @Published public var quickActions: [QuickAction] = []
    @Published public var mcpServers: [MCPServerConfig] = []
    @Published public var browserToken = ""
    @Published public var browserConnected = false
    @Published public var credentials: [CredentialRow] = []
    @Published public var auditRows: [AuditRow] = []
    /// False if the audit log's hash chain no longer verifies.
    @Published public var auditIntact = true
    @Published public var version = "0.1.0"
    @Published public var autoUpdateCheck: Bool { didSet { onChange() } }
    /// One line about the last update check, or empty.
    @Published public var updateStatus = ""
    @Published public var updateAvailable = false
    @Published public var checkingForUpdate = false

    public var onChange: () -> Void = {}
    public var onChooseFolder: () -> Void = {}
    public var onRecheckAgents: () -> Void = {}
    public var onOpenAccessibility: () -> Void = {}
    public var onOpenScreenRecording: () -> Void = {}
    public var onClearHistory: () -> Void = {}
    public var onOpenRepo: () -> Void = {}
    public var onCheckForUpdates: () -> Void = {}
    public var onOpenUpdate: () -> Void = {}
    public var onUpdateAction: (QuickAction) -> Void = { _ in }
    public var onDeleteAction: (UUID) -> Void = { _ in }
    public var onAddAction: () -> Void = {}
    public var onAddCredential: (_ label: String, _ site: String, _ username: String, _ password: String) -> Void = { _, _, _, _ in }
    public var onDeleteCredential: (UUID) -> Void = { _ in }
    public var onRefreshAudit: () -> Void = {}
    public var onCopyBrowserToken: () -> Void = {}
    public var onRegenerateBrowserToken: () -> Void = {}
    public var onShowExtensionFolder: () -> Void = {}
    public var onOpenChromeExtensions: () -> Void = {}
    public var onAddMCP: (_ name: String, _ kind: MCPServerConfig.Kind, _ commandLine: String, _ url: String) -> Void = { _, _, _, _ in }
    public var onSetMCPEnabled: (UUID, Bool) -> Void = { _, _ in }
    public var onDeleteMCP: (UUID) -> Void = { _ in }

    public init(displayName: String, email: String, agent: Agent, showPill: Bool, workingFolder: String,
                composeShortcut: Shortcut = .composeDefault, annotateShortcut: Shortcut = .annotateDefault,
                autoUpdateCheck: Bool = true) {
        self.autoUpdateCheck = autoUpdateCheck
        self.composeShortcut = composeShortcut
        self.annotateShortcut = annotateShortcut
        self.displayName = displayName
        self.email = email
        self.agent = agent
        self.showPill = showPill
        self.workingFolder = workingFolder
    }
}

public struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    public init(model: SettingsModel) { self.model = model }

    public var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: Binding(get: { model.section }, set: { model.section = $0 ?? .profile })) { s in
                Label(s.rawValue, systemImage: s.icon).tag(s)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.04))
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 200)
        } detail: {
            Group {
                switch model.section {
                case .profile: ProfilePane(model: model)
                case .general: GeneralPane(model: model)
                case .agents: AgentsPane(model: model)
                case .quickActions: QuickActionsPane(model: model)
                case .tools: ToolsPane(model: model)
                case .browser: BrowserPane(model: model)
                case .logins: LoginsPane(model: model)
                case .audit: AuditPane(model: model)
                case .shortcuts: ShortcutsPane(model: model)
                case .privacy: PrivacyPane(model: model)
                case .about: AboutPane(model: model)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(HavenTheme.canvas)
            .navigationTitle(model.section.rawValue)
        }
        .frame(width: 700, height: 560)
        .background(HavenTheme.canvas)
        .preferredColorScheme(.dark)
    }
}

// MARK: Panes

struct ProfilePane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    AvatarView(name: model.displayName, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName.isEmpty ? "Your name" : model.displayName).font(.title3.weight(.semibold))
                        Text(model.email.isEmpty ? "No email set" : model.email).foregroundStyle(.secondary)
                        Text("Local profile · bring your own agent").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("Details") {
                TextField("Name", text: $model.displayName)
                TextField("Email", text: $model.email)
            }
            Section("This session") {
                LabeledContent("Tasks started", value: "\(model.taskCount)")
            }
            Section {
                Text("Your profile is stored only on this Mac. Haven has no account system and sends nothing to a server.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct GeneralPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Tasks") {
                Picker("Default agent", selection: $model.agent) {
                    ForEach(Agent.allCases) { a in Label { Text(a.displayName) } icon: { Image(nsImage: AgentIconImage.image(for: a)) }.tag(a) }
                }
                LabeledContent("Working folder") {
                    HStack {
                        Text(model.workingFolder.isEmpty ? "Home folder" : abbreviated(model.workingFolder))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("Choose…", action: model.onChooseFolder)
                        if !model.workingFolder.isEmpty { Button("Reset") { model.workingFolder = "" } }
                    }
                }
            }
            Section("Status") {
                Toggle("Show notch bar", isOn: $model.showPill)
            }
        }
    }

    private func abbreviated(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }
}

struct AgentsPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Installed agents") {
                if let status = model.agentStatus {
                    ForEach(Agent.allCases) { agent in
                        let s = status[agent] ?? AgentStatus(path: nil)
                        HStack(spacing: 10) {
                            AgentIcon(agent, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(agent.displayName)
                                Text(s.path ?? "Not installed").font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            if agent == model.agent { Text("Default").font(.caption).foregroundStyle(.secondary) }
                            Image(systemName: s.installed ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(s.installed ? .green : .secondary)
                        }
                    }
                } else {
                    HStack { ProgressView().controlSize(.small); Text("Looking for agents…") }
                }
            }
            Section("Models") {
                LabeledContent("Your agents") { Label("Free, uses your own subscriptions", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout) }
                LabeledContent("Haven-hosted credits") { Text("Not available yet").foregroundStyle(.secondary) }
            }
            Section {
                Button("Check Again", action: model.onRecheckAgents)
                Text("Haven runs the agent command-line tools already on your Mac, using your own subscriptions.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct ShortcutsPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Global") {
                LabeledContent("New task") { ShortcutRecorder(shortcut: $model.composeShortcut).frame(width: 130, height: 24) }
                LabeledContent("Annotate") { ShortcutRecorder(shortcut: $model.annotateShortcut).frame(width: 130, height: 24) }
                if model.composeShortcut == model.annotateShortcut {
                    Label("Both actions use the same shortcut. Pick different ones.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                Button("Reset to Defaults") {
                    model.composeShortcut = .composeDefault
                    model.annotateShortcut = .annotateDefault
                }
            }
            Section("Composer") {
                LabeledContent("Send") { KeyHint("↩", "") }
                LabeledContent("Stop the running task") { KeyHint("⌘.", "") }
                LabeledContent("Detach to the notch") { KeyHint("esc", "") }
            }
            Section("Task Center") {
                LabeledContent("Cancel task") { KeyHint("⌘.", "") }
                LabeledContent("Run again") { KeyHint("⌘R", "") }
            }
            Section { Text("Click a shortcut, then press the keys you want. It needs at least one modifier key.").font(.callout).foregroundStyle(.secondary) }
        }
    }
}

struct PrivacyPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Permissions") {
                PermissionRow(title: "Accessibility",
                              detail: "Read selected text and identify elements when you point.",
                              granted: model.accessibilityGranted, action: model.onOpenAccessibility)
                PermissionRow(title: "Screen Recording",
                              detail: "Capture a picture of a pinned region. Not used yet.",
                              granted: model.screenRecordingGranted, action: model.onOpenScreenRecording)
            }
            Section("Data") {
                Button("Clear Finished Tasks", action: model.onClearHistory)
                Text("Haven runs locally and has no server. What reaches a model is what the agent you chose sends. Credentials are never handled by Haven.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
            } else {
                Button("Enable…", action: action)
            }
        }
    }
}

struct AboutPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HavenLogo().frame(width: 56, height: 56)
                    Text("Haven").font(.title2.weight(.bold))
                    Text("Version \(model.version)").foregroundStyle(.secondary)
                    Text("Point at anything. Haven does the rest.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section("Updates") {
                HStack {
                    if model.checkingForUpdate { ProgressView().controlSize(.small) }
                    Text(model.updateStatus.isEmpty ? "Haven has not checked yet." : model.updateStatus)
                        .font(.callout).foregroundStyle(model.updateAvailable ? Color.green : Color.secondary)
                    Spacer()
                    if model.updateAvailable {
                        Button("Download", action: model.onOpenUpdate)
                    } else {
                        Button("Check Now", action: model.onCheckForUpdates).disabled(model.checkingForUpdate)
                    }
                }
                Toggle("Check for updates automatically", isOn: $model.autoUpdateCheck)
                Text("Once a day Haven asks GitHub for the latest release. Nothing about you or your Mac is sent. Updates are never installed for you; the link opens the release page.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("View on GitHub", action: model.onOpenRepo)
            }
        }
    }
}

struct QuickActionsPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            if model.quickActions.isEmpty {
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "bolt").font(.system(size: 28)).foregroundStyle(.tertiary)
                        Text("No Quick Actions yet").font(.headline)
                        Text("Save a prompt that worked, then rerun it in one step from the composer.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
            }
            ForEach(model.quickActions) { action in
                Section {
                    ActionEditor(action: action,
                                 onChange: model.onUpdateAction,
                                 onDelete: { model.onDeleteAction(action.id) })
                }
            }
            Section {
                Button { model.onAddAction() } label: { Label("New Quick Action", systemImage: "plus") }
            }
        }
    }
}

/// Edits one action. Keeps its own draft and writes through on every change.
final class ActionDraft: ObservableObject {
    @Published var action: QuickAction
    init(_ action: QuickAction) { self.action = action }
}

struct ActionEditor: View {
    @StateObject private var draft: ActionDraft
    let onChange: (QuickAction) -> Void
    let onDelete: () -> Void

    init(action: QuickAction, onChange: @escaping (QuickAction) -> Void, onDelete: @escaping () -> Void) {
        _draft = StateObject(wrappedValue: ActionDraft(action))
        self.onChange = onChange
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(.tint)
                TextField("Name", text: bind(\.name)).textFieldStyle(.plain).font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
            TextField("Prompt", text: bind(\.prompt), axis: .vertical).lineLimit(2...6)
            HStack {
                Picker("Agent", selection: Binding(get: { draft.action.agent }, set: { draft.action.agent = $0; draft.action.model = nil; onChange(draft.action) })) {
                    Text("Default").tag(Agent?.none)
                    ForEach(Agent.allCases) { Text($0.displayName).tag(Agent?.some($0)) }
                }
                if let agent = draft.action.agent, agent.models.count > 1 {
                    Picker("Model", selection: Binding(get: { draft.action.model }, set: { draft.action.model = $0; onChange(draft.action) })) {
                        ForEach(agent.models) { Text($0.name).tag($0.id) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bind(_ keyPath: WritableKeyPath<QuickAction, String>) -> Binding<String> {
        Binding(get: { draft.action[keyPath: keyPath] }, set: { draft.action[keyPath: keyPath] = $0; onChange(draft.action) })
    }
}

// MARK: Logins and audit

final class NewCredentialDraft: ObservableObject {
    @Published var label = ""
    @Published var site = ""
    @Published var username = ""
    @Published var password = ""

    var isValid: Bool { !label.isEmpty && !site.isEmpty && !password.isEmpty }
    func clear() { label = ""; site = ""; username = ""; password = "" }
}

struct LoginsPane: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var draft = NewCredentialDraft()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "touchid").font(.system(size: 26)).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Agents can use logins without seeing them").font(.headline)
                        Text("Passwords are kept in your Keychain. An agent can only ask Haven to fill a login; you approve each use with Touch ID, and the value never reaches the model.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Saved logins") {
                if model.credentials.isEmpty {
                    Text("No saved logins yet.").foregroundStyle(.secondary)
                }
                ForEach(model.credentials) { c in
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.label)
                            Text(c.username.isEmpty ? c.site : "\(c.username) · \(c.site)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { model.onDeleteCredential(c.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove this login and its saved password")
                    }
                }
            }
            Section("Add a login") {
                TextField("Name", text: $draft.label, prompt: Text("GitHub"))
                TextField("Website", text: $draft.site, prompt: Text("github.com"))
                TextField("Username", text: $draft.username)
                SecureField("Password", text: $draft.password)
                Button("Save to Keychain") {
                    model.onAddCredential(draft.label, draft.site, draft.username, draft.password)
                    draft.clear()
                }
                .disabled(!draft.isValid)
                Text("Haven will only fill this login on an https page whose address is exactly this website.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AuditPane: View {
    @ObservedObject var model: SettingsModel

    private static let format: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yy-MM-dd HH:mm"; return f
    }()

    var body: some View {
        Form {
            Section {
                if model.auditIntact {
                    Label("Log verified: no entry has been altered or removed", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                } else {
                    Label("This log was changed outside Haven", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            Section("Credential access") {
                if model.auditRows.isEmpty { Text("No credential has been used yet.").foregroundStyle(.secondary) }
                ForEach(model.auditRows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: icon(row.outcome)).foregroundStyle(color(row.outcome))
                            Text(row.site).font(.system(size: 13, design: .monospaced))
                            Spacer()
                            Text(Self.format.string(from: row.time)).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Text("\(row.credential) · \(row.task)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if !row.detail.isEmpty { Text(row.detail).font(.caption).foregroundStyle(.tertiary) }
                    }
                    .padding(.vertical, 2)
                }
            }
            Section { Button("Refresh", action: model.onRefreshAudit) }
        }
    }

    private func icon(_ outcome: String) -> String {
        switch outcome { case "approved": return "checkmark.circle.fill"; case "denied": return "hand.raised.fill"; default: return "xmark.octagon.fill" }
    }
    private func color(_ outcome: String) -> Color {
        switch outcome { case "approved": return .green; case "denied": return .orange; default: return .red }
    }
}

// MARK: Tools (MCP)

final class NewMCPDraft: ObservableObject {
    @Published var name = ""
    @Published var kind: MCPServerConfig.Kind = .command
    @Published var commandLine = ""
    @Published var url = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (kind == .command ? !commandLine.trimmingCharacters(in: .whitespaces).isEmpty : url.lowercased().hasPrefix("http"))
    }
    func clear() { name = ""; commandLine = ""; url = "" }
}

struct ToolsPane: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var draft = NewMCPDraft()

    var body: some View {
        Form {
            Section("Connected MCP servers") {
                if model.mcpServers.isEmpty { Text("No servers yet.").foregroundStyle(.secondary) }
                ForEach(model.mcpServers) { server in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(get: { server.enabled }, set: { model.onSetMCPEnabled(server.id, $0) })).labelsHidden()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.name)
                            Text(server.kind == .command ? ([server.command] + server.args).joined(separator: " ") : server.url)
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button(role: .destructive) { model.onDeleteMCP(server.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            Section("Add a server") {
                TextField("Name", text: $draft.name, prompt: Text("filesystem"))
                Picker("Type", selection: $draft.kind) {
                    Text("Command").tag(MCPServerConfig.Kind.command)
                    Text("Web address").tag(MCPServerConfig.Kind.url)
                }
                .pickerStyle(.segmented)
                if draft.kind == .command {
                    TextField("Command", text: $draft.commandLine, prompt: Text("npx -y @modelcontextprotocol/server-filesystem ~/Documents"))
                } else {
                    TextField("Address", text: $draft.url, prompt: Text("https://example.com/mcp"))
                }
                Button("Add Server") {
                    model.onAddMCP(draft.name, draft.kind, draft.commandLine, draft.url)
                    draft.clear()
                }
                .disabled(!draft.isValid)
                Text("Enabled servers are given to Claude tasks. Other agents don't use them yet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Browser extension

struct BrowserPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Circle().fill(model.browserConnected ? Color.green : Color.orange).frame(width: 9, height: 9)
                    Text(model.browserConnected ? "Chrome extension connected" : "Chrome extension not connected").font(.headline)
                }
                Text("With the extension, agents can read and act on web pages, only on sites you connect from the extension's popup, and never on password fields.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Set up") {
                step(1, "Show the extension folder", button: "Show Folder", action: model.onShowExtensionFolder)
                step(2, "In Chrome, turn on Developer mode and choose Load unpacked, then pick that folder", button: "Open Extensions", action: model.onOpenChromeExtensions)
                VStack(alignment: .leading, spacing: 6) {
                    Text("3  Open the Haven extension's options and paste this pairing code").font(.callout)
                    HStack {
                        Text(model.browserToken).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            .lineLimit(1).truncationMode(.middle)
                            .padding(8).background(HavenTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                        Button("Copy", action: model.onCopyBrowserToken)
                    }
                }
                step(4, "On a site you want agents to use, click the Haven icon and choose Connect this site", button: nil, action: {})
            }
            Section {
                Button("Make a New Pairing Code", action: model.onRegenerateBrowserToken)
                Text("A new code disconnects the extension until you paste it again. The code never leaves this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func step(_ n: Int, _ text: String, button: String?, action: @escaping () -> Void) -> some View {
        HStack {
            Text("\(n)  \(text)").font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if let button { Button(button, action: action) }
        }
    }
}

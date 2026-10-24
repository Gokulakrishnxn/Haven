import SwiftUI
import HavenCore

public enum SettingsSection: String, CaseIterable, Identifiable {
    case profile = "Profile", general = "General", agents = "Agents", quickActions = "Quick Actions"
    case shortcuts = "Shortcuts", privacy = "Privacy", about = "About"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .general: return "gearshape"
        case .agents: return "sparkles"
        case .quickActions: return "bolt"
        case .shortcuts: return "command"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
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
    /// nil while detection is running.
    @Published public var agentStatus: [Agent: AgentStatus]?
    @Published public var accessibilityGranted = false
    @Published public var screenRecordingGranted = false
    @Published public var taskCount = 0
    @Published public var quickActions: [QuickAction] = []
    @Published public var version = "0.1.0"

    public var onChange: () -> Void = {}
    public var onChooseFolder: () -> Void = {}
    public var onRecheckAgents: () -> Void = {}
    public var onOpenAccessibility: () -> Void = {}
    public var onOpenScreenRecording: () -> Void = {}
    public var onClearHistory: () -> Void = {}
    public var onOpenRepo: () -> Void = {}
    public var onUpdateAction: (QuickAction) -> Void = { _ in }
    public var onDeleteAction: (UUID) -> Void = { _ in }
    public var onAddAction: () -> Void = {}

    public init(displayName: String, email: String, agent: Agent, showPill: Bool, workingFolder: String) {
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
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 200)
        } detail: {
            Group {
                switch model.section {
                case .profile: ProfilePane(model: model)
                case .general: GeneralPane(model: model)
                case .agents: AgentsPane(model: model)
                case .quickActions: QuickActionsPane(model: model)
                case .shortcuts: ShortcutsPane()
                case .privacy: PrivacyPane(model: model)
                case .about: AboutPane(model: model)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(model.section.rawValue)
        }
        .frame(width: 700, height: 480)
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
            Section {
                Button("Check Again", action: model.onRecheckAgents)
                Text("Haven runs the agent command-line tools already on your Mac, using your own subscriptions.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section("Global") {
                LabeledContent("New task") { KeyHint("⌥Space", "") }
                LabeledContent("Annotate") { KeyHint("⌥⇧Space", "") }
            }
            Section("Composer") {
                LabeledContent("Run") { KeyHint("↩", "") }
                LabeledContent("Run another") { KeyHint("⌘↩", "") }
                LabeledContent("Close") { KeyHint("⎋", "") }
            }
            Section("Task Center") {
                LabeledContent("Cancel task") { KeyHint("⌘.", "") }
                LabeledContent("Run again") { KeyHint("⌘R", "") }
            }
            Section { Text("Shortcuts are fixed for now. Custom shortcuts are planned.").font(.callout).foregroundStyle(.secondary) }
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
                    Image(systemName: "house.circle.fill").font(.system(size: 52)).foregroundStyle(.tint)
                    Text("Haven").font(.title2.weight(.bold))
                    Text("Version \(model.version)").foregroundStyle(.secondary)
                    Text("Point at anything. Haven does the rest.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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

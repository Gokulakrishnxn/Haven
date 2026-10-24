import SwiftUI
import HavenCore

/// What the composer hands back when the user runs a task.
public struct ComposerSubmission {
    public var agent: Agent
    public var model: String?
    public var text: String
    public var files: [URL]
    /// What is still attached after the user removed any chips.
    public var selection: String?
    public var tab: BrowserTab?
}

/// State behind the composer. The app creates one and updates it each time the panel opens.
public final class ComposerModel: ObservableObject {
    @Published public var text = ""
    @Published public var agent: Agent = .claudeCode { didSet { if agent != oldValue { model = nil } } }
    @Published public var model: String?
    @Published public var appName: String?
    @Published public var selection: String?
    @Published public var tab: BrowserTab?
    @Published public var files: [URL] = []
    @Published public var isDropTargeted = false
    @Published public var quickActions: [QuickAction] = []
    /// The task most recently started from this panel; drives the status card above the composer.
    @Published public var activeTask: TaskItem?

    public var onSubmit: (ComposerSubmission, Bool) -> Void = { _, _ in }
    public var onClose: () -> Void = {}
    public var onAnnotate: () -> Void = {}
    public var onAttach: () -> Void = {}
    public var onStop: (UUID) -> Void = { _ in }
    public var onOpenTasks: () -> Void = {}
    /// Asks the app to save the current prompt as a Quick Action.
    public var onSaveAction: (String, Agent, String?) -> Void = { _, _, _ in }

    public init() {}

    public func submit(keepOpen: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(ComposerSubmission(agent: agent, model: model, text: trimmed, files: files, selection: selection, tab: tab), keepOpen)
        text = ""
        files = []
    }

    /// Runs a saved action immediately with the current context.
    public func run(_ action: QuickAction) {
        onSubmit(ComposerSubmission(agent: action.agent ?? agent, model: action.model ?? (action.agent == nil ? model : nil),
                                    text: action.prompt, files: files, selection: selection, tab: tab), true)
        files = []
    }

    public func add(files urls: [URL]) {
        for url in urls where !files.contains(url) { files.append(url) }
    }

    /// Reads file URLs out of dropped items.
    public func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            accepted = true
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { self?.add(files: [url]) }
            }
        }
        return accepted
    }
}

/// Flat near-black surface used by both cards.
private struct CardSurface: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(Color(white: 0.075))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(highlighted ? Color.accentColor : Color.white.opacity(0.09), lineWidth: highlighted ? 2 : 1))
    }
}

/// Two stacked cards: what the agent is doing, and where you talk to it.
public struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @FocusState private var focused: Bool

    public init(model: ComposerModel) { self.model = model }

    private var canRun: Bool { !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasContext: Bool { model.appName != nil || model.selection != nil || model.tab != nil || !model.files.isEmpty }
    private var running: Bool { model.activeTask?.state == .working }

    public var body: some View {
        VStack(spacing: 8) {
            if let task = model.activeTask { statusCard(task) }
            composerCard
        }
        .padding(2)
        .frame(width: 430)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.activeTask?.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.activeTask == nil)
        .onAppear { focused = true }
        .onExitCommand { model.onClose() }
    }

    // MARK: Status card

    private func statusCard(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            WorkingMark(working: task.state == .working, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.state.rawValue).font(.system(size: 13, weight: .semibold))
                Text(task.activity)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 0)
            if task.state != .working {
                Button(action: model.onOpenTasks) { Text("View").font(.system(size: 11, weight: .medium)) }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardSurface())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Composer card

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasContext { contextRow }

            TextField(model.activeTask == nil ? "Anything…" : "Follow up, or start something else…",
                      text: $model.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...5)
                .focused($focused)
                .onSubmit { model.submit(keepOpen: true) }

            HStack(spacing: 4) {
                AgentModelMenu(agent: $model.agent, model: $model.model)
                Spacer()
                ToolbarIconButton(icon: "paperclip", help: "Attach files (or drop them here)", action: model.onAttach)
                QuickActionsMenu(model: model)
                ToolbarIconButton(icon: "scope", help: "Annotate: point at things on screen", action: model.onAnnotate)
                ToolbarIconButton(icon: "clock.arrow.circlepath", help: "Tasks", action: model.onOpenTasks)
                actionButton.padding(.leading, 4)
                // Hidden control so ⌘↩ also sends.
                Button("") { model.submit(keepOpen: true) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardSurface(highlighted: model.isDropTargeted))
        .overlay(dropHint)
        .onDrop(of: ["public.file-url"], isTargeted: Binding(get: { model.isDropTargeted }, set: { model.isDropTargeted = $0 })) { providers in
            model.handleDrop(providers)
        }
    }

    /// Red stop while the current task runs and there is nothing new to send; otherwise send.
    @ViewBuilder private var actionButton: some View {
        if running, !canRun, let task = model.activeTask {
            Button { model.onStop(task.id) } label: { Image(systemName: "stop.fill").font(.system(size: 10)) }
                .buttonStyle(RoundActionStyle(fill: Color(red: 0.96, green: 0.36, blue: 0.36)))
                .accessibilityLabel("Stop")
                .keyboardShortcut(".", modifiers: .command)
        } else {
            Button { model.submit(keepOpen: true) } label: { Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(RoundActionStyle(fill: .white, foreground: .black))
                .disabled(!canRun)
                .opacity(canRun ? 1 : 0.35)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Send")
        }
    }

    private var contextRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let app = model.appName { ContextChip(icon: "macwindow", text: app) }
                if let tab = model.tab {
                    ContextChip(icon: "globe", text: tab.title.isEmpty ? tab.url : String(tab.title.prefix(40)),
                                onRemove: { model.tab = nil })
                }
                if let sel = model.selection {
                    ContextChip(icon: "text.quote", text: String(sel.prefix(60)), onRemove: { model.selection = nil })
                }
                ForEach(model.files, id: \.self) { url in
                    ContextChip(icon: "doc.fill", text: url.lastPathComponent,
                                onRemove: { model.files.removeAll { $0 == url } })
                }
            }
        }
    }

    @ViewBuilder private var dropHint: some View {
        if model.isDropTargeted {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .overlay(Label("Drop to attach", systemImage: "paperclip").font(.headline))
                .allowsHitTesting(false)
        }
    }
}

/// Small filled circle button.
struct RoundActionStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// "Claude · Default ▾" as one quiet menu, like a label in a code editor.
struct AgentModelMenu: View {
    @Binding var agent: Agent
    @Binding var model: String?

    private var modelName: String { agent.models.first { $0.id == model }?.name ?? "Default" }

    var body: some View {
        Menu {
            ForEach(Agent.allCases) { a in
                Menu(a.displayName) {
                    ForEach(a.models) { m in
                        Button {
                            agent = a
                            model = m.id
                        } label: {
                            if a == agent && m.id == model { Label(m.name, systemImage: "checkmark") } else { Text(m.name) }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: AgentIconImage.image(for: agent, size: 13))
                Text(agent.models.count > 1 ? "\(agent.displayName) · \(modelName)" : agent.displayName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Agent and model: \(agent.displayName), \(modelName)")
    }
}

/// Bolt menu: run a saved action in one step, or save the current prompt as one.
struct QuickActionsMenu: View {
    @ObservedObject var model: ComposerModel

    var body: some View {
        Menu {
            if model.quickActions.isEmpty {
                Text("No Quick Actions yet")
            }
            ForEach(model.quickActions) { action in
                Button(action.name) { model.run(action) }
            }
            Divider()
            Button("Save Prompt as Quick Action…") {
                model.onSaveAction(model.text, model.agent, model.model)
            }
            .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } label: {
            Image(systemName: "bolt")
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Quick Actions")
        .accessibilityLabel("Quick Actions")
    }
}

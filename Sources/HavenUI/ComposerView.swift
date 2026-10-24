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

    public var onSubmit: (ComposerSubmission, Bool) -> Void = { _, _ in }
    public var onClose: () -> Void = {}
    public var onAnnotate: () -> Void = {}
    public var onAttach: () -> Void = {}
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
                                    text: action.prompt, files: files, selection: selection, tab: tab), false)
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

public struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @FocusState private var focused: Bool

    public init(model: ComposerModel) { self.model = model }

    private var canRun: Bool { !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasContext: Bool { model.appName != nil || model.selection != nil || model.tab != nil || !model.files.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasContext { contextRow }

            TextField("What should Haven do?", text: $model.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .lineLimit(1...5)
                .focused($focused)
                .onSubmit { model.submit(keepOpen: false) }

            HStack(spacing: 6) {
                AgentMenu(agent: $model.agent)
                ModelMenu(agent: model.agent, model: $model.model)
                ToolbarIconButton(icon: "paperclip", help: "Attach files (or drop them here)", action: model.onAttach)
                ToolbarIconButton(icon: "scope", help: "Annotate: point at things on screen", action: model.onAnnotate)
                QuickActionsMenu(model: model)
                Spacer()
                KeyHint("⌘↩", "Run another")
                KeyHint("esc", "Close").padding(.trailing, 8)
                Button { model.submit(keepOpen: false) } label: { Image(systemName: "arrow.up") }
                    .buttonStyle(RunButtonStyle())
                    .disabled(!canRun)
                    .opacity(canRun ? 1 : 0.4)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Run")
                // Hidden control carrying ⌘↩ so the composer stays open for another task.
                Button("") { model.submit(keepOpen: true) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
            }
        }
        .padding(18)
        .frame(width: 620)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous)
            .strokeBorder(model.isDropTargeted ? Color.accentColor : Color.white.opacity(0.12),
                          lineWidth: model.isDropTargeted ? 2 : 1))
        .overlay(dropHint)
        .onDrop(of: ["public.file-url"], isTargeted: Binding(get: { model.isDropTargeted }, set: { model.isDropTargeted = $0 })) { providers in
            model.handleDrop(providers)
        }
        .onAppear { focused = true }
        .onExitCommand { model.onClose() }
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
            RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(Label("Drop to attach", systemImage: "paperclip").font(.headline))
                .allowsHitTesting(false)
        }
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
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Quick Actions")
        .accessibilityLabel("Quick Actions")
    }
}

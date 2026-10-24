import SwiftUI
import HavenCore

/// State behind the composer. The app creates one and updates it each time the panel opens.
public final class ComposerModel: ObservableObject {
    @Published public var text = ""
    @Published public var agent: Agent = .claudeCode
    @Published public var appName: String?
    @Published public var selection: String?

    /// (agent, text, keepOpen)
    public var onSubmit: (Agent, String, Bool) -> Void = { _, _, _ in }
    public var onClose: () -> Void = {}

    public init() {}

    public func submit(keepOpen: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(agent, trimmed, keepOpen)
        text = ""
    }
}

public struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @FocusState private var focused: Bool

    public init(model: ComposerModel) { self.model = model }

    private var canRun: Bool { !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.appName != nil || model.selection != nil {
                HStack(spacing: 6) {
                    if let app = model.appName { ContextChip(icon: "macwindow", text: app) }
                    if let sel = model.selection {
                        ContextChip(icon: "text.quote", text: String(sel.prefix(60)),
                                    onRemove: { model.selection = nil })
                    }
                }
            }

            TextField("What should Haven do?", text: $model.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .lineLimit(1...5)
                .focused($focused)
                .onSubmit { model.submit(keepOpen: false) }

            HStack(spacing: 14) {
                AgentMenu(agent: $model.agent)
                Spacer()
                KeyHint("⌘↩", "Run another")
                KeyHint("⎋", "Close")
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
        .frame(width: 600)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous)
            .strokeBorder(.white.opacity(0.12)))
        .onAppear { focused = true }
        .onExitCommand { model.onClose() }
    }
}

import SwiftUI
import HavenCore

/// One pin as shown in the bar.
public struct PinSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public var label: String
    public init(id: Int, label: String) { self.id = id; self.label = label }
}

public final class AnnotateBarModel: ObservableObject {
    @Published public var text = ""
    @Published public var agent: Agent = .claudeCode { didSet { if agent != oldValue { model = nil } } }
    @Published public var model: String?
    @Published public var pins: [PinSummary] = []
    /// Bumped to move keyboard focus back into the instruction field.
    @Published public var focusRequest = 0

    public var onSend: (Agent, String?, String) -> Void = { _, _, _ in }
    public var onUndo: () -> Void = {}
    public var onExit: () -> Void = {}

    public init() {}

    public func send() {
        onSend(agent, model, text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Bottom bar of Annotate mode, styled like the composer.
public struct AnnotateBarView: View {
    @ObservedObject var model: AnnotateBarModel
    @FocusState private var focused: Bool

    public init(model: AnnotateBarModel) { self.model = model }

    private var canSend: Bool { !model.pins.isEmpty || !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            pinRow

            TextField("Tell Haven what to do with these…", text: $model.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .lineLimit(1...3)
                .focused($focused)
                .onSubmit(model.send)

            HStack(spacing: 6) {
                AgentMenu(agent: $model.agent)
                ModelMenu(agent: model.agent, model: $model.model)
                Spacer()
                Button(action: model.onUndo) {
                    Label("Undo pin", systemImage: "arrow.uturn.backward").labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(model.pins.isEmpty)
                .opacity(model.pins.isEmpty ? 0.35 : 1)
                .help("Remove the last pin")
                KeyHint("esc", "Exit").padding(.horizontal, 8)
                Button(action: model.send) { Image(systemName: "arrow.up") }
                    .buttonStyle(RunButtonStyle())
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.4)
                    .accessibilityLabel("Send")
            }
        }
        .padding(16)
        .frame(width: 620)
        .background(VisualEffectBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HavenTheme.radiusPanel, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
        .onAppear { focused = true }
        .onChange(of: model.focusRequest) { _ in focused = true }
        .onExitCommand(perform: model.onExit)
    }

    @ViewBuilder private var pinRow: some View {
        if model.pins.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundStyle(.tint)
                Text("Click an element, or drag over a region, to pin it.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.pins) { pin in
                        HStack(spacing: 6) {
                            Text("\(pin.id)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.orange))
                            Text(pin.label).font(.caption).lineLimit(1)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }
}

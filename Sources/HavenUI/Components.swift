import SwiftUI
import AppKit
import HavenCore

/// Translucent system material behind a panel.
public struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material = .hudWindow, blending: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blending = blending
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.state = .active
        v.material = material
        v.blendingMode = blending
        return v
    }

    public func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// Small colored status dot; pulses while working unless Reduce Motion is on.
public struct StatusDot: View {
    let state: TaskState
    var size: CGFloat = 8
    @ObservedObject private var pulse = PulseClock.shared

    public init(_ state: TaskState, size: CGFloat = 8) { self.state = state; self.size = size }

    public var body: some View {
        Circle()
            .fill(HavenTheme.color(for: state))
            .frame(width: size, height: size)
            .opacity(state == .working && pulse.dim ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.8), value: pulse.dim)
            .accessibilityHidden(true)
    }
}

/// Shared slow tick for pulsing dots. Stays still when Reduce Motion is on.
final class PulseClock: ObservableObject {
    static let shared = PulseClock()
    @Published var dim = false
    private var timer: Timer?

    private init() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            self?.dim.toggle()
        }
    }
}

/// Rounded chip used for attached context.
public struct ContextChip: View {
    let icon: String
    let text: String
    var onRemove: (() -> Void)?

    public init(icon: String, text: String, onRemove: (() -> Void)? = nil) {
        self.icon = icon; self.text = text; self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(text).font(.caption).lineLimit(1)
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(text)")
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}

/// Keyboard shortcut hint, e.g. "↩" next to "Run".
public struct KeyHint: View {
    let keys: String
    let label: String

    public init(_ keys: String, _ label: String) { self.keys = keys; self.label = label }

    public var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

/// Menu that picks the agent for a task.
public struct AgentMenu: View {
    @Binding var agent: Agent

    public init(agent: Binding<Agent>) { _agent = agent }

    public var body: some View {
        Menu {
            ForEach(Agent.allCases) { a in
                Button(a.rawValue) { agent = a }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles").font(.caption)
                Text(agent.rawValue).font(.callout)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Agent: \(agent.rawValue)")
    }
}

/// Filled circular action button (the composer's run arrow).
public struct RunButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Color.accentColor))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

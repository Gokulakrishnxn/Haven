import SwiftUI

/// What the pill shows. The app derives this from the task list.
public struct PillState: Equatable, Sendable {
    public var state: TaskState
    public var text: String

    public init(state: TaskState, text: String) { self.state = state; self.text = text }

    public static func from(_ items: [TaskItem]) -> PillState? {
        guard let latest = items.first else { return nil }
        let running = items.filter { $0.state == .working }.count
        if running > 0 { return PillState(state: .working, text: running == 1 ? "1 task working" : "\(running) tasks working") }
        return PillState(state: latest.state, text: latest.state.rawValue)
    }
}

public struct StatusPillView: View {
    let pill: PillState
    let onTap: () -> Void

    public init(pill: PillState, onTap: @escaping () -> Void) { self.pill = pill; self.onTap = onTap }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                StatusDot(pill.state)
                Text(pill.text)
                    .font(.system(size: 12, weight: .medium))
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(VisualEffectBackground(material: .hudWindow))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pill)
        .accessibilityLabel("Haven: \(pill.text)")
        .accessibilityHint("Opens the Task Center")
    }
}

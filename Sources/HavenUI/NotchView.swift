import SwiftUI
import HavenCore

/// What the collapsed notch bar shows. The app derives this from the task list.
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

public final class NotchModel: ObservableObject {
    @Published public var expanded = false
    @Published public var items: [TaskItem] = []
    /// Width of the physical notch (or a default on Macs without one); the collapsed bar wraps it.
    @Published public var notchWidth: CGFloat = 190

    public var onAsk: () -> Void = {}
    public var onAnnotate: () -> Void = {}
    public var onShowTasks: () -> Void = {}

    public init() {}

    var pill: PillState? { PillState.from(items) }
    var latest: TaskItem? { items.first }
}

/// Black bar that sits at the notch. Click it to open actions and the live output of the latest task.
public struct NotchView: View {
    @ObservedObject var model: NotchModel

    public init(model: NotchModel) { self.model = model }

    public var body: some View {
        VStack(spacing: 0) {
            collapsedBar
            if model.expanded { expandedBody.transition(.opacity) }
        }
        .frame(width: model.expanded ? 440 : model.notchWidth + 120)
        .background(Color.black)
        .clipShape(NotchShape(bottomRadius: model.expanded ? 24 : 14))
        .foregroundStyle(.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.expanded)
        .onHover { inside in if !inside && model.expanded { model.expanded = false } }
    }

    // The row level with the notch: status on the left, nothing in the middle (the notch), state on the right.
    private var collapsedBar: some View {
        Button { model.expanded.toggle() } label: {
            HStack(spacing: 8) {
                if let pill = model.pill {
                    HavenLogo(animated: pill.state == .working).frame(width: 16, height: 16)
                    Spacer(minLength: model.notchWidth - 20)
                    Text(pill.text).font(.system(size: 11, weight: .medium)).lineLimit(1)
                } else {
                    HavenLogo().frame(width: 16, height: 16)
                    Spacer(minLength: model.notchWidth - 20)
                    Image(systemName: model.expanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold)).opacity(0.6)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.pill.map { "Haven: \($0.text)" } ?? "Haven")
        .accessibilityHint(model.expanded ? "Collapse" : "Show actions and task output")
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let task = model.latest { taskOutput(task) } else {
                Text("No tasks yet. Ask something, or point at what you mean.")
                    .font(.callout).foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 16).padding(.top, 4)
            }
            HStack(spacing: 8) {
                NotchAction(icon: "plus.bubble", title: "Ask", action: { collapse(); model.onAsk() })
                NotchAction(icon: "scope", title: "Annotate", prominent: true, action: { collapse(); model.onAnnotate() })
                NotchAction(icon: "list.bullet", title: "Tasks", action: { collapse(); model.onShowTasks() })
            }
            .padding(.horizontal, 12).padding(.bottom, 14)
        }
    }

    private func collapse() { model.expanded = false }

    private func taskOutput(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AgentIcon(task.agent, size: 16)
                Text(task.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                StatusDot(task.state)
                Text(task.state.rawValue).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(task.output.isEmpty ? (task.state == .working ? "Working…" : "No output.") : task.output)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(task.output.isEmpty ? 0.5 : 0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 170)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: task.output) { _ in
                    if task.state == .working { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

struct NotchAction: View {
    let icon: String
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(prominent ? Color.accentColor : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Flat top edge (flush with the screen), rounded bottom corners.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

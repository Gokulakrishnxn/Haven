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
    /// Width of the physical notch; the collapsed bar wraps it. Only meaningful when `hasNotch`.
    @Published public var notchWidth: CGFloat = 190
    /// False on Macs and displays without a notch, where the bar is a compact pill instead.
    @Published public var hasNotch = false

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
            if model.expanded { expandedBody.padding(.horizontal, Self.flare).transition(.opacity) }
        }
        .frame(width: width)
        .fixedSize(horizontal: width == nil, vertical: false)
        .background(Color.black)
        .clipShape(NotchShape(bottomRadius: model.expanded ? 22 : 16, flare: Self.flare))
        // A hairline keeps the bar readable against dark wallpapers where there is no physical notch.
        .overlay(NotchShape(bottomRadius: model.expanded ? 22 : 16, flare: Self.flare)
            .stroke(Color.white.opacity(model.hasNotch ? 0 : 0.14), lineWidth: 1))
        .foregroundStyle(.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.expanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.pill)
        .onHover { inside in if !inside && model.expanded { model.expanded = false } }
    }

    /// Concave "ears" at the top corners so the bar flows out of the screen edge like the notch itself.
    private static let flare: CGFloat = 10

    /// Fixed width around a physical notch (a short wing each side, wider when there is status text),
    /// or content-sized for the compact pill.
    private var width: CGFloat? {
        if model.expanded { return 340 }
        guard model.hasNotch else { return nil }
        let wing: CGFloat = model.pill == nil ? 46 : 112
        return model.notchWidth + 2 * (wing + Self.flare)
    }

    private var working: Bool { model.pill?.state == .working }

    // With a notch: status on the left, state on the right, the notch in the middle.
    // Without one: logo, status text and chevron packed together.
    private var collapsedBar: some View {
        Button { model.expanded.toggle() } label: {
            HStack(spacing: 8) {
                WorkingMark(working: working, size: 16)
                if model.hasNotch { Spacer(minLength: model.notchWidth) }
                if model.expanded {
                    Spacer(minLength: 0)
                } else if let pill = model.pill {
                    Text(pill.text).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    if !model.hasNotch { StatusDot(pill.state) }
                } else if !model.hasNotch {
                    Text("Haven").font(.system(size: 12, weight: .medium)).opacity(0.85)
                }
                if model.expanded || !model.hasNotch || model.pill == nil {
                    Image(systemName: model.expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold)).opacity(0.55)
                }
            }
            .padding(.horizontal, Self.flare + 12)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.pill.map { "Haven: \($0.text)" } ?? "Haven")
        .accessibilityHint(model.expanded ? "Collapse" : "Show actions and task output")
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let task = model.latest { taskOutput(task) } else {
                Text("No tasks yet.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 16)
            }
            HStack(spacing: 8) {
                NotchAction(icon: "plus.bubble", title: "Ask", action: { collapse(); model.onAsk() })
                NotchAction(icon: "scope", title: "Annotate", prominent: true, action: { collapse(); model.onAnnotate() })
                NotchAction(icon: "list.bullet", title: "Tasks", action: { collapse(); model.onShowTasks() })
            }
            .padding(.horizontal, 10).padding(.bottom, 10)
        }
    }

    private func collapse() { model.expanded = false }

    private func taskOutput(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AgentIcon(task.agent, size: 14)
                Text(task.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Spacer()
                StatusDot(task.state, size: 6)
                Text(task.state.rawValue).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.65))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(task.output.isEmpty ? (task.state == .working ? "Working…" : "No output.") : task.output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(task.output.isEmpty ? 0.5 : 0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 104)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: task.output) { _ in
                    if task.state == .working { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
        }
        .padding(.horizontal, 10)
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
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(prominent ? Color.accentColor : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Flat top edge flush with the screen, concave ears at the top corners, rounded bottom corners.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var flare: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = flare
        let r = min(bottomRadius, rect.height / 2, (rect.width - 2 * f) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + f, y: rect.minY + f), control: CGPoint(x: rect.minX + f, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + f, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.minX + f + r, y: rect.maxY - r), radius: r, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX - f - r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.maxX - f - r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX - f, y: rect.minY + f))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - f, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// The Haven mark. While a task is running it hops and glows so progress is visible at a glance;
/// it holds still for Reduce Motion.
public struct WorkingMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let working: Bool
    let size: CGFloat

    public init(working: Bool, size: CGFloat = 18) { self.working = working; self.size = size }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !working || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let moving = working && !reduceMotion
            let hop = moving ? -abs(sin(t * 3.4)) * size * 0.14 : 0
            let glow = moving ? (sin(t * 2.4) + 1) / 2 : 0
            HavenLogo(animated: working)
                .frame(width: size, height: size)
                .background(
                    // Drawn as a background so the glow never changes the mark's layout size.
                    Circle()
                        .fill(RadialGradient(colors: [Color.accentColor.opacity(0.55 * glow), .clear],
                                             center: .center, startRadius: 0, endRadius: size * 0.95))
                        .frame(width: size * 2, height: size * 2)
                )
            .offset(y: hop)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

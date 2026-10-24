import SwiftUI
import HavenCore

public final class TaskCenterModel: ObservableObject {
    @Published public var items: [TaskItem] = []
    @Published public var selection: UUID?

    public var onCancel: (UUID) -> Void = { _ in }
    public var onRerun: (UUID) -> Void = { _ in }
    public var onClearFinished: () -> Void = {}

    public init() {}

    public var selected: TaskItem? { items.first { $0.id == selection } ?? items.first }
}

public struct TaskCenterView: View {
    @ObservedObject var model: TaskCenterModel

    public init(model: TaskCenterModel) { self.model = model }

    public var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let task = model.selected {
                TaskDetailView(task: task,
                               onCancel: { model.onCancel(task.id) },
                               onRerun: { model.onRerun(task.id) })
            } else {
                EmptyState()
            }
        }
        .frame(minWidth: 760, minHeight: 440)
    }

    private var sidebar: some View {
        List(selection: $model.selection) {
            ForEach(model.items) { item in
                TaskRow(item: item).tag(item.id)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Clear Finished", action: model.onClearFinished)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .disabled(!model.items.contains { $0.state != .working })
                Spacer()
            }
            .padding(10)
        }
    }
}

struct TaskRow: View {
    let item: TaskItem

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(item.state)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("\(item.agent.rawValue) · \(formatElapsed(item.elapsed(at: ctx.date)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.state.rawValue)")
    }
}

struct TaskDetailView: View {
    let task: TaskItem
    let onCancel: () -> Void
    let onRerun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(task.title).font(.title3.weight(.semibold)).lineLimit(2)
                    Spacer()
                    if task.state == .working {
                        Button("Cancel", action: onCancel).keyboardShortcut(".", modifiers: .command)
                    } else {
                        Button("Run Again", action: onRerun).keyboardShortcut("r", modifiers: .command)
                    }
                }
                HStack(spacing: 8) {
                    StatusDot(task.state)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text("\(task.agent.rawValue) · \(task.state.rawValue) · \(formatElapsed(task.elapsed(at: ctx.date)))")
                    }
                }
                .font(.callout).foregroundStyle(.secondary)
                if !task.context.isEmpty {
                    Text(task.context).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            .padding(20)

            Divider()
            OutputView(text: task.output, working: task.state == .working)
        }
        .navigationTitle("")
    }
}

/// Selectable monospaced output that follows new text unless the user has scrolled up.
struct OutputView: View {
    let text: String
    let working: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? (working ? "Working…" : "No output.") : text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                Color.clear.frame(height: 1).id("end")
            }
            .onChange(of: text) { _ in
                if working { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "house.circle").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("No tasks yet").font(.title3.weight(.semibold))
            HStack(spacing: 4) {
                Text("Press"); KeyHint("⌥Space", "to start one")
            }.foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

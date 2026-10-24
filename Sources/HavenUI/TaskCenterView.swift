import SwiftUI
import HavenCore

public final class TaskCenterModel: ObservableObject {
    @Published public var items: [TaskItem] = []
    @Published public var selection: UUID?

    public var onCancel: (UUID) -> Void = { _ in }
    public var onRerun: (UUID) -> Void = { _ in }
    public var onClearFinished: () -> Void = {}
    public var onSaveAction: (UUID) -> Void = { _ in }

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
                               onRerun: { model.onRerun(task.id) },
                               onSaveAction: { model.onSaveAction(task.id) })
            } else {
                EmptyState()
            }
        }
        .frame(minWidth: 760, minHeight: 440)
        .background(HavenTheme.canvas)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        List(selection: $model.selection) {
            ForEach(model.items) { item in
                TaskRow(item: item).tag(item.id)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(white: 0.04))
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
            AgentIcon(item.agent, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("\(item.agent.displayName) · \(item.state.rawValue) · \(formatElapsed(item.elapsed(at: ctx.date)))")
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
    let onSaveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status card, like the one above the composer.
            HStack(spacing: 12) {
                WorkingMark(working: task.state == .working, size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text("\(task.agent.displayName) · \(task.state.rawValue) · \(formatElapsed(task.elapsed(at: ctx.date)))")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    if !task.context.isEmpty {
                        Text(task.context).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if task.state == .working {
                    Button(action: onCancel) { Image(systemName: "stop.fill").font(.system(size: 10)) }
                        .buttonStyle(RoundActionStyle(fill: Color(red: 0.96, green: 0.36, blue: 0.36)))
                        .keyboardShortcut(".", modifiers: .command)
                        .help("Stop")
                } else {
                    Button(action: onSaveAction) { Image(systemName: "bolt").font(.system(size: 11)) }
                        .buttonStyle(RoundActionStyle(fill: Color.white.opacity(0.12)))
                        .help("Save as Quick Action")
                    Button(action: onRerun) { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
                        .buttonStyle(RoundActionStyle(fill: .white, foreground: .black))
                        .keyboardShortcut("r", modifiers: .command)
                        .help("Run again")
                }
            }
            .padding(14)
            .background(HavenTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HavenTheme.hairline))

            OutputView(text: task.output, working: task.state == .working)
                .background(HavenTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HavenTheme.hairline))
        }
        .padding(16)
        .padding(.top, 14)
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
            HavenLogo()
                .foregroundStyle(.tertiary)
                .frame(width: 52, height: 52)
            Text("No tasks yet").font(.title3.weight(.semibold))
            HStack(spacing: 4) {
                Text("Press"); KeyHint("⌥Space", "to start one")
            }.foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

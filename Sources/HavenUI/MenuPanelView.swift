import SwiftUI
import HavenCore

public final class MenuPanelModel: ObservableObject {
    @Published public var name = ""
    @Published public var items: [TaskItem] = []

    public var onNewTask: () -> Void = {}
    public var onAnnotate: () -> Void = {}
    public var onShowTasks: () -> Void = {}
    public var onSelectTask: (UUID) -> Void = { _ in }
    public var onSettings: () -> Void = {}
    public var onQuit: () -> Void = {}

    public init() {}

    var running: Int { items.filter { $0.state == .working }.count }
}

/// Menu-bar panel: who you are, quick actions, recent tasks, and app commands.
public struct MenuPanelView: View {
    @ObservedObject var model: MenuPanelModel

    public init(model: MenuPanelModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            VStack(spacing: 2) {
                ActionRow(icon: "plus.bubble", title: "New Task", keys: "⌥Space", action: model.onNewTask)
                ActionRow(icon: "scope", title: "Annotate", keys: "⌥⇧Space", action: model.onAnnotate)
            }
            .padding(8)

            if !model.items.isEmpty {
                Divider()
                Text("Recent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                VStack(spacing: 2) {
                    ForEach(model.items.prefix(5)) { item in
                        Button { model.onSelectTask(item.id) } label: {
                            HStack(spacing: 10) {
                                AgentIcon(item.agent, size: 16)
                                Text(item.title).lineLimit(1).font(.callout)
                                Spacer()
                                StatusDot(item.state)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }

            Divider()
            HStack(spacing: 4) {
                FooterButton(title: "Tasks", icon: "list.bullet", action: model.onShowTasks)
                FooterButton(title: "Settings", icon: "gearshape", action: model.onSettings)
                Spacer()
                FooterButton(title: "Quit", icon: "power", action: model.onQuit)
            }
            .padding(8)
        }
        .frame(width: 320)
        .background(HavenTheme.surface)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AvatarView(name: model.name, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name.isEmpty ? "Haven" : "Hi, \(model.name.split(separator: " ").first.map(String.init) ?? model.name)")
                    .font(.headline)
                Text(model.running > 0 ? (model.running == 1 ? "1 task working" : "\(model.running) tasks working") : "All quiet")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let keys: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 20).foregroundStyle(.tint)
                Text(title)
                Spacer()
                KeyHint(keys, "")
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowStyle())
    }
}

struct FooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.callout)
                .padding(.horizontal, 8).padding(.vertical, 5)
        }
        .buttonStyle(HoverRowStyle())
    }
}

final class HoverState: ObservableObject {
    @Published var on = false
}

/// Plain row that highlights on hover, like a system menu item.
struct HoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRow(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct HoverRow<Label: View>: View {
    let label: Label
    let pressed: Bool
    @StateObject private var hover = HoverState()

    var body: some View {
        label
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(pressed ? 0.12 : (hover.on ? 0.07 : 0))))
            .onHover { hover.on = $0 }
    }
}

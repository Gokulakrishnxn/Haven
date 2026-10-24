import SwiftUI
import HavenCore

public final class SelectionPopupModel: ObservableObject {
    @Published public var preview = ""
    @Published public var actions: [QuickAction] = []

    public var onChat: () -> Void = {}
    public var onExplain: () -> Void = {}
    public var onRun: (QuickAction) -> Void = { _ in }

    public init() {}
}

/// Small menu that appears next to selected text: Chat, Explain, and your saved Quick Actions.
public struct SelectionPopupView: View {
    @ObservedObject var model: SelectionPopupModel

    public init(model: SelectionPopupModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("“\(model.preview)”")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)
            PopupRow(icon: "bubble.left", title: "Chat", action: model.onChat)
            PopupRow(icon: "lightbulb", title: "Explain", action: model.onExplain)
            if !model.actions.isEmpty {
                Divider().overlay(Color.white.opacity(0.1)).padding(.vertical, 3)
                ForEach(model.actions) { action in
                    PopupRow(icon: "bolt", title: action.name) { model.onRun(action) }
                }
            }
        }
        .padding(.bottom, 6).padding(.horizontal, 4)
        .frame(width: 220)
        .background(Color(white: 0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .padding(6)
    }
}

struct PopupRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(.white.opacity(0.7))
                Text(title).font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowStyle())
    }
}

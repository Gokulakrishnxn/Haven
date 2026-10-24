import SwiftUI
import HavenCore

public final class ApprovalModel: ObservableObject {
    @Published public var agent: Agent = .claudeCode
    @Published public var taskTitle = ""
    @Published public var summary = ""
    @Published public var reason = ""
    @Published public var allowLabel = "Allow once"

    public var onAllow: () -> Void = {}
    public var onDeny: () -> Void = {}

    public init() {}
}

/// Card that asks the person to allow one action an agent wants to take.
public struct ApprovalView: View {
    @ObservedObject var model: ApprovalModel

    public init(model: ApprovalModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: AgentIconImage.image(for: model.agent, size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(model.agent.displayName) wants to").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    Text(model.summary).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !model.reason.isEmpty {
                Text(model.reason).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            Text("Task: \(model.taskTitle)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
            HStack(spacing: 8) {
                Button(action: model.onDeny) { Text("Deny").frame(maxWidth: .infinity) }
                    .buttonStyle(ApprovalButtonStyle(fill: Color.white.opacity(0.12)))
                    .keyboardShortcut(.cancelAction)
                Button(action: model.onAllow) { Text(model.allowLabel).frame(maxWidth: .infinity) }
                    .buttonStyle(ApprovalButtonStyle(fill: .white, foreground: .black))
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(HavenTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(HavenTheme.hairline))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .padding(6)
    }
}

struct ApprovalButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

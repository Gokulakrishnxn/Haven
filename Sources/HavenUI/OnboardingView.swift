import SwiftUI
import HavenCore

public final class OnboardingModel: ObservableObject {
    @Published public var step = 0
    /// nil while detection is running.
    @Published public var detected: Set<Agent>?
    @Published public var accessibilityGranted = false

    public var onGrantAccessibility: () -> Void = {}
    public var onFinish: () -> Void = {}

    public init() {}
}

public struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    public init(model: OnboardingModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                switch model.step {
                case 0: welcome
                case 1: agents
                default: permissions
                }
            }
            .transition(.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if model.step < 2 { Button("Skip", action: model.onFinish).buttonStyle(.borderless) }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle().fill(i == model.step ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
                Spacer()
                Button(model.step == 2 ? "Done" : "Continue") {
                    if model.step == 2 { model.onFinish() } else { withAnimation { model.step += 1 } }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.step == 1 && model.detected == nil)
            }
        }
        .padding(36)
        .frame(width: 480, height: 380)
        .background(VisualEffectBackground(material: .windowBackground))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "house.circle.fill").font(.system(size: 44)).foregroundStyle(.tint)
            Text("Welcome to Haven").font(.system(size: 28, weight: .bold))
            Text("Point at anything. Haven does the rest.").font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                KeyHint("⌥Space", "Ask from any app")
                KeyHint("⌥⇧Space", "Point at what you mean")
            }.padding(.top, 6)
            Text("Tasks keep running in the background. A small pill at the top of the screen shows progress.")
                .foregroundStyle(.secondary)
        }
    }

    private var agents: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect your agents").font(.system(size: 24, weight: .bold))
            Text("Haven uses the agent CLIs already installed on your Mac.").foregroundStyle(.secondary)
            if let found = model.detected {
                ForEach(Agent.allCases) { agent in
                    HStack(spacing: 10) {
                        Image(systemName: found.contains(agent) ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(found.contains(agent) ? .green : .secondary)
                        Text(agent.rawValue)
                        Spacer()
                        Text(found.contains(agent) ? "Found" : "Not installed").foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Optional permissions").font(.system(size: 24, weight: .bold))
            Text("Haven asks only for what a feature needs, when you use it. Accessibility lets it read selected text and identify elements when you point.")
                .foregroundStyle(.secondary)
            Button(model.accessibilityGranted ? "Accessibility enabled" : "Enable Accessibility…",
                   action: model.onGrantAccessibility)
                .disabled(model.accessibilityGranted)
            Text("You can skip this. Haven still works without it.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

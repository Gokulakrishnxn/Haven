import SwiftUI
import AppKit
import HavenCore

public final class OnboardingModel: ObservableObject {
    @Published public var step = 0
    /// nil while detection is running.
    @Published public var detected: Set<Agent>?
    @Published public var accessibilityGranted = false
    /// The app icon artwork, supplied by the app bundle.
    public var appIcon: NSImage?

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
        .frame(width: 520, height: 540)
        .background(HavenTheme.canvas)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Group {
                if let icon = model.appIcon {
                    Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
                } else {
                    HavenLogo(animated: true).foregroundStyle(.tint)
                }
            }
            .frame(width: 92, height: 92)
            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

            VStack(spacing: 6) {
                Text("Welcome to Haven").font(.system(size: 30, weight: .bold))
                Text("Point at anything. Haven does the rest.").font(.title3).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                WelcomeFeature(icon: "plus.bubble.fill", title: "Ask from any app",
                               detail: "Press ⌥Space. Haven opens over your work with the context already attached.")
                WelcomeFeature(icon: "scope", title: "Point at what you mean",
                               detail: "Press ⌥⇧Space, click or drag over anything, add a note, and send.")
                WelcomeFeature(icon: "rectangle.topthird.inset.filled", title: "Let it run",
                               detail: "Tasks keep going in the background. Open the notch bar any time to see the output.")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var agents: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect your agents").font(.system(size: 24, weight: .bold))
            Text("Haven uses the agent CLIs already installed on your Mac.").foregroundStyle(.secondary)
            if let found = model.detected {
                ForEach(Agent.allCases) { agent in
                    HStack(spacing: 10) {
                        AgentIcon(agent, size: 22)
                        Text(agent.displayName)
                        Spacer()
                        Text(found.contains(agent) ? "Found" : "Not installed").foregroundStyle(.secondary)
                        Image(systemName: found.contains(agent) ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(found.contains(agent) ? .green : .secondary)
                    }
                    .padding(12)
                    .background(HavenTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HavenTheme.hairline))
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

struct WelcomeFeature: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

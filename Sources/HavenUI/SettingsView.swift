import SwiftUI
import HavenCore

public final class SettingsModel: ObservableObject {
    @Published public var agent: Agent { didSet { onChange() } }
    @Published public var showPill: Bool { didSet { onChange() } }
    public var onChange: () -> Void = {}

    public init(agent: Agent, showPill: Bool) {
        self.agent = agent
        self.showPill = showPill
    }
}

public struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    public init(model: SettingsModel) { self.model = model }

    public var body: some View {
        Form {
            Picker("Default agent", selection: $model.agent) {
                ForEach(Agent.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Show status pill", isOn: $model.showPill)
            Section("Shortcuts") {
                LabeledContent("New task") { KeyHint("⌥Space", "") }
                LabeledContent("Annotate") { KeyHint("⌥⇧Space", "") }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }
}

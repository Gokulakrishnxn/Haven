import Foundation

/// A model an agent can be told to use. `id` nil means the agent's own default.
public struct AgentModel: Identifiable, Hashable, Sendable {
    public let id: String?
    public let name: String

    public init(id: String?, name: String) { self.id = id; self.name = name }
    public static let `default` = AgentModel(id: nil, name: "Default")
}

/// Which agent runs a task. Launch details live in HavenRuntime adapters.
public enum Agent: String, CaseIterable, Identifiable, Sendable {
    // Raw values are stored in preferences, so they stay stable.
    case claudeCode = "Claude Code"
    case cursor = "Cursor"
    case codex = "Codex"
    case grok = "Grok"

    public var id: String { rawValue }

    /// Short name shown next to the agent's icon.
    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .grok: return "Grok"
        }
    }

    /// Models offered in the picker. Only Claude's aliases are verified; others use their default.
    public var models: [AgentModel] {
        switch self {
        case .claudeCode:
            return [.default,
                    AgentModel(id: "opus", name: "Opus"),
                    AgentModel(id: "sonnet", name: "Sonnet"),
                    AgentModel(id: "haiku", name: "Haiku")]
        default:
            return [.default]
        }
    }
}

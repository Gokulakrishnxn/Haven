import Foundation

/// Which agent runs a task. Launch details live in HavenRuntime adapters.
public enum Agent: String, CaseIterable, Identifiable, Sendable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case grok = "Grok"

    public var id: String { rawValue }
}

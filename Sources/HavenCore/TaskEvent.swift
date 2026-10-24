import Foundation

/// How a task ended.
public enum Outcome: Equatable, Sendable {
    case success(String?)
    case failure(String)
    case cancelled
}

/// Everything a running agent can tell Haven. UI state and history derive from this stream.
public enum TaskEvent: Equatable, Sendable {
    case started
    case text(String)
    case toolUse(name: String)
    case finished(Outcome)
}

/// Input to an agent run.
public struct AgentRequest: Sendable {
    public var prompt: String
    public var workingDirectory: URL?
    /// Seconds before the run is stopped. nil means no limit.
    public var timeout: TimeInterval?

    public init(prompt: String, workingDirectory: URL? = nil, timeout: TimeInterval? = 3600) {
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }
}

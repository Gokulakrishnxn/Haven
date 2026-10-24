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
    /// Model id for the agent, or nil for its default.
    public var model: String?
    public var workingDirectory: URL?
    /// Extra environment variables for the agent process.
    public var environment: [String: String]
    /// Shell commands the agent may run without asking, by name, for example "haven-vault".
    public var allowedCommands: [String]
    /// Seconds before the run is stopped. nil means no limit.
    public var timeout: TimeInterval?

    public init(prompt: String, model: String? = nil, workingDirectory: URL? = nil, timeout: TimeInterval? = 3600,
                environment: [String: String] = [:], allowedCommands: [String] = []) {
        self.prompt = prompt
        self.model = model
        self.environment = environment
        self.allowedCommands = allowedCommands
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }
}

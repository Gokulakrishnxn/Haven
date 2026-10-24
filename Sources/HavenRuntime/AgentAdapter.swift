import Foundation
import HavenCore

/// Turns raw process output into task events.
public protocol OutputParser {
    mutating func feed(_ data: Data) -> [TaskEvent]
    /// Called once when the process ends. Returns how the task ended.
    mutating func finish(exit: ProcessExit) -> Outcome
}

/// How to launch one agent CLI and understand its output.
public protocol AgentAdapter: Sendable {
    var agent: Agent { get }
    var executable: String { get }
    /// Arguments placed before the prompt.
    var arguments: [String] { get }
    func makeParser() -> OutputParser
}

/// Maps an exit status to an outcome when the agent gave no structured result.
func outcome(for exit: ProcessExit, tail: String) -> Outcome {
    if exit.cancelled { return .cancelled }
    if exit.timedOut { return .failure("Timed out") }
    if exit.succeeded { return .success(nil) }
    let detail = tail.trimmingCharacters(in: .whitespacesAndNewlines)
    let reason = exit.code.map { "Exited with status \($0)" } ?? "Stopped by signal \(exit.signal ?? 0)"
    return .failure(detail.isEmpty ? reason : "\(reason): \(String(detail.suffix(300)))")
}

/// Streams raw text. Used for CLIs without a structured output mode we have verified.
struct PlainTextParser: OutputParser {
    private var tail = ""

    mutating func feed(_ data: Data) -> [TaskEvent] {
        let text = String(decoding: data, as: UTF8.self)
        tail = String((tail + text).suffix(500))
        return [.text(text)]
    }

    mutating func finish(exit: ProcessExit) -> Outcome { outcome(for: exit, tail: tail) }
}

public struct PlainTextAdapter: AgentAdapter {
    public let agent: Agent
    public let executable: String
    public let arguments: [String]

    public init(agent: Agent, executable: String, arguments: [String]) {
        self.agent = agent; self.executable = executable; self.arguments = arguments
    }

    public func makeParser() -> OutputParser { PlainTextParser() }
}

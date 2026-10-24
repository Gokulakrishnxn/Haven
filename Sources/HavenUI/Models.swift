import Foundation
import HavenCore

/// Display state of a task, independent of how it runs.
public enum TaskState: String, Sendable {
    case working = "Working…", done = "Done", failed = "Failed", cancelled = "Cancelled"
}

/// Plain data the Task Center and pill render. The app maps its own task objects to this.
public struct TaskItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var agent: Agent
    public var state: TaskState
    public var output: String
    public var context: String
    public var startedAt: Date
    public var finishedAt: Date?

    public init(id: UUID, title: String, agent: Agent, state: TaskState, output: String,
                context: String, startedAt: Date, finishedAt: Date?) {
        self.id = id; self.title = title; self.agent = agent; self.state = state
        self.output = output; self.context = context; self.startedAt = startedAt; self.finishedAt = finishedAt
    }

    public func elapsed(at now: Date = Date()) -> TimeInterval { (finishedAt ?? now).timeIntervalSince(startedAt) }
}

public func formatElapsed(_ t: TimeInterval) -> String {
    t < 60 ? "\(Int(t))s" : "\(Int(t) / 60)m \(Int(t) % 60)s"
}

public extension TaskItem {
    /// One line describing what the agent is doing right now, for status cards.
    var activity: String {
        let last = output.split(separator: "\n").last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(90)) }
        if let last { return last.hasPrefix("›") ? "Using \(last.dropFirst().trimmingCharacters(in: .whitespaces))" : last }
        switch state {
        case .working: return "Checking connected tools"
        case .done: return "Finished"
        case .failed: return "Something went wrong"
        case .cancelled: return "Stopped"
        }
    }
}

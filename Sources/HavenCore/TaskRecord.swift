import Foundation

/// A finished (or interrupted) task as saved to disk, so history survives restarts.
public struct TaskRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var agent: Agent
    public var model: String?
    public var instruction: String
    public var appName: String?
    public var selectedText: String?
    public var tab: BrowserTab?
    public var files: [String]
    /// "working", "done", "failed" or "cancelled".
    public var status: String
    public var output: String
    public var startedAt: Date
    public var finishedAt: Date?

    public init(id: UUID, agent: Agent, model: String?, instruction: String, appName: String?, selectedText: String?,
                tab: BrowserTab?, files: [String], status: String, output: String, startedAt: Date, finishedAt: Date?) {
        self.id = id; self.agent = agent; self.model = model; self.instruction = instruction
        self.appName = appName; self.selectedText = selectedText; self.tab = tab; self.files = files
        self.status = status; self.output = output; self.startedAt = startedAt; self.finishedAt = finishedAt
    }

    /// Longest output kept per task, so the history file stays small.
    public static let maxOutput = 200_000

    public static func trimmed(_ output: String) -> String {
        output.count <= maxOutput ? output : String(output.suffix(maxOutput))
    }
}

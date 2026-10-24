import Foundation
import HavenCore
import HavenRuntime

final class HavenTask: ObservableObject, Identifiable {
    enum Status: String { case working = "Working…", done = "Done", failed = "Failed", cancelled = "Cancelled" }

    let id: UUID
    let agent: Agent
    let model: String?
    let instruction: String
    let context: TaskContext
    let startedAt: Date
    /// True for tasks loaded from history rather than started in this session.
    let restored: Bool
    fileprivate(set) var finishedAt: Date?
    fileprivate var run: AgentRun?
    @Published var status: Status = .working
    @Published var output = ""

    init(agent: Agent, model: String?, instruction: String, context: TaskContext) {
        self.id = UUID()
        self.agent = agent
        self.model = model
        self.instruction = instruction
        self.context = context
        self.startedAt = Date()
        self.restored = false
    }

    /// Rebuilds a finished task from history. A task that was still running when Haven quit is shown as stopped.
    init(restoring r: TaskRecord) {
        id = r.id
        agent = r.agent
        model = r.model
        instruction = r.instruction
        context = TaskContext(appName: r.appName, selectedText: r.selectedText, tab: r.tab, files: r.files)
        startedAt = r.startedAt
        restored = true
        finishedAt = r.finishedAt ?? r.startedAt
        output = r.output
        switch r.status {
        case "done": status = .done
        case "failed": status = .failed
        default: status = .cancelled
        }
    }

    var record: TaskRecord {
        TaskRecord(id: id, agent: agent, model: model, instruction: instruction, appName: context.appName,
                   selectedText: context.selectedText, tab: context.tab, files: context.files,
                   status: { switch status { case .working: return "working"; case .done: return "done"; case .failed: return "failed"; case .cancelled: return "cancelled" } }(),
                   output: TaskRecord.trimmed(output), startedAt: startedAt, finishedAt: finishedAt)
    }

    var elapsed: TimeInterval { (finishedAt ?? Date()).timeIntervalSince(startedAt) }

    var prompt: String {
        var parts = [instruction]
        if let app = context.appName { parts.append("Context app: \(app)") }
        if let tab = context.tab { parts.append("Browser tab: \(tab.title)\nURL: \(tab.url)") }
        if let text = context.selectedText { parts.append("Selected text:\n\(text)") }
        if !context.files.isEmpty {
            parts.append("Attached files (read them as needed):\n" + context.files.map { "- \($0)" }.joined(separator: "\n"))
        }
        if let brief = context.brief { parts.append(brief) }
        return parts.joined(separator: "\n\n")
    }
}

/// Starts each task through its agent adapter and applies the resulting events.
/// One failing task never affects another.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [HavenTask] = []
    /// Extra prompt text and environment for agents, supplied by the app (for example how to request a login).
    var loginNote: (() -> String?)?
    var helperDirectory: String?
    /// Returns an MCP config file path for a Claude task, or nil.
    var mcpConfigPath: ((UUID) -> String?)?

    /// Called on the main thread whenever a task is added, changes status, or produces output.
    var onChange: (() -> Void)?

    /// Tasks started since launch.
    private(set) var startedCount = 0

    private let history = JSONFileStore<TaskRecord>.appSupport("history.json")
    /// Most tasks kept in history.
    private static let historyLimit = 100

    init() {
        tasks = history.load().map(HavenTask.init(restoring:))
    }

    /// Writes history to disk. Called when tasks start or finish, and on quit.
    func persist() {
        history.save(tasks.prefix(Self.historyLimit).map(\.record))
    }

    var runningCount: Int { tasks.filter { $0.status == .working }.count }

    @discardableResult
    func start(agent: Agent, model: String? = nil, instruction: String, context: TaskContext) -> HavenTask {
        let task = HavenTask(agent: agent, model: model, instruction: instruction, context: context)
        tasks.insert(task, at: 0)
        startedCount += 1
        persist()

        var prompt = task.prompt
        var environment = ["HAVEN_TASK_ID": task.id.uuidString]
        var allowed: [String] = []
        if let note = loginNote?() {
            prompt += "\n\n" + note
            allowed = ["haven-vault", "haven-mac"]
            if let dir = helperDirectory { environment["HAVEN_HELPER_DIR"] = dir }
        }
        let request = AgentRequest(prompt: prompt, model: model, workingDirectory: Preferences.workingFolderURL,
                                   environment: environment, allowedCommands: allowed,
                                   mcpConfigPath: agent == .claudeCode ? mcpConfigPath?(task.id) : nil)
        let run = AgentRunner.launch(AgentRegistry.adapter(for: agent), request: request)
        task.run = run
        Task { @MainActor [weak self, weak task] in
            for await event in run.events {
                guard let self, let task else { return }
                self.apply(event, to: task)
            }
        }
        onChange?()
        return task
    }

    func cancel(_ task: HavenTask) {
        guard task.status == .working else { return }
        task.run?.cancel()  // the .finished(.cancelled) event updates status
    }

    func rerun(_ task: HavenTask) {
        start(agent: task.agent, model: task.model, instruction: task.instruction, context: task.context)
    }

    func clearFinished() {
        tasks.removeAll { $0.status != .working }
        persist()
        onChange?()
    }

    @MainActor
    private func apply(_ event: TaskEvent, to task: HavenTask) {
        switch event {
        case .started:
            break
        case .text(let text):
            task.output += text.hasSuffix("\n") ? text : text + "\n"
        case .toolUse(let name):
            task.output += "› \(name)\n"
        case .finished(let outcome):
            switch outcome {
            case .success(let result):
                task.status = .done
                // Plain-text agents already streamed their output; structured ones may only report a result.
                if task.output.isEmpty, let result { task.output = result }
            case .failure(let message):
                task.status = .failed
                if !task.output.contains(message) { task.output += (task.output.isEmpty ? "" : "\n") + message }
            case .cancelled:
                task.status = .cancelled
            }
            task.finishedAt = Date()
            task.run = nil
            objectWillChange.send()
            persist()
        }
        onChange?()
    }
}

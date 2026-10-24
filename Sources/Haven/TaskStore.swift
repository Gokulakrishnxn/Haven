import Foundation

enum Agent: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case grok = "Grok"

    var id: String { rawValue }

    /// CLI executable name.
    var executable: String {
        switch self {
        case .claudeCode: return "claude"
        case .codex: return "codex"
        case .grok: return "grok"
        }
    }

    /// Arguments placed before the prompt.
    var arguments: [String] {
        switch self {
        case .claudeCode: return ["-p"]
        case .codex: return ["exec"]
        case .grok: return ["-p"]
        }
    }
}

final class HavenTask: ObservableObject, Identifiable {
    enum Status: String { case working = "Working…", done = "Done", failed = "Failed", cancelled = "Cancelled" }

    let id = UUID()
    let agent: Agent
    let instruction: String
    let context: TaskContext
    let startedAt = Date()
    fileprivate(set) var finishedAt: Date?
    fileprivate var process: Process?
    @Published var status: Status = .working
    @Published var output = ""

    init(agent: Agent, instruction: String, context: TaskContext) {
        self.agent = agent
        self.instruction = instruction
        self.context = context
    }

    var elapsed: TimeInterval { (finishedAt ?? Date()).timeIntervalSince(startedAt) }

    var prompt: String {
        var parts = [instruction]
        if let app = context.appName { parts.append("Context app: \(app)") }
        if let text = context.selectedText { parts.append("Selected text:\n\(text)") }
        if let brief = context.brief { parts.append(brief) }
        return parts.joined(separator: "\n\n")
    }
}

/// Runs each task as its own background process so one failure never blocks others.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [HavenTask] = []
    /// Called on the main thread whenever a task is added, changes status, or produces output.
    var onChange: (() -> Void)?

    var runningCount: Int { tasks.filter { $0.status == .working }.count }

    @discardableResult
    func start(agent: Agent, instruction: String, context: TaskContext) -> HavenTask {
        let task = HavenTask(agent: agent, instruction: instruction, context: context)
        tasks.insert(task, at: 0)
        run(task)
        onChange?()
        return task
    }

    func cancel(_ task: HavenTask) {
        guard task.status == .working else { return }
        task.status = .cancelled
        task.finishedAt = Date()
        task.process?.terminate()
        onChange?()
    }

    func rerun(_ task: HavenTask) {
        start(agent: task.agent, instruction: task.instruction, context: task.context)
    }

    func clearFinished() {
        tasks.removeAll { $0.status != .working }
        onChange?()
    }

    private func run(_ task: HavenTask) {
        let process = Process()
        // Login shell so PATH includes where the user installed the agent CLIs.
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "exec \"$0\" \"$@\"", task.agent.executable] + task.agent.arguments + [task.prompt]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        task.process = process

        // Stream output as it arrives.
        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak task] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                task?.output += String(decoding: data, as: UTF8.self)
                self?.onChange?()
            }
        }

        process.terminationHandler = { [weak self, weak task] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let task else { return }
                if !rest.isEmpty { task.output += String(decoding: rest, as: UTF8.self) }
                if task.status == .working {
                    task.status = proc.terminationStatus == 0 ? .done : .failed
                    task.finishedAt = Date()
                }
                task.process = nil
                self?.objectWillChange.send()
                self?.onChange?()
            }
        }
        do {
            try process.run()
        } catch {
            task.output = error.localizedDescription
            task.status = .failed
            task.finishedAt = Date()
        }
    }
}

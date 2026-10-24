import Foundation

enum Agent: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case grok = "Grok"

    var id: String { rawValue }

    /// Executable name and arguments; the prompt is appended last.
    var command: (exe: String, args: [String]) {
        switch self {
        case .claudeCode: return ("claude", ["-p"])
        case .codex: return ("codex", ["exec"])
        case .grok: return ("grok", ["-p"])
        }
    }
}

final class HavenTask: ObservableObject, Identifiable {
    enum Status: String { case working = "Working…", done = "Done", failed = "Failed" }

    let id = UUID()
    let agent: Agent
    let instruction: String
    let context: TaskContext
    @Published var status: Status = .working
    @Published var output = ""

    init(agent: Agent, instruction: String, context: TaskContext) {
        self.agent = agent
        self.instruction = instruction
        self.context = context
    }

    var prompt: String {
        var parts = [instruction]
        if let app = context.appName { parts.append("Context app: \(app)") }
        if let text = context.selectedText { parts.append("Selected text:\n\(text)") }
        return parts.joined(separator: "\n\n")
    }
}

/// Runs each task as its own background process so one failure never blocks others.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [HavenTask] = []
    /// Called on the main thread whenever a task is added or changes status.
    var onChange: (() -> Void)?

    var runningCount: Int { tasks.filter { $0.status == .working }.count }

    func start(agent: Agent, instruction: String, context: TaskContext) {
        let task = HavenTask(agent: agent, instruction: instruction, context: context)
        tasks.insert(task, at: 0)
        run(task)
        onChange?()
    }

    private func run(_ task: HavenTask) {
        let (exe, args) = task.agent.command
        let process = Process()
        // Login shell so PATH includes where the user installed the agent CLIs.
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "exec \"$0\" \"$@\"", exe] + args + [task.prompt]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { [weak self, weak task] proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                task?.output = String(decoding: data, as: UTF8.self)
                task?.status = proc.terminationStatus == 0 ? .done : .failed
                self?.objectWillChange.send()
                self?.onChange?()
            }
        }
        do {
            try process.run()
        } catch {
            task.output = error.localizedDescription
            task.status = .failed
            onChange?()
        }
    }
}

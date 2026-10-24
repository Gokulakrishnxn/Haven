import Foundation
import HavenCore
import HavenRuntime

final class HavenTask: ObservableObject, Identifiable {
    enum Status: String { case working = "Working…", done = "Done", failed = "Failed", cancelled = "Cancelled" }

    let id = UUID()
    let agent: Agent
    let instruction: String
    let context: TaskContext
    let startedAt = Date()
    fileprivate(set) var finishedAt: Date?
    fileprivate var run: AgentRun?
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

/// Starts each task through its agent adapter and applies the resulting events.
/// One failing task never affects another.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [HavenTask] = []
    /// Called on the main thread whenever a task is added, changes status, or produces output.
    var onChange: (() -> Void)?

    var runningCount: Int { tasks.filter { $0.status == .working }.count }

    @discardableResult
    func start(agent: Agent, instruction: String, context: TaskContext) -> HavenTask {
        let task = HavenTask(agent: agent, instruction: instruction, context: context)
        tasks.insert(task, at: 0)

        let run = AgentRunner.launch(AgentRegistry.adapter(for: agent), request: AgentRequest(prompt: task.prompt))
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
        start(agent: task.agent, instruction: task.instruction, context: task.context)
    }

    func clearFinished() {
        tasks.removeAll { $0.status != .working }
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
        }
        onChange?()
    }
}

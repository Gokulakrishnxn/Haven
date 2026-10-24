import Foundation
import HavenCore

/// A live agent run: consume `events`, call `cancel()` to stop it.
public final class AgentRun: @unchecked Sendable {
    public let events: AsyncStream<TaskEvent>
    private let process: SupervisedProcess?

    init(events: AsyncStream<TaskEvent>, process: SupervisedProcess?) {
        self.events = events
        self.process = process
    }

    public func cancel() { process?.terminate() }
}

public enum AgentRegistry {
    public static func adapter(for agent: Agent) -> AgentAdapter {
        switch agent {
        case .claudeCode: return ClaudeCodeAdapter()
        // Cursor, Codex and Grok flags are unverified; they run as plain text without a model flag.
        case .cursor: return PlainTextAdapter(agent: .cursor, executable: "cursor-agent", arguments: ["-p"])
        case .codex: return PlainTextAdapter(agent: .codex, executable: "codex", arguments: ["exec"])
        case .grok: return PlainTextAdapter(agent: .grok, executable: "grok", arguments: ["-p"])
        }
    }
}

public enum AgentRunner {
    /// Launches the adapter's CLI through a login shell (so the user's PATH applies).
    public static func launch(_ adapter: AgentAdapter, request: AgentRequest) -> AgentRun {
        launch(command: ["/bin/zsh", "-lc", "exec \"$0\" \"$@\"", adapter.executable] + adapter.arguments(for: request) + [request.prompt],
               parser: adapter.makeParser(), request: request)
    }

    /// Lower-level entry point, also used by tests with a stand-in command.
    static func launch(command: [String], parser: OutputParser, request: AgentRequest) -> AgentRun {
        var continuation: AsyncStream<TaskEvent>.Continuation!
        let events = AsyncStream<TaskEvent> { continuation = $0 }
        let box = ParserBox(parser)
        let cont = continuation!

        cont.yield(.started)
        do {
            let process = try ProcessSupervisor.launch(
                command: command,
                workingDirectory: request.workingDirectory,
                timeout: request.timeout,
                onOutput: { data in box.feed(data).forEach { cont.yield($0) } },
                onExit: { exit in
                    cont.yield(.finished(box.finish(exit)))
                    cont.finish()
                })
            return AgentRun(events: events, process: process)
        } catch {
            cont.yield(.finished(.failure("\(error)")))
            cont.finish()
            return AgentRun(events: events, process: nil)
        }
    }
}

/// Serializes parser access; output and exit callbacks arrive on the same thread, but be explicit.
private final class ParserBox: @unchecked Sendable {
    private var parser: OutputParser
    private let lock = NSLock()
    init(_ parser: OutputParser) { self.parser = parser }
    func feed(_ d: Data) -> [TaskEvent] { lock.withLock { parser.feed(d) } }
    func finish(_ e: ProcessExit) -> Outcome { lock.withLock { parser.finish(exit: e) } }
}

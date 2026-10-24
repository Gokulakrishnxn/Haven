import Foundation
import Testing
import HavenCore
@testable import HavenRuntime

private func collect(_ run: AgentRun) async -> [TaskEvent] {
    var events: [TaskEvent] = []
    for await e in run.events { events.append(e) }
    return events
}

private func shell(_ script: String, timeout: TimeInterval? = 30) -> AgentRun {
    AgentRunner.launch(command: ["/bin/sh", "-c", script], parser: PlainTextParser(),
                       request: AgentRequest(prompt: "", timeout: timeout))
}

@Suite struct ProcessSupervisorTests {
    @Test func streamsOutputAndSucceeds() async {
        let events = await collect(shell("echo hello"))
        #expect(events.first == .started)
        #expect(events.contains(.text("hello\n")))
        #expect(events.last == .finished(.success(nil)))
    }

    @Test func nonZeroExitFailsWithOutput() async {
        let events = await collect(shell("echo oops; exit 3"))
        guard case .finished(.failure(let message)) = events.last else { Issue.record("expected failure"); return }
        #expect(message.contains("3"))
        #expect(message.contains("oops"))
    }

    @Test func cancelStopsProcessAndItsChildren() async {
        let run = shell("sleep 60 & wait")
        let started = Date()
        try? await Task.sleep(nanoseconds: 300_000_000)
        run.cancel()
        let events = await collect(run)
        #expect(events.last == .finished(.cancelled))
        #expect(Date().timeIntervalSince(started) < 10)
    }

    @Test func timeoutStopsProcess() async {
        let events = await collect(shell("sleep 60", timeout: 0.5))
        #expect(events.last == .finished(.failure("Timed out")))
    }

    @Test func missingExecutableFailsCleanly() async {
        let run = AgentRunner.launch(command: ["/nonexistent/binary"], parser: PlainTextParser(), request: AgentRequest(prompt: ""))
        let events = await collect(run)
        guard case .finished(.failure) = events.last else { Issue.record("expected failure"); return }
    }

    @Test func runsInWorkingDirectory() async {
        let run = AgentRunner.launch(command: ["/bin/pwd"], parser: PlainTextParser(),
                                     request: AgentRequest(prompt: "", workingDirectory: URL(fileURLWithPath: "/tmp")))
        let text = await collect(run).compactMap { event -> String? in if case .text(let t) = event { return t } else { return nil } }.joined()
        #expect(text.contains("tmp"))
    }
}

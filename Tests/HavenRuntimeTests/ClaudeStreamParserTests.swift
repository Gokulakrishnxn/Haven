import Foundation
import Testing
import HavenCore
@testable import HavenRuntime

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "jsonl", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private let ok = ProcessExit(code: 0, signal: nil, cancelled: false, timedOut: false)

@Suite struct ClaudeStreamParserTests {
    @Test func parsesRecordedRun() throws {
        var parser = ClaudeStreamParser()
        let events = parser.feed(try fixture("claude-basic"))
        #expect(events == [.text("hi")])
        #expect(parser.finish(exit: ok) == .success("hi"))
    }

    @Test func handlesChunksSplitAnywhere() throws {
        let data = try fixture("claude-basic")
        for size in [1, 3, 7, 50] {
            var parser = ClaudeStreamParser()
            var events: [TaskEvent] = []
            var i = 0
            while i < data.count {
                events += parser.feed(data[i..<min(i + size, data.count)])
                i += size
            }
            #expect(events == [.text("hi")], "chunk size \(size)")
            #expect(parser.finish(exit: ok) == .success("hi"))
        }
    }

    @Test func reportsToolUse() {
        var parser = ClaudeStreamParser()
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read"},{"type":"text","text":"done"}]}}"# + "\n"
        #expect(parser.feed(Data(line.utf8)) == [.toolUse(name: "Read"), .text("done")])
    }

    @Test func ignoresUnknownEvents() {
        var parser = ClaudeStreamParser()
        #expect(parser.feed(Data(#"{"type":"something_new","x":1}"#.utf8 + [0x0A])).isEmpty)
    }

    @Test func errorResultIsFailure() {
        var parser = ClaudeStreamParser()
        _ = parser.feed(Data(#"{"type":"result","is_error":true,"result":"boom"}"#.utf8 + [0x0A]))
        #expect(parser.finish(exit: ProcessExit(code: 1, signal: nil, cancelled: false, timedOut: false)) == .failure("boom"))
    }

    @Test func nonJSONOutputBecomesFailureDetail() {
        var parser = ClaudeStreamParser()
        _ = parser.feed(Data("command not found\n".utf8))
        let outcome = parser.finish(exit: ProcessExit(code: 127, signal: nil, cancelled: false, timedOut: false))
        guard case .failure(let message) = outcome else { Issue.record("expected failure"); return }
        #expect(message.contains("127"))
        #expect(message.contains("command not found"))
    }

    @Test func cancelledWinsOverResult() {
        var parser = ClaudeStreamParser()
        _ = parser.feed(Data(#"{"type":"result","result":"x"}"#.utf8 + [0x0A]))
        #expect(parser.finish(exit: ProcessExit(code: nil, signal: 15, cancelled: true, timedOut: false)) == .cancelled)
    }
}

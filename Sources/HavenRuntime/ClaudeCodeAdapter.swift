import Foundation
import HavenCore

/// Parses `claude -p --output-format stream-json --verbose` (one JSON object per line).
/// Unknown event types are ignored so new CLI versions do not break the task.
struct ClaudeStreamParser: OutputParser {
    private var pending = Data()
    private var resultText: String?
    private var resultIsError = false
    private var tail = ""

    mutating func feed(_ data: Data) -> [TaskEvent] {
        pending.append(data)
        var events: [TaskEvent] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending[pending.startIndex..<newline]
            pending.removeSubrange(pending.startIndex...newline)
            events += parse(line: Data(line))
        }
        return events
    }

    mutating func finish(exit: ProcessExit) -> Outcome {
        if !pending.isEmpty { _ = parse(line: pending); pending = Data() }
        if exit.cancelled { return .cancelled }
        if exit.timedOut { return .failure("Timed out") }
        if let resultText {
            return resultIsError ? .failure(resultText) : .success(resultText)
        }
        return outcome(for: exit, tail: tail)
    }

    private mutating func parse(line: Data) -> [TaskEvent] {
        guard !line.isEmpty else { return [] }
        guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let type = object["type"] as? String else {
            // Not JSON (for example a startup error): keep it for the failure message.
            tail = String((tail + String(decoding: line, as: UTF8.self)).suffix(500))
            return []
        }
        switch type {
        case "assistant":
            let blocks = ((object["message"] as? [String: Any])?["content"] as? [[String: Any]]) ?? []
            return blocks.compactMap { block in
                switch block["type"] as? String {
                case "text": return (block["text"] as? String).map { .text($0) }
                case "tool_use": return .toolUse(name: (block["name"] as? String) ?? "tool")
                default: return nil
                }
            }
        case "result":
            resultText = object["result"] as? String ?? ""
            resultIsError = object["is_error"] as? Bool ?? false
            return []
        default:
            return []
        }
    }
}

public struct ClaudeCodeAdapter: AgentAdapter {
    public init() {}
    public let agent = Agent.claudeCode
    public let executable = "claude"

    public func arguments(for request: AgentRequest) -> [String] {
        var args = ["-p", "--output-format", "stream-json", "--verbose"]
        if let model = request.model { args += ["--model", model] }
        var variadic = false
        if !request.allowedCommands.isEmpty {
            args += ["--allowedTools"] + request.allowedCommands.map { "Bash(\($0):*)" }
            variadic = true
        }
        if let path = request.mcpConfigPath {
            args += ["--mcp-config", path]
            variadic = true
        }
        // These options are variadic and would swallow the prompt, so end options with "--".
        if variadic { args.append("--") }
        return args
    }

    public func makeParser() -> OutputParser { ClaudeStreamParser() }
}

import Testing
import HavenCore
@testable import HavenRuntime

@Suite struct AdapterArgumentsTests {
    @Test func claudePassesModelAlias() {
        let args = ClaudeCodeAdapter().arguments(for: AgentRequest(prompt: "x", model: "haiku"))
        #expect(args == ["-p", "--output-format", "stream-json", "--verbose", "--model", "haiku"])
    }

    @Test func claudeOmitsModelWhenDefault() {
        let args = ClaudeCodeAdapter().arguments(for: AgentRequest(prompt: "x"))
        #expect(!args.contains("--model"))
    }

    @Test func unverifiedAgentsNeverGetAModelFlag() {
        for agent in [Agent.cursor, .codex, .grok] {
            let args = AgentRegistry.adapter(for: agent).arguments(for: AgentRequest(prompt: "x", model: "whatever"))
            #expect(!args.contains("whatever"), "\(agent)")
        }
    }

    @Test func onlyClaudeOffersModelChoices() {
        #expect(Agent.claudeCode.models.map(\.name) == ["Default", "Opus", "Sonnet", "Haiku"])
        #expect(Agent.cursor.models == [.default])
    }
}

@Suite struct AllowedCommandsTests {
    @Test func allowedCommandsEndOptionsSoThePromptIsNotSwallowed() {
        let args = ClaudeCodeAdapter().arguments(for: AgentRequest(prompt: "x", allowedCommands: ["haven-vault"]))
        #expect(args.suffix(3) == ["--allowedTools", "Bash(haven-vault:*)", "--"])
    }

    @Test func noAllowedCommandsAddsNothing() {
        #expect(!ClaudeCodeAdapter().arguments(for: AgentRequest(prompt: "x")).contains("--"))
    }

    @Test func environmentReachesTheProcess() async {
        var request = AgentRequest(prompt: "")
        request.environment = ["HAVEN_TASK_ID": "abc-123"]
        // Stand-in adapter that just prints the variable.
        struct Echo: AgentAdapter {
            let agent = Agent.claudeCode
            let executable = "sh"
            func arguments(for request: AgentRequest) -> [String] { ["-c", "printf %s \"$HAVEN_TASK_ID\"", "--"] }
            func makeParser() -> OutputParser { PlainTextParser() }
        }
        let run = AgentRunner.launch(Echo(), request: request)
        var text = ""
        for await e in run.events { if case .text(let t) = e { text += t } }
        #expect(text == "abc-123")
    }

    @Test func helperDirectoryIsPrependedToPath() async {
        var request = AgentRequest(prompt: "")
        request.environment = ["HAVEN_HELPER_DIR": "/opt/haven-helpers"]
        struct Echo: AgentAdapter {
            let agent = Agent.claudeCode
            let executable = "sh"
            func arguments(for request: AgentRequest) -> [String] { ["-c", "printf %s \"$PATH\"", "--"] }
            func makeParser() -> OutputParser { PlainTextParser() }
        }
        var text = ""
        for await e in AgentRunner.launch(Echo(), request: request).events { if case .text(let t) = e { text += t } }
        #expect(text.hasPrefix("/opt/haven-helpers:"))
    }
}

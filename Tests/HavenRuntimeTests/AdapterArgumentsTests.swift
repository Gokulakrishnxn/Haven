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

import Foundation
import Testing
import HavenCore
@testable import HavenRuntime

@Suite struct JSONFileStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("haven-test-\(UUID().uuidString).json")
    }

    @Test func roundTripsQuickActions() {
        let store = JSONFileStore<QuickAction>(url: tempURL())
        let actions = [QuickAction(name: "Summarize", prompt: "Summarize this", agent: .claudeCode, model: "haiku"),
                       QuickAction(name: "Explain", prompt: "Explain this")]
        store.save(actions)
        #expect(store.load() == actions)
    }

    @Test func missingFileLoadsEmpty() {
        #expect(JSONFileStore<QuickAction>(url: tempURL()).load().isEmpty)
    }

    @Test func corruptFileLoadsEmptyInsteadOfCrashing() throws {
        let url = tempURL()
        try Data("not json".utf8).write(to: url)
        #expect(JSONFileStore<QuickAction>(url: url).load().isEmpty)
    }
}

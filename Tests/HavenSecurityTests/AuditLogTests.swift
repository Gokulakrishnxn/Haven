import Foundation
import Testing
@testable import HavenSecurity

@Suite struct AuditLogTests {
    private func makeLog() -> (AuditLog, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID().uuidString).jsonl")
        return (AuditLog(url: url), url)
    }

    @Test func chainVerifiesAfterAppends() {
        let (log, _) = makeLog()
        for i in 0..<5 { log.append(credential: "GitHub", site: "github.com", task: "t\(i)", reason: "sign in", outcome: .approved) }
        #expect(log.entries().count == 5)
        #expect(log.firstBrokenIndex() == nil)
    }

    @Test func editingAnEntryIsDetected() throws {
        let (log, url) = makeLog()
        for i in 0..<3 { log.append(credential: "GitHub", site: "github.com", task: "t\(i)", reason: "sign in", outcome: .approved) }
        var text = try String(contentsOf: url, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"outcome\":\"approved\"", with: "\"outcome\":\"denied\"", options: [], range: text.range(of: "\"outcome\":\"approved\""))
        try text.write(to: url, atomically: true, encoding: .utf8)
        #expect(log.firstBrokenIndex() == 0)
    }

    @Test func deletingAnEntryIsDetected() throws {
        let (log, url) = makeLog()
        for i in 0..<3 { log.append(credential: "GitHub", site: "github.com", task: "t\(i)", reason: "x", outcome: .approved) }
        var lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        lines.remove(at: 1)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        #expect(log.firstBrokenIndex() == 1)
    }

    @Test func emptyLogIsIntact() {
        let (log, _) = makeLog()
        #expect(log.entries().isEmpty)
        #expect(log.firstBrokenIndex() == nil)
    }
}

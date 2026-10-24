import Foundation
import HavenCore
import HavenRuntime

/// Finds which agent CLIs are installed, using a login shell so the user's PATH applies.
enum AgentDetector {
    static func detect(_ completion: @escaping ([Agent: String]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var found: [Agent: String] = [:]
            for agent in Agent.allCases {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-lc", "command -v \(AgentRegistry.adapter(for: agent).executable)"]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = Pipe()
                guard (try? p.run()) != nil else { continue }
                p.waitUntilExit()
                let path = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if p.terminationStatus == 0, !path.isEmpty { found[agent] = path }
            }
            DispatchQueue.main.async { completion(found) }
        }
    }
}

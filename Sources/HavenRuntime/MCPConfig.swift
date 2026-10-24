import Foundation
import HavenCore

/// Builds the `--mcp-config` JSON file Claude Code reads.
public enum MCPConfig {
    /// JSON for the enabled, valid servers, or nil if there are none.
    public static func json(for servers: [MCPServerConfig]) -> Data? {
        var entries: [String: Any] = [:]
        for s in servers where s.enabled {
            let name = sanitized(s.name)
            guard !name.isEmpty, entries[name] == nil else { continue }
            switch s.kind {
            case .command:
                guard !s.command.isEmpty else { continue }
                entries[name] = ["command": s.command, "args": s.args]
            case .url:
                guard let url = URL(string: s.url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
                entries[name] = ["type": "http", "url": s.url]
            }
        }
        guard !entries.isEmpty else { return nil }
        return try? JSONSerialization.data(withJSONObject: ["mcpServers": entries], options: [.prettyPrinted, .sortedKeys])
    }

    /// Server names become tool-name prefixes, so keep them to letters, digits, dashes and underscores.
    static func sanitized(_ name: String) -> String {
        String(name.lowercased().map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Writes the config for one task and returns its path, or nil if there is nothing to pass.
    public static func write(for servers: [MCPServerConfig], taskID: UUID, directory: URL = FileManager.default.temporaryDirectory) -> String? {
        guard let data = json(for: servers) else { return nil }
        let url = directory.appendingPathComponent("haven-mcp-\(taskID.uuidString).json")
        do { try data.write(to: url, options: .atomic); return url.path } catch { return nil }
    }
}

import Foundation
import HavenCore
import HavenRuntime

/// Connected MCP servers, saved as JSON in Application Support.
final class MCPStore {
    private let file = JSONFileStore<MCPServerConfig>.appSupport("mcp-servers.json")
    private(set) var servers: [MCPServerConfig]

    init() { servers = file.load() }

    func add(_ server: MCPServerConfig) { servers.append(server); file.save(servers) }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        guard let i = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[i].enabled = enabled
        file.save(servers)
    }

    func delete(_ id: UUID) { servers.removeAll { $0.id == id }; file.save(servers) }

    /// Config file path for one Claude task, or nil when no server is enabled.
    func configPath(for taskID: UUID) -> String? { MCPConfig.write(for: servers, taskID: taskID) }
}

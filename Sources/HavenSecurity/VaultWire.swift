import Foundation

/// Messages between an agent's helper command and the app, one JSON object per line.
/// There is no field for a credential value in either direction.
public struct WireRequest: Codable, Sendable {
    public var action: String
    public var site: String
    public var field: FillField
    public var reason: String
    public var task: String

    public init(action: String = "login", site: String, field: FillField, reason: String, task: String) {
        self.action = action; self.site = site; self.field = field; self.reason = reason; self.task = task
    }
}

public struct WireResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var message: String
    public init(ok: Bool, message: String) { self.ok = ok; self.message = message }
}

public enum VaultSocket {
    /// `~/Library/Application Support/Haven/vault.sock`
    public static var defaultPath: String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Haven/vault.sock").path
    }

    static func address(_ path: String) -> sockaddr_un? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: bytes.count) { dst in
                for (i, b) in bytes.enumerated() { dst[i] = b }
            }
        }
        return addr
    }
}

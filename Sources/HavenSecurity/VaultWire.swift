import Foundation

/// Messages between an agent's helper command and the app, one JSON object per line.
/// There is no field for a credential value in either direction.
public struct WireRequest: Codable, Sendable {
    /// "login" asks for a credential fill; "approve" asks the person to allow an action.
    public var action: String
    public var site: String
    public var field: FillField
    public var reason: String
    public var task: String
    /// For "approve": one line saying what the agent wants to do.
    public var summary: String
    /// For "mac": the command (see `MacCommand`) and its options.
    public var command: String
    public var args: [String: String]

    public init(action: String = "login", site: String = "", field: FillField = .password, reason: String = "",
                task: String, summary: String = "", command: String = "", args: [String: String] = [:]) {
        self.action = action; self.site = site; self.field = field; self.reason = reason; self.task = task; self.summary = summary
        self.command = command; self.args = args
    }

    // Missing fields fall back to defaults so each action only sends what it needs.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action = try c.decode(String.self, forKey: .action)
        site = try c.decodeIfPresent(String.self, forKey: .site) ?? ""
        field = try c.decodeIfPresent(FillField.self, forKey: .field) ?? .password
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
        args = try c.decodeIfPresent([String: String].self, forKey: .args) ?? [:]
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

extension Data {
    /// Everything before the first newline. Written with `firstIndex` because `split(separator:maxSplits:)` on `Data`
    /// is ambiguous to some Swift toolchains.
    var firstLine: Data {
        guard let newline = firstIndex(of: 0x0A) else { return self }
        return Data(self[startIndex..<newline])
    }
}

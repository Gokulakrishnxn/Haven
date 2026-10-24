import Foundation

/// A Model Context Protocol server the user has connected. Passed to agents that support it.
public struct MCPServerConfig: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case command, url }

    public var id: UUID
    public var name: String
    public var kind: Kind
    /// For `.command`: the program to run.
    public var command: String
    public var args: [String]
    /// For `.url`: the remote endpoint.
    public var url: String
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, kind: Kind, command: String = "", args: [String] = [],
                url: String = "", enabled: Bool = true) {
        self.id = id; self.name = name; self.kind = kind
        self.command = command; self.args = args; self.url = url; self.enabled = enabled
    }

    /// Splits "npx -y server /path" into a command and arguments, honoring simple double and single quotes.
    public static func parse(commandLine: String) -> (command: String, args: [String]) {
        var parts: [String] = []
        var current = "", quote: Character?
        for ch in commandLine {
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == " " || ch == "\t" {
                if !current.isEmpty { parts.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return (parts.first ?? "", Array(parts.dropFirst()))
    }
}

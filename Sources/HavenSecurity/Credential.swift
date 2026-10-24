import Foundation

/// Metadata for a saved login. The password itself lives only in the Keychain.
public struct Credential: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    /// Host the login is valid for, for example "github.com".
    public var site: String
    public var username: String

    public init(id: UUID = UUID(), label: String, site: String, username: String) {
        self.id = id
        self.label = label
        self.site = OriginPolicy.normalize(host: site)
        self.username = username
    }
}

/// Decides whether a page may receive a credential.
public enum OriginPolicy {
    /// Lowercases and strips scheme, path and a leading "www.".
    public static func normalize(host input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        s = s.split(separator: "/", maxSplits: 1).first.map(String.init) ?? s
        if s.hasPrefix("www.") { s.removeFirst(4) }
        return s
    }

    /// True only for an https page whose host equals the credential's site exactly (ignoring "www.").
    /// Subdomains, look-alike hosts, embedded user info and plain http are all refused.
    public static func allows(site: String, pageURL: String) -> Bool {
        guard let url = URL(string: pageURL), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil, let host = url.host else { return false }
        return normalize(host: host) == normalize(host: site)
    }
}

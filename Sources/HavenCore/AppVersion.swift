import Foundation

/// A release version such as 1.2.3, accepting a leading "v" and ignoring a pre-release suffix for ordering.
public struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let parts: [Int]
    public let isPrerelease: Bool

    public init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let core = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let numbers = core.first, !numbers.isEmpty else { return nil }
        let nums = numbers.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !nums.isEmpty, nums.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        parts = nums.map { $0! }
        isPrerelease = core.count > 1
    }

    public var description: String { parts.map(String.init).joined(separator: ".") + (isPrerelease ? "-pre" : "") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        let n = max(a.parts.count, b.parts.count)
        for i in 0..<n {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        // 1.0.0-beta comes before 1.0.0.
        return a.isPrerelease && !b.isPrerelease
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool {
        !(a < b) && !(b < a)
    }
}

/// What a GitHub "latest release" response tells us.
public struct ReleaseInfo: Equatable, Sendable {
    public var version: AppVersion
    public var tag: String
    public var pageURL: URL
    public var notes: String

    /// Parses GitHub's release JSON. Drafts and pre-releases are ignored, and only https links on github.com are accepted.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true,
              let tag = o["tag_name"] as? String, let version = AppVersion(tag),
              let page = (o["html_url"] as? String).flatMap(URL.init(string:)),
              page.scheme == "https", page.host == "github.com" else { return nil }
        return ReleaseInfo(version: version, tag: tag, pageURL: page, notes: String((o["body"] as? String ?? "").prefix(600)))
    }

    /// True when this release is newer than the running version.
    public func isNewer(than current: AppVersion) -> Bool { version > current }
}

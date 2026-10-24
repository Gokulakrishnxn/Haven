import Foundation
import CryptoKit

public enum AuditOutcome: String, Codable, Sendable {
    case approved, denied, refused, failed
}

/// One credential access. Never contains a credential value.
public struct AuditEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { hash }
    public var time: Date
    public var credential: String
    public var site: String
    public var task: String
    public var reason: String
    public var outcome: AuditOutcome
    public var detail: String
    public var previousHash: String
    public var hash: String
}

/// Append-only log where each entry commits to the one before it, so edits or deletions are detectable.
public final class AuditLog: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(url: URL) { self.url = url }

    public static func appSupport() -> AuditLog {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Haven", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return AuditLog(url: base.appendingPathComponent("audit.jsonl"))
    }

    @discardableResult
    public func append(credential: String, site: String, task: String, reason: String,
                       outcome: AuditOutcome, detail: String = "", at time: Date = Date()) -> AuditEntry {
        lock.withLock {
            let previous = readEntries().last?.hash ?? String(repeating: "0", count: 64)
            // Whole seconds, so the stored ISO-8601 time hashes the same as the original.
            let time = Date(timeIntervalSince1970: time.timeIntervalSince1970.rounded(.down))
            var entry = AuditEntry(time: time, credential: credential, site: site, task: task, reason: reason,
                                   outcome: outcome, detail: detail, previousHash: previous, hash: "")
            entry.hash = Self.hash(entry)
            write(entry)
            return entry
        }
    }

    public func entries() -> [AuditEntry] { lock.withLock { readEntries() } }

    /// Index of the first entry that does not match its hash or its predecessor, or nil if the chain is intact.
    public func firstBrokenIndex() -> Int? {
        let all = entries()
        var previous = String(repeating: "0", count: 64)
        for (i, e) in all.enumerated() {
            if e.previousHash != previous || e.hash != Self.hash(e) { return i }
            previous = e.hash
        }
        return nil
    }

    private static func hash(_ e: AuditEntry) -> String {
        let fields = [String(Int(e.time.timeIntervalSince1970)), e.credential, e.site, e.task, e.reason,
                      e.outcome.rawValue, e.detail, e.previousHash]
        let digest = SHA256.hash(data: Data(fields.joined(separator: "\u{1F}").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func readEntries() -> [AuditEntry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? dec.decode(AuditEntry.self, from: Data($0.utf8)) }
    }

    private func write(_ entry: AuditEntry) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard var line = try? enc.encode(entry) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }
}

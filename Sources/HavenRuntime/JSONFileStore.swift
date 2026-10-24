import Foundation

/// Small JSON-on-disk store for a list of values. Writes are atomic.
public struct JSONFileStore<Value: Codable>: Sendable where Value: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// `~/Library/Application Support/Haven/<name>`, created on demand.
    public static func appSupport(_ name: String) -> JSONFileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Haven", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return JSONFileStore(url: base.appendingPathComponent(name))
    }

    public func load() -> [Value] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Value].self, from: data)) ?? []
    }

    public func save(_ values: [Value]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(values) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

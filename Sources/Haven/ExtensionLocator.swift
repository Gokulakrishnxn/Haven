import Foundation

/// Finds the Chrome extension folder: bundled in the app, or in the repository next to a development build.
enum ExtensionLocator {
    static func folderURL() -> URL? {
        let fm = FileManager.default
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("extension"),
           fm.fileExists(atPath: bundled.appendingPathComponent("manifest.json").path) { return bundled }
        // Development: walk up from the executable looking for extension/manifest.json.
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let current = dir else { break }
            let candidate = current.appendingPathComponent("extension")
            if fm.fileExists(atPath: candidate.appendingPathComponent("manifest.json").path) { return candidate }
            dir = current.deletingLastPathComponent()
        }
        return nil
    }
}

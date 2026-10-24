import Foundation
import HavenCore
import HavenUI

enum Preferences {
    private static let d = UserDefaults.standard

    static var defaultAgent: Agent {
        get { Agent(rawValue: d.string(forKey: "defaultAgent") ?? "") ?? .claudeCode }
        set { d.set(newValue.rawValue, forKey: "defaultAgent") }
    }

    static var showStatusPill: Bool {
        get { d.object(forKey: "showStatusPill") as? Bool ?? true }
        set { d.set(newValue, forKey: "showStatusPill") }
    }

    static var onboarded: Bool {
        get { d.bool(forKey: "onboarded") }
        set { d.set(newValue, forKey: "onboarded") }
    }

    static var displayName: String {
        get { d.string(forKey: "displayName") ?? NSFullUserName() }
        set { d.set(newValue, forKey: "displayName") }
    }

    static var email: String {
        get { d.string(forKey: "email") ?? "" }
        set { d.set(newValue, forKey: "email") }
    }

    /// Folder agents start in. Empty means the user's home folder.
    static var workingFolder: String {
        get { d.string(forKey: "workingFolder") ?? "" }
        set { d.set(newValue, forKey: "workingFolder") }
    }

    static var workingFolderURL: URL? {
        workingFolder.isEmpty ? nil : URL(fileURLWithPath: workingFolder)
    }

    /// Model id last chosen for the default agent. nil means the agent's own default.
    static var defaultModel: String? {
        get { d.string(forKey: "defaultModel") }
        set { d.set(newValue, forKey: "defaultModel") }
    }

    static var composeShortcut: Shortcut {
        get { shortcut("composeShortcut") ?? .composeDefault }
        set { setShortcut(newValue, "composeShortcut") }
    }

    static var annotateShortcut: Shortcut {
        get { shortcut("annotateShortcut") ?? .annotateDefault }
        set { setShortcut(newValue, "annotateShortcut") }
    }

    private static func shortcut(_ key: String) -> Shortcut? {
        d.data(forKey: key).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    }

    private static func setShortcut(_ value: Shortcut, _ key: String) {
        d.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

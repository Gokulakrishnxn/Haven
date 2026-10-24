import Foundation

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
}

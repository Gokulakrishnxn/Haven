import AppKit
import ApplicationServices
import HavenCore

enum ContextCapture {
    /// Call before showing the composer, while the previous app is still frontmost.
    static func capture() -> TaskContext {
        let app = NSWorkspace.shared.frontmostApplication
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return TaskContext()
        }
        return TaskContext(appName: app.localizedName, selectedText: selectedText(in: app), tab: browserTab(of: app))
    }

    /// Browsers whose scripting dictionary exposes the active tab. Value is the "tab" noun style.
    private static let browsers: [String: Bool] = [
        "com.google.Chrome": false, "com.brave.Browser": false, "com.microsoft.edgemac": false,
        "company.thebrowser.Browser": false,  // Arc
        "com.apple.Safari": true,
    ]

    /// Reads the front window's active tab through Apple Events. macOS asks for Automation
    /// permission the first time, per browser; if it is declined the tab is simply omitted.
    static func browserTab(of app: NSRunningApplication) -> BrowserTab? {
        guard let id = app.bundleIdentifier, let isSafari = browsers[id] else { return nil }
        let source = isSafari
            ? "tell application id \"\(id)\" to return (URL of current tab of front window) & linefeed & (name of current tab of front window)"
            : "tell application id \"\(id)\" to return (URL of active tab of front window) & linefeed & (title of active tab of front window)"
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else { return nil }
        let parts = result.components(separatedBy: "\n")
        guard let url = parts.first, !url.isEmpty else { return nil }
        return BrowserTab(title: parts.dropFirst().joined(separator: "\n"), url: url)
    }

    /// Reads the focused element's selection through Accessibility. Returns nil
    /// (without prompting) when permission has not been granted.
    private static func selectedText(in app: NSRunningApplication) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}

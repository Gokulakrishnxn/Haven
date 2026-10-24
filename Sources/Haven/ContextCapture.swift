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
        return TaskContext(appName: app.localizedName, selectedText: selectedText(in: app))
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

import AppKit
import ApplicationServices

/// What lives under a screen point, in global top-left coordinates.
struct ElementInfo {
    var app: String?
    var role: String?
    var title: String?
    var value: String?
    var frame: CGRect?
}

enum ElementProbe {
    /// Apps already asked to expose their page contents.
    private static var prepared = Set<Int32>()

    /// Chromium-based apps (Chrome, Electron apps such as Slack or Claude) build their accessibility
    /// tree only when a client asks for it; until then every point reports one window-sized element.
    /// `AXManualAccessibility` is the opt-in they honor, with none of the window-management side
    /// effects of `AXEnhancedUserInterface`. The tree is built in the background, so ask early.
    static func prepare(pid: Int32) {
        guard AXIsProcessTrusted(), !prepared.contains(pid) else { return }
        prepared.insert(pid)
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Asks every app with an on-screen window to expose its contents.
    static func prepareVisibleApps() {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
        let own = ProcessInfo.processInfo.processIdentifier
        for w in windows where (w[kCGWindowLayer as String] as? Int) == 0 {
            if let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != own { prepare(pid: pid) }
        }
    }

    /// Roles that are containers rather than things a person points at.
    private static let coarseRoles: Set<String> = ["AXWebArea", "AXWindow", "AXScrollArea", "AXSplitGroup", "AXGroup"]

    /// Finds the frontmost on-screen window under the point (ignoring Haven's own overlay),
    /// then asks that app's Accessibility tree for the element there.
    static func element(at point: CGPoint) -> ElementInfo? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for w in windows {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                  case let windowRect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0),
                  windowRect.contains(point)
            else { continue }

            var info = ElementInfo(app: NSRunningApplication(processIdentifier: pid)?.localizedName)
            guard AXIsProcessTrusted() else { return info }

            prepare(pid: pid)
            var ref: AXUIElement?
            let app = AXUIElementCreateApplication(pid)
            guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &ref) == .success, let el = ref else { return info }

            info.role = string(el, kAXRoleAttribute)
            info.title = string(el, kAXTitleAttribute) ?? string(el, kAXDescriptionAttribute)
            info.value = string(el, kAXValueAttribute)
            info.frame = frame(of: el)

            // A container that fills most of the window means the app is not exposing finer
            // elements. Highlighting it would just outline the whole window, so report no frame
            // and let the person pin the spot or drag a region instead.
            if let f = info.frame, coarseRoles.contains(info.role ?? ""),
               f.width * f.height >= windowRect.width * windowRect.height * 0.6 {
                info.frame = nil
            }
            return info
        }
        return nil
    }

    private static func string(_ el: AXUIElement, _ attr: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v as? String
    }

    private static func frame(of el: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}

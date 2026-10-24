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
    /// Finds the frontmost on-screen window under the point (ignoring Haven's own overlay),
    /// then asks that app's Accessibility tree for the element there.
    static func element(at point: CGPoint) -> ElementInfo? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for w in windows {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                  CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0).contains(point)
            else { continue }

            var info = ElementInfo(app: NSRunningApplication(processIdentifier: pid)?.localizedName)
            guard AXIsProcessTrusted() else { return info }

            var ref: AXUIElement?
            let app = AXUIElementCreateApplication(pid)
            guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &ref) == .success, let el = ref else { return info }

            info.role = string(el, kAXRoleAttribute)
            info.title = string(el, kAXTitleAttribute) ?? string(el, kAXDescriptionAttribute)
            info.value = string(el, kAXValueAttribute)
            info.frame = frame(of: el)
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

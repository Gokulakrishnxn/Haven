import AppKit
import ApplicationServices
import HavenSecurity

/// Carries out Mac-control commands for agents through Accessibility. Policy, permission and audit are
/// handled by the caller; this class only does the work and refuses protected apps and password fields.
@MainActor
final class MacController {
    struct Failure: Error { let message: String }

    /// Elements from the latest snapshot, by reference. Replaced by each new snapshot.
    private var refs: [String: AXUIElement] = [:]
    private var refPIDs: [String: pid_t] = [:]

    private static let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
        "AXMenuItem", "AXLink", "AXComboBox", "AXTab", "AXSlider", "AXSecureTextField", "AXDisclosureTriangle",
    ]

    func run(_ command: MacCommand, args: [String: String]) async throws -> String {
        if command == .status { return status() }
        guard AXIsProcessTrusted() else {
            throw Failure(message: "Haven needs Accessibility permission to see and control apps. Ask the person to enable it in Haven > Settings > Privacy.")
        }
        switch command {
        case .status: return status()
        case .listApps: return listApps()
        case .listWindows: return listWindows()
        case .snapshot: return try snapshot(app: args["app"])
        case .click: return try click(args)
        case .type: return try await type(args)
        case .key: return try key(args)
        case .scroll: return try scroll(args)
        case .openApp: return try await openApp(args)
        case .activateApp: return try activateApp(args)
        }
    }

    // MARK: Read-only

    private func status() -> String {
        "Accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted"). "
        + "Password managers, Keychain Access and System Settings are off limits. Passwords can only be used through haven-vault."
    }

    private var ownPID: pid_t { ProcessInfo.processInfo.processIdentifier }

    private func listApps() -> String {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let lines = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !MacPolicy.isBlocked(bundleID: $0.bundleIdentifier) }
            .map { "\($0.localizedName ?? "?") (\($0.bundleIdentifier ?? "?"))\($0.processIdentifier == front ? " [frontmost]" : "")" }
        return lines.isEmpty ? "No apps are running." : lines.joined(separator: "\n")
    }

    private func listWindows() -> String {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return "No windows." }
        let lines: [String] = windows.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0, let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  !MacPolicy.isBlocked(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier) else { return nil }
            return "\(w[kCGWindowOwnerName as String] as? String ?? "?") @\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)) \(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0))"
        }
        return lines.isEmpty ? "No windows." : lines.joined(separator: "\n")
    }

    /// The named app, or the frontmost one that is not Haven.
    func targetApp(named name: String?) throws -> NSRunningApplication {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
        let app: NSRunningApplication?
        if let name, !name.isEmpty {
            let wanted = name.lowercased()
            app = apps.first { $0.bundleIdentifier?.lowercased() == wanted || $0.localizedName?.lowercased() == wanted }
                ?? apps.first { $0.localizedName?.lowercased().contains(wanted) == true }
        } else if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            app = front
        } else {
            app = topWindowOwner()
        }
        guard let app else { throw Failure(message: name.map { "No running app matches \"\($0)\". Try list-apps." } ?? "No app is in front.") }
        if MacPolicy.isBlocked(bundleID: app.bundleIdentifier) {
            throw Failure(message: "\(app.localizedName ?? "That app") is protected. Haven does not read or control it.")
        }
        return app
    }

    private func topWindowOwner() -> NSRunningApplication? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for w in windows where (w[kCGWindowLayer as String] as? Int) == 0 {
            if let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID, let app = NSRunningApplication(processIdentifier: pid) { return app }
        }
        return nil
    }

    private func snapshot(app name: String?) throws -> String {
        let app = try targetApp(named: name)
        ElementProbe.prepare(pid: app.processIdentifier)
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = copy(axApp, kAXFocusedWindowAttribute) ?? copy(axApp, kAXMainWindowAttribute)
                ?? (copyArray(axApp, kAXWindowsAttribute).first) else {
            throw Failure(message: "\(app.localizedName ?? "That app") has no open window to read.")
        }
        refs = [:]
        refPIDs = [:]
        var counter = 0
        var visited = 0
        let root = node(for: window, pid: app.processIdentifier, depth: 0, counter: &counter, visited: &visited)
        return "App: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"))\n" + SnapshotRenderer.render(root)
    }

    private func node(for el: AXUIElement, pid: pid_t, depth: Int, counter: inout Int, visited: inout Int) -> SnapshotNode {
        visited += 1
        let role = string(el, kAXRoleAttribute) ?? "AXUnknown"
        var label = string(el, kAXTitleAttribute) ?? string(el, kAXDescriptionAttribute) ?? ""
        if label.isEmpty, role == "AXStaticText" || role == "AXTextField" || role == "AXTextArea" || role == "AXLink" {
            label = role == "AXTextField" || role == "AXTextArea" ? "" : (string(el, kAXValueAttribute) ?? "")
        }
        if label.isEmpty { label = string(el, kAXHelpAttribute) ?? string(el, kAXPlaceholderValueAttribute) ?? "" }
        label = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))

        var ref: String?
        if Self.interactiveRoles.contains(role) {
            counter += 1
            ref = "e\(counter)"
            refs[ref!] = el
            refPIDs[ref!] = pid
        }
        var children: [SnapshotNode] = []
        if depth < 14 && visited < 700 {
            for child in copyArray(el, kAXChildrenAttribute) {
                if visited >= 700 { break }
                children.append(node(for: child, pid: pid, depth: depth + 1, counter: &counter, visited: &visited))
            }
        }
        let f = frame(of: el).map { (x: Int($0.minX), y: Int($0.minY), w: Int($0.width), h: Int($0.height)) }
        return SnapshotNode(role: role, label: label, ref: ref, frame: f, children: children)
    }

    // MARK: Mutating

    private func element(_ args: [String: String]) throws -> (AXUIElement, pid_t)? {
        guard let ref = args["ref"] else { return nil }
        guard let el = refs[ref], let pid = refPIDs[ref] else {
            throw Failure(message: "Unknown reference \(ref). Take a new snapshot first; references change each time.")
        }
        if MacPolicy.isBlocked(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier) {
            throw Failure(message: "That app is protected.")
        }
        return (el, pid)
    }

    private func point(_ args: [String: String]) -> CGPoint? {
        guard let x = args["x"].flatMap(Double.init), let y = args["y"].flatMap(Double.init) else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func guardFrontApp() throws {
        if let front = NSWorkspace.shared.frontmostApplication, MacPolicy.isBlocked(bundleID: front.bundleIdentifier) {
            throw Failure(message: "\(front.localizedName ?? "The front app") is protected. Haven will not control it.")
        }
    }

    private func click(_ args: [String: String]) throws -> String {
        try guardFrontApp()
        if let (el, _) = try element(args) {
            if AXUIElementPerformAction(el, kAXPressAction as CFString) == .success { return "Pressed \(args["ref"] ?? "")." }
            guard let f = frame(of: el) else { throw Failure(message: "That element cannot be pressed and has no position.") }
            mouseClick(at: CGPoint(x: f.midX, y: f.midY))
            return "Clicked \(args["ref"] ?? "") at its center."
        }
        guard let p = point(args) else { throw Failure(message: "click needs --ref eN or --x and --y.") }
        if let owner = ownerBundleID(at: p), MacPolicy.isBlocked(bundleID: owner) { throw Failure(message: "That app is protected.") }
        mouseClick(at: p)
        return "Clicked at \(Int(p.x)),\(Int(p.y))."
    }

    private func type(_ args: [String: String]) async throws -> String {
        guard let text = args["text"], !text.isEmpty else { throw Failure(message: "type needs --text.") }
        guard text.count <= 2000 else { throw Failure(message: "Text is too long (limit 2000 characters).") }
        try guardFrontApp()
        var target: AXUIElement?
        if let (el, _) = try element(args) {
            target = el
            AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            try await Task.sleep(nanoseconds: 150_000_000)
        } else {
            var focused: CFTypeRef?
            if AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success {
                target = (focused as! AXUIElement)
            }
        }
        // Passwords go through haven-vault, never through the agent.
        if let target, string(target, kAXSubroleAttribute) == "AXSecureTextField" || string(target, kAXRoleAttribute) == "AXSecureTextField" {
            throw Failure(message: "Refusing to type into a password field. Use haven-vault login instead.")
        }
        KeyTyper.type(text)
        return "Typed \(text.count) characters."
    }

    private func key(_ args: [String: String]) throws -> String {
        guard let combo = args["combo"].flatMap(KeyCombo.parse) else { throw Failure(message: "key needs --combo such as cmd+s, return, or option+left.") }
        try guardFrontApp()
        KeyTyper.press(keyCode: combo.keyCode, flags: combo.flags)
        return "Pressed \(args["combo"] ?? "")."
    }

    private func scroll(_ args: [String: String]) throws -> String {
        guard let dy = args["dy"].flatMap({ Int32($0) }) else { throw Failure(message: "scroll needs --dy, a number of lines (positive scrolls up).") }
        try guardFrontApp()
        var location = point(args)
        if location == nil, let (el, _) = try element(args), let f = frame(of: el) { location = CGPoint(x: f.midX, y: f.midY) }
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: max(-50, min(50, dy)), wheel2: 0, wheel3: 0)
        if let location { event?.location = location }
        event?.post(tap: .cghidEventTap)
        return "Scrolled \(dy) lines."
    }

    private func openApp(_ args: [String: String]) async throws -> String {
        guard let name = args["name"], !name.isEmpty else { throw Failure(message: "open-app needs --name.") }
        let ws = NSWorkspace.shared
        var url: URL? = name.contains(".") ? ws.urlForApplication(withBundleIdentifier: name) : nil
        if url == nil {
            for dir in ["/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities"] {
                let candidate = URL(fileURLWithPath: "\(dir)/\(name).app")
                if FileManager.default.fileExists(atPath: candidate.path) { url = candidate; break }
            }
        }
        guard let url else { throw Failure(message: "Could not find an app named \"\(name)\".") }
        if MacPolicy.isBlocked(bundleID: Bundle(url: url)?.bundleIdentifier) { throw Failure(message: "\(name) is protected.") }
        _ = try await ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return "Opened \(name)."
    }

    private func activateApp(_ args: [String: String]) throws -> String {
        let app = try targetApp(named: args["name"])
        app.activate()
        return "Brought \(app.localizedName ?? "the app") to the front."
    }

    // MARK: Helpers

    private func mouseClick(at p: CGPoint) {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }

    private func ownerBundleID(at point: CGPoint) -> String? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for w in windows where (w[kCGWindowLayer as String] as? Int) == 0 {
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0).contains(point) else { continue }
            return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        }
        return nil
    }

    private func string(_ el: AXUIElement, _ attr: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v as? String
    }

    private func copy(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success, let v else { return nil }
        return (v as! AXUIElement)
    }

    private func copyArray(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return [] }
        return (v as? [AXUIElement]) ?? []
    }

    private func frame(of el: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}

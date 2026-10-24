import Foundation

/// What an agent can ask the Mac-control helper to do.
public enum MacCommand: String, Sendable {
    case status
    case listApps = "list-apps"
    case listWindows = "list-windows"
    case snapshot
    case click, type, key, scroll
    case openApp = "open-app"
    case activateApp = "activate-app"

    /// Commands that change something on screen. These need the person's permission for the task.
    public var mutates: Bool {
        switch self {
        case .click, .type, .key, .scroll, .openApp, .activateApp: return true
        case .status, .listApps, .listWindows, .snapshot: return false
        }
    }
}

public enum MacPolicy {
    /// Apps an agent may never read or control: they hold secrets or can change security settings.
    public static let blockedBundleIDs: Set<String> = [
        "com.apple.systempreferences", "com.apple.keychainaccess", "com.apple.Passwords",
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.lastpass.LastPass", "org.keepassxc.keepassxc", "com.dashlane.dashlanephonefinal",
    ]

    public static func isBlocked(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return blockedBundleIDs.contains(bundleID)
    }
}

/// A key press with modifiers, parsed from text like "cmd+shift+4" or "return".
public struct KeyCombo: Equatable, Sendable {
    public var keyCode: UInt16
    /// CGEventFlags raw bits: shift 0x20000, control 0x40000, option 0x80000, command 0x100000.
    public var flags: UInt64

    private static let keys: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
        "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50,
        "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]
    private static let modifiers: [String: UInt64] = [
        "shift": 0x20000, "ctrl": 0x40000, "control": 0x40000, "alt": 0x80000, "option": 0x80000, "opt": 0x80000,
        "cmd": 0x100000, "command": 0x100000,
    ]

    public static func parse(_ text: String) -> KeyCombo? {
        let parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = parts.last, let code = keys[last] else { return nil }
        var flags: UInt64 = 0
        for m in parts.dropLast() {
            guard let bit = modifiers[m] else { return nil }
            flags |= bit
        }
        return KeyCombo(keyCode: code, flags: flags)
    }
}

/// One element of a window's accessibility tree, ready to print.
public struct SnapshotNode: Sendable {
    public var role: String
    public var label: String
    /// Reference an agent can pass to click or type, or nil for non-interactive elements.
    public var ref: String?
    public var frame: (x: Int, y: Int, w: Int, h: Int)?
    public var children: [SnapshotNode]

    public init(role: String, label: String, ref: String? = nil, frame: (x: Int, y: Int, w: Int, h: Int)? = nil, children: [SnapshotNode] = []) {
        self.role = role; self.label = label; self.ref = ref; self.frame = frame; self.children = children
    }
}

public enum SnapshotRenderer {
    /// Indented outline, one element per line, for example:
    /// `  [e4] button "Save" @412,640 96x36`
    public static func render(_ root: SnapshotNode, maxLines: Int = 400, maxChars: Int = 30_000) -> String {
        var lines: [String] = []
        var truncated = false

        func walk(_ node: SnapshotNode, depth: Int) {
            if lines.count >= maxLines { truncated = true; return }
            let shortRole = node.role.hasPrefix("AX") ? String(node.role.dropFirst(2)).lowercased() : node.role.lowercased()
            if node.ref != nil || !node.label.isEmpty || depth == 0 {
                var line = String(repeating: "  ", count: depth) + (node.ref.map { "[\($0)] " } ?? "") + shortRole
                if !node.label.isEmpty { line += " \"\(node.label.replacingOccurrences(of: "\n", with: " "))\"" }
                if let f = node.frame { line += " @\(f.x),\(f.y) \(f.w)x\(f.h)" }
                lines.append(line)
            }
            // Containers with no label are flattened so the outline stays readable.
            let next = (node.ref != nil || !node.label.isEmpty || depth == 0) ? depth + 1 : depth
            for child in node.children { walk(child, depth: next) }
        }
        walk(root, depth: 0)

        var out = lines.joined(separator: "\n")
        if out.count > maxChars { out = String(out.prefix(maxChars)); truncated = true }
        if truncated { out += "\n… (outline truncated)" }
        return out
    }
}

import AppKit

/// Posts keyboard events: typed text, and key combinations. Used by secure fill and Mac control.
enum KeyTyper {
    /// Types text as key events, 16 UTF-16 units at a time. Never touches the clipboard.
    @MainActor static func type(_ text: String) {
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            let chunk = Array(units[i..<min(i + 16, units.count)])
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
                event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event?.post(tap: .cghidEventTap)
            }
            i += 16
        }
    }

    @MainActor static func press(keyCode: UInt16, flags: UInt64) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down)
            event?.flags = CGEventFlags(rawValue: flags)
            event?.post(tap: .cghidEventTap)
        }
    }
}

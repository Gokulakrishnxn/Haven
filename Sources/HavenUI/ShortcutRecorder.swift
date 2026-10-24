import SwiftUI
import AppKit

/// A global shortcut: a Carbon key code and Carbon modifier mask, plus how to show it.
public struct Shortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.label = label
    }

    public static let composeDefault = Shortcut(keyCode: 49, modifiers: 2048, label: "⌥Space")
    public static let annotateDefault = Shortcut(keyCode: 49, modifiers: 2048 | 512, label: "⌥⇧Space")

    /// Carbon modifier bits: cmd 256, shift 512, option 2048, control 4096.
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= 256 }
        if flags.contains(.shift) { m |= 512 }
        if flags.contains(.option) { m |= 2048 }
        if flags.contains(.control) { m |= 4096 }
        return m
    }

    static func glyphs(_ modifiers: UInt32) -> String {
        (modifiers & 4096 != 0 ? "⌃" : "") + (modifiers & 2048 != 0 ? "⌥" : "") +
        (modifiers & 512 != 0 ? "⇧" : "") + (modifiers & 256 != 0 ? "⌘" : "")
    }

    /// Builds a shortcut from a key press, or nil if it has no modifier (it would hijack normal typing).
    static func from(event: NSEvent) -> Shortcut? {
        let mods = carbonModifiers(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        guard mods != 0 else { return nil }
        let names: [UInt16: String] = [49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let key = names[event.keyCode] ?? (event.charactersIgnoringModifiers?.uppercased() ?? "?")
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods, label: glyphs(mods) + key)
    }
}

/// Button that records the next key combination you press.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut

    init(shortcut: Binding<Shortcut>) { _shortcut = shortcut }

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onRecord = { context.coordinator.set($0) }
        return b
    }

    func updateNSView(_ b: RecorderButton, context: Context) {
        context.coordinator.binding = $shortcut
        b.current = shortcut.label
    }

    func makeCoordinator() -> Coordinator { Coordinator(binding: $shortcut) }

    final class Coordinator {
        var binding: Binding<Shortcut>
        init(binding: Binding<Shortcut>) { self.binding = binding }
        func set(_ s: Shortcut) { binding.wrappedValue = s }
    }

    final class RecorderButton: NSButton {
        var onRecord: (Shortcut) -> Void = { _ in }
        private var recording = false { didSet { refresh() } }
        var current = "" { didSet { refresh() } }

        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded
            target = self
            action = #selector(begin)
            setButtonType(.momentaryPushIn)
            refresh()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 130, height: 24) }

        private func refresh() { title = recording ? "Press shortcut…" : current }

        @objc private func begin() {
            recording = true
            window?.makeFirstResponder(self)
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == 53 { recording = false; return }  // esc cancels
            if let shortcut = Shortcut.from(event: event) {
                recording = false
                onRecord(shortcut)
            } else {
                NSSound.beep()  // needs at least one modifier
            }
        }
    }
}

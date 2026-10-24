import AppKit
import ApplicationServices
import HavenSecurity

/// Types a value into the focused field, but only after confirming through Accessibility that
/// the field really is the kind of field the request names. The value is typed as key events,
/// so it never touches the clipboard and never passes through the agent.
struct SystemFieldFiller: FieldFiller {
    func fill(_ value: String, field: FillField) async -> String? {
        guard AXIsProcessTrusted() else {
            return "Haven needs Accessibility permission to fill fields. Enable it in Settings."
        }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return "No field is focused. Click the login field first."
        }
        let el = element as! AXUIElement
        let role = string(el, kAXRoleAttribute)
        let subrole = string(el, kAXSubroleAttribute)
        let isSecure = subrole == "AXSecureTextField"

        switch field {
        case .password:
            guard isSecure else { return "The focused field is not a password field." }
        case .username:
            guard !isSecure, ["AXTextField", "AXTextArea", "AXComboBox"].contains(role ?? "") else {
                return "The focused field is not a text field for a username."
            }
        }
        await MainActor.run { KeyTyper.type(value) }
        return nil
    }

    private func string(_ el: AXUIElement, _ attr: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v as? String
    }
}

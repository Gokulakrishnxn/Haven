import AppKit

/// Visual tokens from docs/design.md §17. Everything uses system colors so
/// light, dark and accent changes work without extra code.
enum Theme {
    static let radiusControl: CGFloat = 8
    static let radiusPanel: CGFloat = 14
    static let spacing: CGFloat = 4  // base grid unit

    static let captionFont = NSFont.systemFont(ofSize: 11)
    static let bodyFont = NSFont.systemFont(ofSize: 13)
    static let titleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let inputFont = NSFont.systemFont(ofSize: 18)
    static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    static func color(for status: HavenTask.Status) -> NSColor {
        switch status {
        case .working: return .systemOrange
        case .done: return .systemGreen
        case .failed: return .systemRed
        case .cancelled: return .secondaryLabelColor
        }
    }

    /// Standard translucent panel background.
    static func vibrancy(material: NSVisualEffectView.Material = .hudWindow, radius: CGFloat = radiusPanel) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = radius
        v.layer?.masksToBounds = true
        return v
    }

    static func label(_ text: String = "", font: NSFont = bodyFont, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font
        l.textColor = color
        return l
    }
}

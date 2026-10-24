import SwiftUI

/// Design tokens from docs/design.md §17. System colors and materials only,
/// so light, dark and accent changes need no extra code.
public enum HavenTheme {
    /// Window background and flat card fill shared by every screen (near-black, like the composer).
    public static let canvas = Color(white: 0.055)
    public static let surface = Color(white: 0.085)
    public static let hairline = Color.white.opacity(0.09)

    public static let radiusPanel: CGFloat = 18
    public static let radiusControl: CGFloat = 8
    public static let space: CGFloat = 4  // base grid unit

    public static func color(for state: TaskState) -> Color {
        switch state {
        case .working: return .orange
        case .done: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }
}

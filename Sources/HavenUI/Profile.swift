import SwiftUI

/// Round avatar with the person's initials on a gradient derived from their name.
public struct AvatarView: View {
    let name: String
    var size: CGFloat

    public init(name: String, size: CGFloat = 40) { self.name = name; self.size = size }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "H" : String(parts).uppercased()
    }

    private var hue: Double {
        Double(name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
    }

    public var body: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(hue: hue, saturation: 0.55, brightness: 0.95),
                         Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

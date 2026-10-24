import AppKit
import SwiftUI

/// Haven's soft H companion. Its eyes are transparent cutouts, so the mark
/// works with any foreground style and on both light and dark surfaces.
public struct HavenLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let animated: Bool

    public init(animated: Bool = false) {
        self.animated = animated
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated || reduceMotion)) { context in
            let moving = animated && !reduceMotion
            let time = moving ? context.date.timeIntervalSinceReferenceDate : 0
            let breath = moving ? (1 - cos(time * .pi * 2 / 4)) / 2 : 0
            let blink = moving ? Self.eyeOpenness(at: time) : 1

            HavenMark(eyeOpenness: blink, breath: breath)
                .fill(style: FillStyle(eoFill: true))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Matches the SVG blink: open at 42%, closed at 44%, open at 46% of 5.2s.
    private static func eyeOpenness(at time: TimeInterval) -> CGFloat {
        let phase = time.truncatingRemainder(dividingBy: 5.2) / 5.2
        guard phase > 0.42 && phase < 0.46 else { return 1 }
        return 1 - 0.88 * (1 - abs(phase - 0.44) / 0.02)
    }
}

/// Native assets derived from the same outline used by HavenLogo.
public enum HavenBrand {
    /// A static template lets macOS choose the right color for the menu bar.
    /// The eyes are omitted here to keep the silhouette crisp at menu-bar size.
    public static var menuBarImage: NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(HavenMarkGeometry.path(in: rect,
                                                  viewBox: CGRect(x: 16, y: 16, width: 224, height: 224)))
            context.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

private struct HavenMark: Shape {
    let eyeOpenness: CGFloat
    let breath: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(HavenMarkGeometry.path(in: rect))
        let side = min(rect.width, rect.height)
        let scale = side / 256
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let eyeHeight = 22 * eyeOpenness
        for x: CGFloat in [106, 138] {
            let eye = CGRect(x: origin.x + x * scale,
                             y: origin.y + (128 - eyeHeight / 2) * scale,
                             width: 12 * scale,
                             height: eyeHeight * scale)
            path.addRoundedRect(in: eye, cornerSize: CGSize(width: 6 * scale, height: 6 * scale * eyeOpenness))
        }
        // Apply the SVG's midpoint transform in viewBox units so the motion
        // stays equally subtle in both a 22-point pill and a larger welcome mark.
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY - 3 * scale * breath)
            .scaledBy(x: 1 + 0.018 * breath, y: 1 - 0.015 * breath)
            .translatedBy(x: -rect.midX, y: -rect.midY)
        return path.applying(transform)
    }
}

private enum HavenMarkGeometry {
    static func path(in rect: CGRect, viewBox: CGRect = CGRect(x: 0, y: 0, width: 256, height: 256)) -> CGPath {
        let side = min(rect.width, rect.height)
        let scale = side / max(viewBox.width, viewBox.height)
        var transform = CGAffineTransform(translationX: rect.midX - viewBox.midX * scale,
                                          y: rect.midY - viewBox.midY * scale)
            .scaledBy(x: scale, y: scale)
        return outline.copy(using: &transform) ?? outline
    }

    /// Canonical 256 × 256 outline, shared with the SVG brand assets.
    private static let outline: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 72, y: 28))
        path.addCurve(to: CGPoint(x: 104, y: 58), control1: CGPoint(x: 90, y: 28), control2: CGPoint(x: 100, y: 40))
        path.addLine(to: CGPoint(x: 110, y: 84))
        path.addCurve(to: CGPoint(x: 128, y: 100), control1: CGPoint(x: 112, y: 94), control2: CGPoint(x: 118, y: 100))
        path.addCurve(to: CGPoint(x: 146, y: 84), control1: CGPoint(x: 138, y: 100), control2: CGPoint(x: 144, y: 94))
        path.addLine(to: CGPoint(x: 152, y: 58))
        path.addCurve(to: CGPoint(x: 184, y: 28), control1: CGPoint(x: 156, y: 40), control2: CGPoint(x: 166, y: 28))
        path.addCurve(to: CGPoint(x: 224, y: 70), control1: CGPoint(x: 208, y: 28), control2: CGPoint(x: 224, y: 46))
        path.addCurve(to: CGPoint(x: 216, y: 128), control1: CGPoint(x: 224, y: 86), control2: CGPoint(x: 216, y: 104))
        path.addCurve(to: CGPoint(x: 224, y: 186), control1: CGPoint(x: 216, y: 152), control2: CGPoint(x: 224, y: 170))
        path.addCurve(to: CGPoint(x: 184, y: 228), control1: CGPoint(x: 224, y: 210), control2: CGPoint(x: 208, y: 228))
        path.addCurve(to: CGPoint(x: 152, y: 198), control1: CGPoint(x: 166, y: 228), control2: CGPoint(x: 156, y: 216))
        path.addLine(to: CGPoint(x: 146, y: 172))
        path.addCurve(to: CGPoint(x: 128, y: 156), control1: CGPoint(x: 144, y: 162), control2: CGPoint(x: 138, y: 156))
        path.addCurve(to: CGPoint(x: 110, y: 172), control1: CGPoint(x: 118, y: 156), control2: CGPoint(x: 112, y: 162))
        path.addLine(to: CGPoint(x: 104, y: 198))
        path.addCurve(to: CGPoint(x: 72, y: 228), control1: CGPoint(x: 100, y: 216), control2: CGPoint(x: 90, y: 228))
        path.addCurve(to: CGPoint(x: 32, y: 186), control1: CGPoint(x: 48, y: 228), control2: CGPoint(x: 32, y: 210))
        path.addCurve(to: CGPoint(x: 40, y: 128), control1: CGPoint(x: 32, y: 170), control2: CGPoint(x: 40, y: 152))
        path.addCurve(to: CGPoint(x: 32, y: 70), control1: CGPoint(x: 40, y: 104), control2: CGPoint(x: 32, y: 86))
        path.addCurve(to: CGPoint(x: 72, y: 28), control1: CGPoint(x: 32, y: 46), control2: CGPoint(x: 48, y: 28))
        path.closeSubpath()
        return path
    }()
}

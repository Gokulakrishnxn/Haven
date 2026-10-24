import SwiftUI
import HavenCore

/// Simple vector marks for each agent, drawn in code so they scale and follow appearance.
/// These are approximations; swap in official artwork assets if you have the right to use them.
public struct AgentIcon: View {
    let agent: Agent
    var size: CGFloat

    public init(_ agent: Agent, size: CGFloat = 18) { self.agent = agent; self.size = size }

    public var body: some View {
        Group {
            switch agent {
            case .claudeCode: ClaudeMark()
            case .cursor: CursorMark()
            case .codex: Image(systemName: "chevron.left.forwardslash.chevron.right").resizable().scaledToFit().padding(size * 0.2)
            case .grok: Image(systemName: "slash.circle").resizable().scaledToFit().padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Radiating spark in Claude's coral.
struct ClaudeMark: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.85, green: 0.47, blue: 0.34))
                        .frame(width: s * 0.13, height: s * (i % 2 == 0 ? 0.5 : 0.38))
                        .offset(y: -s * (i % 2 == 0 ? 0.25 : 0.19))
                        .rotationEffect(.degrees(Double(i) * 36))
                }
            }
            .frame(width: s, height: s)
        }
    }
}

/// Isometric cube outline in the primary text color.
struct CursorMark: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let r = s * 0.46
            let pts = (0..<6).map { i -> CGPoint in
                let a = Double.pi / 3 * Double(i) - Double.pi / 2
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
            Path { p in
                p.addLines(pts); p.closeSubpath()
                p.move(to: pts[1]); p.addLine(to: c); p.addLine(to: pts[5])
                p.move(to: c); p.addLine(to: pts[3])
            }
            .stroke(Color.primary, style: StrokeStyle(lineWidth: max(1.2, s * 0.09), lineJoin: .round))
        }
    }
}

/// Native menus draw only plain images, so render each icon to an NSImage for them.
/// Claude keeps its color; the others are templates that follow the menu's text color.
@MainActor
public enum AgentIconImage {
    private static var cache: [String: NSImage] = [:]

    public static func image(for agent: Agent, size: CGFloat = 16) -> NSImage {
        let key = "\(agent.rawValue)-\(size)"
        if let hit = cache[key] { return hit }
        let colored = agent == .claudeCode
        let content = AgentIcon(agent, size: size).foregroundStyle(Color.black)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = !colored
        cache[key] = image
        return image
    }
}

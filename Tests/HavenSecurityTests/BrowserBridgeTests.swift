import Foundation
import Testing
@testable import HavenSecurity

/// Stand-in for the extension: a WebSocket client that can pair and answer commands.
private final class FakeExtension: @unchecked Sendable {
    let task: URLSessionWebSocketTask

    init(port: UInt16, origin: String? = nil) {
        var request = URLRequest(url: URL(string: "ws://127.0.0.1:\(port)")!)
        if let origin { request.setValue(origin, forHTTPHeaderField: "Origin") }
        task = URLSession.shared.webSocketTask(with: request)
        task.resume()
    }

    func send(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    func receive() async throws -> [String: Any] {
        switch try await task.receive() {
        case .string(let s): return (try JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:]
        case .data(let d): return (try JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
        @unknown default: return [:]
        }
    }

    /// Answers every command with `reply`, until the connection closes.
    func serve(reply: @escaping @Sendable ([String: Any]) -> [String: Any]) {
        Task {
            while let msg = try? await receive() {
                if let id = msg["id"] as? String {
                    var out = reply(msg); out["id"] = id
                    try? await send(out)
                }
            }
        }
    }
}

/// Each test gets its own port, handed out in sequence so parallel tests never share one. The range sits below the
/// ephemeral port range (49152 and up) so a test client never picks the same number.
private let portLock = NSLock()
nonisolated(unsafe) private var nextTestPort = UInt16.random(in: 20_000...28_000)
private func freePort() -> UInt16 {
    portLock.withLock { nextTestPort += 1; return nextTestPort }
}

private func waitUntil(_ timeout: TimeInterval = 3, _ condition: () -> Bool) async -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end { if condition() { return true }; try? await Task.sleep(nanoseconds: 50_000_000) }
    return condition()
}

@Suite struct BrowserBridgeTests {
    @Test func pairedExtensionReceivesCommandsAndAnswers() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "secret-code", port: port, allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }

        let ext = FakeExtension(port: port)
        try await ext.send(["type": "hello", "token": "secret-code"])
        #expect(try await ext.receive()["type"] as? String == "welcome")
        ext.serve { msg in ["ok": true, "message": "ran \(msg["cmd"] as? String ?? "") with \((msg["args"] as? [String: String])?["ref"] ?? "")"] }

        #expect(await waitUntil { bridge.isConnected })
        let result = await bridge.send("click", args: ["ref": "b3"])
        #expect(result.ok)
        #expect(result.message == "ran click with b3")
    }

    @Test func wrongPairingCodeIsRejected() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "secret-code", port: port, allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }

        let ext = FakeExtension(port: port)
        try await ext.send(["type": "hello", "token": "guess"])
        // The server says "rejected" and closes; the close can win the race, so either outcome is a rejection.
        let reply = try? await ext.receive()
        #expect(reply == nil || reply?["type"] as? String == "rejected")
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(!bridge.isConnected)
        let result = await bridge.send("snapshot", args: [:])
        #expect(!result.ok)
        #expect(result.message.contains("not connected"))
    }

    @Test func aWebPageIsTurnedAwayByItsOrigin() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "secret-code", port: port, allowedOrigin: "chrome-extension://abc")
        try bridge.start(); defer { bridge.stop() }

        let page = FakeExtension(port: port, origin: "https://evil.example")
        // Even with the right code, the connection never completes.
        try? await page.send(["type": "hello", "token": "secret-code"])
        _ = try? await page.receive()
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(!bridge.isConnected)
    }

    @Test func theExtensionOriginIsAccepted() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "secret-code", port: port, allowedOrigin: "chrome-extension://abc")
        try bridge.start(); defer { bridge.stop() }

        let ext = FakeExtension(port: port, origin: "chrome-extension://abc")
        try await ext.send(["type": "hello", "token": "secret-code"])
        #expect(try await ext.receive()["type"] as? String == "welcome")
        #expect(await waitUntil { bridge.isConnected })
    }

    @Test func noExtensionMeansAClearError() async throws {
        let bridge = BrowserBridge(token: "x", port: freePort(), allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }
        let result = await bridge.send("snapshot", args: [:])
        #expect(!result.ok)
        #expect(result.message.contains("extension is not connected"))
    }

    @Test func slowBrowserTimesOut() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "t", port: port, allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }
        let ext = FakeExtension(port: port)
        try await ext.send(["type": "hello", "token": "t"])
        _ = try await ext.receive()
        #expect(await waitUntil { bridge.isConnected })
        let result = await bridge.send("snapshot", args: [:], timeout: 0.5)  // the fake never answers
        #expect(!result.ok)
        #expect(result.message.contains("did not answer"))
    }

    @Test func screenshotBytesComeBack() async throws {
        let port = freePort()
        let bridge = BrowserBridge(token: "t", port: port, allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }
        let ext = FakeExtension(port: port)
        try await ext.send(["type": "hello", "token": "t"])
        _ = try await ext.receive()
        ext.serve { _ in ["ok": true, "message": "Screenshot taken.", "image": Data([1, 2, 3]).base64EncodedString()] }
        #expect(await waitUntil { bridge.isConnected })
        let result = await bridge.send("snapshot", args: [:])
        #expect(result.image == Data([1, 2, 3]))
    }
}

@Suite struct PairingTokenTests {
    @Test func tokensAreUniqueAndUrlSafe() {
        let a = PairingToken.make(), b = PairingToken.make()
        #expect(a != b)
        #expect(a.count >= 30)
        #expect(a.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test func tokenIsSavedPrivatelyAndReused() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tok-\(UUID().uuidString)")
        let first = PairingToken.loadOrCreate(at: url)
        #expect(PairingToken.loadOrCreate(at: url) == first)
        #expect((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
        let second = PairingToken.regenerate(at: url)
        #expect(second != first)
        #expect(PairingToken.loadOrCreate(at: url) == second)
    }
}

@Suite struct BrowserCommandTests {
    @Test func readingDoesNotNeedPermissionButChangesDo() {
        for c in [BrowserCommand.status, .listTabs, .snapshot, .extractText, .wait] { #expect(!c.mutates, "\(c)") }
        for c in [BrowserCommand.openTab, .activateTab, .closeTab, .navigate, .back, .forward, .refresh, .click, .type, .select, .scroll] {
            #expect(c.mutates, "\(c)")
        }
    }
}

@Suite struct BridgeExposureTests {
    /// First non-loopback IPv4 address of this machine, if it has one.
    private func lanAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let a = ptr.pointee
            guard let sa = a.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET), (a.ifa_flags & UInt32(IFF_LOOPBACK)) == 0,
                  (a.ifa_flags & UInt32(IFF_UP)) != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            return String(cString: host)
        }
        return nil
    }

    @Test func bridgeIsNotReachableFromOtherAddresses() throws {
        guard let ip = lanAddress() else { return }  // no network interface to test against
        let port = freePort()
        let bridge = BrowserBridge(token: "t", port: port, allowedOrigin: nil)
        try bridge.start(); defer { bridge.stop() }
        Thread.sleep(forTimeInterval: 0.3)

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, ip, &addr.sin_addr)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        #expect(result != 0, "the bridge accepted a connection on \(ip)")
    }
}

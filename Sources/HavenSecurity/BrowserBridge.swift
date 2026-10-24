import Foundation
import Network

/// What an agent can ask the browser helper to do.
public enum BrowserCommand: String, Sendable {
    case status
    case listTabs = "list-tabs"
    case snapshot
    case extractText = "extract-text"
    case openTab = "open-tab", activateTab = "activate-tab", closeTab = "close-tab"
    case navigate, back, forward, refresh
    case click, type, select, scroll
    case wait

    /// Commands that change the page or the browser. These need the person's permission for the task.
    public var mutates: Bool {
        switch self {
        case .status, .listTabs, .snapshot, .extractText, .wait: return false
        default: return true
        }
    }
}

public struct BridgeResult: Sendable {
    public var ok: Bool
    public var message: String
    /// PNG bytes for screenshots.
    public var image: Data?
    public init(ok: Bool, message: String, image: Data? = nil) { self.ok = ok; self.message = message; self.image = image }
}

/// Pairing code shared between the Haven app and the browser extension. It stays on this Mac.
public enum PairingToken {
    public static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    /// Reads the saved code, or creates one (file mode 0600).
    public static func loadOrCreate(at url: URL) -> String {
        if let existing = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), existing.count >= 20 {
            return existing
        }
        return regenerate(at: url)
    }

    @discardableResult
    public static func regenerate(at url: URL) -> String {
        let token = make()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? token.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return token
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Haven/browser-token")
    }
}

/// Local WebSocket server the Haven browser extension connects to.
///
/// Only loopback connections are accepted. The extension must send the pairing code first, and a
/// browser page that tries to connect is turned away by its Origin header (a page cannot fake it)
/// and by not knowing the code.
public final class BrowserBridge: @unchecked Sendable {
    public static let port: UInt16 = 48731
    /// Fixed by the public key in the extension's manifest.
    public static let extensionOrigin = "chrome-extension://cndngolgdahpgimhdelcajjecedloapo"

    private let queue = DispatchQueue(label: "run.haven.browser-bridge")
    private let port: UInt16
    private var token: String
    private let allowedOrigin: String?
    private var listener: NWListener?
    private var active: NWConnection?
    private var pending: [String: CheckedContinuation<BridgeResult, Never>] = [:]
    private var nextID = 0

    public init(token: String, port: UInt16 = BrowserBridge.port, allowedOrigin: String? = BrowserBridge.extensionOrigin) {
        self.token = token
        self.port = port
        self.allowedOrigin = allowedOrigin
    }

    public var isConnected: Bool { queue.sync { active != nil } }

    public func updateToken(_ new: String) {
        queue.sync {
            token = new
            active?.cancel()  // the extension must pair again with the new code
            active = nil
        }
    }

    public func start() throws {
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        let allowed = allowedOrigin
        ws.setClientRequestHandler(queue) { _, headers in
            // A browser page always sends its Origin. Refuse anything that is not the extension.
            if let origin = headers.first(where: { $0.name.lowercased() == "origin" })?.value, let allowed, origin != allowed {
                return NWProtocolWebSocket.Response(status: .reject, subprotocol: nil)
            }
            return NWProtocolWebSocket.Response(status: .accept, subprotocol: nil)
        }
        let params = NWParameters.tcp
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw BridgeError("Bad port") }
        // Bind to 127.0.0.1 only. Restricting the interface type alone still listens on every address.
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: nwPort)
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        queue.sync {
            listener?.cancel(); listener = nil
            active?.cancel(); active = nil
            for (_, c) in pending { c.resume(returning: BridgeResult(ok: false, message: "Haven is shutting down.")) }
            pending = [:]
        }
    }

    /// Sends one command to the extension and waits for its answer.
    public func send(_ command: String, args: [String: String], timeout: TimeInterval = 25) async -> BridgeResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<BridgeResult, Never>) in
            queue.async {
                guard let connection = self.active else {
                    continuation.resume(returning: BridgeResult(ok: false, message: "The Haven browser extension is not connected. Ask the person to install it and pair it in Haven > Settings > Browser."))
                    return
                }
                self.nextID += 1
                let id = "r\(self.nextID)"
                self.pending[id] = continuation
                let payload: [String: Any] = ["id": id, "cmd": command, "args": args]
                if let data = try? JSONSerialization.data(withJSONObject: payload) { self.write(data, to: connection) }
                self.queue.asyncAfter(deadline: .now() + timeout) {
                    if let c = self.pending.removeValue(forKey: id) {
                        c.resume(returning: BridgeResult(ok: false, message: "The browser did not answer in time."))
                    }
                }
            }
        }
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        var paired = false
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.drop(connection) }
            if case .cancelled = state { self?.drop(connection) }
        }
        connection.start(queue: queue)
        // Must pair quickly or be dropped.
        queue.asyncAfter(deadline: .now() + 3) { if !paired { connection.cancel() } }

        func receive() {
            connection.receiveMessage { [weak self] data, context, _, error in
                guard let self, error == nil else { return }
                if let data, let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    if !paired {
                        if object["type"] as? String == "hello", object["token"] as? String == self.token {
                            paired = true
                            self.active?.cancel()
                            self.active = connection
                            self.write(Data(#"{"type":"welcome"}"#.utf8), to: connection)
                        } else {
                            // Say why, then close once the message has gone out.
                            self.write(Data(#"{"type":"rejected"}"#.utf8), to: connection) { connection.cancel() }
                            return
                        }
                    } else if let id = object["id"] as? String, let c = self.pending.removeValue(forKey: id) {
                        let image = (object["image"] as? String).flatMap { Data(base64Encoded: $0) }
                        c.resume(returning: BridgeResult(ok: object["ok"] as? Bool ?? false, message: object["message"] as? String ?? "", image: image))
                    }
                }
                receive()
            }
        }
        receive()
    }

    private func drop(_ connection: NWConnection) {
        if active === connection { active = nil }
    }

    private func write(_ data: Data, to connection: NWConnection, then done: (() -> Void)? = nil) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in done?() })
    }
}

struct BridgeError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

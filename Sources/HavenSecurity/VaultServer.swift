import Foundation

/// Listens on a Unix socket owned by the current user and passes requests to `handler`.
public final class VaultServer: @unchecked Sendable {
    public typealias Handler = @Sendable (WireRequest) async -> WireResponse

    private let path: String
    private let handler: Handler
    private var listenFD: Int32 = -1

    public init(path: String = VaultSocket.defaultPath, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    public func start() throws {
        unlink(path)
        guard var addr = VaultSocket.address(path) else { throw SpawnLikeError("Socket path is too long") }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SpawnLikeError("socket() failed") }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); throw SpawnLikeError("Could not listen on \(path)") }
        chmod(path, 0o600)  // only this user
        listenFD = fd

        Thread.detachNewThread { [weak self] in
            while let self, self.listenFD >= 0 {
                let client = accept(fd, nil, nil)
                if client < 0 { if errno == EINTR { continue } else { break } }
                Thread.detachNewThread { self.serve(client) }
            }
        }
    }

    public func stop() {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        unlink(path)
    }

    private func serve(_ fd: Int32) {
        defer { close(fd) }
        // Refuse other users' processes outright.
        var uid: uid_t = 0, gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { return }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while !data.contains(0x0A), data.count < 16_384 {
            let n = read(fd, &buffer, buffer.count)
            if n <= 0 { break }
            data.append(contentsOf: buffer[0..<n])
        }
        let line = data.split(separator: 0x0A, maxSplits: 1).first.map(Data.init) ?? Data()

        let response: WireResponse
        if let request = try? JSONDecoder().decode(WireRequest.self, from: line), request.action == "login" {
            let semaphore = DispatchSemaphore(value: 0)
            var result = WireResponse(ok: false, message: "No answer.")
            Task { result = await handler(request); semaphore.signal() }
            semaphore.wait()
            response = result
        } else {
            response = WireResponse(ok: false, message: "Unrecognized request.")
        }
        if var out = try? JSONEncoder().encode(response) {
            out.append(0x0A)
            out.withUnsafeBytes { _ = write(fd, $0.baseAddress, out.count) }
        }
    }
}

struct SpawnLikeError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

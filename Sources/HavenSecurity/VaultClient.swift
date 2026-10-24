import Foundation

/// Sends one request to the app and returns its answer. Used by the `haven-vault` command.
public enum VaultClient {
    public static func send(_ request: WireRequest, socketPath: String = VaultSocket.defaultPath) -> WireResponse {
        guard var addr = VaultSocket.address(socketPath) else { return WireResponse(ok: false, message: "Socket path is too long.") }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return WireResponse(ok: false, message: "Could not open a socket.") }
        defer { close(fd) }

        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { return WireResponse(ok: false, message: "Haven is not running.") }

        guard var payload = try? JSONEncoder().encode(request) else { return WireResponse(ok: false, message: "Bad request.") }
        payload.append(0x0A)
        payload.withUnsafeBytes { _ = write(fd, $0.baseAddress, payload.count) }

        // The person may take a while to approve, so wait for the answer.
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while !data.contains(0x0A) {
            let n = read(fd, &buffer, buffer.count)
            if n <= 0 { break }
            data.append(contentsOf: buffer[0..<n])
        }
        let line = data.split(separator: 0x0A, maxSplits: 1).first.map(Data.init) ?? Data()
        return (try? JSONDecoder().decode(WireResponse.self, from: line))
            ?? WireResponse(ok: false, message: "No answer from Haven.")
    }
}

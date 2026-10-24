import Foundation
import Testing
@testable import HavenSecurity

@Suite struct VaultServerTests {
    private func socketPath() -> String { "/tmp/hv-\(UUID().uuidString.prefix(8)).sock" }

    @Test func clientAndServerExchangeOneRequest() async throws {
        let path = socketPath()
        let server = VaultServer(path: path) { request in
            WireResponse(ok: request.site == "github.com", message: "got \(request.field.rawValue) for \(request.task)")
        }
        try server.start()
        defer { server.stop() }

        let response = VaultClient.send(WireRequest(site: "github.com", field: .password, reason: "x", task: "t-1"), socketPath: path)
        #expect(response == WireResponse(ok: true, message: "got password for t-1"))
    }

    @Test func socketIsPrivateToTheUser() throws {
        let path = socketPath()
        let server = VaultServer(path: path) { _ in WireResponse(ok: true, message: "") }
        try server.start()
        defer { server.stop() }
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attrs[.posixPermissions] as? Int) == 0o600)
    }

    @Test func clientReportsWhenAppIsNotRunning() {
        let response = VaultClient.send(WireRequest(site: "a.com", field: .password, reason: "", task: ""), socketPath: socketPath())
        #expect(!response.ok)
        #expect(response.message.contains("not running"))
    }

    @Test func garbageIsRejected() throws {
        let path = socketPath()
        let server = VaultServer(path: path) { _ in WireResponse(ok: true, message: "should not run") }
        try server.start()
        defer { server.stop() }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        defer { close(fd) }
        var addr = try #require(VaultSocket.address(path))
        _ = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        let junk = Array("{\"action\":\"dump\"}\n".utf8)
        _ = write(fd, junk, junk.count)
        var buf = [UInt8](repeating: 0, count: 256)
        let n = read(fd, &buf, buf.count)
        let reply = String(decoding: buf[0..<max(n, 0)], as: UTF8.self)
        #expect(reply.contains("\"ok\":false"))
    }
}

@Suite struct WireRequestTests {
    @Test func approveRequestNeedsOnlyItsOwnFields() throws {
        let json = #"{"action":"approve","summary":"delete the file","reason":"cleanup","task":"t1"}"#
        let r = try JSONDecoder().decode(WireRequest.self, from: Data(json.utf8))
        #expect(r.action == "approve")
        #expect(r.summary == "delete the file")
        #expect(r.site == "")
        #expect(r.field == .password)
    }

    @Test func requestWithoutActionIsRejected() {
        #expect(throws: (any Error).self) { try JSONDecoder().decode(WireRequest.self, from: Data(#"{"site":"a.com"}"#.utf8)) }
    }

    @Test func serverPassesApproveRequestsToTheHandler() async throws {
        let path = "/tmp/hv-\(UUID().uuidString.prefix(8)).sock"
        let server = VaultServer(path: path) { r in WireResponse(ok: r.action == "approve", message: r.summary) }
        try server.start()
        defer { server.stop() }
        let response = VaultClient.send(WireRequest(action: "approve", reason: "r", task: "t", summary: "send the email"), socketPath: path)
        #expect(response == WireResponse(ok: true, message: "send the email"))
    }
}

import Foundation
import Testing
import HavenRuntime
@testable import HavenSecurity

private struct FakeAuth: Authenticator {
    var approve: Bool
    func authenticate(reason: String) async -> Bool { approve }
}

private final class FakeFiller: FieldFiller, @unchecked Sendable {
    var filled: [(String, FillField)] = []
    var problem: String?
    func fill(_ value: String, field: FillField) async -> String? {
        if let problem { return problem }
        filled.append((value, field))
        return nil
    }
}

private let secret = "s3cret-Pa55word!"

private struct Fixture {
    let service: SecureFillService
    let filler: FakeFiller
    let audit: AuditLog
    let vault: CredentialVault
}

private func fixture(approve: Bool = true, page: String? = "https://github.com/login", fillerProblem: String? = nil) throws -> Fixture {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let vault = CredentialVault(file: JSONFileStore(url: dir.appendingPathComponent("c.json")), secrets: InMemorySecretStore())
    try vault.add(label: "GitHub", site: "github.com", username: "octocat", password: secret)
    let filler = FakeFiller()
    filler.problem = fillerProblem
    let audit = AuditLog(url: dir.appendingPathComponent("a.jsonl"))
    let service = SecureFillService(vault: vault, authenticator: FakeAuth(approve: approve), filler: filler, audit: audit,
                                    currentPageURL: { page })
    return Fixture(service: service, filler: filler, audit: audit, vault: vault)
}

private func request(site: String = "github.com", field: FillField = .password) -> FillRequest {
    FillRequest(site: site, field: field, reason: "sign in to review a PR", taskID: "t1", taskTitle: "Review PR")
}

@Suite struct SecureFillTests {
    @Test func approvedFillTypesTheValueAndAudits() async throws {
        let f = try fixture()
        let response = await f.service.handle(request())
        #expect(response.ok)
        #expect(f.filler.filled.count == 1)
        #expect(f.filler.filled[0].0 == secret)
        let entries = f.audit.entries()
        #expect(entries.count == 1)
        #expect(entries[0].outcome == .approved)
        #expect(entries[0].credential == "GitHub")
        #expect(entries[0].site == "github.com")
        #expect(entries[0].task == "Review PR")
    }

    @Test func usernameFieldFillsTheUsername() async throws {
        let f = try fixture()
        _ = await f.service.handle(request(field: .username))
        #expect(f.filler.filled.first?.0 == "octocat")
    }

    @Test func responseAndAuditNeverContainTheSecret() async throws {
        for approve in [true, false] {
            let f = try fixture(approve: approve)
            let response = await f.service.handle(request())
            #expect(!response.message.contains(secret))
            let dump = f.audit.entries().map { "\($0)" }.joined()
            #expect(!dump.contains(secret))
        }
    }

    @Test func deniedTouchIDFillsNothing() async throws {
        let f = try fixture(approve: false)
        let response = await f.service.handle(request())
        #expect(!response.ok)
        #expect(f.filler.filled.isEmpty)
        #expect(f.audit.entries().first?.outcome == .denied)
    }

    @Test func wrongPageIsRefusedBeforeAnyPrompt() async throws {
        let f = try fixture(page: "https://github.com.evil.example/login")
        let response = await f.service.handle(request())
        #expect(!response.ok)
        #expect(f.filler.filled.isEmpty)
        #expect(f.audit.entries().first?.outcome == .refused)
    }

    @Test func noBrowserPageIsRefused() async throws {
        let f = try fixture(page: nil)
        #expect(await f.service.handle(request()).ok == false)
        #expect(f.filler.filled.isEmpty)
    }

    @Test func unknownSiteIsRefused() async throws {
        let f = try fixture()
        let response = await f.service.handle(request(site: "example.org"))
        #expect(!response.ok)
        #expect(f.audit.entries().first?.outcome == .refused)
    }

    @Test func fillerRejectingTheFieldIsAFailureNotASuccess() async throws {
        let f = try fixture(fillerProblem: "The focused field is not a password field.")
        let response = await f.service.handle(request())
        #expect(!response.ok)
        #expect(f.audit.entries().first?.outcome == .failed)
    }

    @Test func removingACredentialRemovesItsSecret() throws {
        let f = try fixture()
        let id = try #require(f.vault.all().first?.id)
        f.vault.remove(id)
        #expect(f.vault.all().isEmpty)
        #expect(f.vault.credential(forSite: "github.com") == nil)
    }
}

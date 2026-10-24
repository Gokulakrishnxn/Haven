import Foundation
import HavenRuntime

/// Saved logins: metadata on disk, passwords in the Keychain.
public final class CredentialVault: @unchecked Sendable {
    private let file: JSONFileStore<Credential>
    private let secrets: SecretStore
    private let lock = NSLock()

    public init(file: JSONFileStore<Credential>, secrets: SecretStore) {
        self.file = file
        self.secrets = secrets
    }

    public static func standard() -> CredentialVault {
        CredentialVault(file: .appSupport("credentials.json"), secrets: KeychainSecretStore())
    }

    public func all() -> [Credential] { lock.withLock { file.load() } }

    public func credential(forSite site: String) -> Credential? {
        let wanted = OriginPolicy.normalize(host: site)
        return all().first { $0.site == wanted }
    }

    @discardableResult
    public func add(label: String, site: String, username: String, password: String) throws -> Credential {
        let credential = Credential(label: label, site: site, username: username)
        try secrets.save(password, for: credential.id)
        lock.withLock { file.save(file.load() + [credential]) }
        return credential
    }

    public func remove(_ id: UUID) {
        try? secrets.delete(id)
        lock.withLock { file.save(file.load().filter { $0.id != id }) }
    }

    /// Only the fill pipeline should call this, and only after approval.
    func secret(for credential: Credential) throws -> String { try secrets.read(credential.id) }
}

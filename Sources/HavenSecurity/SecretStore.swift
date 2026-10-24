import Foundation
import Security

public enum SecretError: Error, Equatable {
    case notFound
    case keychain(Int32)
}

/// Where password values live. Nothing outside this protocol ever stores or reads them.
public protocol SecretStore: Sendable {
    func save(_ secret: String, for id: UUID) throws
    func read(_ id: UUID) throws -> String
    func delete(_ id: UUID) throws
}

/// macOS Keychain, generic-password items under one service name.
public struct KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "run.haven.vault") { self.service = service }

    private func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString]
    }

    public func save(_ secret: String, for id: UUID) throws {
        try? delete(id)
        var q = query(id)
        q[kSecValueData as String] = Data(secret.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecretError.keychain(status) }
    }

    public func read(_ id: UUID) throws -> String {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { throw SecretError.notFound }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw SecretError.keychain(status)
        }
        return value
    }

    public func delete(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretError.keychain(status) }
    }
}

/// For tests.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var values: [UUID: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(_ secret: String, for id: UUID) throws { lock.withLock { values[id] = secret } }

    public func read(_ id: UUID) throws -> String {
        try lock.withLock { guard let v = values[id] else { throw SecretError.notFound }; return v }
    }

    public func delete(_ id: UUID) throws { lock.withLock { _ = values.removeValue(forKey: id) } }
}

import Foundation
import Testing
@testable import HavenSecurity

/// Uses the real Keychain under a throwaway service name, and cleans up after itself.
@Suite struct KeychainSecretStoreTests {
    @Test func saveReadReplaceDelete() throws {
        let store = KeychainSecretStore(service: "run.haven.tests.\(UUID().uuidString)")
        let id = UUID()
        try store.save("first", for: id)
        #expect(try store.read(id) == "first")
        try store.save("second", for: id)
        #expect(try store.read(id) == "second")
        try store.delete(id)
        #expect(throws: SecretError.notFound) { try store.read(id) }
    }
}

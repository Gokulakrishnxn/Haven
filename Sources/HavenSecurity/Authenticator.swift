import Foundation
import LocalAuthentication

/// Asks the person to approve one use of a credential.
public protocol Authenticator: Sendable {
    func authenticate(reason: String) async -> Bool
}

/// Touch ID, falling back to the account password when biometrics are unavailable.
public struct TouchIDAuthenticator: Authenticator {
    public init() {}

    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }
}

import Foundation

public enum FillField: String, Codable, Sendable { case username, password }

/// What an agent asks for. It names a site and a reason; it never receives a value.
public struct FillRequest: Sendable {
    public var site: String
    public var field: FillField
    public var reason: String
    public var taskID: String
    public var taskTitle: String

    public init(site: String, field: FillField, reason: String, taskID: String, taskTitle: String) {
        self.site = site; self.field = field; self.reason = reason; self.taskID = taskID; self.taskTitle = taskTitle
    }
}

/// The answer an agent sees. Deliberately has no field that could carry a credential value.
public struct FillResponse: Equatable, Sendable {
    public var ok: Bool
    public var message: String
    public init(ok: Bool, message: String) { self.ok = ok; self.message = message }
}

/// Puts a value into the verified field on screen. Implemented by the app with Accessibility.
public protocol FieldFiller: Sendable {
    /// Returns an error message if the focused field is not a suitable, verified target.
    func fill(_ value: String, field: FillField) async -> String?
}

/// The whole secure-fill pipeline:
/// find credential, check the page origin, ask for Touch ID, fill the field, write the audit entry.
public final class SecureFillService: @unchecked Sendable {
    private let vault: CredentialVault
    private let authenticator: Authenticator
    private let filler: FieldFiller
    private let audit: AuditLog
    private let currentPageURL: @Sendable () async -> String?

    public init(vault: CredentialVault, authenticator: Authenticator, filler: FieldFiller, audit: AuditLog,
                currentPageURL: @escaping @Sendable () async -> String?) {
        self.vault = vault
        self.authenticator = authenticator
        self.filler = filler
        self.audit = audit
        self.currentPageURL = currentPageURL
    }

    public func handle(_ request: FillRequest) async -> FillResponse {
        func log(_ credential: Credential?, _ outcome: AuditOutcome, _ detail: String) {
            audit.append(credential: credential?.label ?? "(none)", site: OriginPolicy.normalize(host: request.site),
                         task: request.taskTitle, reason: request.reason, outcome: outcome, detail: detail)
        }

        guard let credential = vault.credential(forSite: request.site) else {
            log(nil, .refused, "No saved login for this site")
            return FillResponse(ok: false, message: "No saved login for \(request.site).")
        }

        // Refuse before asking the person anything if the visible page is not the credential's site.
        guard let page = await currentPageURL(), OriginPolicy.allows(site: credential.site, pageURL: page) else {
            log(credential, .refused, "The page in front is not \(credential.site) over https")
            return FillResponse(ok: false, message: "The page in front is not \(credential.site) over https.")
        }

        let prompt = "Haven wants to fill the \(request.field.rawValue) for \(credential.site) for the task “\(request.taskTitle)”."
        guard await authenticator.authenticate(reason: prompt) else {
            log(credential, .denied, "Not approved")
            return FillResponse(ok: false, message: "The person did not approve.")
        }

        do {
            let value = request.field == .password ? try vault.secret(for: credential) : credential.username
            if let problem = await filler.fill(value, field: request.field) {
                log(credential, .failed, problem)
                return FillResponse(ok: false, message: problem)
            }
            log(credential, .approved, "Filled \(request.field.rawValue)")
            return FillResponse(ok: true, message: "Filled the \(request.field.rawValue) field.")
        } catch {
            log(credential, .failed, "Could not read the saved credential")
            return FillResponse(ok: false, message: "Could not read the saved credential.")
        }
    }
}

import AppKit
import HavenCore
import HavenSecurity

/// Owns the vault, the audit log and the local socket that agents' `haven-vault` calls arrive on.
final class VaultController {
    let vault = CredentialVault.standard()
    let audit = AuditLog.appSupport()
    private let store: TaskStore
    private var server: VaultServer?
    private lazy var service = SecureFillService(
        vault: vault, authenticator: TouchIDAuthenticator(), filler: SystemFieldFiller(), audit: audit,
        currentPageURL: { await MainActor.run { Self.frontBrowserURL() } })

    init(store: TaskStore) { self.store = store }

    func start() {
        let server = VaultServer { [weak self] request in
            guard let self else { return WireResponse(ok: false, message: "Haven is shutting down.") }
            return await self.handle(request)
        }
        do { try server.start(); self.server = server } catch { NSLog("Haven vault socket failed: \(error)") }
    }

    func stop() { server?.stop() }

    var hasLogins: Bool { !vault.all().isEmpty }

    private func handle(_ request: WireRequest) async -> WireResponse {
        // An agent may only ask while one of its tasks is running.
        let title: String? = await MainActor.run {
            store.tasks.first { $0.id.uuidString == request.task && $0.status == .working }?.instruction
        }
        guard let title else {
            audit.append(credential: "(none)", site: OriginPolicy.normalize(host: request.site), task: "(no active task)",
                         reason: request.reason, outcome: .refused, detail: "Request did not come from a running task")
            return WireResponse(ok: false, message: "Logins can only be requested by a running Haven task.")
        }
        let result = await service.handle(FillRequest(site: request.site, field: request.field, reason: request.reason,
                                                      taskID: request.task, taskTitle: title))
        return WireResponse(ok: result.ok, message: result.message)
    }

    /// URL of the active tab, if a supported browser is frontmost.
    @MainActor private static func frontBrowserURL() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return ContextCapture.browserTab(of: app)?.url
    }

    /// Prompt addition that tells an agent how to sign in without being given a password.
    static let agentNote = """
    Saved logins are available. If a page needs you to sign in, click the field, then run \
    `haven-vault login --site <host> --field username|password --reason "<why>"`. The person approves with Touch ID \
    and Haven types the value into the field. You will never see the username or password, so do not ask for them.
    """
}

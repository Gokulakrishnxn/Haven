import AppKit
import HavenCore
import HavenSecurity

/// Owns the vault, the audit log and the local socket that agents' `haven-vault` calls arrive on.
final class VaultController {
    let vault = CredentialVault.standard()
    let audit = AuditLog.appSupport()
    private let store: TaskStore
    @MainActor private lazy var mac = MacController()
    /// Tasks the person has allowed to control apps.
    private var macGrants = Set<String>()
    private let macLock = NSLock()
    /// Created lazily on the main actor, where its panel lives.
    @MainActor private lazy var approvals = ApprovalPresenter()
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
        let found: (title: String, agent: Agent)? = await MainActor.run {
            store.tasks.first { $0.id.uuidString == request.task && $0.status == .working }.map { ($0.instruction, $0.agent) }
        }
        guard let found else {
            audit.append(credential: request.action == "approve" ? "(approval)" : "(none)",
                         site: OriginPolicy.normalize(host: request.site), task: "(no active task)",
                         reason: request.reason, outcome: .refused, detail: "Request did not come from a running task")
            return WireResponse(ok: false, message: "Requests can only come from a running Haven task.")
        }
        let title = found.title

        if request.action == "mac" { return await handleMac(request, taskTitle: title, agent: found.agent) }

        if request.action == "approve" {
            let allowed = await MainActor.run { approvals }.ask(agent: found.agent, task: title, summary: request.summary, reason: request.reason)
            audit.append(credential: "(approval)", site: "-", task: title, reason: "\(request.summary) — \(request.reason)",
                         outcome: allowed ? .approved : .denied, detail: allowed ? "Allowed once" : "Denied or timed out")
            return WireResponse(ok: allowed, message: allowed ? "Approved." : "Denied. Do not take this action.")
        }
        let result = await service.handle(FillRequest(site: request.site, field: request.field, reason: request.reason,
                                                      taskID: request.task, taskTitle: title))
        return WireResponse(ok: result.ok, message: result.message)
    }

    /// Mac control: reading is open to running tasks; anything that changes the screen needs a yes, once per task.
    private func handleMac(_ request: WireRequest, taskTitle: String, agent: Agent) async -> WireResponse {
        func log(_ outcome: AuditOutcome, _ detail: String) {
            audit.append(credential: "(mac control)", site: request.command, task: taskTitle,
                         reason: Self.describe(request), outcome: outcome, detail: detail)
        }
        guard let command = MacCommand(rawValue: request.command) else {
            log(.refused, "Unknown command")
            return WireResponse(ok: false, message: "Unknown command \(request.command).")
        }
        if command.mutates {
            let granted = macLock.withLock { macGrants.contains(request.task) }
            if !granted {
                let allowed = await MainActor.run { approvals }.ask(
                    agent: agent, task: taskTitle, summary: "see and control apps on your Mac",
                    reason: "It wants to \(command.rawValue) as part of this task. Passwords and password managers stay off limits.",
                    allowLabel: "Allow for this task")
                guard allowed else {
                    log(.denied, "Mac control not allowed")
                    return WireResponse(ok: false, message: "Denied. Do not control apps for this task.")
                }
                macLock.withLock { _ = macGrants.insert(request.task) }
            }
        }
        do {
            let text = try await MainActor.run { mac }.run(command, args: request.args)
            if command.mutates || command == .snapshot { log(.approved, command == .snapshot ? "Read a window outline" : "Done") }
            return WireResponse(ok: true, message: text)
        } catch let failure as MacController.Failure {
            log(.failed, failure.message)
            return WireResponse(ok: false, message: failure.message)
        } catch {
            log(.failed, "\(error)")
            return WireResponse(ok: false, message: "\(error)")
        }
    }

    /// What goes in the audit log. Typed text is never recorded, only its length.
    private static func describe(_ r: WireRequest) -> String {
        var args = r.args
        if let text = args.removeValue(forKey: "text") { args["text"] = "\(text.count) characters" }
        return args.isEmpty ? r.command : r.command + " " + args.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }

    /// URL of the active tab, if a supported browser is frontmost.
    @MainActor private static func frontBrowserURL() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return ContextCapture.browserTab(of: app)?.url
    }

    /// Prompt addition for agents. Approval is always offered; sign-in only when logins are saved.
    static func agentNote(hasLogins: Bool) -> String {
        var note = """
        Before any action that is hard to undo (sending a message, deleting, purchasing, submitting a form), ask the person \
        first by running `haven-vault approve --action "<what you are about to do>" --reason "<why>"`. \
        Continue only if it exits successfully and prints Approved.
        """
        note += """


        You can see and control Mac apps with `haven-mac`: `snapshot [--app NAME]` prints an outline of the window with [eN] references; \
        `click --ref eN` (or `--x N --y N`), `type --text "..." [--ref eN]`, `key --combo cmd+s`, `scroll --dy N`, \
        `list-apps`, `open-app --name NAME`. Take a fresh snapshot before using references. The person is asked once per task \
        before you change anything. Password fields, password managers and System Settings are off limits; use haven-vault for logins.
        """
        if hasLogins {
            note += """

            Saved logins are available. If a page needs you to sign in, click the field, then run \
            `haven-vault login --site <host> --field username|password --reason "<why>"`. The person approves with Touch ID \
            and Haven types the value into the field. You will never see the username or password, so do not ask for them.
            """
        }
        return note
    }
}

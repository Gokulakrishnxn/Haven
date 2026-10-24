# Haven — Delivery Plan

Companion to [prd.md](prd.md) and [design.md](design.md). Dates are relative to project start (W1 = week 1).

## 1. Working agreements

- **Branches:** `main` is production and always builds. `design` carries UI, UX and site changes. `features` carries capability work. Nothing reaches `main` except through a pull request.
- **Commits:** one logical change each, imperative subject with a type prefix (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`).
- **Pull requests:** state summary, changes, why, how it was verified, known limits.
- **Definition of done:** builds clean, tests pass, accessibility checked (VoiceOver, keyboard), docs updated, security checklist reviewed for any change that touches permissions, credentials or agent execution.

## 2. Milestones

| Milestone | Window | Exit criteria |
|---|---|---|
| **M0 Scaffold** | done | Shortcut composer, context capture, background tasks, status pill, task window |
| **M1 Runtime** | W1–W3 | Package split (Core/Runtime/UI), adapter protocol, streaming events for Claude Code and Codex, process supervisor with cancel and timeout, contract tests |
| **M2 Task Center** | W3–W5 | Event timeline, live output, rerun, persistence (SQLite), onboarding with CLI detection |
| **M3 Annotate** | W5–W9 | Overlay on all displays, AX capture for native apps, Chrome extension and native-messaging bridge, structured brief, pin state |
| **M4 Trust** | W9–W12 | Vault (Keychain + Touch ID), origin verification, approval policy engine, audit log, injection test suite |
| **M5 Release 1.0** | W12–W14 | Hardened runtime, signing, notarization, Sparkle updates, crash reporting (opt-in), public site live |
| **M6 Reuse** | W14–W18 | Quick Actions, selection popup, MCP and skills per task, Grok adapter, notch UI |

## 3. Work breakdown

### M1 Runtime
1. Split into SwiftPM targets: `HavenCore`, `HavenRuntime`, `HavenSecurity`, `HavenUI`, `Haven` (executable).
2. Define `AgentAdapter` (detect, launch, event stream, cancel).
3. Implement Claude Code and Codex adapters emitting `TaskEvent`.
4. `ProcessSupervisor`: one process group per task, SIGTERM then SIGKILL, timeouts, resource limits.
5. Contract tests using recorded fixtures per adapter version.

### M2 Task Center
1. Event-sourced task state; SQLite store with migrations.
2. Timeline view (messages, tool calls, approvals, result).
3. Onboarding: detect CLIs, show auth state, link to install help.
4. Settings: shortcuts, default agent, retention.

### M3 Annotate
1. Overlay window per display, above all spaces, click-through off only in Annotate mode.
2. Native capture via AX hit-test; fall back to region capture with screenshot.
3. Browser extension (Manifest V3): hit-test, selector generation, text and role, bounds; native-messaging host in the app.
4. Brief builder: JSON schema plus markdown renderer; version the schema.
5. Pin lifecycle bound to task events.

### M4 Trust
1. `Vault`: Keychain items with access control requiring user presence.
2. Origin verification before fill (exact origin match, visible login form, no cross-origin frames).
3. `PolicyEngine`: action classes and defaults; per-task overrides.
4. Append-only `AuditLog` with hash chaining; export.
5. Security test suite: injection corpora, origin spoofing, fill into hidden fields.

### M5 Release
1. Hardened runtime, entitlements review, helper sandboxing.
2. Developer ID signing, notarization, DMG, Sparkle appcast.
3. Site: landing, security page, docs, download.
4. Beta program; crash-free rate gate at 99.5 %.

### M6 Reuse
1. Quick Action model and editor.
2. Selection popup via AX-triggered, non-activating panel.
3. MCP client and skills loader scoped per task.
4. Notch rendering where `NSScreen.safeAreaInsets` indicates one.

## 4. Quality gates

| Gate | Check |
|---|---|
| Build | `swift build` and `swift test` on CI (macOS runner) |
| Static | SwiftLint and `swift-format` in CI |
| Performance | Composer latency benchmark; idle CPU and memory budget |
| Accessibility | VoiceOver walkthrough of every surface per release |
| Security | Threat-model review per milestone; injection suite must pass |
| Privacy | Verify no network egress from Haven itself except updater |

## 5. Risks and contingencies

| Risk | Contingency |
|---|---|
| Adapter output format changes | Pin supported CLI versions; fall back to plain-text mode |
| Notarization or entitlement issues | Start signing in M1, not M5 |
| Extension store review delay | Ship as developer-mode unpacked extension during beta |
| Scope creep in Annotate | Browser-first; native AX capture cut to element and region only |

## 6. Team and ownership

Single maintainer today (Gokulakrishnxn). Roles to fill for 1.0: design review, security review, QA on assistive tech.

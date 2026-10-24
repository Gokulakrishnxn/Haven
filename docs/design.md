# Haven — Design Document

Architecture, interaction design and visual system. Companion to [prd.md](prd.md) and [plan.md](plan.md).

---

## Part I — System architecture

### 1. Context

```
                 ┌────────────────────────────────────────────┐
                 │                   User                      │
                 └───────┬──────────────────────────▲─────────┘
                  ⌥Space │ ⌥⇧Space (annotate)       │ pill · task center · approvals
                         ▼                          │
┌────────────────────────────────────────────────────────────────────────────┐
│                               Haven.app                                    │
│                                                                            │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────────────────────┐   │
│  │  HavenUI     │  │  HavenCore      │  │  HavenSecurity               │   │
│  │ composer     │◀▶│ domain model    │◀▶│ Vault · Policy · Audit       │   │
│  │ overlay      │  │ Task · Context  │  │ Approvals · Origin check     │   │
│  │ pill/notch   │  │ Brief · Events  │  └──────────────────────────────┘   │
│  │ task center  │  └───────┬─────────┘                                     │
│  └──────────────┘          │                                               │
│                            ▼                                               │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ HavenRuntime                                                      │     │
│  │  Scheduler ─▶ ProcessSupervisor ─▶ AgentAdapter[Claude|Codex|Grok]│     │
│  │       │                                    │                      │     │
│  │       └──── CapabilityBroker ◀─────────────┘                      │     │
│  │              ├─ BrowserBridge (native messaging)                  │     │
│  │              ├─ MacAutomation (AX · AppleScript)                  │     │
│  │              └─ McpHost · SkillLoader                             │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                            │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ HavenStore: SQLite (encrypted) · event log · audit chain          │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└───────────────┬──────────────────────────────┬─────────────────────────────┘
                │ stdio / pty                  │ native messaging
                ▼                              ▼
        Agent CLIs (user-installed)     Chrome extension (MV3)
```

### 2. Modules (SwiftPM targets)

| Target | Responsibility | May depend on |
|---|---|---|
| `HavenCore` | Pure domain types: `Task`, `TaskEvent`, `Context`, `Brief`, `Pin`, `Approval`. No I/O. | none |
| `HavenSecurity` | `Vault`, `PolicyEngine`, `AuditLog`, `OriginVerifier`. | Core |
| `HavenRuntime` | `Scheduler`, `ProcessSupervisor`, adapters, `CapabilityBroker`, bridges. | Core, Security |
| `HavenStore` | Persistence and migrations. | Core |
| `HavenUI` | AppKit surfaces and view models. | Core |
| `Haven` | Executable: composition root, lifecycle, menu bar. | all |

Rule: UI never touches processes or Keychain directly; it talks to services through protocols defined in Core.

### 3. Key abstractions

```swift
protocol AgentAdapter {
    var id: AgentID { get }
    func detect() async -> AgentAvailability          // installed? signed in? version?
    func launch(_ request: AgentRequest) -> AsyncStream<TaskEvent>
    func cancel(_ task: TaskID) async
}

enum TaskEvent {
    case started, text(String), toolUse(ToolCall)
    case approvalRequested(Approval), credentialRequested(CredentialRequest)
    case finished(Result<Output, Failure>)
}
```

State is **event-sourced**: a task's UI, history and audit all derive from its `TaskEvent` stream. This makes the timeline, replay and crash recovery the same code path.

### 4. Task lifecycle

```
 queued ─▶ running ─▶ awaitingApproval ─▶ running ─▶ succeeded
    │          │              │                         │
    │          └──────────────┴──▶ failed / cancelled   └▶ (save as Quick Action)
    └─────────────────────────────▶ cancelled
```

Each task owns a process group and a working directory. The supervisor enforces timeouts and kills the whole group on cancel. A task crash emits `finished(.failure)` and touches nothing else.

### 5. Annotation pipeline

```
 pointer ─▶ HitTester ─┬─ Browser?  ─▶ BrowserBridge ─▶ {selector, role, text, bounds, url}
                       └─ Native?   ─▶ AX hit-test   ─▶ {role, title, value, frame, app, window}
          region drag ─▶ ScreenCapture (crop) ───────────────▶ {png, frame}
                                   │
                                   ▼
                          PinSet (numbered, noted)
                                   │
                                   ▼
                BriefBuilder ─▶ Brief v1 (JSON) + markdown rendering
                                   │
                                   ▼
                              Task context
```

Brief schema (v1, abridged):

```json
{
  "version": 1,
  "instruction": "Make this match the spec",
  "pins": [{
    "n": 1,
    "kind": "web-element",
    "origin": "https://app.example.com/settings",
    "selector": "main > form button.primary",
    "role": "button", "text": "Save",
    "bounds": {"x": 412, "y": 640, "w": 96, "h": 36},
    "note": "Too small; should be 44pt tall",
    "screenshot": "pins/1.png"
  }]
}
```

Page text in a brief is wrapped and labeled as untrusted data when rendered for the agent.

### 6. Security architecture

**Trust boundaries**

```
 [User intent] ═══ trusted
 [Haven process] ═ trusted, minimal
 [Agent CLI]  ──── semi-trusted (acts for user, can be misled)
 [Web pages, documents, selections] ─ UNTRUSTED data
```

**Controls**

| Threat | Control |
|---|---|
| Prompt injection from page content | Untrusted content is delimited and labeled; it cannot change the approval policy; outbound or destructive actions need explicit approval regardless of agent claims |
| Credential exfiltration | Vault returns values only to the fill primitive, which writes into a verified field; values are never serialized into events, logs or prompts |
| Wrong-site fill | Exact origin match, top-frame only, visible login form, field-type verification |
| Over-broad capability | Capabilities granted per task and per origin or app; expire on task end |
| Silent actions | Approval classes: read, write, send, delete, spend. Defaults: read auto, others ask |
| Tampered audit | Hash-chained append-only log; export includes chain head |
| Helper compromise | Browser bridge and automation helpers run as separate processes with narrow entitlements |

**Permissions (just-in-time)**: Accessibility (annotate native, selection), Screen Recording (region capture), Automation (per app), Keychain access (vault). Each is requested at the moment the feature is first used, with a one-line reason, and the feature degrades gracefully without it.

### 7. Persistence

SQLite with WAL, encrypted at rest using a key held in Keychain. Tables: `tasks`, `events`, `briefs`, `actions`, `audit` (hash-chained), `settings`. Retention is user-configurable; audit is exempt unless the user exports and clears it.

### 8. Performance budget

| Path | Budget |
|---|---|
| Shortcut to composer visible | < 200 ms p95 (composer window kept warm) |
| Annotate overlay on | < 150 ms |
| Brief build (5 pins) | < 300 ms |
| Idle | < 1 % CPU, < 120 MB |

### 9. Testing strategy

- Unit tests for Core and Security (pure, fast).
- Adapter contract tests against recorded CLI transcripts.
- Property tests for selector generation stability.
- Security suite: injection corpus, origin spoofing, hidden-field fill.
- UI tests for composer, annotate and approval flows; accessibility audits.

---

## Part II — Interaction and visual design

### 10. Design philosophy

Haven should feel like it shipped with macOS. Four rules:

1. **Deference.** The user's work is the content; Haven's chrome stays small and translucent.
2. **Clarity.** One primary action per surface. Plain language. No jargon in UI.
3. **Depth.** Layers communicate state: composer above, pill beside, task center behind.
4. **Restraint.** No badges, no counters except where they carry meaning, no sounds by default.

### 11. Surfaces

| Surface | Purpose | Form |
|---|---|---|
| **Composer** | Start a task | 600 pt wide floating panel, vibrancy `hudWindow`, 14 pt radius, centered in the upper third |
| **Annotate overlay** | Point and note | Full-screen, 8 % dim, crosshair cursor, numbered pins |
| **Status pill** | Glanceable state | 30 pt tall capsule, top-center; becomes notch extension on notch Macs |
| **Task Center** | Review and act | Split window: list, timeline, result |
| **Approval sheet** | Authorize an action | Small sheet anchored to the pill; Touch ID where relevant |
| **Settings** | Configure | Standard macOS Settings window with toolbar tabs |

### 12. Composer

```
┌────────────────────────────────────────────────────────────┐
│  [ Safari · “selected text preview…” ]  ✕                  │  context chip(s)
│                                                            │
│  What should Haven do?                                     │  18 pt, no border
│                                                            │
│  ◉ Claude Code ▾        ⌘K Capabilities      ↩ Run   ⎋     │  footer
└────────────────────────────────────────────────────────────┘
```

- Opens with focus in the field; the previous app stays active behind it.
- Context chips are removable. Dropping a file adds a chip.
- `⌘K` opens a compact capability picker (browser, files, MCP, skills) for this task only.
- `⌘↩` runs and keeps the composer open for a parallel task.

### 13. Annotate mode

- Enter: `⌥⇧Space`. Exit: `⎋`.
- Hover highlights the element under the pointer with a 2 pt accent outline and a role label.
- Click: places pin and opens a one-line note field anchored to it.
- Drag: draws a region pin. Shift-click: adds to the set.
- Bottom center: a floating bar with instruction field, agent chip and `↩ Send`.
- Pins stay visible after sending, colored by task state.

### 14. Status pill and notch

| State | Appearance |
|---|---|
| Idle with no tasks | Hidden |
| Working | Amber dot (soft pulse), "2 tasks working" |
| Needs approval | Blue dot, "Approve to continue" |
| Done | Green dot, brief "Done" then settles |
| Failed | Red dot, "1 failed" |

On Macs with a notch the pill merges into the notch's expanded area. Reduce Motion replaces pulse with a static dot.

### 15. Task Center

- Left: tasks grouped by state, each with title, agent, elapsed.
- Center: event timeline (messages, tool calls, approvals) with collapsible detail.
- Right (optional): result, files changed, artifacts, *Save as action*.
- Keyboard: `↑↓` navigate, `⌘.` cancel, `⌘R` rerun.

### 16. Approvals and credentials

An approval states **what**, **where**, **why**, in one sentence each, with *Allow once*, *Allow for this task*, and *Deny*. Credential requests additionally invoke Touch ID and show the site's verified origin. No value is ever displayed.

### 17. Visual system

| Token | Value |
|---|---|
| Typeface | SF Pro (system); SF Mono for output |
| Sizes | 11 caption · 13 body · 15 title · 18 composer input · 28 display |
| Corner radius | 8 control · 14 panel · capsule for pill |
| Material | System vibrancy (`hudWindow`, `sidebar`); no custom blurs |
| Accent | System accent color; semantic: working = `systemOrange`, approval = `systemBlue`, success = `systemGreen`, failure = `systemRed` |
| Spacing | 4 pt grid: 4 · 8 · 12 · 16 · 24 |
| Motion | 180 ms ease-out for appear; 120 ms for dismiss; spring only on pill state change; all respect Reduce Motion |
| Iconography | SF Symbols, regular weight |

Dark and light are first-class; nothing hard-codes a color.

### 18. Accessibility

- Every control labeled; composer announces attached context.
- Annotate mode is fully keyboard-operable: arrow keys step between detectable elements, `Space` places a pin.
- Pill state changes post accessibility announcements.
- Honors Reduce Motion, Reduce Transparency, Increase Contrast, and system text sizing where applicable.

### 19. Onboarding

Three screens, each skippable: (1) shortcut and what Haven does, (2) detect and connect installed agents, (3) optional permissions explained one at a time. Haven is usable after screen 2.

### 20. Voice and copy

Short, declarative, human. Say what happened and what's next. Avoid "AI", "assistant", "magic". Errors state the cause and the fix.

---

## Part III — Landing site

`site/`: Next.js (App Router, TypeScript), statically prerendered, no tracking.

**Stack (shared with the Aria project for consistency):** Tailwind CSS v4, shadcn `radix-nova` primitives (`Button`, `Card`, plus an `Accordion` built on `radix-ui`), `lucide-react` icons, `motion` for the hero demo, and the same neutral oklch token set, following the system light or dark appearance.

**Sections:** hero with animated shortcut-to-pill demo, "new gesture" statement, Anywhere, Annotate, Detach, Bring your own brain, Security, capabilities grid, FAQ, closing call to action.

**Principles:** SF system typography, restrained monochrome with semantic status colors (working, approval, done), generous space, glass surfaces, `prefers-reduced-motion` respected, semantic landmarks and keyboard-operable accordion.

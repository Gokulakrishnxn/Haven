# Haven — Product Requirements Document

| | |
|---|---|
| **Owner** | Gokulakrishnxn |
| **Status** | Draft v1 |
| **Platform** | macOS 13+ (Apple silicon first) |
| **Related** | [plan.md](plan.md) · [design.md](design.md) · [../README.md](../README.md) |

---

## 1. Summary

Haven is a native macOS command surface for AI agents. The user invokes it from the work in front of them, points at what they mean, says what they want, and lets the agent finish in the background across the browser, files and apps.

**Positioning:** *Cursor for your entire Mac, with a visual pointer.* Haven combines two ideas:

1. **Detach-style harness.** Global shortcut, bring-your-own agent, background tasks, credential boundary.
2. **Annotation as input.** Click an element, select a region, drop a note. Haven turns the pointing gesture into structured context (selector, role, text, screenshot) that agents can act on precisely. This extends the idea behind Agentation (web-only, React-only) to the whole Mac.

## 2. Problem

| # | Problem | Evidence in daily use |
|---|---|---|
| P1 | Chat apps make you carry context to the agent | Copy, paste, describe "the blue button on the left" |
| P2 | Agents are trapped in one window | An IDE agent cannot act in the browser; a browser agent cannot touch files |
| P3 | Vague references produce wrong edits | "Fix this" without a selector or element identity |
| P4 | Logged-in work forces a bad choice | Give the agent a password, or do it yourself |
| P5 | Long tasks need babysitting | A watched terminal is wasted attention |
| P6 | Tooling sprawl | Global plugin lists nobody curates |

## 3. Goals and Non-goals

### Goals
- G1. Invoke an agent from any app in under 200 ms, with context attached.
- G2. Let users **point** at things (web element, native control, region, file, selection) and annotate them.
- G3. Run tasks in the background, in parallel, with calm, glanceable status.
- G4. Complete logged-in work without any credential entering model context.
- G5. Be agent-agnostic: Claude Code, Codex, Grok today; others by adapter.
- G6. Make every sensitive action reviewable, before and after.
- G7. Feel like a first-party Apple utility: fast, quiet, keyboard-first, accessible.

### Non-goals
- A chat client with history, tabs and sidebars.
- A new foundation model.
- Windows or Linux.
- A coding-only tool.

## 4. Users

| Persona | Job to be done | Primary entry point |
|---|---|---|
| **Developer** | "Fix this error / review this diff / change this component" | Terminal or editor selection; web annotation on a running app |
| **Designer / PM** | "This spacing is off; make it match" | Annotate a live page or app window |
| **Operator** | "Process these approvals in our admin tool" | Browser task with secure login |
| **Researcher** | "Read these tabs and summarize" | Selected text, tab context |
| **Power user** | "Turn this into a one-key action" | Quick Actions |

## 5. Principles

1. **Invoke from the work.** Haven is not a destination.
2. **Point, don't describe.** Structured context beats prose.
3. **Detach, don't babysit.** Progress recedes; attention returns only when needed.
4. **The user holds the keys.** Agents ask; the user approves.
5. **Quiet by default.** No badges, no feeds, no nagging.

## 6. Core user journeys

### J1. Ask from anywhere
1. User presses `⌥Space`. The composer appears over the current app with frontmost app and selection attached.
2. User picks an agent (remembered from last time), types, presses `↩`.
3. Composer dismisses. A status pill appears and the task runs.

### J2. Annotate and send
1. User presses `⌥⇧Space` to enter Annotate mode. The screen dims slightly; a crosshair follows the pointer.
2. User clicks an element, drags a region, or shift-clicks several. Each gets a numbered pin and a note field.
3. User presses `↩`. Haven packages pins (element identity, text, bounds, screenshot crop, URL or app) as a structured brief and starts a task.
4. Pins show live state (queued, working, done) until the task ends.

### J3. Detach and return
1. Tasks recede to the pill (or notch where available).
2. When a task needs approval or finishes, the pill changes state quietly. Click opens the Task Center at that task.

### J4. Secure sign-in
1. The agent reaches a login page and requests a credential scoped to *site* and *task*.
2. macOS shows a Touch ID sheet naming the site and reason.
3. Haven fills the verified field directly from Keychain. The value never enters model context. The event is written to the audit log.

### J5. Save as Quick Action
1. After a successful task, user chooses *Save as action*, names it, and assigns an optional shortcut.
2. On selected text in any app, the action appears in the contextual popup and runs in one step.

## 7. Functional requirements

Priority: **P0** ships in v1.0, **P1** in v1.x, **P2** later.

### 7.1 Invocation and context
| ID | Requirement | Pri |
|---|---|---|
| F1 | Global shortcut opens composer; configurable | P0 |
| F2 | Attach frontmost app, selected text, files (drag or Finder selection), active browser tab | P0 |
| F3 | Context remains bound to the task after the composer closes | P0 |
| F4 | Selection popup with Quick Actions in any app | P1 |

### 7.2 Annotation
| ID | Requirement | Pri |
|---|---|---|
| F5 | Annotate mode overlay across all displays | P0 |
| F6 | Browser: capture CSS selector, tag, role, text, bounding box, URL via extension | P0 |
| F7 | Native apps: capture AX role, title, value, frame, window and app via Accessibility | P0 |
| F8 | Region capture with screenshot crop | P0 |
| F9 | Multiple numbered pins with per-pin notes, reorder and delete | P0 |
| F10 | Output as structured JSON plus agent-readable markdown | P0 |
| F11 | Optional integration with `agentation-mcp` to enrich React source locations | P2 |
| F12 | Pin state reflects task progress | P1 |

### 7.3 Agents
| ID | Requirement | Pri |
|---|---|---|
| F13 | Adapters for Claude Code and Codex | P0 |
| F14 | Adapter for Grok | P1 |
| F15 | Per-task agent and model selection; sensible remembered default | P0 |
| F16 | Detect installed CLIs and their auth state; guide the user when missing | P0 |
| F17 | Stream structured events (text, tool use, approval request, result) from adapters | P0 |

### 7.4 Capabilities
| ID | Requirement | Pri |
|---|---|---|
| F18 | Browser control in the user's Chrome profile, only on connected sites | P0 |
| F19 | macOS automation via Accessibility and AppleScript with per-app consent | P1 |
| F20 | MCP servers attachable per task | P1 |
| F21 | Skills attachable per task | P1 |
| F22 | Capabilities are per task, never a global dashboard | P0 |

### 7.5 Tasks
| ID | Requirement | Pri |
|---|---|---|
| F23 | Background execution, one supervised process per task | P0 |
| F24 | Parallel tasks; failure of one never affects others | P0 |
| F25 | Status pill (and notch on supported Macs) | P0 |
| F26 | Task Center: list, live event timeline, final result, cancel, rerun | P0 |
| F27 | Task history persisted locally | P1 |
| F28 | Notifications only for approvals and completions of long tasks | P1 |

### 7.6 Credentials and trust
| ID | Requirement | Pri |
|---|---|---|
| F29 | Credentials live only in macOS Keychain | P0 |
| F30 | Touch ID (or password fallback) for every fill | P0 |
| F31 | Values never enter model context or logs | P0 |
| F32 | Fill only verified login fields on the requested origin | P0 |
| F33 | Scoped grants: site + task + reason | P0 |
| F34 | Append-only audit log, exportable | P0 |
| F35 | Approval policy per action class (read, write, send, delete, spend) | P0 |
| F36 | Destructive or outbound actions always require explicit approval | P0 |

### 7.7 Reuse
| ID | Requirement | Pri |
|---|---|---|
| F37 | Quick Actions: saved prompt, context rule, capabilities | P1 |
| F38 | Workflows: multi-step playbooks | P2 |

## 8. Non-functional requirements

| Area | Requirement |
|---|---|
| **Performance** | Composer visible < 200 ms after shortcut (p95). Idle CPU < 1 %. Idle memory < 120 MB. |
| **Reliability** | Supervisor restarts crashed helpers; tasks are isolated; app never blocks on an agent. |
| **Privacy** | Local-first. No Haven server in the data path. No telemetry without opt-in. |
| **Security** | Hardened runtime, sandboxed helpers, signed and notarized builds. See design.md §Security. |
| **Accessibility** | Full VoiceOver support, keyboard operability, Reduce Motion, Increase Contrast, Dynamic Type-equivalent scaling. |
| **Localization** | English at launch; strings externalized from day one. |
| **Compatibility** | macOS 13+; notch UI optional with graceful fallback on other displays. |

## 9. Success metrics

| Metric | Target (90 days post-launch) |
|---|---|
| Time from shortcut to task start (median) | < 6 s |
| Share of tasks started with context | > 70 % |
| Share of tasks using annotation | > 25 % |
| Average parallel tasks per active session | > 1.5 |
| Task success without follow-up | > 60 % |
| Secure fills approved vs denied | > 90 % approved (trust signal) |
| Week-4 retention | > 40 % |
| Crash-free sessions | > 99.5 % |

## 10. Risks

| Risk | Mitigation |
|---|---|
| Prompt injection from pages and documents | Content is data, never instructions; approvals for outbound or destructive actions; origin-scoped capabilities; injection tests in CI |
| Permission fatigue at onboarding | Request each permission just in time, explain why, work degraded without it |
| Agent CLI changes break adapters | Versioned adapters, contract tests, capability detection |
| Notch absent on many Macs | Pill is the primary surface; notch is progressive enhancement |
| Overlap with Claude desktop, ChatGPT desktop, Raycast | Differentiate on annotation, credential boundary and agent neutrality |
| Agentation licensing (PolyForm Shield) | Own capture implementation; interoperate only through its MCP interface |

## 11. Open questions

1. Browser extension: Chrome only at launch, or Safari and Arc?
2. Pricing: free with bring-your-own agent, paid for hosted credits and team features?
3. Is a team policy layer (shared approval rules) in scope for v1?
4. Distribution: direct download only, or also Mac App Store (sandbox constraints for Accessibility)?

## 12. Release scope

| Release | Scope |
|---|---|
| **v0.1 (now)** | Menu-bar app, shortcut composer, context capture, background tasks, status pill, task window |
| **v0.5** | Adapter protocol with streaming events, Task Center, persistence, onboarding |
| **v0.8** | Annotate mode (browser + native), Chrome extension, structured briefs |
| **v1.0** | Vault, Touch ID fills, audit log, approval policy, signed and notarized release |
| **v1.x** | Quick Actions, MCP and skills per task, Grok, notch UI |
| **v2** | Workflows, team policies |

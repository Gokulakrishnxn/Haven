# Haven

**A native macOS command surface for AI agents.**
Invoke an agent from whatever you are working on, then let it run in the background while you keep working.

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![status](https://img.shields.io/badge/status-early%20scaffold-blue)

---

## Table of Contents

1. [Overview](#overview)
2. [Current Status](#current-status)
3. [System Architecture](#system-architecture)
4. [Component Reference](#component-reference)
5. [Runtime Flow](#runtime-flow)
6. [Security Model](#security-model)
7. [Getting Started](#getting-started)
8. [Repository and Branching](#repository-and-branching)
9. [Roadmap](#roadmap)

---

## Overview

Chat apps make you carry context to the agent. Haven reverses that: press a global shortcut from any app, and the current context (frontmost app, selected text) is attached to a task for the agent of your choice. The composer closes and the task continues in the background.

Haven is model-agnostic. It drives the agent CLIs already installed on your Mac (Claude Code, Codex, Grok) and does not ship its own model.

## Current Status

This repository is an early scaffold. Items below are marked by what exists today.

| Capability | State |
|---|---|
| Menu-bar app, no Dock icon | Implemented |
| Global shortcuts: ⌥Space (ask), ⌥⇧Space (annotate) | Implemented |
| Context capture: frontmost app and selected text | Implemented (selected text needs Accessibility) |
| Composer: two flat dark cards, a live status card ("Working…" with the agent's current activity) above a minimal composer with one agent · model menu, attach, Quick Actions, annotate, history, and a red stop button while a task runs; it stays open as a follow-up surface and Esc detaches it to the notch | Implemented |
| Triple-click selected text in any app for a small menu: Chat, Explain, and your Quick Actions | Implemented (needs Accessibility; not yet tried in many apps) |
| Agents: Claude, Cursor, Codex, Grok | Claude verified (including `--model` aliases); Cursor, Codex and Grok flags unverified |
| Background tasks with live streamed output, cancel, rerun | Implemented |
| Structured events from Claude Code (`stream-json`), process-group cancel and timeout | Implemented, with tests |
| Structured events from Codex and Grok | Planned (plain text for now) |
| Notch bar: wraps the notch (or sits at top center), expands to live output of the latest task plus Ask, Annotate and Tasks actions | Implemented |
| Menu-bar panel with profile, quick actions and recent tasks | Implemented |
| Settings: Profile, General (default agent, working folder, notch bar), Agents, Shortcuts, Privacy, About | Implemented |
| Welcome screen with the Haven logo | Implemented |
| Task Center (SwiftUI split view, header actions, live output) | Implemented |
| Annotate mode: hover highlight, element and region pins, notes, brief | Implemented (element identity needs Accessibility; no screenshot yet) |
| Onboarding, agent detection, Settings | Implemented |
| Chrome extension for DOM selectors | Planned |
| Quick Actions: save a prompt, rerun in one step from the composer, save from a finished task, manage in Settings | Implemented |
| Browser tab as context (Chrome, Arc, Brave, Edge, Safari) | Implemented, not yet verified against a live browser; needs Automation permission |
| Saved logins in Keychain, Touch ID before every fill, origin check, verified-field fill | Implemented (pipeline and Keychain tested; live fill into a real login page not yet verified) |
| `haven-vault` helper agents run to request a login without seeing it | Implemented; verified end to end up to the approval step |
| Audit log of every credential access (hash-chained, verifiable in Settings) | Implemented |
| Haven-hosted credits | Not available (no hosted service exists) |
| Persistence of task history, per-action approval policy | Planned |
| MCP and skills per task | Planned |

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          macOS (user session)                        │
│                                                                      │
│   Any app ──────────────┐                                            │
│   (browser, editor...)  │ ⌥Space                                     │
│                         ▼                                            │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │                       Haven.app (accessory)                   │   │
│  │                                                               │   │
│  │   ┌───────────┐   ┌────────────────┐   ┌───────────────────┐  │   │
│  │   │  HotKey   │──▶│  AppDelegate   │──▶│  ContextCapture   │  │   │
│  │   │ (Carbon)  │   │ (coordinator + │   │ (NSWorkspace +    │  │   │
│  │   └───────────┘   │  status menu)  │   │  Accessibility)   │  │   │
│  │                   └───────┬────────┘   └─────────┬─────────┘  │   │
│  │                           │ TaskContext          │            │   │
│  │                           ▼                      │            │   │
│  │                   ┌────────────────┐             │            │   │
│  │                   │ ComposerPanel  │◀────────────┘            │   │
│  │                   │ (floating UI)  │                          │   │
│  │                   └───────┬────────┘                          │   │
│  │                           │ agent + instruction + context     │   │
│  │                           ▼                                   │   │
│  │                   ┌────────────────┐                          │   │
│  │                   │   TaskStore    │ onChange                 │   │
│  │                   │ (HavenTask[])  │──┬──▶ status menu        │   │
│  │                   └───────┬────────┘  ├──▶ StatusPill         │   │
│  │                           │           └──▶ OutputWindow       │   │
│  └───────────────────────────┼───────────────────────────────────┘   │
│                              │ spawn (one Process per task)          │
│                              ▼                                       │
│              ┌────────────────────────────────┐                      │
│              │ /bin/zsh -lc  (login PATH)     │                      │
│              │   claude -p │ codex exec │ ... │                      │
│              └────────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Design principles

- **Invoke from the work.** Context is captured before Haven takes focus.
- **Detach, don't babysit.** Submitting a task closes the composer; execution continues independently.
- **Isolation.** Each task is its own process. A failure in one never blocks another.
- **Bring your own agent.** Haven shells out to installed CLIs and uses existing subscriptions.
- **Least privilege.** Accessibility is requested only when the user opts in from the menu.

## Component Reference

The package is split into four targets plus tests.

| Target | Path | Responsibility |
|---|---|---|
| `HavenCore` | `Sources/HavenCore/` | Pure domain types: `Agent`, `TaskContext`, `TaskEvent`, `Outcome`, `AgentRequest`, `Pin`, `BriefBuilder`. No I/O. |
| `HavenRuntime` | `Sources/HavenRuntime/` | `ProcessSupervisor` (process groups, cancel, timeout), `AgentAdapter` and output parsers, `ClaudeCodeAdapter` (structured `stream-json`), `AgentRunner`, `AgentRegistry` |
| `HavenUI` | `Sources/HavenUI/` | SwiftUI components and screens (composer, notch bar, menu-bar panel, Task Center, onboarding, settings). Depends only on `HavenCore`; screens render plain data and call closures, so they never touch processes |
| `Haven` | `Sources/Haven/` | The app shell: hotkeys, context capture, Annotate overlay (AppKit), task store, and AppKit hosts for the SwiftUI screens |
| `HavenRuntimeTests` | `Tests/HavenRuntimeTests/` | Parser contract tests against a recorded Claude Code run, and supervisor tests |

App components in `Sources/Haven/`:

| Component | File | Responsibility |
|---|---|---|
| Entry point | `main.swift` | Starts `NSApplication` with the accessory activation policy (menu bar only) |
| Coordinator | `AppDelegate.swift` | Owns the status item, registers the hotkey, wires capture, composer and task store |
| Global shortcut | `HotKey.swift` | Registers ⌥Space through Carbon `RegisterEventHotKey`; needs no extra permission |
| Context capture | `ContextCapture.swift` | Reads the frontmost app, and the focused element's selected text via the Accessibility API when trusted |
| Composer | `ComposerPanel.swift` | Borderless floating `NSPanel` with context chip, agent picker and input; Return submits, Esc closes |
| Task store | `TaskStore.swift` | `HavenTask` model; starts runs through adapters and applies the resulting `TaskEvent`s; cancel, rerun, clear; `onChange` callback for UI |
| Annotate | `AnnotateOverlay.swift`, `ElementProbe.swift`, `Brief.swift` | Full-screen overlay per display; hit-tests the window under the pointer and its Accessibility element; collects numbered pins and notes; builds a markdown and JSON brief that labels captured content as untrusted data |
| Onboarding and settings | `OnboardingWindow.swift`, `SettingsWindow.swift`, `AgentDetector.swift`, `Preferences.swift` | First-run steps, installed-CLI detection, default agent and pill toggle |
| Design tokens | `Theme.swift` | Shared fonts, radii, status colors and vibrancy helper |
| Status pill | `StatusPill.swift` | Non-activating floating pill at top-center showing running count or last result; click opens the output window |
| Task Center | `OutputWindow.swift` | Source-list sidebar of tasks, header with status, elapsed time and Cancel or Run Again, and live output |

Screens are SwiftUI, hosted in AppKit panels and windows. The shell stays AppKit where SwiftUI cannot do the job (borderless non-activating panels, global hotkeys, the full-screen Annotate overlay).

**Building without Xcode:** the SDK in use declares `@State` as a macro whose plugin ships only with full Xcode, so it fails under the Command Line Tools. The UI therefore uses `ObservableObject` view models with `@ObservedObject`, `@StateObject` and `@FocusState`, which compile with the Command Line Tools. Avoid `@State` and `@Observable` until the project requires full Xcode.

Development aid: launch with `HAVEN_SHOW=composer|tasks|onboarding|settings` to open a window at start, and `HAVEN_RUN="prompt"` to start a task with the default agent.

### Quick Actions

Save a prompt that worked (from the composer's bolt menu, or **Save as Action** on a finished task), then run it again in one step. Actions remember their agent and model, run with whatever context is current (app, selection, browser tab, attached files), and are managed under Settings > Quick Actions. They are stored as JSON in Application Support.

### Secure sign-in

```
agent ── haven-vault login --site github.com --field password ──▶ unix socket (0600)
                                                                      │
        Haven: running task? ─▶ saved login? ─▶ page is https://github.com? ─▶ Touch ID
                                                                      │
        Accessibility: focused field is a password field? ─▶ type value ─▶ audit entry
                                                                      │
agent ◀── "Filled the password field." (no value, ever) ─────────────┘
```

### Annotate flow

1. ⌥⇧Space dims every display lightly. Hovering highlights the element under the pointer.
2. Click pins an element; drag pins a region. Each pin is numbered and takes a short note.
3. Return sends the instruction plus all pins as one brief to the chosen agent. ⌫ removes the last pin; ⎋ exits.

### Task model

```
HavenTask
├── agent         Agent (claudeCode | codex | grok)
├── instruction   user text
├── context       TaskContext { appName?, selectedText? }
├── status        working → done | failed
└── output        combined stdout and stderr
```

## Runtime Flow

1. User presses **⌥Space** in any app.
2. `HotKey` fires; `AppDelegate` calls `ContextCapture.capture()` while the previous app is still frontmost.
3. `ComposerPanel` appears with the captured context shown.
4. User picks an agent, types an instruction, presses Return.
5. `TaskStore` builds a prompt (instruction, app name, selected text, annotation brief) and asks `AgentRunner` to launch the agent's adapter. The CLI runs in its own process group through a login shell, and its output is parsed into `TaskEvent`s (text, tool use, finished).
6. The composer closes. The task runs in the background; the status pill shows the running count and the menu lists recent tasks.
7. Clicking the pill (or **Show Tasks…** in the menu) opens the Task Center, where output streams live.
8. On exit, the task becomes `done` (exit code 0) or `failed`, and its output is stored on the task.

## Security Model

Haven runs agents that can act on your machine, so the boundaries matter.

- **Permissions are opt-in.** Selected-text capture needs Accessibility; Haven only prompts when the user chooses "Enable Selected-Text Context…".
- **Passwords never enter model context.** Saved logins live in the macOS Keychain. An agent can only run `haven-vault login --site <host> --field username|password --reason "<why>"`, which has no way to carry a credential value in either direction. Haven checks that the page in front is an https page on exactly that site, asks for Touch ID (with password fallback) naming the site and task, confirms through Accessibility that the focused field is the right kind of field, and types the value as key events (never the clipboard).
- **Only running tasks may ask.** The helper's socket is private to the user (mode 0600, same-user peers only), and a request must carry the ID of a task that is currently running.
- **Every access leaves an audit trail.** Each request, approved, denied or refused, is appended to a hash-chained log with the credential name, site, task and reason, never the value. Settings verifies the chain and flags edits or deletions.
- **Honest limits.** Touch ID is enforced by Haven, not by a Keychain access-control entry (unsigned builds cannot use those). A process running as you could read the Keychain item with your approval. Origin is read from the browser's active tab, so it is only as trustworthy as that browser's scripting interface.
- **Untrusted content is data.** Selected text is passed as context, but page or document content must never be treated as instructions. This is a design requirement for future browser and annotation features.
- **Approvals.** Credential use is approved per use. Broader approvals for writing, sending and deleting are planned.
- **Local-first.** Haven has no server component and sends nothing itself; data goes only to the agent CLI the user selects.

## Getting Started

Requirements: macOS 13+, Swift 5.9+ toolchain (Xcode or Command Line Tools), and at least one agent CLI on your `PATH`.

```bash
git clone https://github.com/Gokulakrishnxn/Haven.git
cd Haven
swift run
```

A house icon appears in the menu bar. Press **⌥Space** to open the composer.

Run the tests (with only the Command Line Tools installed, the testing macro plugin path must be passed explicitly):

```bash
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

With full Xcode, plain `swift test` works.

## Documentation and Site

| Resource | Location |
|---|---|
| Product requirements | [`docs/prd.md`](docs/prd.md) |
| Delivery plan | [`docs/plan.md`](docs/plan.md) |
| Architecture and design | [`docs/design.md`](docs/design.md) |
| Landing site (Next.js) | [`site/`](site/): `cd site && npm install && npm run dev` |

## Repository and Branching

| Branch | Purpose |
|---|---|
| `main` | Production. Always buildable and releasable. |
| `design` | UI and visual changes, including the composer and status UI. |
| `features` | Add-on features such as annotation, Keychain fill and MCP. |

Work lands on `design` or `features` and reaches `main` only through a pull request that explains what changed, why, and how it was verified.

## Roadmap

1. **Notch-integrated status UI** and persistence of task history.
2. **Chrome extension and region screenshots** for annotation: DOM selector, role and text from the page, plus a cropped screenshot (needs Screen Recording). Integration with the `agentation-mcp` server is planned. Agentation is licensed under PolyForm Shield, so Haven will use its own capture layer and integrate only through the MCP interface.
3. **Verify secure fill against real login pages**, add a per-action approval policy, and persist task history.
4. **Parallel task management**, Quick Actions and Workflows.
5. **MCP servers and skills** attached per task.

Detailed milestones are in [`docs/plan.md`](docs/plan.md).

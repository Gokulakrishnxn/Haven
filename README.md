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
| Global shortcut (⌥Space) opens composer | Implemented |
| Context capture: frontmost app and selected text | Implemented (selected text needs Accessibility permission) |
| Agent picker: Claude Code, Codex, Grok | Implemented (Codex and Grok flags unverified) |
| Background task execution, one process per task | Implemented |
| Task status in the menu bar | Implemented |
| Task output viewer (list and detail window) | Implemented |
| Floating status pill (running count, last result) | Implemented |
| Notch-integrated status UI | Planned |
| Browser annotation (Agentation-style) | Planned |
| Keychain secure fill with Touch ID | Planned |
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

All sources live in `Sources/Haven/`.

| Component | File | Responsibility |
|---|---|---|
| Entry point | `main.swift` | Starts `NSApplication` with the accessory activation policy (menu bar only) |
| Coordinator | `AppDelegate.swift` | Owns the status item, registers the hotkey, wires capture, composer and task store |
| Global shortcut | `HotKey.swift` | Registers ⌥Space through Carbon `RegisterEventHotKey`; needs no extra permission |
| Context capture | `ContextCapture.swift` | Reads the frontmost app, and the focused element's selected text via the Accessibility API when trusted |
| Composer | `ComposerPanel.swift` | Borderless floating `NSPanel` with context chip, agent picker and input; Return submits, Esc closes |
| Task engine | `TaskStore.swift` | `Agent` command mapping, `HavenTask` model and state, background process execution, and an `onChange` callback for UI updates |
| Status pill | `StatusPill.swift` | Non-activating floating pill at top-center showing running count or last result; click opens the output window |
| Output window | `OutputWindow.swift` | Split view: task list with status on the left, selected task's output on the right |

The UI is plain AppKit, so the project builds with the Xcode Command Line Tools alone (SwiftUI macros require full Xcode).

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
5. `TaskStore` builds a prompt (instruction, app name, selected text) and spawns the agent CLI through a login shell.
6. The composer closes. The task runs in the background; the status pill shows the running count and the menu lists recent tasks.
7. Clicking the pill (or **Show Tasks…** in the menu) opens the output window.
8. On exit, the task becomes `done` (exit code 0) or `failed`, and its output is stored on the task.

## Security Model

Haven runs agents that can act on your machine, so the boundaries matter.

- **Permissions are opt-in.** Selected-text capture needs Accessibility; Haven only prompts when the user chooses "Enable Selected-Text Context…".
- **No credentials handled.** Haven does not read or store passwords. Planned Keychain fill will keep values out of model context.
- **Untrusted content is data.** Selected text is passed as context, but page or document content must never be treated as instructions. This is a design requirement for future browser and annotation features.
- **Approvals.** Sensitive actions will require explicit user approval (planned).
- **Local-first.** Haven has no server component and sends nothing itself; data goes only to the agent CLI the user selects.

## Getting Started

Requirements: macOS 13+, Swift 5.9+ toolchain (Xcode or Command Line Tools), and at least one agent CLI on your `PATH`.

```bash
git clone https://github.com/Gokulakrishnxn/Haven.git
cd Haven
swift run
```

A house icon appears in the menu bar. Press **⌥Space** to open the composer.

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

1. **Live output streaming** and notch-integrated status UI (output is currently shown once a task finishes).
2. **Chrome annotation mode**: select page elements, attach selector, text and region screenshot to a task. Integration with the `agentation-mcp` server is planned. Agentation is licensed under PolyForm Shield, so Haven will use its own capture layer and integrate only through the MCP interface.
3. **Keychain secure fill** with Touch ID and an audit log.
4. **Parallel task management**, Quick Actions and Workflows.
5. **MCP servers and skills** attached per task.

Detailed milestones are in [`docs/plan.md`](docs/plan.md).

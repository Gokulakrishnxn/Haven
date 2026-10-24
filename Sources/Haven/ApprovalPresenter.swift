import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// Shows one approval card at a time under the notch and returns the person's answer.
/// No answer within the timeout counts as a denial.
@MainActor
final class ApprovalPresenter {
    private let model = ApprovalModel()
    private let panel: NSPanel
    private var queue: [(agent: Agent, task: String, summary: String, reason: String, done: (Bool) -> Void)] = []
    private var showing = false
    private var timeout: DispatchWorkItem?

    private static let timeoutSeconds: TimeInterval = 120

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 372, height: 180),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingController(rootView: ApprovalView(model: model))
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host
        model.onAllow = { [weak self] in self?.answer(true) }
        model.onDeny = { [weak self] in self?.answer(false) }
    }

    func ask(agent: Agent, task: String, summary: String, reason: String) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.append((agent, task, summary, reason, { continuation.resume(returning: $0) }))
            presentNext()
        }
    }

    private func presentNext() {
        guard !showing, let next = queue.first else { return }
        showing = true
        model.agent = next.agent
        model.taskTitle = next.task
        model.summary = next.summary
        model.reason = next.reason

        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        panel.setContentSize(panel.contentViewController?.view.fittingSize ?? panel.frame.size)
        if let screen = NSScreen.main {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.frame.midX - panel.frame.width / 2, y: screen.frame.maxY - 48))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Development aid: HAVEN_AUTO_APPROVE=1 answers Allow after a second so the full path can be tested unattended.
        if ProcessInfo.processInfo.environment["HAVEN_AUTO_APPROVE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.answer(true) }
        }

        let item = DispatchWorkItem { [weak self] in self?.answer(false) }
        timeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutSeconds, execute: item)
    }

    private func answer(_ allowed: Bool) {
        guard showing, !queue.isEmpty else { return }
        timeout?.cancel()
        let finished = queue.removeFirst()
        showing = false
        panel.orderOut(nil)
        finished.done(allowed)
        presentNext()
    }
}

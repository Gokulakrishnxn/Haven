import AppKit
import SwiftUI
import HavenCore
import HavenUI

/// First-run window hosting the SwiftUI onboarding steps.
final class OnboardingWindow: NSWindowController {
    private let model = OnboardingModel()
    private var poll: Timer?
    var onFinish: (() -> Void)?

    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(model: model)))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        model.onGrantAccessibility = { ContextCapture.requestAccessibility() }
        model.onFinish = { [weak self] in
            Preferences.onboarded = true
            self?.poll?.invalidate()
            self?.window?.orderOut(nil)
            self?.onFinish?()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        model.step = 0
        model.detected = nil
        model.accessibilityGranted = AXIsProcessTrusted()
        AgentDetector.detect { [weak self] found in self?.model.detected = Set(found.keys) }
        // The user grants Accessibility in System Settings; reflect it without a restart.
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.model.accessibilityGranted = AXIsProcessTrusted()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }
}

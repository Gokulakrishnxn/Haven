import AppKit
import HavenCore
import HavenRuntime

/// Saved Quick Actions, persisted as JSON in Application Support.
final class QuickActionStore: ObservableObject {
    @Published private(set) var actions: [QuickAction]
    private let file = JSONFileStore<QuickAction>.appSupport("quick-actions.json")

    init() { actions = file.load() }

    func add(_ action: QuickAction) {
        actions.append(action)
        file.save(actions)
    }

    func update(_ action: QuickAction) {
        guard let i = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[i] = action
        file.save(actions)
    }

    func delete(_ id: UUID) {
        actions.removeAll { $0.id == id }
        file.save(actions)
    }

    /// Asks for a name, then saves the prompt. Returns the new action, or nil if cancelled.
    @discardableResult
    func saveWithPrompt(prompt: String, agent: Agent?, model: String?, suggestedName: String) -> QuickAction? {
        let alert = NSAlert()
        alert.messageText = "Save as Quick Action"
        alert.informativeText = "Give it a short name. You can run it again in one step from the composer."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = suggestedName
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .floating
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let action = QuickAction(name: name, prompt: prompt, agent: agent, model: model)
        add(action)
        return action
    }

    static func suggestedName(for prompt: String) -> String {
        let words = prompt.split(separator: " ").prefix(4).joined(separator: " ")
        return words.isEmpty ? "New action" : words
    }
}

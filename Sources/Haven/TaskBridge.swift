import Foundation
import HavenCore
import HavenUI

/// Maps app task objects to the plain data the SwiftUI layer renders.
extension HavenTask {
    var item: TaskItem {
        let state: TaskState
        switch status {
        case .working: state = .working
        case .done: state = .done
        case .failed: state = .failed
        case .cancelled: state = .cancelled
        }
        return TaskItem(id: id, title: instruction, agent: agent, state: state, output: output,
                        context: Self.contextSummary(context), startedAt: startedAt, finishedAt: finishedAt)
    }

    static func contextSummary(_ c: TaskContext) -> String {
        var parts: [String] = []
        if let app = c.appName { parts.append("From \(app)") }
        if let t = c.selectedText { parts.append("“\(t.prefix(120))”") }
        if !c.files.isEmpty { parts.append(c.files.count == 1 ? "1 file" : "\(c.files.count) files") }
        if c.brief != nil { parts.append("With annotations") }
        return parts.joined(separator: " · ")
    }
}
